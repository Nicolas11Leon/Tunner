import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../features/audio_synthesizer/data/soundfont_synthesizer_service.dart';
import '../../features/audio_synthesizer/data/stem_export_persistence_service.dart';
import '../../features/audio_synthesizer/domain/offline_score_wav_renderer.dart';
import '../../features/audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import '../../features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import '../../features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import '../../features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import '../../features/audio_synthesizer/domain/stem_export_entity.dart';
import '../../features/drone/domain/drone_timbre.dart';
import '../../features/drone/domain/harmonic_drone_config.dart';
import '../../features/drone/domain/harmonic_drone_synthesizer.dart';
import '../../features/mixer/domain/mixer_track_entity.dart';
import '../../features/sheet_music/domain/score_tree.dart';
import '../../features/tuner/domain/temperament_engine.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing Pure Dart offline audio synthesis, SoundFont2
/// (.sf2) inspection and rendering, polyphonic chord rendering, stem/MIDI
/// export, and seamless harmonic drone generation.
class SynthDroneMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final SoundFontSynthesizerService _soundFontService;
  final StemAudioSynthesizer _stemSynthesizer;
  final HarmonicDroneSynthesizer _droneSynthesizer;

  SynthDroneMcpModule(
    this.facade, {
    SoundFontSynthesizerService? soundFontService,
    StemAudioSynthesizer? stemSynthesizer,
    HarmonicDroneSynthesizer? droneSynthesizer,
  })  : _soundFontService = soundFontService ?? SoundFontSynthesizerService(),
        _stemSynthesizer = stemSynthesizer ?? const StemAudioSynthesizer(),
        _droneSynthesizer =
            droneSynthesizer ?? const HarmonicDroneSynthesizer();

  @override
  String get moduleName => 'synth_drone';

  PolyphonicVoicePool get _voicePool => facade.root.synthVoicePool;

  OfflineScoreWavRenderer get _scoreRenderer => facade.offlineScoreWavRenderer;

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (4)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://synth/soundfonts/active',
        name: 'Active SoundFont2 Bank',
        description:
            'Metadata of the currently loaded SoundFont2 (.sf2) bank and its available GM presets.',
        mimeType: 'application/json',
        reader: () async {
          final sf = _soundFontService.activeSoundFont;
          final presets = sf.presets
              .map(
                (p) => {
                  'name': p.name,
                  'patch': p.patch,
                  'bank': p.bank,
                  'zoneCount': p.zones.length,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://synth/soundfonts/active',
            data: {
              'soundFontName': sf.soundFontName,
              'activePatch': _soundFontService.activePatch,
              'presetCount': sf.presets.length,
              'instrumentCount': sf.instruments.length,
              'sampleCount': sf.sampleHeaders.length,
              'presets': presets,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://synth/polyphonic/state',
        name: 'Polyphonic Voice Pool State',
        description:
            'Current configuration and active voice telemetry of the PolyphonicVoicePool engine.',
        mimeType: 'application/json',
        reader: () async {
          final pool = _voicePool;
          return McpResourceContent.json(
            uri: 'tunner://synth/polyphonic/state',
            data: {
              'maxPolyphony': pool.maxPolyphony,
              'activeVoiceCount': pool.activeVoiceCount,
              'waveform': pool.waveform.name,
              'pulseWidth': pool.pulseWidth,
              'masterGain': pool.masterGain,
              'sampleRate': pool.sampleRate.round(),
              'adsr': {
                'attackSeconds': pool.attackSeconds,
                'decaySeconds': pool.decaySeconds,
                'sustainLevel': pool.sustainLevel,
                'releaseSeconds': pool.releaseSeconds,
              },
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://drone/timbres',
        name: 'Harmonic Drone Timbres Catalog',
        description:
            'Available procedural timbres for harmonic pedal drone synthesis.',
        mimeType: 'application/json',
        reader: () async {
          final timbres = DroneTimbre.values
              .map(
                (t) => {
                  'id': t.name,
                  'displayName': t.displayName,
                  'description': t.description,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://drone/timbres',
            data: {
              'count': timbres.length,
              'timbres': timbres,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://drone/config/default',
        name: 'Default Harmonic Drone Configuration',
        description:
            'Canonical default HarmonicDroneConfig and its calculated frequencies at A4=440 Hz.',
        mimeType: 'application/json',
        reader: () async {
          const config = HarmonicDroneConfig();
          final freqs = _droneSynthesizer.calculateFrequencies(
            config: config,
            a4Ref: 440.0,
          );
          return McpResourceContent.json(
            uri: 'tunner://drone/config/default',
            data: {
              ...config.toJson(),
              'rootDisplayName': config.rootDisplayName,
              'fifthDisplayName': config.fifthDisplayName,
              'octaveDisplayName': config.octaveDisplayName,
              'rootMidiNumber': config.rootMidiNumber,
              'frequenciesHz': freqs,
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (7)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_synth_tone_wav',
        description:
            'Synthesizes a canonical 16-bit mono WAV file for a pure sine tone, harmonic musical note, or atonal metronome woodblock click.',
        inputSchema: {
          'type': 'object',
          'required': ['type'],
          'properties': {
            'type': {
              'type': 'string',
              'enum': ['sine', 'musical_note', 'metronome_click'],
            },
            'frequencyHz': {'type': 'number', 'minimum': 20.0, 'maximum': 20000.0},
            'durationSeconds': {'type': 'number', 'minimum': 0.02, 'maximum': 30.0},
            'isDownbeat': {'type': 'boolean'},
            'seamlessLoop': {'type': 'boolean'},
            'sampleRate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'outputPath': {'type': 'string'},
          },
        },
        handler: _handleSynthToneWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_synth_score_wav',
        description:
            'Renders the active session score, a provided scoreJson, or a list of timed MIDI note events to a canonical 16-bit mono WAV file via OfflineScoreWavRenderer.',
        inputSchema: {
          'type': 'object',
          'required': ['outputPath'],
          'properties': {
            'outputPath': {'type': 'string'},
            'scoreJson': {'type': 'object'},
            'notes': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['startSeconds', 'durationSeconds', 'midiPitch'],
                'properties': {
                  'startSeconds': {'type': 'number', 'minimum': 0.0},
                  'durationSeconds': {'type': 'number', 'minimum': 0.02},
                  'midiPitch': {'type': 'integer', 'minimum': 0, 'maximum': 127},
                  'velocity': {'type': 'integer', 'minimum': 1, 'maximum': 127},
                  'patch': {'type': 'integer', 'minimum': 0, 'maximum': 127},
                },
              },
            },
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'totalDurationSeconds': {'type': 'number', 'minimum': 0.1, 'maximum': 300.0},
            'sampleRate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'a4Ref': {'type': 'number', 'minimum': 220.0, 'maximum': 880.0},
            'engine': {
              'type': 'string',
              'enum': ['additive', 'sf2', 'polyphonic'],
            },
            'sf2Patch': {'type': 'integer', 'minimum': 0, 'maximum': 127},
          },
        },
        handler: _handleSynthScoreWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_sf2_load_bank',
        description:
            'Loads and inspects an external SoundFont2 (.sf2) bank from the sandboxed workspace, or resets to the built-in Tunner Acoustic Essentials bank.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'sf2FilePath': {'type': 'string'},
            'resetToEssentials': {'type': 'boolean'},
          },
        },
        handler: _handleSf2LoadBank,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_sf2_render_note',
        description:
            'Renders a single MIDI note using the active SoundFont2 bank and patch to a WAV file inside the workspace.',
        inputSchema: {
          'type': 'object',
          'required': ['midiPitch', 'outputPath'],
          'properties': {
            'midiPitch': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            'patch': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            'durationSeconds': {'type': 'number', 'minimum': 0.05, 'maximum': 30.0},
            'velocity': {'type': 'integer', 'minimum': 1, 'maximum': 127},
            'sampleRate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'outputPath': {'type': 'string'},
          },
        },
        handler: _handleSf2RenderNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_polyphonic_render_chord',
        description:
            'Renders a polyphonic chord using PolyphonicVoicePool to a stereo 16-bit WAV file inside the workspace.',
        inputSchema: {
          'type': 'object',
          'required': ['midiNotes', 'durationSeconds', 'outputPath'],
          'properties': {
            'midiNotes': {
              'type': 'array',
              'minItems': 1,
              'items': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            },
            'waveform': {
              'type': 'string',
              'enum': ['sine', 'sawtooth', 'pulse', 'triangle'],
            },
            'durationSeconds': {'type': 'number', 'minimum': 0.05, 'maximum': 30.0},
            'velocity': {'type': 'number', 'minimum': 0.05, 'maximum': 1.0},
            'adsr': {
              'type': 'object',
              'properties': {
                'attack': {'type': 'number', 'minimum': 0.001, 'maximum': 5.0},
                'decay': {'type': 'number', 'minimum': 0.001, 'maximum': 5.0},
                'sustain': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
                'release': {'type': 'number', 'minimum': 0.001, 'maximum': 5.0},
              },
            },
            'sampleRate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'outputPath': {'type': 'string'},
          },
        },
        handler: _handlePolyphonicRenderChord,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_export_stems_and_midi',
        description:
            'Synthesizes individual audio stems, stereo master mixdown WAV, and Standard MIDI File (SMF) for a score and persists them inside the workspace.',
        inputSchema: {
          'type': 'object',
          'required': ['bpm', 'trackTitle'],
          'properties': {
            'scoreJson': {'type': 'object'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'trackTitle': {'type': 'string'},
            'sampleRate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'a4Ref': {'type': 'number', 'minimum': 220.0, 'maximum': 880.0},
            'includeMasterMixdown': {'type': 'boolean'},
            'includeIndividualStems': {'type': 'boolean'},
            'includeMidiFile': {'type': 'boolean'},
            'includeMelodyTrack': {'type': 'boolean'},
            'includeMetronomeTrack': {'type': 'boolean'},
            'includeAccompanimentTrack': {'type': 'boolean'},
            'outputSubfolder': {'type': 'string'},
          },
        },
        handler: _handleExportStemsAndMidi,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_drone_generate_wav',
        description:
            'Generates a seamless looping harmonic pedal drone WAV file with configurable timbre, fifth/octave harmonics, volume, A4 reference, and historical temperament.',
        inputSchema: {
          'type': 'object',
          'required': ['rootNoteIndex', 'octave', 'outputPath'],
          'properties': {
            'rootNoteIndex': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'octave': {'type': 'integer', 'minimum': 0, 'maximum': 8},
            'includeFifth': {'type': 'boolean'},
            'includeOctave': {'type': 'boolean'},
            'timbre': {
              'type': 'string',
              'enum': ['pureSine', 'warmFlute', 'richCello', 'organ'],
            },
            'harmonicBalance': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'volume': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'a4Ref': {'type': 'number', 'minimum': 220.0, 'maximum': 880.0},
            'temperamentId': {'type': 'string'},
            'temperamentRootKey': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'durationSeconds': {'type': 'number', 'minimum': 0.2, 'maximum': 30.0},
            'sampleRate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'outputPath': {'type': 'string'},
          },
        },
        handler: _handleDroneGenerateWav,
      ),
    );
  }

  // ===========================================================================
  // Prompts (2)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'compose_and_render_practice_backing',
        description:
            'Guided workflow to configure a score, synthesize a reference harmonic drone in a target temperament, and export stems + master WAV + MIDI.',
        arguments: const [
          McpPromptArgument(
            name: 'key',
            description: 'Target musical key or tonic (e.g., C, D, La).',
            required: false,
          ),
          McpPromptArgument(
            name: 'bpm',
            description: 'Practice tempo in BPM (default 100).',
            required: false,
          ),
          McpPromptArgument(
            name: 'temperamentId',
            description: 'Historical temperament identifier (default equal).',
            required: false,
          ),
        ],
        builder: (args) async {
          final key = args['key'] ?? 'C';
          final bpm = args['bpm'] ?? '100';
          final temperamentId = args['temperamentId'] ?? 'equal';
          return McpPromptResult(
            description: 'Practice backing track synthesis and stem export workflow.',
            messages: [
              McpPromptMessage.user(
                'Prepare a complete practice backing package in key $key at $bpm BPM '
                'using temperament "$temperamentId".\n'
                '1. Read `tunner://drone/timbres` and `tunner://drone/config/default`.\n'
                '2. Generate a seamless reference drone with `tunner_drone_generate_wav`.\n'
                '3. Render the active score or custom notes with `tunner_synth_score_wav`.\n'
                '4. Export individual stems, stereo master mixdown, and SMF MIDI using '
                '`tunner_export_stems_and_midi`.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'audition_soundfont_instrument_range',
        description:
            'Guided workflow to load an external .sf2 SoundFont bank, inspect presets, and render audition notes across octaves.',
        arguments: const [
          McpPromptArgument(
            name: 'sf2FilePath',
            description: 'Workspace-relative path to the .sf2 SoundFont file.',
            required: true,
          ),
          McpPromptArgument(
            name: 'patch',
            description: 'Optional GM patch number (0..127) to audition.',
            required: false,
          ),
        ],
        builder: (args) async {
          final sf2Path = args['sf2FilePath']!;
          final patch = args['patch'] ?? '0';
          return McpPromptResult(
            description: 'SoundFont2 bank audition workflow.',
            messages: [
              McpPromptMessage.user(
                'Audition SoundFont2 bank at "$sf2Path" (target patch $patch):\n'
                '1. Call `tunner_sf2_load_bank` with `sf2FilePath: "$sf2Path"`.\n'
                '2. Read `tunner://synth/soundfonts/active` to verify presets and zone counts.\n'
                '3. Call `tunner_sf2_render_note` for MIDI notes 48 (C3), 60 (C4), and 72 (C5) '
                'with patch $patch to inspect pitch interpolation and envelope behavior.',
              ),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tool Handlers
  // ===========================================================================

  Future<McpToolResult> _handleSynthToneWav(Map<String, dynamic> args) async {
    final type = _requireString(args, 'type');
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 96000);
    final frequencyHz = _optionalDouble(args, 'frequencyHz') ?? 440.0;
    final durationSeconds =
        (_optionalDouble(args, 'durationSeconds') ?? 1.0).clamp(0.02, 30.0);
    final isDownbeat = _optionalBool(args, 'isDownbeat') ?? true;
    final seamlessLoop = _optionalBool(args, 'seamlessLoop') ?? true;
    final rawOutputPath = _optionalString(args, 'outputPath') ?? 'synth_$type.wav';

    if (frequencyHz <= 0.0 || !frequencyHz.isFinite) {
      throw const McpException.invalidParams(
        'Parameter "frequencyHz" must be a positive finite number.',
      );
    }

    final Uint8List wavBytes;
    final double actualDuration;
    switch (type) {
      case 'sine':
        wavBytes = PcmWavSynthesizer.generateSineToneWav(
          frequency: frequencyHz,
          durationSeconds: durationSeconds,
          sampleRate: sampleRate,
          seamlessLoop: seamlessLoop,
        );
        actualDuration = math.max(0, wavBytes.length - 44) / (2.0 * sampleRate);
      case 'musical_note':
        final durationMs = (durationSeconds * 1000.0).round().clamp(20, 30000);
        wavBytes = PcmWavSynthesizer.generateMusicalNoteWav(
          frequency: frequencyHz,
          durationMs: durationMs,
          sampleRate: sampleRate,
        );
        actualDuration = durationMs / 1000.0;
      case 'metronome_click':
        wavBytes = PcmWavSynthesizer.generateMetronomeClickWav(
          isDownbeat: isDownbeat,
          sampleRate: sampleRate,
        );
        actualDuration = math.max(0, wavBytes.length - 44) / (2.0 * sampleRate);
      default:
        throw McpException.invalidParams(
          'Invalid tone type "$type". Expected sine, musical_note, or metronome_click.',
        );
    }

    final outFile = _resolveWorkspaceFile(rawOutputPath);
    await _writeBytesEnsuringParent(outFile, wavBytes);

    return McpToolResult.json({
      'outputPath': outFile.path,
      'type': type,
      'sizeBytes': wavBytes.lengthInBytes,
      'durationSeconds': actualDuration,
      'sampleRate': sampleRate,
      'channels': 1,
      'bitsPerSample': 16,
    });
  }

  Future<McpToolResult> _handleSynthScoreWav(Map<String, dynamic> args) async {
    final outputPath = _requireString(args, 'outputPath');
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 96000);
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final engine = _optionalString(args, 'engine') ?? 'additive';
    final sf2Patch = _optionalInt(args, 'sf2Patch');

    if (a4Ref <= 20.0 || !a4Ref.isFinite) {
      throw const McpException.invalidParams(
        'Parameter "a4Ref" must be greater than 20 Hz.',
      );
    }

    final SoundFontSynthesizerService? sf2Service =
        engine == 'sf2' ? _soundFontService : null;
    final PolyphonicVoicePool? voicePool =
        engine == 'polyphonic' ? _voicePool : null;

    if (engine != 'additive' && engine != 'sf2' && engine != 'polyphonic') {
      throw McpException.invalidParams(
        'Invalid engine "$engine". Expected additive, sf2, or polyphonic.',
      );
    }

    final rawNotes = args['notes'];
    final rawScoreJson = args['scoreJson'];

    final Uint8List wavBytes;
    final int renderedEventCount;
    final double durationSeconds;
    final String sourceMode;

    if (rawNotes != null) {
      if (rawNotes is! List || rawNotes.isEmpty) {
        throw const McpException.invalidParams(
          'Parameter "notes" must be a non-empty array of note event objects.',
        );
      }
      final events = <OfflineNoteEvent>[];
      double maxEndSec = 0.0;
      for (final item in rawNotes) {
        if (item is! Map<String, dynamic>) {
          throw const McpException.invalidParams(
            'Each item in "notes" must be a JSON object.',
          );
        }
        final startSec = _requireDouble(item, 'startSeconds');
        final durSec = _requireDouble(item, 'durationSeconds');
        final midiPitch = _requireInt(item, 'midiPitch').clamp(0, 127);
        final velocity = (_optionalInt(item, 'velocity') ?? 100).clamp(1, 127);
        final patch = _optionalInt(item, 'patch');
        if (startSec < 0.0 || durSec <= 0.0) {
          throw const McpException.invalidParams(
            'Note events require startSeconds >= 0 and durationSeconds > 0.',
          );
        }
        events.add(
          OfflineNoteEvent(
            startSeconds: startSec,
            durationSeconds: durSec,
            midiPitch: midiPitch,
            velocity: velocity,
            patch: patch,
          ),
        );
        maxEndSec = math.max(maxEndSec, startSec + durSec);
      }

      durationSeconds = math.max(
        0.1,
        _optionalDouble(args, 'totalDurationSeconds') ?? (maxEndSec + 0.1),
      );
      renderedEventCount = events.length;
      sourceMode = 'note_events';

      wavBytes = _scoreRenderer.renderEventsToWav(
        events: events,
        totalDurationSeconds: durationSeconds,
        sampleRate: sampleRate,
        a4Ref: a4Ref,
        soundFontService: sf2Service,
        sf2Patch: sf2Patch,
        polyphonicPool: voicePool,
      );
    } else {
      final HierarchicalScore score;
      if (rawScoreJson != null) {
        if (rawScoreJson is! Map<String, dynamic>) {
          throw const McpException.invalidParams(
            'Parameter "scoreJson" must be a JSON object.',
          );
        }
        score = HierarchicalScore.fromMap(rawScoreJson);
        sourceMode = 'score_json';
      } else if (facade.activeScore != null) {
        score = facade.activeScore!;
        sourceMode = 'active_score';
      } else {
        throw const McpException.invalidParams(
          'Provide "notes", "scoreJson", or load an active score in the session.',
        );
      }

      final bpm = (_optionalInt(args, 'bpm') ?? score.baseBpm).clamp(20, 300);
      durationSeconds = OfflineScoreWavRenderer.calculateScoreDurationSeconds(
        score: score,
        bpm: bpm,
      );
      renderedEventCount = OfflineScoreWavRenderer.extractScoreEvents(
        score: score,
        bpm: bpm,
      ).length;

      wavBytes = _scoreRenderer.renderScoreToWav(
        score: score,
        bpm: bpm,
        sampleRate: sampleRate,
        a4Ref: a4Ref,
        soundFontService: sf2Service,
        sf2Patch: sf2Patch,
        polyphonicPool: voicePool,
      );
    }

    final outFile = _resolveWorkspaceFile(outputPath);
    await _writeBytesEnsuringParent(outFile, wavBytes);

    return McpToolResult.json({
      'outputPath': outFile.path,
      'sourceMode': sourceMode,
      'engine': engine,
      'eventCount': renderedEventCount,
      'durationSeconds': durationSeconds,
      'sampleRate': sampleRate,
      'channels': 1,
      'bitsPerSample': 16,
      'sizeBytes': wavBytes.lengthInBytes,
    });
  }

  Future<McpToolResult> _handleSf2LoadBank(Map<String, dynamic> args) async {
    final resetToEssentials = _optionalBool(args, 'resetToEssentials') ?? false;
    final sf2FilePath = _optionalString(args, 'sf2FilePath');

    if (resetToEssentials) {
      _soundFontService.resetToEssentialsBank();
    } else {
      if (sf2FilePath == null) {
        throw const McpException.invalidParams(
          'Provide "sf2FilePath" or set "resetToEssentials" to true.',
        );
      }
      final file = _resolveWorkspaceFile(sf2FilePath);
      if (!await file.exists()) {
        throw McpException.fileNotFound('SoundFont2 file not found: $sf2FilePath');
      }
      final bytes = await file.readAsBytes();
      try {
        _soundFontService.loadSoundFontFromBytes(bytes);
      } catch (e) {
        throw McpException.acousticError('Failed to parse SoundFont2 file: $e');
      }
    }

    final sf = _soundFontService.activeSoundFont;
    return McpToolResult.json({
      'soundFontName': sf.soundFontName,
      'activePatch': _soundFontService.activePatch,
      'presetCount': sf.presets.length,
      'instrumentCount': sf.instruments.length,
      'sampleCount': sf.sampleHeaders.length,
      'presets': sf.presets
          .map(
            (p) => {
              'name': p.name,
              'patch': p.patch,
              'bank': p.bank,
              'zoneCount': p.zones.length,
            },
          )
          .toList(growable: false),
    });
  }

  Future<McpToolResult> _handleSf2RenderNote(Map<String, dynamic> args) async {
    final midiPitch = _requireInt(args, 'midiPitch').clamp(0, 127);
    final outputPath = _requireString(args, 'outputPath');
    final patch = _optionalInt(args, 'patch');
    final durationSeconds =
        (_optionalDouble(args, 'durationSeconds') ?? 1.0).clamp(0.05, 30.0);
    final velocity = (_optionalInt(args, 'velocity') ?? 100).clamp(1, 127);
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 96000);

    if (patch != null) {
      _soundFontService.selectPatch(patch.clamp(0, 127));
    }

    final activePatch = _soundFontService.activePatch;
    final preset = _soundFontService.activeSoundFont.findPreset(activePatch);
    final wavBytes = _soundFontService.synthesizeNoteWav(
      midiPitch: midiPitch,
      durationSeconds: durationSeconds,
      velocity: velocity,
      sampleRate: sampleRate,
    );

    final outFile = _resolveWorkspaceFile(outputPath);
    await _writeBytesEnsuringParent(outFile, wavBytes);

    return McpToolResult.json({
      'outputPath': outFile.path,
      'patch': activePatch,
      'presetName': preset?.name ?? 'Fallback Sine',
      'midiPitch': midiPitch,
      'velocity': velocity,
      'durationSeconds': durationSeconds,
      'sampleRate': sampleRate,
      'sizeBytes': wavBytes.lengthInBytes,
    });
  }

  Future<McpToolResult> _handlePolyphonicRenderChord(
    Map<String, dynamic> args,
  ) async {
    final rawNotes = args['midiNotes'];
    if (rawNotes is! List || rawNotes.isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "midiNotes" must be a non-empty list of MIDI note integers.',
      );
    }
    final midiNotes = <int>[];
    for (final n in rawNotes) {
      if (n is! num) {
        throw const McpException.invalidParams(
          'All entries in "midiNotes" must be integers.',
        );
      }
      midiNotes.add(n.toInt().clamp(0, 127));
    }

    final durationSeconds =
        _requireDouble(args, 'durationSeconds').clamp(0.05, 30.0);
    final outputPath = _requireString(args, 'outputPath');
    final velocity = (_optionalDouble(args, 'velocity') ?? 0.8).clamp(0.05, 1.0);
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 96000);
    final rawWaveform = _optionalString(args, 'waveform');

    final pool = _voicePool;
    pool.panic();
    pool.sampleRate = sampleRate.toDouble();

    if (rawWaveform != null) {
      pool.waveform = _parseWaveform(rawWaveform);
    }

    final rawAdsr = args['adsr'];
    if (rawAdsr != null) {
      if (rawAdsr is! Map<String, dynamic>) {
        throw const McpException.invalidParams(
          'Parameter "adsr" must be a JSON object.',
        );
      }
      final attack = _optionalDouble(rawAdsr, 'attack');
      final decay = _optionalDouble(rawAdsr, 'decay');
      final sustain = _optionalDouble(rawAdsr, 'sustain');
      final release = _optionalDouble(rawAdsr, 'release');
      if (attack != null) pool.attackSeconds = attack;
      if (decay != null) pool.decaySeconds = decay;
      if (sustain != null) pool.sustainLevel = sustain;
      if (release != null) pool.releaseSeconds = release;
    }

    for (final midi in midiNotes) {
      pool.noteOn(midi, velocity);
    }

    final wavBytes = pool.renderWavBlock(
      durationSeconds: durationSeconds,
      sampleRate: sampleRate,
    );
    pool.panic();

    final outFile = _resolveWorkspaceFile(outputPath);
    await _writeBytesEnsuringParent(outFile, wavBytes);

    return McpToolResult.json({
      'outputPath': outFile.path,
      'renderedNotes': midiNotes,
      'waveform': pool.waveform.name,
      'channels': 2,
      'sampleRate': sampleRate,
      'durationSeconds': durationSeconds,
      'sizeBytes': wavBytes.lengthInBytes,
    });
  }

  Future<McpToolResult> _handleExportStemsAndMidi(
    Map<String, dynamic> args,
  ) async {
    final bpm = _requireInt(args, 'bpm').clamp(20, 300);
    final trackTitle = _requireString(args, 'trackTitle');
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 96000);
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final outputSubfolder = _optionalString(args, 'outputSubfolder');

    if (outputSubfolder != null) {
      if (outputSubfolder.contains('..') ||
          outputSubfolder.contains('/') ||
          outputSubfolder.contains('\\') ||
          outputSubfolder.contains('\x00')) {
        throw McpException.securityViolation(
          'Invalid outputSubfolder containing path traversal characters: $outputSubfolder',
        );
      }
    }

    final rawScore = args['scoreJson'];
    final HierarchicalScore score;
    if (rawScore != null) {
      if (rawScore is! Map<String, dynamic>) {
        throw const McpException.invalidParams(
          'Parameter "scoreJson" must be a JSON object.',
        );
      }
      score = HierarchicalScore.fromMap(rawScore);
    } else if (facade.activeScore != null) {
      score = facade.activeScore!;
    } else {
      throw const McpException.invalidParams(
        'Provide "scoreJson" or load an active score in the session.',
      );
    }

    final config = StemExportConfig(
      sampleRate: sampleRate,
      includeMasterMixdown: _optionalBool(args, 'includeMasterMixdown') ?? true,
      includeIndividualStems:
          _optionalBool(args, 'includeIndividualStems') ?? true,
      includeMidiFile: _optionalBool(args, 'includeMidiFile') ?? true,
      includeMelodyTrack: _optionalBool(args, 'includeMelodyTrack') ?? true,
      includeMetronomeTrack:
          _optionalBool(args, 'includeMetronomeTrack') ?? true,
      includeAccompanimentTrack:
          _optionalBool(args, 'includeAccompanimentTrack') ?? true,
    );

    final bundle = _stemSynthesizer.exportStemsAndMidi(
      score: score,
      mixerConsole: MixerConsoleEntity.defaultSetup(),
      bpm: bpm,
      trackTitle: trackTitle,
      config: config,
      a4Ref: a4Ref,
    );

    final persistence = StemExportPersistenceService(
      documentsPathProvider: () async => facade.workspaceDirectory.path,
    );
    final savedPaths = await persistence.saveExportBundle(
      bundle,
      customSubfolder: outputSubfolder,
    );

    return McpToolResult.json({
      'savedPaths': savedPaths,
      'totalBytes': bundle.totalBytes,
      'files': bundle.files.map((f) => f.toJson()).toList(growable: false),
    });
  }

  Future<McpToolResult> _handleDroneGenerateWav(
    Map<String, dynamic> args,
  ) async {
    final rootNoteIndex = _requireInt(args, 'rootNoteIndex').clamp(0, 11);
    final octave = _requireInt(args, 'octave').clamp(0, 8);
    final outputPath = _requireString(args, 'outputPath');
    final includeFifth = _optionalBool(args, 'includeFifth') ?? true;
    final includeOctave = _optionalBool(args, 'includeOctave') ?? false;
    final rawTimbre = _optionalString(args, 'timbre') ?? DroneTimbre.warmFlute.name;
    final harmonicBalance =
        (_optionalDouble(args, 'harmonicBalance') ?? 0.35).clamp(0.0, 1.0);
    final volume = (_optionalDouble(args, 'volume') ?? 0.7).clamp(0.0, 1.0);
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final temperamentId = _optionalString(args, 'temperamentId') ?? 'equal';
    final temperamentRootKey =
        (_optionalInt(args, 'temperamentRootKey') ?? 0).clamp(0, 11);
    final durationSeconds =
        (_optionalDouble(args, 'durationSeconds') ?? 2.0).clamp(0.2, 30.0);
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 96000);

    final timbre = _parseDroneTimbre(rawTimbre);
    final temperament = TemperamentEngine.getById(temperamentId);
    final config = HarmonicDroneConfig(
      rootNoteIndex: rootNoteIndex,
      octave: octave,
      includeFifth: includeFifth,
      includeOctave: includeOctave,
      timbre: timbre,
      volume: volume,
      harmonicBalance: harmonicBalance,
    );

    final freqs = _droneSynthesizer.calculateFrequencies(
      config: config,
      a4Ref: a4Ref,
      temperament: temperament,
      temperamentRootKey: temperamentRootKey,
    );

    final wavBytes = _droneSynthesizer.generateDroneWavBuffer(
      config: config,
      a4Ref: a4Ref,
      temperament: temperament,
      temperamentRootKey: temperamentRootKey,
      sampleRate: sampleRate,
      durationSeconds: durationSeconds,
      applyConfigVolume: true,
    );

    final outFile = _resolveWorkspaceFile(outputPath);
    await _writeBytesEnsuringParent(outFile, wavBytes);

    return McpToolResult.json({
      'outputPath': outFile.path,
      'rootDisplayName': config.rootDisplayName,
      'timbre': timbre.name,
      'volume': volume,
      'temperamentId': temperament.id,
      'frequenciesHz': freqs,
      'sampleRate': sampleRate,
      'durationSeconds': durationSeconds,
      'sizeBytes': wavBytes.lengthInBytes,
    });
  }

  // ===========================================================================
  // Security & Argument Helpers
  // ===========================================================================

  File _resolveWorkspaceFile(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || trimmed.contains('\x00')) {
      throw McpException.securityViolation('Invalid or empty file path.');
    }

    final rootPath = _normalizeAbsolutePath(facade.workspaceDirectory.absolute.path);
    final candidateRaw = _isAbsolutePath(trimmed)
        ? trimmed
        : '$rootPath${Platform.pathSeparator}$trimmed';
    final resolvedPath = _normalizeAbsolutePath(candidateRaw);

    final prefix = rootPath.endsWith(Platform.pathSeparator)
        ? rootPath
        : '$rootPath${Platform.pathSeparator}';
    if (resolvedPath != rootPath && !resolvedPath.startsWith(prefix)) {
      throw McpException.securityViolation(
        'Path traversal violation: "$rawPath" escapes workspace directory.',
      );
    }
    return File(resolvedPath);
  }

  static bool _isAbsolutePath(String p) {
    if (p.startsWith('/') || p.startsWith('\\')) return true;
    return p.length >= 2 && p[1] == ':';
  }

  static String _normalizeAbsolutePath(String path) {
    final uri = Uri.file(path, windows: Platform.isWindows).normalizePath();
    var normalized = uri.toFilePath(windows: Platform.isWindows);
    if (normalized.length > 1 && normalized.endsWith(Platform.pathSeparator)) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static Future<void> _writeBytesEnsuringParent(
    File file,
    Uint8List bytes,
  ) async {
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsBytes(bytes, flush: true);
  }

  static SynthWaveform _parseWaveform(String raw) {
    for (final w in SynthWaveform.values) {
      if (w.name == raw) return w;
    }
    throw McpException.invalidParams(
      'Invalid waveform "$raw". Expected sine, sawtooth, pulse, or triangle.',
    );
  }

  static DroneTimbre _parseDroneTimbre(String raw) {
    for (final t in DroneTimbre.values) {
      if (t.name == raw) return t;
    }
    throw McpException.invalidParams(
      'Invalid timbre "$raw". Expected pureSine, warmFlute, richCello, or organ.',
    );
  }

  static String _requireString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! String || v.trim().isEmpty) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a non-empty string.',
      );
    }
    return v.trim();
  }

  static String? _optionalString(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! String) {
      throw McpException.invalidParams('Parameter "$key" must be a string.');
    }
    final trimmed = v.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int _requireInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v.toInt();
  }

  static int? _optionalInt(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be an integer.');
    }
    return v.toInt();
  }

  static double _requireDouble(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be a number.');
    }
    return v.toDouble();
  }

  static double? _optionalDouble(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num) {
      throw McpException.invalidParams('Parameter "$key" must be a number.');
    }
    return v.toDouble();
  }

  static bool? _optionalBool(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! bool) {
      throw McpException.invalidParams('Parameter "$key" must be a boolean.');
    }
    return v;
  }
}
