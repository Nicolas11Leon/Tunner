import 'dart:io';
import 'dart:typed_data';

import '../../core/audio/domain/offline_wav_decoder.dart';
import '../../features/chord_analyzer/domain/chord_entity.dart';
import '../../features/chord_analyzer/domain/chroma_vector_calculator.dart';
import '../../features/chord_analyzer/domain/polyphonic_chord_recognizer.dart';
import '../../features/chord_analyzer/domain/polyphonic_multitone_detector.dart';
import '../../features/harmonic_tutor/domain/harmonic_reference_synth.dart';
import '../../features/harmonic_tutor/domain/harmonic_role_entity.dart';
import '../../features/harmonic_tutor/domain/harmonic_tutor_session_entity.dart';
import '../../features/harmonic_tutor/domain/just_intonation_calculator.dart';
import '../../features/media_vault/domain/wav_pcm_codec.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing polyphonic chord recognition, multi-tone voicing
/// decomposition, Just Intonation (JI) harmonic analysis, beat-frequency
/// diagnostics, and JI reference chord synthesis.
class HarmonyChordsMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final WavPcmCodec _wavCodec;
  final PolyphonicChordRecognizer _statefulRecognizer;

  HarmonicTutorSessionEntity _session = const HarmonicTutorSessionEntity();
  HarmonicRole? _forcedRole;

  HarmonyChordsMcpModule(
    this.facade, {
    WavPcmCodec? wavCodec,
    PolyphonicChordRecognizer? statefulRecognizer,
  })  : _wavCodec = wavCodec ?? const WavPcmCodec(),
        _statefulRecognizer =
            statefulRecognizer ?? PolyphonicChordRecognizer(stateless: false);

  @override
  String get moduleName => 'harmony_chords';

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
        uri: 'tunner://harmony/chord-qualities',
        name: 'Supported Chord Qualities Catalog',
        description:
            'Canonical catalog of supported harmonic chord qualities, interval formulas, and semitone offsets.',
        mimeType: 'application/json',
        reader: () async {
          final qualities = ChordQuality.values
              .map(
                (q) => {
                  'id': q.name,
                  'symbolSuffix': q.symbolSuffix,
                  'nameSpanish': q.nameSpanish,
                  'intervalsSemitones': q.intervalsInSemitones,
                  'formula': q.formulaLabel,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://harmony/chord-qualities',
            data: {
              'count': qualities.length,
              'qualities': qualities,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://harmony/just-intonation/roles',
        name: 'Just Intonation Harmonic Roles Reference',
        description:
            'Reference table of all 12 HarmonicRole entries with pure rational p/q ratios, JI cents, and 12-TET offsets.',
        mimeType: 'application/json',
        reader: () async {
          final roles = HarmonicRole.values
              .map(
                (r) => {
                  'id': r.name,
                  'semitones': r.semitones,
                  'numerator': r.numerator,
                  'denominator': r.denominator,
                  'ratio': '${r.numerator}/${r.denominator}',
                  'ratioDecimal': r.ratio,
                  'justCents': r.justCents,
                  'tetOffsetCents': r.tetOffsetCents,
                  'symbol': r.symbol,
                  'labelEs': r.labelEs,
                  'description': r.description,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://harmony/just-intonation/roles',
            data: {
              'count': roles.length,
              'roles': roles,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://harmony/just-intonation/chord-types',
        name: 'Harmonic Tutor Chord Types Catalog',
        description:
            'Catalog of Just Intonation chord types supported by the Harmonic Tutor.',
        mimeType: 'application/json',
        reader: () async {
          final chordTypes = HarmonicChordType.values
              .map(
                (ct) => {
                  'id': ct.name,
                  'label': ct.label,
                  'roles': ct.roles.map((r) => r.name).toList(growable: false),
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://harmony/just-intonation/chord-types',
            data: {
              'count': chordTypes.length,
              'chordTypes': chordTypes,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://harmony/tutor/session/current',
        name: 'Active Harmonic Tutor Session State',
        description:
            'Live state of the active Just Intonation Harmonic Tutor session, including root, chord type, drone state, and last analysis.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://harmony/tutor/session/current',
            data: _serializeSession(),
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
        name: 'tunner_analyze_chord_from_pcm',
        description:
            'Identifies a polyphonic chord from raw PCM samples or a workspace WAV file using ChromaVectorCalculator and PolyphonicChordRecognizer (defaults to stateless mode).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'samples': {
              'type': 'array',
              'items': {'type': 'number'},
              'description':
                  'Normalized mono PCM samples in [-1.0, 1.0]. Provide either samples or wavPath.',
            },
            'wavPath': {
              'type': 'string',
              'description':
                  'Workspace-relative or workspace-contained path to a RIFF/WAVE file.',
            },
            'sampleRate': {
              'type': 'number',
              'default': 44100.0,
              'description': 'Sample rate in Hz (overridden by WAV header when wavPath is used).',
            },
            'a4Ref': {
              'type': 'number',
              'default': 440.0,
              'description': 'Concert pitch reference for A4 in Hz.',
            },
            'noiseGateRms': {
              'type': 'number',
              'default': 0.008,
              'description': 'Minimum RMS energy threshold to reject silence.',
            },
            'minMidi': {
              'type': 'integer',
              'default': 21,
              'description': 'Lowest MIDI note analyzed (21 = A0).',
            },
            'maxMidi': {
              'type': 'integer',
              'default': 108,
              'description': 'Highest MIDI note analyzed (108 = C8).',
            },
            'stateless': {
              'type': 'boolean',
              'default': true,
              'description':
                  'When true, bypasses temporal hysteresis for atomic one-shot MCP calls.',
            },
          },
        },
        handler: _handleAnalyzeChordFromPcm,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_analyze_chord_from_frequencies',
        description:
            'Identifies a chord from a discrete map of frequency (Hz) to amplitude pairs.',
        inputSchema: const {
          'type': 'object',
          'required': ['frequencyAmplitudes'],
          'properties': {
            'frequencyAmplitudes': {
              'type': 'object',
              'additionalProperties': {'type': 'number'},
              'description':
                  'Map of frequency in Hz (as string keys) to linear amplitude values.',
            },
            'a4Ref': {
              'type': 'number',
              'default': 440.0,
              'description': 'Concert pitch reference for A4 in Hz.',
            },
            'stateless': {
              'type': 'boolean',
              'default': true,
              'description':
                  'When true, bypasses temporal hysteresis for atomic one-shot MCP calls.',
            },
          },
        },
        handler: _handleAnalyzeChordFromFrequencies,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_detect_polyphonic_voicing',
        description:
            'Decomposes simultaneous polyphonic voices (piano/guitar/ensemble) from PCM samples or a workspace WAV file, reporting individual voice cents, salience, harmonic roles, and bass inversion.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'samples': {
              'type': 'array',
              'items': {'type': 'number'},
              'description':
                  'Normalized mono PCM samples in [-1.0, 1.0]. Provide either samples or wavPath.',
            },
            'wavPath': {
              'type': 'string',
              'description':
                  'Workspace-relative or workspace-contained path to a RIFF/WAVE file.',
            },
            'sampleRate': {
              'type': 'number',
              'default': 44100.0,
            },
            'a4Ref': {
              'type': 'number',
              'default': 440.0,
            },
            'maxVoices': {
              'type': 'integer',
              'default': 6,
            },
            'minMidi': {
              'type': 'integer',
              'default': 21,
            },
            'maxMidi': {
              'type': 'integer',
              'default': 108,
            },
            'noiseGateRms': {
              'type': 'number',
              'default': 0.008,
            },
            'stateless': {
              'type': 'boolean',
              'default': true,
            },
          },
        },
        handler: _handleDetectPolyphonicVoicing,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_analyze_just_intonation',
        description:
            'Computes Just Intonation target frequency, cents offset vs JI and 12-TET, acoustic beat frequency in Hz, lock status, and tuning advice for a performed frequency against a root.',
        inputSchema: const {
          'type': 'object',
          'required': ['userFrequencyHz', 'rootFrequencyHz'],
          'properties': {
            'userFrequencyHz': {
              'type': 'number',
              'description': 'Detected user pitch frequency in Hz.',
            },
            'rootFrequencyHz': {
              'type': 'number',
              'description': 'Harmonic root frequency in Hz.',
            },
            'forcedRole': {
              'type': 'string',
              'description':
                  'Optional HarmonicRole enum name (e.g., majorThird, perfectFifth, harmonicSeventh).',
            },
            'rootNoteName': {
              'type': 'string',
              'description': 'Optional root note label to record in the active session.',
            },
            'chordType': {
              'type': 'string',
              'description': 'Optional HarmonicChordType enum name for session state.',
            },
            'updateSession': {
              'type': 'boolean',
              'default': true,
              'description': 'When true, updates tunner://harmony/tutor/session/current.',
            },
          },
        },
        handler: _handleAnalyzeJustIntonation,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_calculate_ji_target_frequency',
        description:
            'Calculates the exact Just Intonation target frequency in Hz for a root frequency, HarmonicRole, and optional octave offset.',
        inputSchema: const {
          'type': 'object',
          'required': ['rootFrequencyHz', 'role'],
          'properties': {
            'rootFrequencyHz': {
              'type': 'number',
              'description': 'Harmonic root frequency in Hz.',
            },
            'role': {
              'type': 'string',
              'description': 'HarmonicRole enum name (e.g., majorThird, perfectFifth).',
            },
            'octaveOffset': {
              'type': 'integer',
              'default': 0,
              'description': 'Octave transposition offset (e.g., -1, 0, +1).',
            },
          },
        },
        handler: _handleCalculateJiTargetFrequency,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_synthesize_ji_reference_chord',
        description:
            'Synthesizes a pure Just Intonation reference chord/drone using HarmonicReferenceSynth and optionally writes a 16-bit mono WAV file inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'required': ['rootFrequencyHz'],
          'properties': {
            'rootFrequencyHz': {
              'type': 'number',
              'description': 'Harmonic root frequency in Hz.',
            },
            'chordType': {
              'type': 'string',
              'description':
                  'HarmonicChordType enum name (defaults to majorTriad when roles is omitted).',
            },
            'roles': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  'Explicit list of HarmonicRole names overriding chordType.',
            },
            'durationMs': {
              'type': 'integer',
              'default': 2000,
              'description': 'Duration in milliseconds (50 to 30000).',
            },
            'volume': {
              'type': 'number',
              'default': 0.4,
              'description': 'Normalized volume in [0.0, 1.0].',
            },
            'sampleRate': {
              'type': 'integer',
              'default': 44100,
              'description': 'Sample rate in Hz.',
            },
            'outputPath': {
              'type': 'string',
              'description':
                  'Optional workspace-contained output path for exporting a 16-bit PCM WAV file.',
            },
          },
        },
        handler: _handleSynthesizeJiReferenceChord,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_harmonic_tutor_configure_session',
        description:
            'Configures the active Harmonic Tutor session state (root note, root frequency, chord type, forced role, drone/listening flags).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'rootNoteName': {'type': 'string'},
            'rootFrequencyHz': {'type': 'number'},
            'chordType': {'type': 'string'},
            'forcedRole': {'type': 'string'},
            'clearForcedRole': {'type': 'boolean', 'default': false},
            'isDroneActive': {'type': 'boolean'},
            'isListening': {'type': 'boolean'},
          },
        },
        handler: _handleConfigureTutorSession,
      ),
    );
  }

  // ===========================================================================
  // Prompts (2)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'conservatory_just_intonation_drill',
        description:
            'Guides a musician or singer to eliminate acoustic beating on a triad or dominant seventh chord in Just Intonation.',
        arguments: const [
          McpPromptArgument(
            name: 'rootNote',
            description: 'Target root note and frequency (e.g., C4 = 261.63 Hz).',
            required: false,
          ),
          McpPromptArgument(
            name: 'chordType',
            description: 'HarmonicChordType name (e.g., majorTriad, dominantSeventh).',
            required: false,
          ),
          McpPromptArgument(
            name: 'targetRole',
            description: 'HarmonicRole to practice (e.g., majorThird, harmonicSeventh).',
            required: false,
          ),
        ],
        builder: (args) async {
          final rootNote = args['rootNote'] ?? 'C4 (261.63 Hz)';
          final chordType = args['chordType'] ?? 'majorTriad';
          final targetRole = args['targetRole'] ?? 'majorThird';
          return McpPromptResult(
            description: 'Conservatory Just Intonation acoustic lock drill workflow.',
            messages: [
              McpPromptMessage.user(
                'Conduct a Just Intonation drill for root $rootNote, chordType "$chordType", focusing on role "$targetRole":\n'
                '1. Read resource "tunner://harmony/just-intonation/roles" to inspect the pure p/q ratio and 12-TET offset.\n'
                '2. Synthesize a reference drone (root + perfectFifth) using "tunner_synthesize_ji_reference_chord".\n'
                '3. Compute the exact JI target frequency with "tunner_calculate_ji_target_frequency".\n'
                '4. Evaluate each performed pitch iteratively with "tunner_analyze_just_intonation" until status == "pureConsonance" (|centsOffsetFromJi| <= 3.0) and beatFrequencyHz is minimized.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'polyphonic_voicing_audit',
        description:
            'Audits a polyphonic chord recording to diagnose per-voice intonation, salience balance, and bass inversion.',
        arguments: const [
          McpPromptArgument(
            name: 'wavPath',
            description: 'Workspace path to the polyphonic WAV recording.',
            required: false,
          ),
          McpPromptArgument(
            name: 'instrument',
            description: 'Instrument context (e.g., piano, guitar, string quartet).',
            required: false,
          ),
        ],
        builder: (args) async {
          final wavPath = args['wavPath'] ?? '<workspace_wav_path>';
          final instrument = args['instrument'] ?? 'guitar/piano';
          return McpPromptResult(
            description: 'Polyphonic chord voicing and intonation audit workflow.',
            messages: [
              McpPromptMessage.user(
                'Audit the polyphonic voicing in "$wavPath" for $instrument:\n'
                '1. Run "tunner_detect_polyphonic_voicing" with stateless=true to decompose simultaneous voices.\n'
                '2. Flag any voice with |centsDeviation| > 8.0 cents and report its harmonicRole and salience.\n'
                '3. Compare bassVoice against chord.rootNoteIndex to report whether the chord is in root position or an inversion (slash chord).\n'
                '4. Provide actionable tuning or fingering corrections per voice.',
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

  Future<McpToolResult> _handleAnalyzeChordFromPcm(
    Map<String, dynamic> args,
  ) async {
    final loaded = await _loadSamplesOrWav(args);
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final noiseGateRms = _optionalDouble(args, 'noiseGateRms') ?? 0.008;
    final minMidi = (_optionalInt(args, 'minMidi') ?? 21).clamp(0, 127);
    final maxMidi = (_optionalInt(args, 'maxMidi') ?? 108).clamp(minMidi, 127);
    final stateless = _optionalBool(args, 'stateless') ?? true;

    if (a4Ref <= 0.0) {
      throw const McpException.invalidParams('Parameter "a4Ref" must be positive.');
    }

    final calculator = ChromaVectorCalculator(
      minMidiNote: minMidi,
      maxMidiNote: maxMidi,
    );
    final chroma = calculator.calculateFromSamples(
      samples: loaded.samples,
      sampleRate: loaded.sampleRate,
      a4Ref: a4Ref,
      noiseGateRms: noiseGateRms,
    );

    final recognizer = stateless
        ? PolyphonicChordRecognizer(stateless: true, calculator: calculator)
        : _statefulRecognizer;
    final chord = recognizer.identifyFromChroma(chroma, stateless: stateless);

    return McpToolResult.json({
      ...chord.toJson(),
      'sampleRate': loaded.sampleRate,
      'sampleCount': loaded.samples.length,
      'stateless': stateless,
      if (loaded.wavPath != null) 'wavPath': loaded.wavPath,
    });
  }

  Future<McpToolResult> _handleAnalyzeChordFromFrequencies(
    Map<String, dynamic> args,
  ) async {
    final rawMap = args['frequencyAmplitudes'];
    if (rawMap is! Map || rawMap.isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "frequencyAmplitudes" must be a non-empty object mapping Hz strings to amplitudes.',
      );
    }

    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final stateless = _optionalBool(args, 'stateless') ?? true;
    if (a4Ref <= 0.0) {
      throw const McpException.invalidParams('Parameter "a4Ref" must be positive.');
    }

    final freqAmps = <double, double>{};
    for (final entry in rawMap.entries) {
      final freq = double.tryParse(entry.key.toString());
      final ampVal = entry.value;
      if (freq == null || !freq.isFinite || freq <= 0.0) {
        throw McpException.invalidParams(
          'Invalid frequency key "${entry.key}" in frequencyAmplitudes.',
        );
      }
      if (ampVal is! num || !ampVal.isFinite) {
        throw McpException.invalidParams(
          'Invalid amplitude value for frequency "${entry.key}".',
        );
      }
      freqAmps[freq] = ampVal.toDouble();
    }

    const calculator = ChromaVectorCalculator();
    final chroma = calculator.calculateFromFrequencies(
      frequencyAmplitudes: freqAmps,
      a4Ref: a4Ref,
    );
    final recognizer = stateless
        ? PolyphonicChordRecognizer(stateless: true, calculator: calculator)
        : _statefulRecognizer;
    final chord = recognizer.identifyFromChroma(chroma, stateless: stateless);

    return McpToolResult.json({
      ...chord.toJson(),
      'a4Ref': a4Ref,
      'stateless': stateless,
    });
  }

  Future<McpToolResult> _handleDetectPolyphonicVoicing(
    Map<String, dynamic> args,
  ) async {
    final loaded = await _loadSamplesOrWav(args);
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final maxVoices = (_optionalInt(args, 'maxVoices') ?? 6).clamp(1, 16);
    final minMidi = (_optionalInt(args, 'minMidi') ?? 21).clamp(0, 127);
    final maxMidi = (_optionalInt(args, 'maxMidi') ?? 108).clamp(minMidi, 127);
    final noiseGateRms = _optionalDouble(args, 'noiseGateRms') ?? 0.008;
    final stateless = _optionalBool(args, 'stateless') ?? true;

    if (a4Ref <= 0.0) {
      throw const McpException.invalidParams('Parameter "a4Ref" must be positive.');
    }

    final detector = PolyphonicMultiToneDetector(
      minMidiNote: minMidi,
      maxMidiNote: maxMidi,
      maxVoices: maxVoices,
      noiseGateRms: noiseGateRms,
      chordRecognizer: PolyphonicChordRecognizer(stateless: stateless),
    );
    final result = detector.detectFromSamples(
      samples: loaded.samples,
      sampleRate: loaded.sampleRate,
      a4Ref: a4Ref,
    );

    String? slashSymbol;
    bool isInverted = false;
    final bass = result.bassVoice;
    if (result.chord.isRecognized && bass != null) {
      isInverted = bass.pitchClassIndex != result.chord.rootNoteIndex;
      slashSymbol = isInverted
          ? '${result.chord.symbol}/${bass.noteNameInternational}'
          : result.chord.symbol;
    }

    return McpToolResult.json({
      ...result.toJson(),
      'isInverted': isInverted,
      'slashSymbol': slashSymbol,
      'sampleRate': loaded.sampleRate,
      'sampleCount': loaded.samples.length,
      if (loaded.wavPath != null) 'wavPath': loaded.wavPath,
    });
  }

  Future<McpToolResult> _handleAnalyzeJustIntonation(
    Map<String, dynamic> args,
  ) async {
    final userFreq = _requireDouble(args, 'userFrequencyHz');
    final rootFreq = _requireDouble(args, 'rootFrequencyHz');
    final forcedRoleRaw = _optionalString(args, 'forcedRole');
    final rootNoteName = _optionalString(args, 'rootNoteName');
    final chordTypeRaw = _optionalString(args, 'chordType');
    final updateSession = _optionalBool(args, 'updateSession') ?? true;

    if (userFreq <= 0.0 || rootFreq <= 0.0) {
      throw const McpException.invalidParams(
        'Parameters "userFrequencyHz" and "rootFrequencyHz" must be strictly positive.',
      );
    }

    final forcedRole =
        forcedRoleRaw != null ? _parseHarmonicRole(forcedRoleRaw) : null;
    final analysis = JustIntonationCalculator.analyze(
      userFrequency: userFreq,
      rootFrequency: rootFreq,
      forcedRole: forcedRole,
    );

    if (updateSession) {
      _forcedRole = forcedRole ?? _forcedRole;
      _session = _session.copyWith(
        rootNoteName: rootNoteName ?? _session.rootNoteName,
        rootFrequency: rootFreq,
        chordType: chordTypeRaw != null
            ? _parseHarmonicChordType(chordTypeRaw)
            : _session.chordType,
        activeAnalysis: analysis,
      );
    }

    return McpToolResult.json(_serializeAnalysis(analysis));
  }

  Future<McpToolResult> _handleCalculateJiTargetFrequency(
    Map<String, dynamic> args,
  ) async {
    final rootFreq = _requireDouble(args, 'rootFrequencyHz');
    if (rootFreq <= 0.0) {
      throw const McpException.invalidParams(
        'Parameter "rootFrequencyHz" must be strictly positive.',
      );
    }
    final role = _parseHarmonicRole(_requireString(args, 'role'));
    final octaveOffset = _optionalInt(args, 'octaveOffset') ?? 0;

    final targetFreq = JustIntonationCalculator.targetFrequency(
      rootFrequency: rootFreq,
      role: role,
      octaveOffset: octaveOffset,
    );

    return McpToolResult.json({
      'rootFrequencyHz': rootFreq,
      'role': role.name,
      'octaveOffset': octaveOffset,
      'targetFrequencyHz': targetFreq,
      'ratio': '${role.numerator}/${role.denominator}',
      'ratioDecimal': role.ratio,
      'justCents': role.justCents,
      'tetOffsetCents': role.tetOffsetCents,
    });
  }

  Future<McpToolResult> _handleSynthesizeJiReferenceChord(
    Map<String, dynamic> args,
  ) async {
    final rootFreq = _requireDouble(args, 'rootFrequencyHz');
    if (rootFreq <= 0.0) {
      throw const McpException.invalidParams(
        'Parameter "rootFrequencyHz" must be strictly positive.',
      );
    }
    final durationMs = (_optionalInt(args, 'durationMs') ?? 2000).clamp(50, 30000);
    final volume = (_optionalDouble(args, 'volume') ?? 0.4).clamp(0.0, 1.0);
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 192000);
    final chordTypeRaw = _optionalString(args, 'chordType');
    final outputPathRaw = _optionalString(args, 'outputPath');

    final rawRoles = args['roles'];
    final List<HarmonicRole> roles;
    HarmonicChordType? resolvedChordType;

    if (rawRoles is List && rawRoles.isNotEmpty) {
      roles = rawRoles
          .map((e) => _parseHarmonicRole(e.toString()))
          .toList(growable: false);
    } else {
      resolvedChordType = chordTypeRaw != null
          ? _parseHarmonicChordType(chordTypeRaw)
          : HarmonicChordType.majorTriad;
      roles = resolvedChordType.roles;
    }

    final synth = HarmonicReferenceSynth(sampleRate: sampleRate);
    final buffer = synth.generateChordBuffer(
      rootFrequency: rootFreq,
      roles: roles,
      durationMs: durationMs,
      volume: volume,
    );

    double peakAmplitude = 0.0;
    final samples64 = Float64List(buffer.length);
    for (int i = 0; i < buffer.length; i++) {
      final v = buffer[i].toDouble();
      samples64[i] = v;
      final absV = v.abs();
      if (absV > peakAmplitude) {
        peakAmplitude = absV;
      }
    }

    final voicesHz = roles
        .map((r) => rootFreq * r.ratio)
        .toList(growable: false);

    String? writtenPath;
    int? byteLength;
    if (outputPathRaw != null) {
      final outFile = _resolveWorkspaceFile(outputPathRaw);
      final wavBytes = _wavCodec.encodeMono16Bit(
        samples64,
        sampleRate: sampleRate,
      );
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(wavBytes, flush: true);
      writtenPath = outFile.path;
      byteLength = wavBytes.length;
    }

    _session = _session.copyWith(
      rootFrequency: rootFreq,
      chordType: resolvedChordType ?? _session.chordType,
      isDroneActive: true,
    );

    return McpToolResult.json({
      'sampleRate': sampleRate,
      'totalSamples': buffer.length,
      'durationMs': durationMs,
      'roles': roles.map((r) => r.name).toList(growable: false),
      'voicesHz': voicesHz,
      'peakAmplitude': peakAmplitude,
      'wavFilePath': ?writtenPath,
      'byteLength': ?byteLength,
    });
  }

  Future<McpToolResult> _handleConfigureTutorSession(
    Map<String, dynamic> args,
  ) async {
    final rootNoteName = _optionalString(args, 'rootNoteName');
    final rootFrequencyHz = _optionalDouble(args, 'rootFrequencyHz');
    final chordTypeRaw = _optionalString(args, 'chordType');
    final forcedRoleRaw = _optionalString(args, 'forcedRole');
    final clearForcedRole = _optionalBool(args, 'clearForcedRole') ?? false;
    final isDroneActive = _optionalBool(args, 'isDroneActive');
    final isListening = _optionalBool(args, 'isListening');

    if (rootFrequencyHz != null && rootFrequencyHz <= 0.0) {
      throw const McpException.invalidParams(
        'Parameter "rootFrequencyHz" must be strictly positive.',
      );
    }

    if (clearForcedRole) {
      _forcedRole = null;
    } else if (forcedRoleRaw != null) {
      _forcedRole = _parseHarmonicRole(forcedRoleRaw);
    }

    _session = _session.copyWith(
      rootNoteName: rootNoteName,
      rootFrequency: rootFrequencyHz,
      chordType: chordTypeRaw != null
          ? _parseHarmonicChordType(chordTypeRaw)
          : null,
      isDroneActive: isDroneActive,
      isListening: isListening,
    );

    return McpToolResult.json(_serializeSession());
  }

  // ===========================================================================
  // Serialization & Input Helpers
  // ===========================================================================

  Map<String, dynamic> _serializeSession() {
    final active = _session.activeAnalysis;
    return {
      'rootNoteName': _session.rootNoteName,
      'rootFrequency': _session.rootFrequency,
      'chordType': _session.chordType.name,
      'forcedRole': _forcedRole?.name,
      'isDroneActive': _session.isDroneActive,
      'isListening': _session.isListening,
      'activeAnalysis': active != null ? _serializeAnalysis(active) : null,
    };
  }

  static Map<String, dynamic> _serializeAnalysis(HarmonicAnalysisResult a) {
    return {
      'userFrequencyHz': a.userFrequency,
      'rootFrequencyHz': a.rootFrequency,
      'role': a.role.name,
      'ratio': '${a.role.numerator}/${a.role.denominator}',
      'ratioDecimal': a.role.ratio,
      'targetFrequencyJi': a.targetFrequencyJi,
      'centsOffsetFromJi': a.centsOffsetFromJi,
      'centsOffsetFrom12Tet': a.centsOffsetFrom12Tet,
      'beatFrequencyHz': a.beatFrequencyHz,
      'status': a.status.name,
      'statusCode': a.status.code,
      'statusLabel': a.status.label,
      'isLocked': a.isLocked,
      'tuningAdvice': a.tuningAdvice,
    };
  }

  Future<({List<double> samples, double sampleRate, String? wavPath})>
      _loadSamplesOrWav(Map<String, dynamic> args) async {
    final wavPathRaw = _optionalString(args, 'wavPath');
    if (wavPathRaw != null) {
      final file = _resolveWorkspaceFile(wavPathRaw);
      if (!await file.exists()) {
        throw McpException.fileNotFound('WAV file not found: $wavPathRaw');
      }
      final bytes = await file.readAsBytes();
      try {
        final decoded = OfflineWavDecoder.decode(bytes);
        return (
          samples: decoded.samples,
          sampleRate: decoded.sampleRate.toDouble(),
          wavPath: file.path,
        );
      } on FormatException catch (e) {
        throw McpException.acousticError('Invalid WAV file "$wavPathRaw": ${e.message}');
      }
    }

    final rawSamples = args['samples'];
    if (rawSamples is! List || rawSamples.isEmpty) {
      throw const McpException.invalidParams(
        'Provide either a non-empty "samples" array or a valid "wavPath".',
      );
    }
    final samples = <double>[];
    for (final v in rawSamples) {
      if (v is! num || !v.isFinite) {
        throw const McpException.invalidParams(
          'All entries in "samples" must be finite numbers.',
        );
      }
      samples.add(v.toDouble());
    }
    final sampleRate = _optionalDouble(args, 'sampleRate') ?? 44100.0;
    if (sampleRate <= 0.0) {
      throw const McpException.invalidParams(
        'Parameter "sampleRate" must be strictly positive.',
      );
    }
    return (samples: samples, sampleRate: sampleRate, wavPath: null);
  }

  File _resolveWorkspaceFile(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || trimmed.contains('\x00')) {
      throw const McpException.securityViolation('Invalid or empty file path.');
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

  static HarmonicRole _parseHarmonicRole(String raw) {
    final clean = raw.trim();
    for (final role in HarmonicRole.values) {
      if (role.name == clean || role.symbol == clean) return role;
    }
    throw McpException.invalidMusicTheory('Unknown HarmonicRole: "$raw".');
  }

  static HarmonicChordType _parseHarmonicChordType(String raw) {
    final clean = raw.trim();
    for (final ct in HarmonicChordType.values) {
      if (ct.name == clean) return ct;
    }
    throw McpException.invalidMusicTheory('Unknown HarmonicChordType: "$raw".');
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
    if (v is! num || !v.isFinite) {
      throw McpException.invalidParams('Parameter "$key" must be a finite number.');
    }
    return v.toDouble();
  }

  static double? _optionalDouble(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v == null) return null;
    if (v is! num || !v.isFinite) {
      throw McpException.invalidParams('Parameter "$key" must be a finite number.');
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
