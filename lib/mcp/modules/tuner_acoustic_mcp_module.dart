import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/audio/domain/offline_wav_decoder.dart';
import '../../features/acoustic_lab/domain/harmonic_series_analyzer.dart';
import '../../features/tuner/domain/acoustic_echo_suppressor.dart';
import '../../features/tuner/domain/acoustic_rigor_profile.dart';
import '../../features/tuner/domain/mcleod_pitch_method.dart';
import '../../features/tuner/domain/note_entity.dart';
import '../../features/tuner/domain/offline_pitch_contour_analyzer.dart';
import '../../features/tuner/domain/signal_conditioning_filter.dart';
import '../../features/tuner/domain/temperament_engine.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing offline pitch contour detection (MPM),
/// historical temperament calculations, chromatic note-frequency math,
/// harmonic series spectral analysis, ambient noise-floor calibration, and
/// acoustic echo suppression simulation.
class TunerAcousticMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final TemperamentEngine _temperamentEngine;

  TunerAcousticMcpModule(
    this.facade, {
    TemperamentEngine? temperamentEngine,
  }) : _temperamentEngine = temperamentEngine ?? const TemperamentEngine();

  @override
  String get moduleName => 'tuner_acoustic';

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
        uri: 'tunner://tuner/temperaments',
        name: 'Historical Temperaments Catalog',
        description:
            'Complete catalog of the 11 historical and microtonal temperaments in TemperamentEngine.',
        mimeType: 'application/json',
        reader: () async {
          final items = TemperamentEngine.allTemperaments
              .map(
                (t) => {
                  'id': t.id,
                  'name': t.name,
                  'historicalEra': t.historicalEra,
                  'description': t.description,
                  'centsOffsets': t.centsOffsets,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://tuner/temperaments',
            data: {
              'count': items.length,
              'temperaments': items,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://tuner/rigor-presets',
        name: 'Acoustic Rigor Presets',
        description:
            'Catalog of the 6 acoustic rigor profiles (AcousticRigorPreset) with DSP sensitivity parameters.',
        mimeType: 'application/json',
        reader: () async {
          final presets = AcousticRigorPreset.values.map((preset) {
            final profile = AcousticRigorProfile.fromPreset(preset);
            return {
              ...profile.toJson(),
              'displayName': preset.displayName,
              'subtitle': preset.subtitle,
              'description': preset.description,
            };
          }).toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://tuner/rigor-presets',
            data: {
              'count': presets.length,
              'presets': presets,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://tuner/note-reference',
        name: 'Chromatic Note Reference (Octave 4, A4=440 Hz)',
        description:
            'Canonical chromatic reference table mapping solfege and English note names to MIDI numbers and 12-EDO frequencies at A4=440 Hz.',
        mimeType: 'application/json',
        reader: () async {
          final notes = <Map<String, dynamic>>[];
          for (int i = 0; i < 12; i++) {
            final midi = 60 + i; // C4..B4
            final english = '${TemperamentEngine.chromaticNoteNamesEnglish[i]}4';
            final solfege = '${TemperamentEngine.chromaticNoteNames[i]}4';
            final freq = NoteEntity.frequencyForNote(english, a4Ref: 440.0);
            notes.add({
              'degree': i,
              'solfegeName': solfege,
              'englishName': english,
              'midiNumber': midi,
              'frequencyHz': freq,
            });
          }
          return McpResourceContent.json(
            uri: 'tunner://tuner/note-reference',
            data: {
              'a4Ref': 440.0,
              'octave': 4,
              'notes': notes,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://acoustic-lab/harmonic-intervals',
        name: 'Harmonic Series Partials and THD Thresholds',
        description:
            'Canonical table of the first 8 harmonic series partials and Total Harmonic Distortion (THD) timbre classification thresholds.',
        mimeType: 'application/json',
        reader: () async {
          final harmonics = List.generate(
            8,
            (idx) => {
              'k': idx + 1,
              'label': HarmonicBarEntity.getLabelForHarmonic(idx + 1),
            },
            growable: false,
          );
          return McpResourceContent.json(
            uri: 'tunner://acoustic-lab/harmonic-intervals',
            data: {
              'harmonics': harmonics,
              'thdThresholds': const [
                {
                  'maxPercent': 8.0,
                  'classification': 'Puro y Suave (Tipo Senoidal / Flauta Dulce)',
                },
                {
                  'maxPercent': 25.0,
                  'classification': 'Cálido y Redondo (Flauta Traversa / Voz Media)',
                },
                {
                  'maxPercent': 55.0,
                  'classification': 'Brillante y Resonante (Violín / Vientos Madera)',
                },
                {
                  'maxPercent': 100.0,
                  'classification': 'Penetrante y Armónico (Trompeta / Caña Doble)',
                },
              ],
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (6)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_detect_pitch_wav',
        description:
            'Runs sliding-window McLeod Pitch Method (MPM) contour analysis on a WAV file inside the workspace, computing median/mean pitch, dominant note, and cents deviation against a chosen temperament.',
        inputSchema: {
          'type': 'object',
          'required': ['wavFilePath'],
          'properties': {
            'wavFilePath': {'type': 'string'},
            'windowSize': {'type': 'integer', 'minimum': 256, 'maximum': 16384},
            'hopSize': {'type': 'integer', 'minimum': 64, 'maximum': 8192},
            'a4Ref': {'type': 'number', 'minimum': 220.0, 'maximum': 880.0},
            'temperamentId': {'type': 'string'},
            'rootKey': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'anchorA4': {'type': 'boolean'},
            'minClarity': {'type': 'number', 'minimum': 0.05, 'maximum': 0.99},
            'silenceThreshold': {'type': 'number', 'minimum': 0.0001, 'maximum': 0.5},
            'rigorPreset': {
              'type': 'string',
              'enum': [
                'beginner',
                'balancedRehearsal',
                'studioRecording',
                'noisyStage',
                'conservatoryMastery',
                'custom',
              ],
            },
            'applyDcBlocker': {'type': 'boolean'},
            'maxFrames': {'type': 'integer', 'minimum': 1, 'maximum': 5000},
          },
        },
        handler: _handleDetectPitchWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_frequency_to_note',
        description:
            'Maps a frequency in Hz (or noteName) to solfege/English note names, MIDI number, target frequency, and cents deviation under a selected historical temperament.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'frequencyHz': {'type': 'number', 'minimum': 20.0, 'maximum': 20000.0},
            'noteName': {'type': 'string'},
            'a4Ref': {'type': 'number', 'minimum': 220.0, 'maximum': 880.0},
            'temperamentId': {'type': 'string'},
            'rootKey': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'anchorA4': {'type': 'boolean'},
          },
        },
        handler: _handleFrequencyToNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_temperament_table',
        description:
            'Computes the 12-tone chromatic frequency and cents-offset table for a given historical temperament, tonic rootKey, octave, and A4 reference.',
        inputSchema: {
          'type': 'object',
          'required': ['temperamentId'],
          'properties': {
            'temperamentId': {'type': 'string'},
            'rootKey': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'octave': {'type': 'integer', 'minimum': 0, 'maximum': 8},
            'a4Ref': {'type': 'number', 'minimum': 220.0, 'maximum': 880.0},
            'anchorA4': {'type': 'boolean'},
          },
        },
        handler: _handleTemperamentTable,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_analyze_harmonics_wav',
        description:
            'Performs directed Hann-windowed DFT harmonic series analysis on a WAV file, with optional auto-F0 detection, returning partial amplitudes, spectral centroid, THD %, and timbre classification.',
        inputSchema: {
          'type': 'object',
          'required': ['wavFilePath'],
          'properties': {
            'wavFilePath': {'type': 'string'},
            'fundamentalHz': {'type': 'number', 'minimum': 20.0, 'maximum': 10000.0},
            'startTimeMs': {'type': 'integer', 'minimum': 0},
            'windowSize': {'type': 'integer', 'minimum': 256, 'maximum': 16384},
            'maxHarmonics': {'type': 'integer', 'minimum': 1, 'maximum': 24},
          },
        },
        handler: _handleAnalyzeHarmonicsWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_analyze_noise_floor_wav',
        description:
            'Measures ambient RMS, peak RMS, DC-offset, and recommended noise gate threshold on a WAV file using SignalConditioningFilter.',
        inputSchema: {
          'type': 'object',
          'required': ['wavFilePath'],
          'properties': {
            'wavFilePath': {'type': 'string'},
            'frameSize': {'type': 'integer', 'minimum': 128, 'maximum': 16384},
          },
        },
        handler: _handleAnalyzeNoiseFloorWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_simulate_echo_suppression',
        description:
            'Simulates AcousticEchoSuppressor (AES) blanking window behavior on a timeline of metronome click timestamps and detected pitch events.',
        inputSchema: {
          'type': 'object',
          'required': ['clickTimestampsMs', 'pitchEvents'],
          'properties': {
            'clickTimestampsMs': {
              'type': 'array',
              'items': {'type': 'integer', 'minimum': 0},
            },
            'pitchEvents': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['timeMs', 'pitchHz'],
                'properties': {
                  'timeMs': {'type': 'integer', 'minimum': 0},
                  'pitchHz': {'type': 'number', 'minimum': 0.0},
                },
              },
            },
            'blankingDurationMs': {'type': 'integer', 'minimum': 1, 'maximum': 500},
          },
        },
        handler: _handleSimulateEchoSuppression,
      ),
    );
  }

  // ===========================================================================
  // Prompts (2)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'audit_recording_intonation_and_timbre',
        description:
            'Guided acoustic audit pipeline combining noise-floor analysis, pitch contour detection under a temperament, and harmonic series timbre analysis.',
        arguments: const [
          McpPromptArgument(
            name: 'wavFilePath',
            description: 'Workspace-relative path to the WAV recording.',
            required: true,
          ),
          McpPromptArgument(
            name: 'temperamentId',
            description: 'Target temperament ID (default equal).',
            required: false,
          ),
          McpPromptArgument(
            name: 'a4Ref',
            description: 'Concert pitch A4 in Hz (default 440.0).',
            required: false,
          ),
        ],
        builder: (args) async {
          final wavPath = args['wavFilePath']!;
          final temperamentId = args['temperamentId'] ?? 'equal';
          final a4Ref = args['a4Ref'] ?? '440.0';
          return McpPromptResult(
            description: 'Intonation and timbre forensic audit workflow.',
            messages: [
              McpPromptMessage.user(
                'Perform a full acoustic intonation and timbre audit on "$wavPath" '
                '(temperament: "$temperamentId", A4=$a4Ref Hz):\n'
                '1. Call `tunner_analyze_noise_floor_wav` to inspect RMS noise floor and DC offset.\n'
                '2. Call `tunner_detect_pitch_wav` with `temperamentId: "$temperamentId"` and `a4Ref: $a4Ref`.\n'
                '3. Call `tunner_analyze_harmonics_wav` to measure THD %, spectral centroid, and timbre quality.\n'
                '4. Summarize pitch stability, cents deviation, and overtone profile.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'compare_historical_temperaments',
        description:
            'Guided comparison of 12-EDO, Just Intonation, Werckmeister III, and Vallotti frequency tables in a target key.',
        arguments: const [
          McpPromptArgument(
            name: 'rootKey',
            description: 'Chromatic tonic index 0..11 (default 0 = C/Do).',
            required: false,
          ),
          McpPromptArgument(
            name: 'octave',
            description: 'Target octave 0..8 (default 4).',
            required: false,
          ),
          McpPromptArgument(
            name: 'a4Ref',
            description: 'Concert pitch A4 in Hz (default 440.0).',
            required: false,
          ),
        ],
        builder: (args) async {
          final rootKey = args['rootKey'] ?? '0';
          final octave = args['octave'] ?? '4';
          final a4Ref = args['a4Ref'] ?? '440.0';
          return McpPromptResult(
            description: 'Historical temperament comparison workflow.',
            messages: [
              McpPromptMessage.user(
                'Compare historical temperaments for rootKey=$rootKey, octave=$octave, A4=$a4Ref Hz:\n'
                '1. Read `tunner://tuner/temperaments`.\n'
                '2. Call `tunner_temperament_table` for "equal", "just_intonation", "werckmeister_iii", and "vallotti".\n'
                '3. Contrast major thirds, pure fifths, and wolf intervals across the four systems.',
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

  Future<McpToolResult> _handleDetectPitchWav(Map<String, dynamic> args) async {
    final wavFilePath = _requireString(args, 'wavFilePath');
    final file = _resolveWorkspaceFile(wavFilePath);
    if (!await file.exists()) {
      throw McpException.fileNotFound('WAV file not found: $wavFilePath');
    }

    final windowSize = (_optionalInt(args, 'windowSize') ?? 4096).clamp(256, 16384);
    final hopSize = (_optionalInt(args, 'hopSize') ?? 1024).clamp(64, 8192);
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final temperamentId = _optionalString(args, 'temperamentId');
    final rootKey = (_optionalInt(args, 'rootKey') ?? 0).clamp(0, 11);
    final anchorA4 = _optionalBool(args, 'anchorA4') ?? true;
    final applyDcBlocker = _optionalBool(args, 'applyDcBlocker') ?? false;
    final rawRigor = _optionalString(args, 'rigorPreset');
    final customMinClarity = _optionalDouble(args, 'minClarity');
    final customSilence = _optionalDouble(args, 'silenceThreshold');
    final maxFrames = _optionalInt(args, 'maxFrames');

    final MusicalTemperament? temperament =
        temperamentId != null ? TemperamentEngine.getById(temperamentId) : null;

    OfflinePitchContourAnalyzer analyzer = facade.offlinePitchContourAnalyzer;
    if (rawRigor != null || customMinClarity != null || customSilence != null) {
      double minClarity = 0.40;
      double silenceThreshold = 0.005;
      if (rawRigor != null) {
        final preset = _parseRigorPreset(rawRigor);
        final profile = AcousticRigorProfile.fromPreset(preset);
        minClarity = profile.minClarity;
        silenceThreshold = profile.noiseGateThreshold;
      }
      if (customMinClarity != null) {
        minClarity = customMinClarity.clamp(0.05, 0.99);
      }
      if (customSilence != null) {
        silenceThreshold = customSilence.clamp(0.0001, 0.5);
      }
      analyzer = OfflinePitchContourAnalyzer(
        pitchDetector: McleodPitchMethod(
          minClarity: minClarity,
          silenceThreshold: silenceThreshold,
        ),
        temperamentEngine: _temperamentEngine,
      );
    }

    final wavBytes = await file.readAsBytes();
    final OfflinePitchContourResult result;
    try {
      result = analyzer.analyzeWavBytes(
        wavBytes,
        windowSize: windowSize,
        hopSize: hopSize,
        a4Ref: a4Ref,
        temperament: temperament,
        rootKey: rootKey,
        anchorA4: anchorA4,
        applyDcBlocker: applyDcBlocker,
      );
    } catch (e) {
      throw McpException.acousticError('Failed to decode or analyze WAV: $e');
    }

    final framesSource = (maxFrames != null && result.samples.length > maxFrames)
        ? result.samples.sublist(0, maxFrames)
        : result.samples;

    final frames = framesSource
        .map(
          (s) => {
            'timeMs': s.timeMs,
            'pitched': !s.isSilent && s.frequencyHz > 20.0,
            'pitchHz': s.frequencyHz,
            'noteName': s.targetNoteName,
            'cents': s.centsDeviation,
          },
        )
        .toList(growable: false);

    return McpToolResult.json({
      'wavFilePath': file.path,
      'sampleRate': result.sampleRate,
      'durationSeconds': result.durationSeconds,
      'totalFrameCount': result.samples.length,
      'voicedFrameCount': result.voicedFrameCount,
      'medianPitchHz': result.medianPitchHz,
      'meanPitchHz': result.meanPitchHz,
      'averageAbsoluteCentsDeviation': result.averageAbsoluteCentsDeviation,
      'temperamentId': temperament?.id ?? 'equal',
      'a4Ref': a4Ref,
      if (result.dominantNote != null)
        'dominantNote': result.dominantNote!.toJson(),
      'frames': frames,
    });
  }

  Future<McpToolResult> _handleFrequencyToNote(
    Map<String, dynamic> args,
  ) async {
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final temperamentId = _optionalString(args, 'temperamentId') ?? 'equal';
    final rootKey = (_optionalInt(args, 'rootKey') ?? 0).clamp(0, 11);
    final anchorA4 = _optionalBool(args, 'anchorA4') ?? true;

    double? freq = _optionalDouble(args, 'frequencyHz');
    final noteName = _optionalString(args, 'noteName');
    if (freq == null && noteName != null) {
      freq = NoteEntity.frequencyForNote(noteName, a4Ref: a4Ref);
      if (freq <= 0.0) {
        throw McpException.invalidMusicTheory(
          'Unable to parse note name "$noteName".',
        );
      }
    }
    if (freq == null || freq <= 0.0 || !freq.isFinite) {
      throw const McpException.invalidParams(
        'Provide a positive "frequencyHz" or a valid "noteName".',
      );
    }

    final note = NoteEntity.fromFrequency(freq, a4Ref: a4Ref);
    final temperament = TemperamentEngine.getById(temperamentId);
    final targetHz = _temperamentEngine.getTargetFrequency(
      midiNumber: note.midiNumber,
      temperament: temperament,
      a4Ref: a4Ref,
      rootKey: rootKey,
      anchorA4: anchorA4,
    );
    final centsDeviation = _temperamentEngine.calculateCentsDeviation(
      detectedFrequency: freq,
      targetFrequency: targetHz,
    );

    return McpToolResult.json({
      'inputFrequencyHz': freq,
      'solfegeName': note.toSolfegeName(),
      'englishName': note.toEnglishName(),
      'midiNumber': note.midiNumber,
      'targetFrequencyHz': targetHz,
      'centsDeviation': centsDeviation,
      'temperamentId': temperament.id,
      'a4Ref': a4Ref,
    });
  }

  Future<McpToolResult> _handleTemperamentTable(
    Map<String, dynamic> args,
  ) async {
    final temperamentId = _requireString(args, 'temperamentId');
    final rootKey = (_optionalInt(args, 'rootKey') ?? 0).clamp(0, 11);
    final octave = (_optionalInt(args, 'octave') ?? 4).clamp(0, 8);
    final a4Ref = _optionalDouble(args, 'a4Ref') ?? 440.0;
    final anchorA4 = _optionalBool(args, 'anchorA4') ?? true;

    final temperament = TemperamentEngine.getById(temperamentId);
    final baseMidi = (octave + 1) * 12;
    final notes = <Map<String, dynamic>>[];

    for (int degree = 0; degree < 12; degree++) {
      final midi = baseMidi + degree;
      final centsOffset = _temperamentEngine.getCentsOffset(
        noteIndex: degree,
        temperament: temperament,
        rootKey: rootKey,
      );
      final freqHz = _temperamentEngine.getTargetFrequency(
        midiNumber: midi,
        temperament: temperament,
        a4Ref: a4Ref,
        rootKey: rootKey,
        anchorA4: anchorA4,
      );
      notes.add({
        'degree': degree,
        'solfege': '${TemperamentEngine.chromaticNoteNames[degree]}$octave',
        'english': '${TemperamentEngine.chromaticNoteNamesEnglish[degree]}$octave',
        'midi': midi,
        'centsOffset': centsOffset,
        'frequencyHz': freqHz,
      });
    }

    return McpToolResult.json({
      'temperamentId': temperament.id,
      'temperamentName': temperament.name,
      'rootKey': rootKey,
      'octave': octave,
      'a4Ref': a4Ref,
      'anchorA4': anchorA4,
      'notes': notes,
    });
  }

  Future<McpToolResult> _handleAnalyzeHarmonicsWav(
    Map<String, dynamic> args,
  ) async {
    final wavFilePath = _requireString(args, 'wavFilePath');
    final file = _resolveWorkspaceFile(wavFilePath);
    if (!await file.exists()) {
      throw McpException.fileNotFound('WAV file not found: $wavFilePath');
    }

    final fundamentalHz = _optionalDouble(args, 'fundamentalHz');
    final startTimeMs = (_optionalInt(args, 'startTimeMs') ?? 0).clamp(0, 1 << 30);
    final windowSize = (_optionalInt(args, 'windowSize') ?? 4096).clamp(256, 16384);
    final maxHarmonics = (_optionalInt(args, 'maxHarmonics') ?? 8).clamp(1, 24);

    final wavBytes = await file.readAsBytes();
    final analyzer = HarmonicSeriesAnalyzer(maxHarmonics: maxHarmonics);
    final TimbreAnalysisResult analysis;
    try {
      analysis = analyzer.analyzeWavBytes(
        wavBytes,
        fundamentalHz: fundamentalHz,
        windowSize: windowSize,
        startTimeMs: startTimeMs,
      );
    } catch (e) {
      throw McpException.acousticError('Failed to analyze WAV harmonics: $e');
    }

    return McpToolResult.json({
      'wavFilePath': file.path,
      ...analysis.toJson(),
    });
  }

  Future<McpToolResult> _handleAnalyzeNoiseFloorWav(
    Map<String, dynamic> args,
  ) async {
    final wavFilePath = _requireString(args, 'wavFilePath');
    final file = _resolveWorkspaceFile(wavFilePath);
    if (!await file.exists()) {
      throw McpException.fileNotFound('WAV file not found: $wavFilePath');
    }

    final frameSize = (_optionalInt(args, 'frameSize') ?? 2048).clamp(128, 16384);
    final wavBytes = await file.readAsBytes();
    final DecodedWavAudio decoded;
    try {
      decoded = OfflineWavDecoder.decode(wavBytes);
    } catch (e) {
      throw McpException.acousticError('Failed to decode WAV file: $e');
    }

    final frames = <Float64List>[];
    final samples = decoded.samples;
    for (int offset = 0; offset < samples.length; offset += frameSize) {
      final end = math.min(offset + frameSize, samples.length);
      if (end - offset >= 64) {
        frames.add(Float64List.sublistView(samples, offset, end));
      }
    }

    final report = SignalConditioningFilter.analyzeNoiseFrames(frames);
    return McpToolResult.json({
      'wavFilePath': file.path,
      'sampleRate': decoded.sampleRate,
      'meanRms': report.meanRms,
      'peakRms': report.peakRms,
      'recommendedNoiseGate': report.recommendedNoiseGate,
      'detectedDcOffset': report.detectedDcOffset,
      'totalFramesAnalyzed': report.totalFramesAnalyzed,
    });
  }

  Future<McpToolResult> _handleSimulateEchoSuppression(
    Map<String, dynamic> args,
  ) async {
    final rawClicks = args['clickTimestampsMs'];
    final rawPitches = args['pitchEvents'];
    if (rawClicks is! List) {
      throw const McpException.invalidParams(
        'Parameter "clickTimestampsMs" must be an array of integers.',
      );
    }
    if (rawPitches is! List) {
      throw const McpException.invalidParams(
        'Parameter "pitchEvents" must be an array of pitch event objects.',
      );
    }

    final blankingDurationMs =
        (_optionalInt(args, 'blankingDurationMs') ?? 70).clamp(1, 500);

    final timeline = <_EchoSimEvent>[];
    for (final c in rawClicks) {
      if (c is! num) {
        throw const McpException.invalidParams(
          'All entries in "clickTimestampsMs" must be integers.',
        );
      }
      timeline.add(_EchoSimEvent(timeMs: c.toInt(), isClick: true, pitchHz: 0.0));
    }

    for (final p in rawPitches) {
      if (p is! Map<String, dynamic>) {
        throw const McpException.invalidParams(
          'All entries in "pitchEvents" must be JSON objects.',
        );
      }
      final timeMs = _requireInt(p, 'timeMs');
      final pitchHz = _requireDouble(p, 'pitchHz');
      timeline.add(_EchoSimEvent(timeMs: timeMs, isClick: false, pitchHz: pitchHz));
    }

    timeline.sort((a, b) {
      final cmp = a.timeMs.compareTo(b.timeMs);
      if (cmp != 0) return cmp;
      // Process clicks before pitch events at the exact same timestamp.
      if (a.isClick == b.isClick) return 0;
      return a.isClick ? -1 : 1;
    });

    final suppressor = AcousticEchoSuppressor(
      blankingDurationMs: blankingDurationMs,
    );
    final results = <Map<String, dynamic>>[];

    for (final event in timeline) {
      if (event.isClick) {
        suppressor.notifyClickEmitted(timestampMs: event.timeMs);
      } else {
        final suppressed = suppressor.shouldSuppressPitch(
          event.pitchHz,
          timestampMs: event.timeMs,
        );
        results.add({
          'timeMs': event.timeMs,
          'pitchHz': event.pitchHz,
          'suppressed': suppressed,
        });
      }
    }

    return McpToolResult.json({
      'blankingDurationMs': blankingDurationMs,
      'results': results,
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

  static AcousticRigorPreset _parseRigorPreset(String raw) {
    for (final p in AcousticRigorPreset.values) {
      if (p.name == raw) return p;
    }
    throw McpException.invalidParams('Invalid rigorPreset "$raw".');
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

class _EchoSimEvent {
  final int timeMs;
  final bool isClick;
  final double pitchHz;

  const _EchoSimEvent({
    required this.timeMs,
    required this.isClick,
    required this.pitchHz,
  });
}
