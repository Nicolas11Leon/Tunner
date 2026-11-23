import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../features/mixer/domain/mixer_track_entity.dart';
import '../../features/sheet_music/domain/score_tree.dart';
import '../../features/song_library/domain/song_package_entity.dart';
import '../../features/transcription/domain/audio_to_score_transcription_engine.dart';
import '../../features/transcription/domain/live_transcription_engine.dart';
import '../../features/transcription/domain/polyphonic_transcription_engine.dart';
import '../../features/universal_importer/data/pdf_score_parser.dart';
import '../../features/universal_importer/domain/canonical_pitch_notation_codec.dart';
import '../../features/universal_importer/domain/parsed_score_result_entity.dart';
import '../../features/universal_importer/domain/vector_omr_engine.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing universal score ingestion (MusicXML, MXL, MIDI,
/// ABC, PDF Vector OMR, WAV), direct headless Vector OMR geometry processing,
/// offline/frame-based audio transcription, pitch contour analysis, and
/// canonical pitch notation conversion.
///
/// Pure Dart: zero `package:flutter/` or `dart:ui` dependencies.
class ImportersOmrMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final PdfScoreParser _pdfParser;
  final VectorOmrEngine _omrEngine;

  Map<String, dynamic>? _lastImportResult;

  ImportersOmrMcpModule({
    required this.facade,
    PdfScoreParser pdfParser = const PdfScoreParser(),
    VectorOmrEngine omrEngine = const VectorOmrEngine(),
  })  : _pdfParser = pdfParser,
        _omrEngine = omrEngine;

  @override
  String get moduleName => 'importers_omr';

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ---------------------------------------------------------------------------
  // Resources
  // ---------------------------------------------------------------------------

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://importer/formats',
        name: 'Supported Import and Export Formats',
        description:
            'Lists all score, OMR, and audio formats supported by Tunner in headless Pure Dart mode.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://importer/formats',
            data: {
              'import': const [
                'musicxml',
                'xml',
                'mxl',
                'mid',
                'midi',
                'abc',
                'pdf_vector_omr',
                'wav_monophonic',
              ],
              'export': const [
                'musicxml',
                'midi_smf0',
                'midi_smf1',
                'abc',
                'pdf_vector',
              ],
              'transcriptionModes': const [
                'wav_mpm_monophonic',
                'pitch_contour_offline',
                'frames_monophonic',
                'frames_polyphonic',
              ],
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://importer/last-result',
        name: 'Last Import or Transcription Result',
        description:
            'Metadata, counts, and warnings from the most recent import, OMR, or transcription operation in this session.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://importer/last-result',
            data: _lastImportResult ??
                const {
                  'hasResult': false,
                  'format': null,
                  'title': null,
                  'totalMeasures': 0,
                  'totalNotes': 0,
                  'warnings': <String>[],
                },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tools
  // ---------------------------------------------------------------------------

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_import_score',
        description:
            'Universally imports a score from MusicXML (.musicxml/.xml/.mxl), MIDI (.mid/.midi), ABC (.abc), vector PDF (.pdf), or WAV (.wav) via filePath, contentBase64, or textContent.',
        inputSchema: {
          'type': 'object',
          'required': ['fileName'],
          'properties': {
            'filePath': {'type': 'string'},
            'contentBase64': {'type': 'string'},
            'textContent': {'type': 'string'},
            'fileName': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'timeSignature': {'type': 'string'},
            'loadAsActive': {'type': 'boolean'},
          },
        },
        handler: _handleImportScore,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_import_pdf_omr',
        description:
            'Runs headless Vector OMR on a vector PDF score (from workspace filePath or contentBase64) and reconstructs a HierarchicalScore.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'filePath': {'type': 'string'},
            'contentBase64': {'type': 'string'},
            'fileName': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'timeSignature': {'type': 'string'},
            'loadAsActive': {'type': 'boolean'},
          },
        },
        handler: _handleImportPdfOmr,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_omr_process_geometry',
        description:
            'Invokes VectorOmrEngine directly on raw vector lines and rectangles to reconstruct a HierarchicalScore headless.',
        inputSchema: {
          'type': 'object',
          'required': ['lines'],
          'properties': {
            'title': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'timeSignature': {'type': 'string'},
            'loadAsActive': {'type': 'boolean'},
            'lines': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['x1', 'y1', 'x2', 'y2'],
                'properties': {
                  'x1': {'type': 'number'},
                  'y1': {'type': 'number'},
                  'x2': {'type': 'number'},
                  'y2': {'type': 'number'},
                },
              },
            },
            'rects': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['x', 'y', 'width', 'height'],
                'properties': {
                  'x': {'type': 'number'},
                  'y': {'type': 'number'},
                  'width': {'type': 'number'},
                  'height': {'type': 'number'},
                  'isFilled': {'type': 'boolean'},
                },
              },
            },
          },
        },
        handler: _handleOmrProcessGeometry,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_transcribe_wav',
        description:
            'Transcribes a WAV audio buffer or workspace file into a rhythmically quantized HierarchicalScore using MPM, with optional OfflinePitchContourAnalyzer diagnostics.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'filePath': {'type': 'string'},
            'audioBase64': {'type': 'string'},
            'title': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'timeSignature': {'type': 'string'},
            'minClarity': {'type': 'number', 'minimum': 0.1, 'maximum': 1.0},
            'silenceRms': {'type': 'number', 'minimum': 0.0, 'maximum': 0.5},
            'includePitchContour': {'type': 'boolean'},
            'loadAsActive': {'type': 'boolean'},
          },
        },
        handler: _handleTranscribeWav,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_transcribe_frames',
        description:
            'Transcribes a sequence of monophonic or polyphonic pitch frames into a quantized HierarchicalScore using LiveTranscriptionEngine or PolyphonicTranscriptionEngine.',
        inputSchema: {
          'type': 'object',
          'required': ['mode', 'bpm', 'frames'],
          'properties': {
            'mode': {
              'type': 'string',
              'enum': ['monophonic', 'polyphonic'],
            },
            'title': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'timeSignature': {'type': 'string'},
            'loadAsActive': {'type': 'boolean'},
            'frames': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['frameDurationMs'],
                'properties': {
                  'noteName': {'type': 'string'},
                  'noteNames': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                  'frequencyHz': {'type': 'number'},
                  'clarity': {'type': 'number'},
                  'energyRms': {'type': 'number'},
                  'frameDurationMs': {'type': 'number', 'minimum': 1.0},
                },
              },
            },
          },
        },
        handler: _handleTranscribeFrames,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_pitch_convert',
        description:
            'Converts between Latin/English note names, MIDI numbers (0..127), and frequencies in Hz using CanonicalPitchNotationCodec.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'noteName': {'type': 'string'},
            'midiNumber': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            'frequencyHz': {'type': 'number', 'minimum': 15.0, 'maximum': 20000.0},
            'a4Ref': {'type': 'number', 'minimum': 350.0, 'maximum': 500.0},
            'preferFlats': {'type': 'boolean'},
          },
        },
        handler: _handlePitchConvert,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Prompts
  // ---------------------------------------------------------------------------

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'convert_score_pipeline',
        description:
            'Guides an AI agent through importing a score from any supported format, validating metric integrity, and exporting to target formats.',
        arguments: const [
          McpPromptArgument(
            name: 'sourcePath',
            description: 'Workspace-relative path to the source score file.',
            required: true,
          ),
          McpPromptArgument(
            name: 'targetFormats',
            description:
                'Comma-separated export targets (e.g. "musicxml,midi,pdf").',
            required: false,
          ),
        ],
        builder: (args) async {
          final sourcePath = args['sourcePath']!.trim();
          final targets = (args['targetFormats']?.trim().isNotEmpty ?? false)
              ? args['targetFormats']!.trim()
              : 'musicxml, midi, pdf';

          return McpPromptResult(
            description:
                'End-to-end score conversion pipeline with metric validation.',
            messages: [
              McpPromptMessage.user(
                'Convert "$sourcePath" into [$targets] using Tunner MCP:\n'
                '1. Call `tunner_import_score` with `filePath: "$sourcePath"` and `loadAsActive: true`.\n'
                '2. Read `tunner://importer/last-result` and inspect any parser warnings.\n'
                '3. Run `tunner_score_validate` to verify every measure meets its time signature.\n'
                '4. If any measure is invalid, repair it with `tunner_score_quantize` or `tunner_score_insert_note`.\n'
                '5. Export the validated score using the requested exporters (`tunner_export_musicxml`, `tunner_export_midi`, `tunner_export_abc`, `tunner_export_pdf`).',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'transcribe_recording_and_publish',
        description:
            'Transcribes a WAV recording into a clean score, optionally transposes it, and publishes printable PDF and MIDI files.',
        arguments: const [
          McpPromptArgument(
            name: 'wavPath',
            description: 'Workspace-relative path to the WAV recording.',
            required: true,
          ),
          McpPromptArgument(
            name: 'bpm',
            description: 'Estimated tempo in BPM (default: 120).',
            required: false,
          ),
          McpPromptArgument(
            name: 'targetKey',
            description: 'Optional target key or transposition description.',
            required: false,
          ),
        ],
        builder: (args) async {
          final wavPath = args['wavPath']!.trim();
          final bpm = (args['bpm']?.trim().isNotEmpty ?? false)
              ? args['bpm']!.trim()
              : '120';
          final targetKey = (args['targetKey']?.trim().isNotEmpty ?? false)
              ? args['targetKey']!.trim()
              : 'original key';

          return McpPromptResult(
            description:
                'Audio transcription, cleanup, and publication workflow.',
            messages: [
              McpPromptMessage.user(
                'Transcribe "$wavPath" at $bpm BPM and prepare for publication ($targetKey):\n'
                '1. Call `tunner_transcribe_wav` with `filePath: "$wavPath"`, `bpm: $bpm`, `includePitchContour: true`, `loadAsActive: true`.\n'
                '2. Read `tunner://score/active` and inspect the transcribed notes.\n'
                '3. Clean transient artifacts with `tunner_score_quantize`, `tunner_score_delete_note`, or `tunner_score_insert_note`.\n'
                '4. Transpose if needed via `tunner_score_transpose` and validate with `tunner_score_validate`.\n'
                '5. Export printable PDF (`tunner_export_pdf`) and reference MIDI (`tunner_export_midi`).',
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tool Handlers
  // ---------------------------------------------------------------------------

  Future<McpToolResult> _handleImportScore(Map<String, dynamic> args) async {
    final fileName = (args['fileName'] as String?)?.trim() ?? '';
    if (fileName.isEmpty) {
      return McpToolResult.error('Parameter "fileName" must be a non-empty string.');
    }

    final bytes = await _loadInputBytes(
      filePath: args['filePath'] as String?,
      contentBase64: args['contentBase64'] as String?,
      textContent: args['textContent'] as String?,
    );
    if (bytes == null || bytes.isEmpty) {
      return McpToolResult.error(
        'Provide non-empty input via "filePath", "contentBase64", or "textContent".',
      );
    }

    final bpmOverride = (args['bpm'] as num?)?.toInt();
    final rawTs = args['timeSignature'] as String?;
    final loadAsActive = args['loadAsActive'] as bool? ?? true;

    ParsedScoreResult result;
    try {
      final isWav = fileName.toLowerCase().endsWith('.wav') || _isWavHeader(bytes);
      if (isWav && (bpmOverride != null || rawTs != null)) {
        final ts = _parseTimeSignature(rawTs) ?? TimeSignature.commonTime44;
        result = facade.root.scoreImporterService.transcribeAudioToScoreResult(
          bytes: bytes,
          fileName: fileName,
          bpm: (bpmOverride ?? 120).clamp(20, 300),
          timeSignature: ts,
        );
      } else {
        result = await facade.root.scoreImporterService.parseScoreData(
          bytes: bytes,
          fileName: fileName,
        );
      }
    } on FormatException catch (e) {
      return McpToolResult.error('Failed to parse "$fileName": ${e.message}');
    }

    var score = result.package.score;
    if (bpmOverride != null) {
      score = score.copyWith(baseBpm: bpmOverride.clamp(20, 300));
    }

    if (loadAsActive) {
      facade.setActiveScore(score);
    }

    final summary = {
      'hasResult': true,
      'format': result.format,
      'title': result.package.title,
      'composer': result.package.composer,
      'bpm': score.baseBpm,
      'totalMeasures': result.totalMeasures,
      'totalNotes': result.totalNotes,
      'warnings': result.warnings,
      'loadedAsActive': loadAsActive,
    };
    _lastImportResult = summary;

    return McpToolResult.json({
      ...summary,
      'score': score.toMap(),
    });
  }

  Future<McpToolResult> _handleImportPdfOmr(Map<String, dynamic> args) async {
    final fileName = (args['fileName'] as String?)?.trim().isNotEmpty == true
        ? (args['fileName'] as String).trim()
        : 'document.pdf';
    final bytes = await _loadInputBytes(
      filePath: args['filePath'] as String?,
      contentBase64: args['contentBase64'] as String?,
      textContent: null,
    );
    if (bytes == null || bytes.isEmpty) {
      return McpToolResult.error(
        'Provide a vector PDF via "filePath" or "contentBase64".',
      );
    }

    final bpmOverride = (args['bpm'] as num?)?.toInt();
    final loadAsActive = args['loadAsActive'] as bool? ?? true;

    ParsedScoreResult result;
    try {
      result = await _pdfParser.parseScoreData(
        bytes: bytes,
        fileName: fileName,
      );
    } on FormatException catch (e) {
      return McpToolResult.error('Vector OMR failed for "$fileName": ${e.message}');
    }

    var score = result.package.score;
    if (bpmOverride != null) {
      score = score.copyWith(baseBpm: bpmOverride.clamp(20, 300));
    }

    if (loadAsActive) {
      facade.setActiveScore(score);
    }

    final summary = {
      'hasResult': true,
      'format': result.format,
      'title': score.title,
      'bpm': score.baseBpm,
      'totalMeasures': result.totalMeasures,
      'totalNotes': result.totalNotes,
      'warnings': result.warnings,
      'loadedAsActive': loadAsActive,
    };
    _lastImportResult = summary;

    return McpToolResult.json({
      ...summary,
      'score': score.toMap(),
    });
  }

  Future<McpToolResult> _handleOmrProcessGeometry(
    Map<String, dynamic> args,
  ) async {
    final rawLines = args['lines'];
    if (rawLines is! List) {
      return McpToolResult.error('Parameter "lines" must be an array.');
    }
    final rawRects = args['rects'] as List? ?? const [];
    final title = (args['title'] as String?)?.trim().isNotEmpty == true
        ? (args['title'] as String).trim()
        : 'Vector OMR Score';
    final bpm = ((args['bpm'] as num?)?.toInt() ?? 120).clamp(20, 300);
    final ts =
        _parseTimeSignature(args['timeSignature'] as String?) ??
            TimeSignature.commonTime44;
    final loadAsActive = args['loadAsActive'] as bool? ?? true;

    final lines = <OmrLine>[];
    for (final item in rawLines) {
      if (item is! Map<String, dynamic>) continue;
      lines.add(
        OmrLine(
          x1: (item['x1'] as num?)?.toDouble() ?? 0.0,
          y1: (item['y1'] as num?)?.toDouble() ?? 0.0,
          x2: (item['x2'] as num?)?.toDouble() ?? 0.0,
          y2: (item['y2'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    final rects = <OmrRect>[];
    for (final item in rawRects) {
      if (item is! Map<String, dynamic>) continue;
      rects.add(
        OmrRect(
          x: (item['x'] as num?)?.toDouble() ?? 0.0,
          y: (item['y'] as num?)?.toDouble() ?? 0.0,
          width: (item['width'] as num?)?.toDouble() ?? 0.0,
          height: (item['height'] as num?)?.toDouble() ?? 0.0,
          isFilled: item['isFilled'] as bool? ?? true,
        ),
      );
    }

    HierarchicalScore score;
    try {
      score = _omrEngine.processGeometricElements(
        lines: lines,
        rects: rects,
        title: title,
        bpm: bpm,
        timeSignature: ts,
      );
    } on FormatException catch (e) {
      return McpToolResult.error('Vector OMR geometry error: ${e.message}');
    }

    if (loadAsActive) {
      facade.setActiveScore(score);
    }

    int totalNotes = 0;
    for (final m in score.measures) {
      totalNotes += m.notes.where((n) => !n.isRest).length;
    }

    final summary = {
      'hasResult': true,
      'format': 'VectorOMRGeometry',
      'title': score.title,
      'bpm': score.baseBpm,
      'totalMeasures': score.totalMeasures,
      'totalNotes': totalNotes,
      'warnings': const <String>[],
      'loadedAsActive': loadAsActive,
    };
    _lastImportResult = summary;

    return McpToolResult.json({
      ...summary,
      'score': score.toMap(),
    });
  }

  Future<McpToolResult> _handleTranscribeWav(Map<String, dynamic> args) async {
    final bytes = await _loadInputBytes(
      filePath: args['filePath'] as String?,
      contentBase64: args['audioBase64'] as String?,
      textContent: null,
    );
    if (bytes == null || bytes.isEmpty) {
      return McpToolResult.error(
        'Provide WAV audio via "filePath" or "audioBase64".',
      );
    }

    final title = (args['title'] as String?)?.trim().isNotEmpty == true
        ? (args['title'] as String).trim()
        : 'Audio Transcription';
    final bpm = ((args['bpm'] as num?)?.toInt() ?? 120).clamp(20, 300);
    final ts =
        _parseTimeSignature(args['timeSignature'] as String?) ??
            TimeSignature.commonTime44;
    final minClarity =
        ((args['minClarity'] as num?)?.toDouble() ?? 0.65).clamp(0.1, 1.0);
    final silenceRms =
        ((args['silenceRms'] as num?)?.toDouble() ?? 0.005).clamp(0.0, 0.5);
    final includePitchContour = args['includePitchContour'] as bool? ?? false;
    final loadAsActive = args['loadAsActive'] as bool? ?? true;

    final engine = AudioToScoreTranscriptionEngine(
      minClarity: minClarity,
      silenceRms: silenceRms,
    );
    final score = engine.transcribeAudioFile(
      audioBytes: bytes,
      title: title,
      bpm: bpm,
      timeSignature: ts,
    );

    if (loadAsActive) {
      facade.setActiveScore(score);
    }

    int totalNotes = 0;
    for (final m in score.measures) {
      totalNotes += m.notes.where((n) => !n.isRest).length;
    }

    Map<String, dynamic>? pitchContourSummary;
    if (includePitchContour) {
      try {
        final contour = facade.offlinePitchContourAnalyzer.analyzeWavBytes(bytes);
        pitchContourSummary = {
          'sampleRate': contour.sampleRate,
          'durationSeconds': contour.durationSeconds,
          'voicedFrameCount': contour.voicedFrameCount,
          'totalFrameCount': contour.samples.length,
          'medianPitchHz': contour.medianPitchHz,
          'meanPitchHz': contour.meanPitchHz,
          'averageAbsoluteCentsDeviation':
              contour.averageAbsoluteCentsDeviation,
          'dominantNote': contour.dominantNote?.name,
        };
      } catch (e) {
        pitchContourSummary = {'error': e.toString()};
      }
    }

    const warnings = [
      'Monophonic MPM offline transcription executed on WAV audio.',
    ];
    final summary = {
      'hasResult': true,
      'format': 'AudioWAV',
      'title': score.title,
      'bpm': score.baseBpm,
      'totalMeasures': score.totalMeasures,
      'totalNotes': totalNotes,
      'warnings': warnings,
      'loadedAsActive': loadAsActive,
    };
    _lastImportResult = summary;

    return McpToolResult.json({
      ...summary,
      'pitchContour': ?pitchContourSummary,
      'score': score.toMap(),
    });
  }

  Future<McpToolResult> _handleTranscribeFrames(
    Map<String, dynamic> args,
  ) async {
    final mode = (args['mode'] as String?)?.trim().toLowerCase();
    if (mode != 'monophonic' && mode != 'polyphonic') {
      return McpToolResult.error(
        'Parameter "mode" must be "monophonic" or "polyphonic".',
      );
    }

    final bpm = ((args['bpm'] as num?)?.toInt() ?? 120).clamp(20, 300);
    final ts =
        _parseTimeSignature(args['timeSignature'] as String?) ??
            TimeSignature.commonTime44;
    final title = (args['title'] as String?)?.trim().isNotEmpty == true
        ? (args['title'] as String).trim()
        : 'Frame Transcription';
    final loadAsActive = args['loadAsActive'] as bool? ?? true;

    final rawFrames = args['frames'];
    if (rawFrames is! List || rawFrames.isEmpty) {
      return McpToolResult.error('Parameter "frames" must be a non-empty array.');
    }

    final seedPackage = SongPackage(
      id: 'frames_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      composer: 'Tunner Frame Transcriber',
      genre: MusicGenre.contemporary,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: bpm,
      tracks: const [
        AudioTrack(
          id: 'transcribed_track',
          title: 'Transcribed Track',
          instrumentIcon: 'mic',
          volume: 1.0,
        ),
      ],
      score: HierarchicalScore(
        title: title,
        baseBpm: bpm,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: ts,
            notes: [
              HierarchicalNote.rest(startTick: 0, durationTicks: ts.totalTicks),
            ],
          ),
        ],
      ),
    );

    SongPackage resultPackage = seedPackage;
    if (mode == 'monophonic') {
      final engine = LiveTranscriptionEngine();
      engine.start(initialPackage: seedPackage, bpm: bpm);
      for (final raw in rawFrames) {
        if (raw is! Map<String, dynamic>) continue;
        final frameDur =
            ((raw['frameDurationMs'] as num?)?.toDouble() ?? 20.0).clamp(1.0, 2000.0);
        final noteName = (raw['noteName'] as String?)?.trim() ?? '--';
        final clarity = (raw['clarity'] as num?)?.toDouble() ?? 0.95;
        final freq = (raw['frequencyHz'] as num?)?.toDouble() ??
            (noteName != '--'
                ? CanonicalPitchNotationCodec.midiToFrequency(
                    CanonicalPitchNotationCodec.parseOrDefault(noteName)
                        .midiNumber,
                  )
                : 0.0);
        engine.processPitchFrame(
          frequencyHz: freq,
          clarity: clarity,
          noteName: noteName,
          frameDurationMs: frameDur,
        );
      }
      resultPackage = engine.stop() ?? seedPackage;
    } else {
      final engine = PolyphonicTranscriptionEngine();
      engine.start(initialPackage: seedPackage, bpm: bpm);
      for (final raw in rawFrames) {
        if (raw is! Map<String, dynamic>) continue;
        final frameDur =
            ((raw['frameDurationMs'] as num?)?.toDouble() ?? 20.0).clamp(1.0, 2000.0);
        final rawNoteNames = raw['noteNames'];
        final noteNames = rawNoteNames is List
            ? rawNoteNames.map((e) => e.toString().trim()).toList()
            : <String>[];
        final energyRms = (raw['energyRms'] as num?)?.toDouble() ?? 0.2;
        engine.processPolyphonicFrame(
          noteNames: noteNames,
          energyRms: energyRms,
          frameDurationMs: frameDur,
        );
      }
      resultPackage = engine.stop() ?? seedPackage;
    }

    final score = resultPackage.score;
    if (loadAsActive) {
      facade.setActiveScore(score);
    }

    int totalNotes = 0;
    for (final m in score.measures) {
      totalNotes += m.notes.where((n) => !n.isRest).length;
    }

    final summary = {
      'hasResult': true,
      'format': 'Frames($mode)',
      'title': score.title,
      'bpm': score.baseBpm,
      'totalMeasures': score.totalMeasures,
      'totalNotes': totalNotes,
      'warnings': const <String>[],
      'loadedAsActive': loadAsActive,
    };
    _lastImportResult = summary;

    return McpToolResult.json({
      ...summary,
      'score': score.toMap(),
    });
  }

  Future<McpToolResult> _handlePitchConvert(Map<String, dynamic> args) async {
    final noteName = (args['noteName'] as String?)?.trim();
    final midiInput = (args['midiNumber'] as num?)?.toInt();
    final freqInput = (args['frequencyHz'] as num?)?.toDouble();
    final a4Ref = ((args['a4Ref'] as num?)?.toDouble() ?? 440.0).clamp(350.0, 500.0);
    final preferFlats = args['preferFlats'] as bool? ?? false;

    ParsedPitchNotation? parsed;
    int? midi;

    if (noteName != null && noteName.isNotEmpty) {
      parsed = CanonicalPitchNotationCodec.parse(noteName);
      if (parsed == null) {
        return McpToolResult.error('Invalid note name: "$noteName".');
      }
      midi = parsed.midiNumber;
    } else if (midiInput != null) {
      if (midiInput < 0 || midiInput > 127) {
        return McpToolResult.error('midiNumber must be between 0 and 127.');
      }
      midi = midiInput;
      final solfege = CanonicalPitchNotationCodec.midiToSolfege(
        midi,
        preferFlats: preferFlats,
      );
      parsed = CanonicalPitchNotationCodec.parse(solfege);
    } else if (freqInput != null) {
      midi = CanonicalPitchNotationCodec.frequencyToMidi(freqInput, a4Ref: a4Ref);
      if (midi == null) {
        return McpToolResult.error('Invalid frequencyHz: $freqInput.');
      }
      final solfege = CanonicalPitchNotationCodec.midiToSolfege(
        midi,
        preferFlats: preferFlats,
      );
      parsed = CanonicalPitchNotationCodec.parse(solfege);
    } else {
      return McpToolResult.error(
        'Provide at least one of "noteName", "midiNumber", or "frequencyHz".',
      );
    }

    final frequencyHz = CanonicalPitchNotationCodec.midiToFrequency(
      midi,
      a4Ref: a4Ref,
    );

    return McpToolResult.json({
      'solfegeName': parsed?.solfegeName ??
          CanonicalPitchNotationCodec.midiToSolfege(midi, preferFlats: preferFlats),
      'englishName': parsed?.englishName ??
          CanonicalPitchNotationCodec.midiToEnglish(midi, preferFlats: preferFlats),
      'midiNumber': midi,
      'frequencyHz': double.parse(frequencyHz.toStringAsFixed(5)),
      'a4Ref': a4Ref,
      if (parsed != null) 'step': parsed.step,
      if (parsed != null) 'solfegeBase': parsed.solfegeBase,
      if (parsed != null) 'alter': parsed.alter,
      if (parsed != null) 'octave': parsed.octave,
    });
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  Future<Uint8List?> _loadInputBytes({
    required String? filePath,
    required String? contentBase64,
    required String? textContent,
  }) async {
    if (filePath != null && filePath.trim().isNotEmpty) {
      final resolved = _resolveWorkspacePath(filePath.trim());
      final file = File(resolved);
      if (!await file.exists()) {
        throw McpException.fileNotFound('File not found in workspace: $filePath');
      }
      return file.readAsBytes();
    }
    if (contentBase64 != null && contentBase64.trim().isNotEmpty) {
      try {
        return base64Decode(contentBase64.trim());
      } on FormatException {
        throw const McpException.invalidParams('Invalid base64 payload.');
      }
    }
    if (textContent != null && textContent.isNotEmpty) {
      return Uint8List.fromList(utf8.encode(textContent));
    }
    return null;
  }

  String _resolveWorkspacePath(String rawPath) {
    if (rawPath.trim().isEmpty || rawPath.contains('\u0000')) {
      throw const McpException.invalidParams('Invalid file path.');
    }
    final base = _normalizePath(facade.workspaceDirectory.absolute.path);
    final isAbs = rawPath.startsWith('/') ||
        rawPath.startsWith(r'\') ||
        (rawPath.length >= 2 && rawPath[1] == ':');
    final candidate =
        isAbs ? rawPath : '$base${Platform.pathSeparator}$rawPath';
    final normalized = _normalizePath(File(candidate).absolute.path);
    final basePrefix =
        base.endsWith(Platform.pathSeparator) ? base : '$base${Platform.pathSeparator}';
    if (!normalized.startsWith(basePrefix)) {
      throw McpException.securityViolation(
        'Access denied: path escapes workspace boundary ($rawPath).',
      );
    }
    return normalized;
  }

  static String _normalizePath(String input) {
    final sep = Platform.pathSeparator;
    final unified = input.replaceAll('/', sep).replaceAll(r'\', sep);
    final isPosixAbs = unified.startsWith(sep);
    final stack = <String>[];
    for (final seg in unified.split(sep)) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (stack.isNotEmpty && stack.last != '..') {
          stack.removeLast();
        } else if (!isPosixAbs) {
          stack.add('..');
        }
      } else {
        stack.add(seg);
      }
    }
    return isPosixAbs ? '$sep${stack.join(sep)}' : stack.join(sep);
  }

  static TimeSignature? _parseTimeSignature(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parts = raw.trim().split('/');
    if (parts.length != 2) return null;
    final numVal = int.tryParse(parts[0].trim());
    final denVal = int.tryParse(parts[1].trim());
    if (numVal == null || denVal == null) return null;
    if (numVal < 1 || numVal > 32) return null;
    if (denVal != 1 && denVal != 2 && denVal != 4 && denVal != 8 && denVal != 16) {
      return null;
    }
    return TimeSignature(numVal, denVal);
  }

  static bool _isWavHeader(Uint8List bytes) {
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }
}
