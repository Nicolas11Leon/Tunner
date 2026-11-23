import 'dart:io';
import 'dart:typed_data';

import '../../features/metronome/domain/offline_metronome_track_generator.dart';
import '../../features/metronome/domain/tap_tempo_engine.dart';
import '../../features/metronome/domain/tempo_entity.dart';
import '../../features/sheet_music/domain/score_tree.dart';
import '../../features/song_library/domain/song_package_entity.dart';
import '../../features/vocal_autotune/domain/autotune_config_entity.dart';
import '../../features/vocal_autotune/domain/scale_quantizer.dart';
import '../../features/vocal_autotune/domain/vocal_autotune_processor.dart';
import '../../features/vocal_autotune/domain/vocal_score_converter.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing offline vocal pitch quantization, autonomous
/// TD-PSOLA WAV autotune processing, voice-to-score transcription, scale
/// snapping, offline metronome click-track WAV generation, and tap-tempo
/// batch analysis.
class AutotuneMetronomeMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final VocalScoreConverter _vocalScoreConverter;

  AutotuneMetronomeMcpModule(
    this.facade, {
    VocalScoreConverter? vocalScoreConverter,
  }) : _vocalScoreConverter =
            vocalScoreConverter ?? const VocalScoreConverter();

  @override
  String get moduleName => 'autotune_metronome';

  OfflineMetronomeTrackGenerator get _metronomeGenerator =>
      facade.offlineMetronomeTrackGenerator;

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (3)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://vocal-autotune/scales',
        name: 'Vocal AutoTune Musical Scales',
        description:
            'Catalog of the 7 musical scales supported by VocalScaleType and their semitone intervals.',
        mimeType: 'application/json',
        reader: () async {
          final scales = VocalScaleType.values
              .map(
                (s) => {
                  'id': s.name,
                  'displayName': s.displayName,
                  'intervals': s.intervals,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://vocal-autotune/scales',
            data: {
              'count': scales.length,
              'scales': scales,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://vocal-autotune/presets',
        name: 'Vocal AutoTune Presets',
        description:
            'Canonical AutoTuneConfigEntity presets (naturalStudio, smoothPop, hardTuneUrban, vocalDoubler).',
        mimeType: 'application/json',
        reader: () async {
          final presets = [
            {
              'id': 'naturalStudio',
              'config': AutoTuneConfigEntity.naturalStudio().toJson(),
            },
            {
              'id': 'smoothPop',
              'config': AutoTuneConfigEntity.smoothPop().toJson(),
            },
            {
              'id': 'hardTuneUrban',
              'config': AutoTuneConfigEntity.hardTuneUrban().toJson(),
            },
            {
              'id': 'vocalDoubler',
              'config': AutoTuneConfigEntity.vocalDoubler().toJson(),
            },
          ];
          return McpResourceContent.json(
            uri: 'tunner://vocal-autotune/presets',
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
        uri: 'tunner://metronome/tempo-marks',
        name: 'Italian Tempo Marks Catalog',
        description:
            'Canonical catalog of the 8 standard Italian tempo markings (Larghissimo to Prestissimo) with BPM ranges.',
        mimeType: 'application/json',
        reader: () async {
          final marks = TempoMark.standardMarks
              .map((m) => m.toJson())
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://metronome/tempo-marks',
            data: {
              'count': marks.length,
              'marks': marks,
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
        name: 'tunner_vocal_autotune_wav',
        description:
            'Autonomously extracts F0 contour and applies TD-PSOLA pitch correction with optional formant preservation to a WAV file inside the workspace.',
        inputSchema: {
          'type': 'object',
          'required': ['inputWavPath'],
          'properties': {
            'inputWavPath': {'type': 'string'},
            'outputWavPath': {'type': 'string'},
            'scaleRoot': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'scaleType': {
              'type': 'string',
              'enum': [
                'chromatic',
                'major',
                'naturalMinor',
                'harmonicMinor',
                'majorPentatonic',
                'minorPentatonic',
                'blues',
              ],
            },
            'preset': {
              'type': 'string',
              'enum': [
                'naturalStudio',
                'smoothPop',
                'hardTuneUrban',
                'vocalDoubler',
              ],
            },
            'retuneSpeedMs': {'type': 'number', 'minimum': 0.0, 'maximum': 500.0},
            'correctionAmount': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'formantPreservation': {'type': 'boolean'},
            'leadVocalMix': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
            'a4Reference': {'type': 'number', 'minimum': 220.0, 'maximum': 880.0},
            'windowSize': {'type': 'integer', 'minimum': 256, 'maximum': 16384},
            'hopSize': {'type': 'integer', 'minimum': 64, 'maximum': 8192},
            'crossfadeMs': {'type': 'number', 'minimum': 0.0, 'maximum': 40.0},
          },
        },
        handler: _handleVocalAutotuneWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vocal_quantize_pitch',
        description:
            'Quantizes a detected pitch in Hz to the nearest allowed pitch class of a configured musical scale using ScaleQuantizer.',
        inputSchema: {
          'type': 'object',
          'required': ['detectedPitchHz', 'config'],
          'properties': {
            'detectedPitchHz': {'type': 'number', 'minimum': 0.0, 'maximum': 20000.0},
            'config': {'type': 'object'},
            'deltaSeconds': {'type': 'number', 'minimum': 0.001, 'maximum': 1.0},
          },
        },
        handler: _handleVocalQuantizePitch,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vocal_wav_to_score',
        description:
            'Extracts a pitch contour from a vocal WAV file and transcribes it into a quantized HierarchicalScore via VocalScoreConverter.',
        inputSchema: {
          'type': 'object',
          'required': ['inputWavPath', 'bpm'],
          'properties': {
            'inputWavPath': {'type': 'string'},
            'title': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 30, 'maximum': 300},
            'timeSignatureNumerator': {'type': 'integer', 'minimum': 1, 'maximum': 16},
            'timeSignatureDenominator': {'type': 'integer', 'minimum': 1, 'maximum': 16},
            'preferCorrectedPitch': {'type': 'boolean'},
            'setAsActiveScore': {'type': 'boolean'},
            'snapToScale': {
              'type': 'object',
              'required': ['rootKey', 'scaleType'],
              'properties': {
                'rootKey': {'type': 'integer', 'minimum': 0, 'maximum': 11},
                'scaleType': {'type': 'string'},
              },
            },
          },
        },
        handler: _handleVocalWavToScore,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_vocal_snap_score_to_scale',
        description:
            'Snaps all pitched notes in a SongPackage JSON object to the nearest allowed degree of a target scale (Melodyne-style 1-Tap Snap).',
        inputSchema: {
          'type': 'object',
          'required': ['scorePackageJson', 'rootKey', 'scaleType'],
          'properties': {
            'scorePackageJson': {'type': 'object'},
            'rootKey': {'type': 'integer', 'minimum': 0, 'maximum': 11},
            'scaleType': {'type': 'string'},
          },
        },
        handler: _handleVocalSnapScoreToScale,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_metronome_generate_click_wav',
        description:
            'Generates a deterministic 16-bit mono WAV metronome click-track supporting simple and compound meters (3/4, 4/4, 6/8, etc.), subdivisions, and count-in bars.',
        inputSchema: {
          'type': 'object',
          'required': ['bpm', 'bars', 'outputPath'],
          'properties': {
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'numerator': {'type': 'integer', 'minimum': 1, 'maximum': 32},
            'denominator': {'type': 'integer', 'minimum': 1, 'maximum': 16},
            'bars': {'type': 'integer', 'minimum': 1, 'maximum': 256},
            'countInBars': {'type': 'integer', 'minimum': 0, 'maximum': 16},
            'subdivision': {'type': 'integer', 'minimum': 1, 'maximum': 4},
            'sampleRate': {'type': 'integer', 'minimum': 8000, 'maximum': 96000},
            'outputPath': {'type': 'string'},
          },
        },
        handler: _handleMetronomeGenerateClickWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_metronome_analyze_tap_tempo',
        description:
            'Analyzes a sequence of tap timestamps in milliseconds using TapTempoEngine to compute weighted BPM, jitter statistics, and Italian tempo mark.',
        inputSchema: {
          'type': 'object',
          'required': ['timestampsMs'],
          'properties': {
            'timestampsMs': {
              'type': 'array',
              'minItems': 1,
              'items': {'type': 'integer', 'minimum': 0},
            },
            'minBpm': {'type': 'integer', 'minimum': 20, 'maximum': 250},
            'maxBpm': {'type': 'integer', 'minimum': 40, 'maximum': 300},
            'inactivityTimeoutMs': {'type': 'integer', 'minimum': 500, 'maximum': 10000},
          },
        },
        handler: _handleMetronomeAnalyzeTapTempo,
      ),
    );
  }

  // ===========================================================================
  // Prompts (2)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'vocal_take_postproduction_pipeline',
        description:
            'Guided vocal post-production pipeline: pitch audit, preset selection, autonomous TD-PSOLA autotune rendering, and voice-to-score transcription.',
        arguments: const [
          McpPromptArgument(
            name: 'inputWavPath',
            description: 'Workspace-relative path to the raw vocal WAV take.',
            required: true,
          ),
          McpPromptArgument(
            name: 'scaleRoot',
            description: 'Chromatic tonic index 0..11 (default 0 = Do/C).',
            required: false,
          ),
          McpPromptArgument(
            name: 'scaleType',
            description: 'Target VocalScaleType (default major).',
            required: false,
          ),
          McpPromptArgument(
            name: 'bpm',
            description: 'Target transcription tempo in BPM (default 120).',
            required: false,
          ),
        ],
        builder: (args) async {
          final inputPath = args['inputWavPath']!;
          final scaleRoot = args['scaleRoot'] ?? '0';
          final scaleType = args['scaleType'] ?? 'major';
          final bpm = args['bpm'] ?? '120';
          return McpPromptResult(
            description: 'Vocal take post-production and transcription workflow.',
            messages: [
              McpPromptMessage.user(
                'Process the vocal take at "$inputPath" in scaleRoot=$scaleRoot, '
                'scaleType="$scaleType", bpm=$bpm:\n'
                '1. Read `tunner://vocal-autotune/scales` and `tunner://vocal-autotune/presets`.\n'
                '2. Inspect raw intonation with `tunner_detect_pitch_wav`.\n'
                '3. Run `tunner_vocal_autotune_wav` with formant preservation enabled.\n'
                '4. Transcribe the corrected WAV to sheet music via `tunner_vocal_wav_to_score`.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'build_rehearsal_click_track',
        description:
            'Guided workflow to calibrate tempo via tap-tempo analysis, inspect Italian tempo markings, and render a rehearsal click-track WAV.',
        arguments: const [
          McpPromptArgument(
            name: 'bpm',
            description: 'Target BPM if already known (default 108).',
            required: false,
          ),
          McpPromptArgument(
            name: 'meter',
            description: 'Time signature such as 3/4, 4/4, or 6/8 (default 4/4).',
            required: false,
          ),
          McpPromptArgument(
            name: 'bars',
            description: 'Number of rehearsal bars (default 8).',
            required: false,
          ),
        ],
        builder: (args) async {
          final bpm = args['bpm'] ?? '108';
          final meter = args['meter'] ?? '4/4';
          final bars = args['bars'] ?? '8';
          return McpPromptResult(
            description: 'Rehearsal click-track generation workflow.',
            messages: [
              McpPromptMessage.user(
                'Build a rehearsal click track at $bpm BPM in $meter for $bars bars:\n'
                '1. If tap timestamps are provided, analyze them with `tunner_metronome_analyze_tap_tempo`.\n'
                '2. Read `tunner://metronome/tempo-marks` to confirm the Italian tempo marking.\n'
                '3. Render the WAV click track with `tunner_metronome_generate_click_wav` '
                'including 1 count-in bar.',
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

  Future<McpToolResult> _handleVocalAutotuneWav(
    Map<String, dynamic> args,
  ) async {
    final inputWavPath = _requireString(args, 'inputWavPath');
    final inputFile = _resolveWorkspaceFile(inputWavPath);
    if (!await inputFile.exists()) {
      throw McpException.fileNotFound('Input WAV file not found: $inputWavPath');
    }

    final rawOutputPath = _optionalString(args, 'outputWavPath') ??
        _deriveAutotunedOutputPath(inputWavPath);
    final outputFile = _resolveWorkspaceFile(rawOutputPath);

    final config = _buildAutoTuneConfig(args);
    final windowSize = (_optionalInt(args, 'windowSize') ?? 4096).clamp(256, 16384);
    final hopSize = (_optionalInt(args, 'hopSize') ?? 1024).clamp(64, 8192);
    final crossfadeMs = (_optionalDouble(args, 'crossfadeMs') ?? 8.0).clamp(0.0, 40.0);

    final inputBytes = await inputFile.readAsBytes();
    final beforeContour = facade.offlinePitchContourAnalyzer.analyzeWavBytes(
      inputBytes,
      windowSize: windowSize,
      hopSize: hopSize,
      a4Ref: config.a4Reference,
    );

    final processor = VocalAutoTuneProcessor(config: config);
    final Uint8List outputBytes;
    try {
      outputBytes = processor.processWavBytes(
        wavBytes: inputBytes,
        customConfig: config,
        windowSize: windowSize,
        hopSize: hopSize,
        crossfadeMs: crossfadeMs,
      );
    } catch (e) {
      throw McpException.acousticError('Failed to process vocal autotune WAV: $e');
    }

    await _writeBytesEnsuringParent(outputFile, outputBytes);

    final afterContour = facade.offlinePitchContourAnalyzer.analyzeWavBytes(
      outputBytes,
      windowSize: windowSize,
      hopSize: hopSize,
      a4Ref: config.a4Reference,
    );

    return McpToolResult.json({
      'inputWavPath': inputFile.path,
      'outputWavPath': outputFile.path,
      'sizeBytes': outputBytes.lengthInBytes,
      'voicedFramesBefore': beforeContour.voicedFrameCount,
      'voicedFramesAfter': afterContour.voicedFrameCount,
      'averageCentsBefore': beforeContour.averageAbsoluteCentsDeviation,
      'averageCentsAfter': afterContour.averageAbsoluteCentsDeviation,
      'medianPitchBeforeHz': beforeContour.medianPitchHz,
      'medianPitchAfterHz': afterContour.medianPitchHz,
      'config': config.toJson(),
    });
  }

  Future<McpToolResult> _handleVocalQuantizePitch(
    Map<String, dynamic> args,
  ) async {
    final detectedPitchHz = _requireDouble(args, 'detectedPitchHz');
    final rawConfig = args['config'];
    if (rawConfig is! Map<String, dynamic>) {
      throw const McpException.invalidParams(
        'Parameter "config" must be a JSON object.',
      );
    }
    final deltaSeconds =
        (_optionalDouble(args, 'deltaSeconds') ?? 0.02).clamp(0.001, 1.0);

    final configMap = Map<String, dynamic>.from(rawConfig);
    configMap.putIfAbsent('isEnabled', () => true);
    final config = AutoTuneConfigEntity.fromJson(configMap);

    final quantizer = ScaleQuantizer();
    final result = quantizer.quantize(
      detectedPitchHz: detectedPitchHz,
      config: config,
      deltaSeconds: deltaSeconds,
    );
    return McpToolResult.json(result.toJson());
  }

  Future<McpToolResult> _handleVocalWavToScore(
    Map<String, dynamic> args,
  ) async {
    final inputWavPath = _requireString(args, 'inputWavPath');
    final inputFile = _resolveWorkspaceFile(inputWavPath);
    if (!await inputFile.exists()) {
      throw McpException.fileNotFound('Input WAV file not found: $inputWavPath');
    }

    final bpm = _requireInt(args, 'bpm').clamp(30, 300);
    final title = _optionalString(args, 'title') ?? 'Vocal Transcription';
    final num = (_optionalInt(args, 'timeSignatureNumerator') ?? 4).clamp(1, 16);
    final den = (_optionalInt(args, 'timeSignatureDenominator') ?? 4).clamp(1, 16);
    final preferCorrected = _optionalBool(args, 'preferCorrectedPitch') ?? false;
    final setAsActiveScore = _optionalBool(args, 'setAsActiveScore') ?? false;

    final wavBytes = await inputFile.readAsBytes();
    final contour = facade.offlinePitchContourAnalyzer.analyzeWavBytes(wavBytes);

    final conversion = _vocalScoreConverter.convertTrackToScore(
      pitchTrack: contour.samples,
      title: title,
      bpm: bpm,
      timeSignature: TimeSignature(num, den),
      preferCorrectedPitch: preferCorrected,
    );

    SongPackage finalPackage = conversion.package;
    final rawSnap = args['snapToScale'];
    if (rawSnap != null) {
      if (rawSnap is! Map<String, dynamic>) {
        throw const McpException.invalidParams(
          'Parameter "snapToScale" must be a JSON object.',
        );
      }
      final rootKey = _requireInt(rawSnap, 'rootKey').clamp(0, 11);
      final scaleType = _parseScaleType(_requireString(rawSnap, 'scaleType'));
      finalPackage = _vocalScoreConverter.snapToScale(
        package: finalPackage,
        rootKey: rootKey,
        scaleType: scaleType,
      );
    }

    if (setAsActiveScore) {
      facade.setActiveScore(finalPackage.score);
    }

    return McpToolResult.json({
      'title': finalPackage.title,
      'bpm': finalPackage.defaultBpm,
      'totalNotes': conversion.totalNotes,
      'measureCount': finalPackage.score.measures.length,
      'averageCentsError': conversion.averageCentsError,
      'autoTunedNotesCount': conversion.autoTunedNotesCount,
      'score': finalPackage.score.toMap(),
      'package': finalPackage.toMap(),
    });
  }

  Future<McpToolResult> _handleVocalSnapScoreToScale(
    Map<String, dynamic> args,
  ) async {
    final rawPackage = args['scorePackageJson'];
    if (rawPackage is! Map<String, dynamic>) {
      throw const McpException.invalidParams(
        'Parameter "scorePackageJson" must be a JSON object.',
      );
    }
    final rootKey = _requireInt(args, 'rootKey').clamp(0, 11);
    final scaleType = _parseScaleType(_requireString(args, 'scaleType'));

    final SongPackage original = SongPackage.fromMap(rawPackage);
    final SongPackage snapped = _vocalScoreConverter.snapToScale(
      package: original,
      rootKey: rootKey,
      scaleType: scaleType,
    );

    int modifiedCount = 0;
    for (int m = 0;
        m < original.score.measures.length && m < snapped.score.measures.length;
        m++) {
      final origNotes = original.score.measures[m].notes;
      final newNotes = snapped.score.measures[m].notes;
      for (int n = 0; n < origNotes.length && n < newNotes.length; n++) {
        if (origNotes[n].noteName != newNotes[n].noteName) {
          modifiedCount++;
        }
      }
    }

    return McpToolResult.json({
      'updatedPackage': snapped.toMap(),
      'modifiedNotesCount': modifiedCount,
    });
  }

  Future<McpToolResult> _handleMetronomeGenerateClickWav(
    Map<String, dynamic> args,
  ) async {
    final bpm = _requireInt(args, 'bpm').clamp(20, 300);
    final numerator = (_optionalInt(args, 'numerator') ?? 4).clamp(1, 32);
    final denominator = (_optionalInt(args, 'denominator') ?? 4).clamp(1, 16);
    final bars = _requireInt(args, 'bars').clamp(1, 256);
    final countInBars = (_optionalInt(args, 'countInBars') ?? 0).clamp(0, 16);
    final subdivision = (_optionalInt(args, 'subdivision') ?? 1).clamp(1, 4);
    final sampleRate = (_optionalInt(args, 'sampleRate') ?? 44100).clamp(8000, 96000);
    final outputPath = _requireString(args, 'outputPath');

    final result = _metronomeGenerator.generateTrack(
      bpm: bpm,
      numerator: numerator,
      denominator: denominator,
      bars: bars,
      countInBars: countInBars,
      subdivision: subdivision,
      sampleRate: sampleRate,
    );

    final outFile = _resolveWorkspaceFile(outputPath);
    await _writeBytesEnsuringParent(outFile, result.wavBytes);

    return McpToolResult.json({
      'outputPath': outFile.path,
      ...result.toJson(),
    });
  }

  Future<McpToolResult> _handleMetronomeAnalyzeTapTempo(
    Map<String, dynamic> args,
  ) async {
    final rawTimestamps = args['timestampsMs'];
    if (rawTimestamps is! List || rawTimestamps.isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "timestampsMs" must be a non-empty array of integers.',
      );
    }

    final timestamps = <int>[];
    for (final item in rawTimestamps) {
      if (item is! num) {
        throw const McpException.invalidParams(
          'All entries in "timestampsMs" must be integers.',
        );
      }
      timestamps.add(item.toInt());
    }

    final minBpm = (_optionalInt(args, 'minBpm') ?? 20).clamp(20, 250);
    final maxBpm = (_optionalInt(args, 'maxBpm') ?? 300).clamp(40, 300);
    final timeoutMs =
        (_optionalInt(args, 'inactivityTimeoutMs') ?? 3200).clamp(500, 10000);

    final engine = TapTempoEngine(
      minBpm: minBpm,
      maxBpm: maxBpm,
      inactivityTimeoutMs: timeoutMs,
    );
    final result = engine.analyzeTimestamps(timestamps);

    return McpToolResult.json(result.toJson());
  }

  // ===========================================================================
  // Helpers & Security
  // ===========================================================================

  AutoTuneConfigEntity _buildAutoTuneConfig(Map<String, dynamic> args) {
    final presetName = _optionalString(args, 'preset');
    AutoTuneConfigEntity base;
    switch (presetName) {
      case 'naturalStudio':
        base = AutoTuneConfigEntity.naturalStudio();
      case 'smoothPop':
        base = AutoTuneConfigEntity.smoothPop();
      case 'hardTuneUrban':
        base = AutoTuneConfigEntity.hardTuneUrban();
      case 'vocalDoubler':
        base = AutoTuneConfigEntity.vocalDoubler();
      case null:
        base = const AutoTuneConfigEntity(isEnabled: true);
      default:
        throw McpException.invalidParams(
          'Invalid preset "$presetName". Expected naturalStudio, smoothPop, hardTuneUrban, or vocalDoubler.',
        );
    }

    final rawScaleType = _optionalString(args, 'scaleType');
    return base.copyWith(
      isEnabled: true,
      scaleRoot: _optionalInt(args, 'scaleRoot')?.clamp(0, 11),
      scaleType: rawScaleType != null ? _parseScaleType(rawScaleType) : null,
      retuneSpeedMs: _optionalDouble(args, 'retuneSpeedMs')?.clamp(0.0, 500.0),
      correctionAmount:
          _optionalDouble(args, 'correctionAmount')?.clamp(0.0, 1.0),
      formantPreservation: _optionalBool(args, 'formantPreservation'),
      leadVocalMix: _optionalDouble(args, 'leadVocalMix')?.clamp(0.0, 1.0),
      a4Reference: _optionalDouble(args, 'a4Reference'),
    );
  }

  static String _deriveAutotunedOutputPath(String inputPath) {
    final lower = inputPath.toLowerCase();
    if (lower.endsWith('.wav')) {
      return '${inputPath.substring(0, inputPath.length - 4)}_autotuned.wav';
    }
    return '${inputPath}_autotuned.wav';
  }

  static VocalScaleType _parseScaleType(String raw) {
    for (final s in VocalScaleType.values) {
      if (s.name == raw) return s;
    }
    throw McpException.invalidParams(
      'Invalid scaleType "$raw". Expected chromatic, major, naturalMinor, harmonicMinor, majorPentatonic, minorPentatonic, or blues.',
    );
  }

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
