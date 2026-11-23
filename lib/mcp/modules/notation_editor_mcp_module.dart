import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../../features/mixer/domain/mixer_track_entity.dart';
import '../../features/score_editor/domain/score_editor_domain.dart';
import '../../features/sheet_music/domain/score_playback_coordinator.dart';
import '../../features/sheet_music/domain/score_tree.dart';
import '../../features/song_library/domain/song_package_entity.dart';
import '../../features/transcription/domain/live_transcription_engine.dart';
import '../../features/universal_importer/domain/canonical_abc_exporter.dart';
import '../../features/universal_importer/domain/canonical_midi_exporter.dart';
import '../../features/universal_importer/domain/canonical_musicxml_exporter.dart';
import '../../features/universal_importer/domain/canonical_pdf_exporter.dart';
import '../../features/universal_importer/domain/canonical_pitch_notation_codec.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing polyphonic score composition, editing,
/// validation, quantization, transposition, undo/redo history, note preview,
/// and canonical multi-format export (MusicXML, MIDI Format 0/1, ABC, PDF SMuFL).
///
/// Pure Dart: zero `package:flutter/` or `dart:ui` dependencies.
class NotationEditorMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final ScoreEditorOperations _operations;
  final ScoreUndoRedoHistory _history;
  final CanonicalMusicXmlExporter _musicXmlExporter;
  final CanonicalMidiExporter _midiExporter;
  final CanonicalAbcExporter _abcExporter;
  final CanonicalPdfExporter _pdfExporter;

  String _activeScoreId = 'mcp_score_default';
  String _activeComposer = 'Tunner MCP Composer';

  NotationEditorMcpModule({
    required this.facade,
    ScoreEditorOperations operations = const ScoreEditorOperations(),
    ScoreUndoRedoHistory? history,
    CanonicalMusicXmlExporter musicXmlExporter =
        const CanonicalMusicXmlExporter(),
    CanonicalMidiExporter midiExporter = const CanonicalMidiExporter(),
    CanonicalAbcExporter abcExporter = const CanonicalAbcExporter(),
    CanonicalPdfExporter pdfExporter = const CanonicalPdfExporter(),
  })  : _operations = operations,
        _history = history ?? ScoreUndoRedoHistory(),
        _musicXmlExporter = musicXmlExporter,
        _midiExporter = midiExporter,
        _abcExporter = abcExporter,
        _pdfExporter = pdfExporter;

  @override
  String get moduleName => 'notation_editor';

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
        uri: 'tunner://score/active',
        name: 'Active Score',
        description:
            'Full hierarchical state of the active polyphonic score in the MCP session.',
        mimeType: 'application/json',
        reader: () async {
          final score = facade.activeScore;
          if (score == null) {
            return McpResourceContent.json(
              uri: 'tunner://score/active',
              data: {
                'hasActiveScore': false,
                'score': null,
              },
            );
          }
          return McpResourceContent.json(
            uri: 'tunner://score/active',
            data: {
              'hasActiveScore': true,
              'id': _activeScoreId,
              'title': score.title,
              'composer': _activeComposer,
              'bpm': score.baseBpm,
              'staffCount': score.staffCount,
              'totalMeasures': score.totalMeasures,
              'isValid': score.isValidScore,
              'measures': score.measures
                  .map((m) => m.toMap())
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://score/studies/canonical',
        name: 'Canonical Pedagogical Studies',
        description:
            'Catalog of built-in pedagogical scores from HierarchicalScore.getCanonicalStudies().',
        mimeType: 'application/json',
        reader: () async {
          final studies = HierarchicalScore.getCanonicalStudies();
          return McpResourceContent.json(
            uri: 'tunner://score/studies/canonical',
            data: {
              'studies': studies.map((s) {
                final ts = s.measures.isNotEmpty
                    ? s.measures.first.timeSignature.toString()
                    : '4/4';
                return {
                  'title': s.title,
                  'baseBpm': s.baseBpm,
                  'totalMeasures': s.totalMeasures,
                  'staffCount': s.staffCount,
                  'timeSignature': ts,
                  'isValid': s.isValidScore,
                };
              }).toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://score/history/status',
        name: 'Score Undo/Redo History Status',
        description:
            'Current state of the Memento Undo/Redo stacks for the active score session.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://score/history/status',
            data: {
              'canUndo': _history.canUndo,
              'canRedo': _history.canRedo,
              'undoCount': _history.undoCount,
              'redoCount': _history.redoCount,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://score/time-signatures',
        name: 'Standard Time Signatures',
        description:
            'Supported standard time signatures and their sub-tick resolution (16th-note base).',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://score/time-signatures',
            data: {
              'baseResolution': '1/16 (4 ticks per quarter note)',
              'signatures': TimeSignature.standardSignatures
                  .map(
                    (ts) => {
                      'label': ts.toString(),
                      'numerator': ts.numerator,
                      'denominator': ts.denominator,
                      'totalTicks': ts.totalTicks,
                    },
                  )
                  .toList(growable: false),
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
        name: 'tunner_score_create',
        description:
            'Creates a new polyphonic HierarchicalScore in the active MCP session with optional Grand Staff support.',
        inputSchema: {
          'type': 'object',
          'required': ['title'],
          'properties': {
            'title': {'type': 'string'},
            'composer': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'timeSignature': {'type': 'string'},
            'keySignatureFifths': {
              'type': 'integer',
              'minimum': -7,
              'maximum': 7,
            },
            'measureCount': {'type': 'integer', 'minimum': 1, 'maximum': 128},
            'staffCount': {'type': 'integer', 'minimum': 1, 'maximum': 4},
          },
        },
        handler: _handleScoreCreate,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_get_measure',
        description:
            'Returns a focused view of a single measure in the active score with metric validation details.',
        inputSchema: {
          'type': 'object',
          'required': ['measureIndex'],
          'properties': {
            'measureIndex': {'type': 'integer', 'minimum': 0},
          },
        },
        handler: _handleGetMeasure,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_insert_note',
        description:
            'Inserts or updates a single note or rest ("--") in a measure, preserving independent (staff, voice) polyphony.',
        inputSchema: {
          'type': 'object',
          'required': ['measureIndex', 'startTick', 'durationTicks', 'noteName'],
          'properties': {
            'measureIndex': {'type': 'integer', 'minimum': 0},
            'startTick': {'type': 'integer', 'minimum': 0},
            'durationTicks': {'type': 'integer', 'minimum': 1},
            'noteName': {'type': 'string'},
            'voice': {'type': 'integer', 'minimum': 1},
            'staff': {'type': 'integer', 'minimum': 1},
            'isTied': {'type': 'boolean'},
          },
        },
        handler: _handleInsertNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_insert_chord',
        description:
            'Inserts simultaneous chord notes at a given measure and tick within a specific (staff, voice) stream.',
        inputSchema: {
          'type': 'object',
          'required': [
            'measureIndex',
            'startTick',
            'durationTicks',
            'noteNames',
          ],
          'properties': {
            'measureIndex': {'type': 'integer', 'minimum': 0},
            'startTick': {'type': 'integer', 'minimum': 0},
            'durationTicks': {'type': 'integer', 'minimum': 1},
            'noteNames': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'voice': {'type': 'integer', 'minimum': 1},
            'staff': {'type': 'integer', 'minimum': 1},
            'isTied': {'type': 'boolean'},
          },
        },
        handler: _handleInsertChord,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_compose_measures',
        description:
            'Atomically composes or replaces one or more polyphonic measures (supporting staff, voice, chords, rests, and ties) in a single call.',
        inputSchema: {
          'type': 'object',
          'required': ['measures'],
          'properties': {
            'measures': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'index': {'type': 'integer', 'minimum': 0},
                  'timeSignature': {'type': 'string'},
                  'keySignatureFifths': {
                    'type': 'integer',
                    'minimum': -7,
                    'maximum': 7,
                  },
                  'events': {
                    'type': 'array',
                    'items': {
                      'type': 'object',
                      'required': ['startTick', 'durationTicks'],
                      'properties': {
                        'startTick': {'type': 'integer', 'minimum': 0},
                        'durationTicks': {'type': 'integer', 'minimum': 1},
                        'notes': {
                          'type': 'array',
                          'items': {'type': 'string'},
                        },
                        'noteName': {'type': 'string'},
                        'isRest': {'type': 'boolean'},
                        'voice': {'type': 'integer', 'minimum': 1},
                        'staff': {'type': 'integer', 'minimum': 1},
                        'isTied': {'type': 'boolean'},
                      },
                    },
                  },
                },
              },
            },
          },
        },
        handler: _handleComposeMeasures,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_delete_note',
        description:
            'Deletes a note at the given measure and tick (optionally filtered by noteName, voice, or staff) and replaces emptied slots with a rest.',
        inputSchema: {
          'type': 'object',
          'required': ['measureIndex', 'startTick'],
          'properties': {
            'measureIndex': {'type': 'integer', 'minimum': 0},
            'startTick': {'type': 'integer', 'minimum': 0},
            'noteName': {'type': 'string'},
            'voice': {'type': 'integer', 'minimum': 1},
            'staff': {'type': 'integer', 'minimum': 1},
          },
        },
        handler: _handleDeleteNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_add_measure',
        description:
            'Appends or inserts an empty rest measure into the active score.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'timeSignature': {'type': 'string'},
            'keySignatureFifths': {
              'type': 'integer',
              'minimum': -7,
              'maximum': 7,
            },
            'insertAtIndex': {'type': 'integer', 'minimum': 0},
          },
        },
        handler: _handleAddMeasure,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_remove_measure',
        description:
            'Removes the measure at measureIndex (preserving at least 1 measure) and re-indexes remaining measures.',
        inputSchema: {
          'type': 'object',
          'required': ['measureIndex'],
          'properties': {
            'measureIndex': {'type': 'integer', 'minimum': 0},
          },
        },
        handler: _handleRemoveMeasure,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_set_metadata',
        description:
            'Updates score metadata (title, composer, bpm, staffCount) and/or measure timeSignature and keySignatureFifths.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'composer': {'type': 'string'},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'staffCount': {'type': 'integer', 'minimum': 1, 'maximum': 4},
            'keySignatureFifths': {
              'type': 'integer',
              'minimum': -7,
              'maximum': 7,
            },
            'measureIndex': {'type': 'integer', 'minimum': 0},
            'timeSignature': {'type': 'string'},
          },
        },
        handler: _handleSetMetadata,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_quantize',
        description:
            'Quantizes note and rest durations in the active score (or a specific measure) to canonical rhythmic values.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'measureIndex': {'type': 'integer', 'minimum': 0},
          },
        },
        handler: _handleQuantize,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_transpose',
        description:
            'Transposes all pitched notes in the active score by semitones (-24..24) using canonical MIDI/enharmonic arithmetic.',
        inputSchema: {
          'type': 'object',
          'required': ['semitones'],
          'properties': {
            'semitones': {'type': 'integer', 'minimum': -24, 'maximum': 24},
            'preferFlats': {'type': 'boolean'},
          },
        },
        handler: _handleTranspose,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_validate',
        description:
            'Validates metric integrity of the active score or a specific measure, reporting exact tick coverage.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'measureIndex': {'type': 'integer', 'minimum': 0},
          },
        },
        handler: _handleValidate,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_undo',
        description: 'Reverts the most recent edit on the active score.',
        inputSchema: {'type': 'object', 'properties': {}},
        handler: _handleUndo,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_redo',
        description: 'Re-applies the most recently undone edit on the active score.',
        inputSchema: {'type': 'object', 'properties': {}},
        handler: _handleRedo,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_score_preview_note',
        description:
            'Auditions a single note via the headless ScorePlaybackCoordinator and returns its MIDI number and frequency.',
        inputSchema: {
          'type': 'object',
          'required': ['noteName'],
          'properties': {
            'noteName': {'type': 'string'},
            'durationSeconds': {'type': 'number', 'minimum': 0.05, 'maximum': 5.0},
            'velocity': {'type': 'number', 'minimum': 0.05, 'maximum': 1.0},
          },
        },
        handler: _handlePreviewNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_export_musicxml',
        description:
            'Exports the active score to canonical W3C MusicXML 3.1 (preserving Grand Staff, voices, key signatures, and ties) and optionally writes to workspace.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'outputPath': {'type': 'string'},
            'title': {'type': 'string'},
            'composer': {'type': 'string'},
          },
        },
        handler: _handleExportMusicXml,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_export_midi',
        description:
            'Exports the active score to a Standard MIDI File (auto SMF Format 1 for multi-staff/polyphonic scores, or Format 0) and optionally writes to workspace.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'outputPath': {'type': 'string'},
            'programNumber': {'type': 'integer', 'minimum': 0, 'maximum': 127},
            'bpm': {'type': 'integer', 'minimum': 20, 'maximum': 300},
            'format': {'type': 'integer', 'enum': [0, 1]},
            'staffProgramNumbers': {'type': 'object'},
          },
        },
        handler: _handleExportMidi,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_export_abc',
        description:
            'Exports the active score to canonical ABC Notation (preserving key signatures, ties, and multi-voice directives) and optionally writes to workspace.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'outputPath': {'type': 'string'},
            'title': {'type': 'string'},
            'composer': {'type': 'string'},
          },
        },
        handler: _handleExportAbc,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_export_pdf',
        description:
            'Exports the active score to a printable vector SMuFL PDF (ISO 32000-1) in Pure Dart and optionally writes to workspace.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'outputPath': {'type': 'string'},
            'title': {'type': 'string'},
            'composer': {'type': 'string'},
          },
        },
        handler: _handleExportPdf,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Prompts
  // ---------------------------------------------------------------------------

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'compose_piano_waltz_3_4',
        description:
            'Guides an AI agent to compose a two-hand Grand Staff piano waltz in 3/4, validate metric coverage, and export to MusicXML, MIDI Format 1, and PDF.',
        arguments: const [
          McpPromptArgument(
            name: 'title',
            description: 'Title of the piano waltz composition.',
            required: false,
          ),
          McpPromptArgument(
            name: 'key',
            description: 'Target key signature (e.g. "C Major", "A Minor", "G Major").',
            required: false,
          ),
          McpPromptArgument(
            name: 'measures',
            description: 'Number of measures to compose (default: 8).',
            required: false,
          ),
          McpPromptArgument(
            name: 'bpm',
            description: 'Tempo in BPM (default: 108).',
            required: false,
          ),
        ],
        builder: (args) async {
          final title = (args['title']?.trim().isNotEmpty ?? false)
              ? args['title']!.trim()
              : 'Vals de Salon en 3/4';
          final key = (args['key']?.trim().isNotEmpty ?? false)
              ? args['key']!.trim()
              : 'C Major';
          final measures = (args['measures']?.trim().isNotEmpty ?? false)
              ? args['measures']!.trim()
              : '8';
          final bpm = (args['bpm']?.trim().isNotEmpty ?? false)
              ? args['bpm']!.trim()
              : '108';

          return McpPromptResult(
            description:
                'Structured workflow for composing a Grand Staff piano waltz in 3/4.',
            messages: [
              McpPromptMessage.user(
                'Compose a piano waltz titled "$title" in $key ($measures measures, $bpm BPM, 3/4 time = 12 sub-ticks per measure) using Tunner MCP tools:\n'
                '1. Call `tunner_score_create` with `title: "$title"`, `timeSignature: "3/4"`, `bpm: $bpm`, `measureCount: $measures`, `staffCount: 2`, and `keySignatureFifths` matching $key.\n'
                '2. Call `tunner_score_compose_measures` in blocks of 4 measures:\n'
                '   - Right hand melody on `staff: 1, voice: 1` (treble clef).\n'
                '   - Left hand waltz accompaniment (bass note on tick 0, chords on ticks 4 and 8, each 4 ticks) on `staff: 2, voice: 2` (bass clef).\n'
                '3. Call `tunner_score_validate` to verify 12/12 sub-tick coverage in every measure.\n'
                '4. Export canonical artifacts via `tunner_export_musicxml`, `tunner_export_midi` (`format: 1`), and `tunner_export_pdf`.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'harmonize_and_transpose_study',
        description:
            'Reads the active score, adds harmonic chord voicings, and transposes the study to a target instrument tessitura.',
        arguments: const [
          McpPromptArgument(
            name: 'targetInstrument',
            description: 'Target instrument name or ID (e.g. "bb_clarinet", "violin").',
            required: false,
          ),
          McpPromptArgument(
            name: 'semitones',
            description: 'Transposition offset in semitones (-24..24).',
            required: false,
          ),
        ],
        builder: (args) async {
          final instrument = (args['targetInstrument']?.trim().isNotEmpty ?? false)
              ? args['targetInstrument']!.trim()
              : 'grand_piano';
          final semitones = (args['semitones']?.trim().isNotEmpty ?? false)
              ? args['semitones']!.trim()
              : '0';

          return McpPromptResult(
            description:
                'Harmonize the active melodic line and transpose for the target instrument.',
            messages: [
              McpPromptMessage.user(
                'Read `tunner://score/active` to inspect the active score:\n'
                '1. Analyze the melodic contour and key signature of each measure.\n'
                '2. Add supporting harmonic triads on `staff: 2, voice: 2` via `tunner_score_insert_chord` without overwriting the melody on `staff: 1, voice: 1`.\n'
                '3. Transpose by $semitones semitones using `tunner_score_transpose` (or adapt to `$instrument` via `tunner_song_adapt_instrument`).\n'
                '4. Validate with `tunner_score_validate`.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'fix_metric_errors',
        description:
            'Audits metric coverage across all measures in the active score and repairs incomplete or overflowing bars.',
        arguments: const [
          McpPromptArgument(
            name: 'targetTimeSignature',
            description: 'Optional expected time signature (e.g. "4/4", "3/4").',
            required: false,
          ),
        ],
        builder: (args) async {
          final ts = (args['targetTimeSignature']?.trim().isNotEmpty ?? false)
              ? args['targetTimeSignature']!.trim()
              : 'current measure time signature';

          return McpPromptResult(
            description: 'Metric validation and repair workflow.',
            messages: [
              McpPromptMessage.user(
                'Repair metric errors in the active score (target: $ts):\n'
                '1. Run `tunner_score_validate` to list all invalid measures.\n'
                '2. For each invalid measure, call `tunner_score_get_measure` to inspect its notes and occupied ticks.\n'
                '3. Use `tunner_score_quantize`, `tunner_score_insert_note` (with `"--"` for rests), or `tunner_score_compose_measures` to fill gaps or trim overflows.\n'
                '4. Re-run `tunner_score_validate` until `isValidScore` is `true`.',
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

  Future<McpToolResult> _handleScoreCreate(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim() ?? '';
    if (title.isEmpty) {
      return McpToolResult.error('Parameter "title" must be a non-empty string.');
    }

    final composer = (args['composer'] as String?)?.trim();
    final bpm = ((args['bpm'] as num?)?.toInt() ?? 120).clamp(20, 300);
    final ts = _parseTimeSignature(args['timeSignature'] as String?);
    if (ts == null) {
      return McpToolResult.error(
        'Invalid "timeSignature". Expected format like "4/4", "3/4", "2/4", "6/8".',
      );
    }
    final keyFifths =
        ((args['keySignatureFifths'] as num?)?.toInt() ?? 0).clamp(-7, 7);
    final measureCount =
        ((args['measureCount'] as num?)?.toInt() ?? 4).clamp(1, 128);
    final staffCount =
        ((args['staffCount'] as num?)?.toInt() ?? 1).clamp(1, 4);

    final measures = List<MeasureEntity>.generate(measureCount, (idx) {
      final notes = <HierarchicalNote>[];
      for (int s = 1; s <= staffCount; s++) {
        notes.add(
          HierarchicalNote.rest(
            startTick: 0,
            durationTicks: ts.totalTicks,
            voice: s,
            staff: s,
          ),
        );
      }
      return MeasureEntity(
        index: idx,
        timeSignature: ts,
        keySignatureFifths: keyFifths,
        notes: notes,
      );
    });

    final score = HierarchicalScore(
      title: title,
      baseBpm: bpm,
      measures: measures,
      staffCount: staffCount,
    );

    _activeScoreId = 'score_${DateTime.now().microsecondsSinceEpoch}';
    _activeComposer =
        (composer != null && composer.isNotEmpty) ? composer : 'Tunner MCP Composer';
    _history.clear();
    facade.setActiveScore(score);

    return McpToolResult.json({
      'scoreId': _activeScoreId,
      'title': score.title,
      'composer': _activeComposer,
      'bpm': score.baseBpm,
      'timeSignature': ts.toString(),
      'keySignatureFifths': keyFifths,
      'staffCount': score.staffCount,
      'totalMeasures': score.totalMeasures,
      'isValid': score.isValidScore,
    });
  }

  Future<McpToolResult> _handleGetMeasure(Map<String, dynamic> args) async {
    final score = facade.activeScore;
    if (score == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create or import a score first.',
      );
    }

    final measureIndex = (args['measureIndex'] as num?)?.toInt();
    if (measureIndex == null ||
        measureIndex < 0 ||
        measureIndex >= score.measures.length) {
      return McpToolResult.error(
        'measureIndex out of range (0..${score.measures.length - 1}).',
      );
    }

    final m = score.measures[measureIndex];
    final occupiedTicks = _countOccupiedTicks(m);
    return McpToolResult.json({
      'index': m.index,
      'timeSignature': m.timeSignature.toString(),
      'totalTicks': m.timeSignature.totalTicks,
      'keySignatureFifths': m.keySignatureFifths,
      'isValidMeasure': m.isValidMeasure,
      'occupiedTicks': occupiedTicks,
      'notes': m.notes.map((n) => n.toMap()).toList(growable: false),
    });
  }

  Future<McpToolResult> _handleInsertNote(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final measureIndex = (args['measureIndex'] as num?)?.toInt();
    final startTick = (args['startTick'] as num?)?.toInt();
    final durationTicks = (args['durationTicks'] as num?)?.toInt();
    final noteName = (args['noteName'] as String?)?.trim();
    final voice = ((args['voice'] as num?)?.toInt() ?? 1).clamp(1, 16);
    final staff = ((args['staff'] as num?)?.toInt() ?? 1).clamp(1, 4);
    final isTied = args['isTied'] as bool? ?? false;

    if (measureIndex == null ||
        measureIndex < 0 ||
        measureIndex >= currentPkg.score.measures.length) {
      return McpToolResult.error('Invalid measureIndex.');
    }
    if (startTick == null || startTick < 0) {
      return McpToolResult.error('startTick must be >= 0.');
    }
    if (durationTicks == null || durationTicks <= 0) {
      return McpToolResult.error('durationTicks must be > 0.');
    }
    if (noteName == null || noteName.isEmpty) {
      return McpToolResult.error('noteName must be a non-empty string (use "--" for rest).');
    }

    _history.recordState(currentPkg);
    final updated = _operations.insertOrUpdateNote(
      package: currentPkg,
      measureIndex: measureIndex,
      startTick: startTick,
      durationTicks: durationTicks,
      noteName: noteName,
      voice: voice,
      staff: staff,
      isTied: isTied,
    );
    facade.setActiveScore(updated.score);

    final measure = updated.score.measures[measureIndex];
    return McpToolResult.json({
      'measureIndex': measureIndex,
      'isValidMeasure': measure.isValidMeasure,
      'notesCount': measure.notes.length,
      'staffCount': updated.score.staffCount,
    });
  }

  Future<McpToolResult> _handleInsertChord(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final measureIndex = (args['measureIndex'] as num?)?.toInt();
    final startTick = (args['startTick'] as num?)?.toInt();
    final durationTicks = (args['durationTicks'] as num?)?.toInt();
    final rawNames = args['noteNames'];
    final voice = ((args['voice'] as num?)?.toInt() ?? 1).clamp(1, 16);
    final staff = ((args['staff'] as num?)?.toInt() ?? 1).clamp(1, 4);
    final isTied = args['isTied'] as bool? ?? false;

    if (measureIndex == null ||
        measureIndex < 0 ||
        measureIndex >= currentPkg.score.measures.length) {
      return McpToolResult.error('Invalid measureIndex.');
    }
    if (startTick == null || startTick < 0) {
      return McpToolResult.error('startTick must be >= 0.');
    }
    if (durationTicks == null || durationTicks <= 0) {
      return McpToolResult.error('durationTicks must be > 0.');
    }
    if (rawNames is! List || rawNames.isEmpty) {
      return McpToolResult.error('noteNames must be a non-empty array of note strings.');
    }

    final noteNames = rawNames
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    _history.recordState(currentPkg);
    final updated = _operations.insertChordNotes(
      package: currentPkg,
      measureIndex: measureIndex,
      startTick: startTick,
      durationTicks: durationTicks,
      noteNames: noteNames,
      voice: voice,
      staff: staff,
      isTied: isTied,
    );
    facade.setActiveScore(updated.score);

    final measure = updated.score.measures[measureIndex];
    return McpToolResult.json({
      'measureIndex': measureIndex,
      'insertedCount': noteNames.length,
      'isValidMeasure': measure.isValidMeasure,
      'staffCount': updated.score.staffCount,
    });
  }

  Future<McpToolResult> _handleComposeMeasures(
    Map<String, dynamic> args,
  ) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final rawMeasures = args['measures'];
    if (rawMeasures is! List || rawMeasures.isEmpty) {
      return McpToolResult.error('Parameter "measures" must be a non-empty array.');
    }

    _history.recordState(currentPkg);
    final updatedMeasures = List<MeasureEntity>.from(currentPkg.score.measures);
    int maxStaff = currentPkg.score.staffCount;

    for (int i = 0; i < rawMeasures.length; i++) {
      final item = rawMeasures[i];
      if (item is! Map<String, dynamic>) {
        return McpToolResult.error('Each entry in "measures" must be an object.');
      }

      final targetIdx = (item['index'] as num?)?.toInt() ?? i;
      if (targetIdx < 0) {
        return McpToolResult.error('Measure index must be >= 0.');
      }

      // Ensure list grows if composing beyond current measure count.
      while (updatedMeasures.length <= targetIdx) {
        final templateTs = updatedMeasures.isNotEmpty
            ? updatedMeasures.last.timeSignature
            : TimeSignature.commonTime44;
        final templateKey = updatedMeasures.isNotEmpty
            ? updatedMeasures.last.keySignatureFifths
            : 0;
        updatedMeasures.add(
          MeasureEntity(
            index: updatedMeasures.length,
            timeSignature: templateTs,
            keySignatureFifths: templateKey,
            notes: [
              HierarchicalNote.rest(
                startTick: 0,
                durationTicks: templateTs.totalTicks,
              ),
            ],
          ),
        );
      }

      final existing = updatedMeasures[targetIdx];
      final rawTs = item['timeSignature'] as String?;
      final ts = rawTs != null ? _parseTimeSignature(rawTs) : existing.timeSignature;
      if (ts == null) {
        return McpToolResult.error('Invalid timeSignature "$rawTs" at measure $targetIdx.');
      }
      final keyFifths = (item['keySignatureFifths'] as num?)?.toInt().clamp(-7, 7) ??
          existing.keySignatureFifths;

      final rawEvents = item['events'];
      final builtNotes = <HierarchicalNote>[];
      if (rawEvents is List) {
        for (final ev in rawEvents) {
          if (ev is! Map<String, dynamic>) continue;
          final startTick = (ev['startTick'] as num?)?.toInt() ?? 0;
          final durationTicks = (ev['durationTicks'] as num?)?.toInt() ?? 4;
          final voice = ((ev['voice'] as num?)?.toInt() ?? 1).clamp(1, 16);
          final staff = ((ev['staff'] as num?)?.toInt() ?? 1).clamp(1, 4);
          final isTied = ev['isTied'] as bool? ?? false;
          final isRestFlag = ev['isRest'] as bool? ?? false;
          if (staff > maxStaff) maxStaff = staff;

          final rawNotesList = ev['notes'];
          final singleNoteName = (ev['noteName'] as String?)?.trim();

          if (isRestFlag) {
            builtNotes.add(
              HierarchicalNote.rest(
                startTick: startTick,
                durationTicks: durationTicks,
                voice: voice,
                staff: staff,
              ),
            );
          } else if (rawNotesList is List && rawNotesList.isNotEmpty) {
            final cleanNotes = rawNotesList
                .map((n) => n.toString().trim())
                .where((n) => n.isNotEmpty)
                .toList(growable: false);
            if (cleanNotes.isEmpty ||
                (cleanNotes.length == 1 && cleanNotes.first == '--')) {
              builtNotes.add(
                HierarchicalNote.rest(
                  startTick: startTick,
                  durationTicks: durationTicks,
                  voice: voice,
                  staff: staff,
                ),
              );
            } else {
              for (final name in cleanNotes) {
                if (name == '--') continue;
                builtNotes.add(
                  HierarchicalNote.note(
                    startTick: startTick,
                    durationTicks: durationTicks,
                    noteName: name,
                    isTied: isTied,
                    voice: voice,
                    staff: staff,
                  ),
                );
              }
            }
          } else if (singleNoteName != null &&
              singleNoteName.isNotEmpty &&
              singleNoteName != '--') {
            builtNotes.add(
              HierarchicalNote.note(
                startTick: startTick,
                durationTicks: durationTicks,
                noteName: singleNoteName,
                isTied: isTied,
                voice: voice,
                staff: staff,
              ),
            );
          } else {
            builtNotes.add(
              HierarchicalNote.rest(
                startTick: startTick,
                durationTicks: durationTicks,
                voice: voice,
                staff: staff,
              ),
            );
          }
        }
      }

      builtNotes.sort((a, b) {
        final tickCmp = a.startTick.compareTo(b.startTick);
        if (tickCmp != 0) return tickCmp;
        final staffCmp = a.staff.compareTo(b.staff);
        if (staffCmp != 0) return staffCmp;
        final voiceCmp = a.voice.compareTo(b.voice);
        if (voiceCmp != 0) return voiceCmp;
        return a.noteName.compareTo(b.noteName);
      });

      updatedMeasures[targetIdx] = MeasureEntity(
        index: targetIdx,
        timeSignature: ts,
        keySignatureFifths: keyFifths,
        notes: builtNotes.isNotEmpty
            ? builtNotes
            : [
                HierarchicalNote.rest(
                  startTick: 0,
                  durationTicks: ts.totalTicks,
                ),
              ],
      );
    }

    final updatedScore = currentPkg.score.copyWith(
      measures: updatedMeasures,
      staffCount: maxStaff,
    );
    facade.setActiveScore(updatedScore);

    int totalNotes = 0;
    final validationErrors = <Map<String, dynamic>>[];
    for (final m in updatedScore.measures) {
      totalNotes += m.notes.where((n) => !n.isRest).length;
      if (!m.isValidMeasure) {
        validationErrors.add(_describeMeasureValidationError(m));
      }
    }

    return McpToolResult.json({
      'totalMeasures': updatedScore.totalMeasures,
      'totalNotes': totalNotes,
      'staffCount': updatedScore.staffCount,
      'isValidScore': updatedScore.isValidScore,
      'validationErrors': validationErrors,
    });
  }

  Future<McpToolResult> _handleDeleteNote(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final measureIndex = (args['measureIndex'] as num?)?.toInt();
    final startTick = (args['startTick'] as num?)?.toInt();
    final noteName = (args['noteName'] as String?)?.trim();
    final voice = (args['voice'] as num?)?.toInt();
    final staff = (args['staff'] as num?)?.toInt();

    if (measureIndex == null ||
        measureIndex < 0 ||
        measureIndex >= currentPkg.score.measures.length) {
      return McpToolResult.error('Invalid measureIndex.');
    }
    if (startTick == null || startTick < 0) {
      return McpToolResult.error('startTick must be >= 0.');
    }

    _history.recordState(currentPkg);
    final targetMeasure = currentPkg.score.measures[measureIndex];
    final updatedNotes = <HierarchicalNote>[];
    final restSlotsAdded = <(int, int, int)>{};

    if (noteName != null && noteName.isNotEmpty) {
      final remainingAtSlot = targetMeasure.notes.where((n) {
        final matchesSlot = n.startTick == startTick &&
            (voice == null || n.voice == voice) &&
            (staff == null || n.staff == staff);
        if (!matchesSlot) return false;
        return n.noteName != noteName;
      }).toList();

      for (final n in targetMeasure.notes) {
        final matchesTarget = n.startTick == startTick &&
            n.noteName == noteName &&
            (voice == null || n.voice == voice) &&
            (staff == null || n.staff == staff);
        if (!matchesTarget) {
          updatedNotes.add(n);
        } else if (remainingAtSlot.every(
          (r) => r.staff != n.staff || r.voice != n.voice,
        )) {
          final key = (n.startTick, n.staff, n.voice);
          if (restSlotsAdded.add(key)) {
            updatedNotes.add(
              HierarchicalNote.rest(
                startTick: n.startTick,
                durationTicks: n.durationTicks,
                voice: n.voice,
                staff: n.staff,
              ),
            );
          }
        }
      }
    } else {
      final rawUpdated = _operations.deleteNoteAt(
        package: currentPkg,
        measureIndex: measureIndex,
        startTick: startTick,
        voice: voice,
        staff: staff,
      );
      // Deduplicate stacked rests at the same (startTick, staff, voice).
      for (final n in rawUpdated.score.measures[measureIndex].notes) {
        if (n.isRest && n.startTick == startTick) {
          final key = (n.startTick, n.staff, n.voice);
          if (!restSlotsAdded.add(key)) continue;
        }
        updatedNotes.add(n);
      }
    }

    final updatedMeasures = List<MeasureEntity>.from(currentPkg.score.measures);
    updatedMeasures[measureIndex] = targetMeasure.copyWith(notes: updatedNotes);
    final updatedScore = currentPkg.score.copyWith(measures: updatedMeasures);
    facade.setActiveScore(updatedScore);

    final measure = updatedScore.measures[measureIndex];
    return McpToolResult.json({
      'measureIndex': measureIndex,
      'remainingNotes': measure.notes.length,
      'isValidMeasure': measure.isValidMeasure,
    });
  }

  Future<McpToolResult> _handleAddMeasure(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final rawTs = args['timeSignature'] as String?;
    final ts = rawTs != null
        ? _parseTimeSignature(rawTs)
        : (currentPkg.score.measures.isNotEmpty
            ? currentPkg.score.measures.last.timeSignature
            : TimeSignature.commonTime44);
    if (ts == null) {
      return McpToolResult.error('Invalid timeSignature "$rawTs".');
    }

    final keyFifths = (args['keySignatureFifths'] as num?)?.toInt().clamp(-7, 7) ??
        (currentPkg.score.measures.isNotEmpty
            ? currentPkg.score.measures.last.keySignatureFifths
            : 0);
    final insertAtIndex = (args['insertAtIndex'] as num?)?.toInt();

    _history.recordState(currentPkg);
    final measures = List<MeasureEntity>.from(currentPkg.score.measures);
    final clampedIndex = insertAtIndex == null
        ? measures.length
        : insertAtIndex.clamp(0, measures.length);

    final newMeasure = MeasureEntity(
      index: clampedIndex,
      timeSignature: ts,
      keySignatureFifths: keyFifths,
      notes: [
        HierarchicalNote.rest(
          startTick: 0,
          durationTicks: ts.totalTicks,
        ),
      ],
    );
    measures.insert(clampedIndex, newMeasure);

    final reindexed = List<MeasureEntity>.generate(
      measures.length,
      (i) => measures[i].copyWith(index: i),
    );
    final updatedScore = currentPkg.score.copyWith(measures: reindexed);
    facade.setActiveScore(updatedScore);

    return McpToolResult.json({
      'totalMeasures': updatedScore.totalMeasures,
      'addedIndex': clampedIndex,
      'timeSignature': ts.toString(),
      'keySignatureFifths': keyFifths,
    });
  }

  Future<McpToolResult> _handleRemoveMeasure(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final measureIndex = (args['measureIndex'] as num?)?.toInt();
    if (measureIndex == null ||
        measureIndex < 0 ||
        measureIndex >= currentPkg.score.measures.length) {
      return McpToolResult.error('Invalid measureIndex.');
    }
    if (currentPkg.score.measures.length <= 1) {
      return McpToolResult.error(
        'Cannot remove the last remaining measure of a score.',
      );
    }

    _history.recordState(currentPkg);
    final updated = _operations.removeMeasure(
      package: currentPkg,
      measureIndex: measureIndex,
    );
    facade.setActiveScore(updated.score);

    return McpToolResult.json({
      'totalMeasures': updated.score.totalMeasures,
      'removedIndex': measureIndex,
    });
  }

  Future<McpToolResult> _handleSetMetadata(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final title = (args['title'] as String?)?.trim();
    final composer = (args['composer'] as String?)?.trim();
    final bpm = (args['bpm'] as num?)?.toInt();
    final staffCount = (args['staffCount'] as num?)?.toInt();
    final keyFifths = (args['keySignatureFifths'] as num?)?.toInt();
    final measureIndex = (args['measureIndex'] as num?)?.toInt();
    final rawTs = args['timeSignature'] as String?;

    TimeSignature? parsedTs;
    if (rawTs != null) {
      parsedTs = _parseTimeSignature(rawTs);
      if (parsedTs == null) {
        return McpToolResult.error('Invalid timeSignature "$rawTs".');
      }
    }

    _history.recordState(currentPkg);
    if (composer != null && composer.isNotEmpty) {
      _activeComposer = composer;
    }

    final updatedMeasures = List<MeasureEntity>.from(currentPkg.score.measures);
    if (keyFifths != null || parsedTs != null) {
      if (measureIndex != null) {
        if (measureIndex < 0 || measureIndex >= updatedMeasures.length) {
          return McpToolResult.error('Invalid measureIndex.');
        }
        final target = updatedMeasures[measureIndex];
        updatedMeasures[measureIndex] = target.copyWith(
          keySignatureFifths: keyFifths?.clamp(-7, 7) ?? target.keySignatureFifths,
          timeSignature: parsedTs ?? target.timeSignature,
        );
      } else {
        for (int i = 0; i < updatedMeasures.length; i++) {
          final target = updatedMeasures[i];
          updatedMeasures[i] = target.copyWith(
            keySignatureFifths:
                keyFifths?.clamp(-7, 7) ?? target.keySignatureFifths,
            timeSignature: parsedTs ?? target.timeSignature,
          );
        }
      }
    }

    final updatedScore = currentPkg.score.copyWith(
      title: (title != null && title.isNotEmpty) ? title : currentPkg.score.title,
      baseBpm: bpm != null ? bpm.clamp(20, 300) : currentPkg.score.baseBpm,
      staffCount:
          staffCount != null ? staffCount.clamp(1, 4) : currentPkg.score.staffCount,
      measures: updatedMeasures,
    );
    facade.setActiveScore(updatedScore);

    final sampleMeasure = updatedScore.measures.isNotEmpty
        ? updatedScore.measures[measureIndex ?? 0]
        : null;

    return McpToolResult.json({
      'title': updatedScore.title,
      'composer': _activeComposer,
      'bpm': updatedScore.baseBpm,
      'staffCount': updatedScore.staffCount,
      'timeSignature': sampleMeasure?.timeSignature.toString(),
      'keySignatureFifths': sampleMeasure?.keySignatureFifths,
    });
  }

  Future<McpToolResult> _handleQuantize(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final targetIndex = (args['measureIndex'] as num?)?.toInt();
    if (targetIndex != null &&
        (targetIndex < 0 || targetIndex >= currentPkg.score.measures.length)) {
      return McpToolResult.error('Invalid measureIndex.');
    }

    _history.recordState(currentPkg);
    int quantizedCount = 0;

    final updatedMeasures = <MeasureEntity>[];
    for (int i = 0; i < currentPkg.score.measures.length; i++) {
      final m = currentPkg.score.measures[i];
      if (targetIndex != null && i != targetIndex) {
        updatedMeasures.add(m);
        continue;
      }

      final maxTicks = m.timeSignature.totalTicks;
      final quantizedNotes = <HierarchicalNote>[];
      for (final n in m.notes) {
        final safeStart = n.startTick.clamp(0, math.max(0, maxTicks - 1)).toInt();
        final qDur = RhythmicQuantizer.quantizeDuration(n.durationTicks);
        final clampedDur =
            math.min(qDur, maxTicks - safeStart).clamp(1, maxTicks).toInt();
        if (clampedDur != n.durationTicks || safeStart != n.startTick) {
          quantizedCount++;
        }
        quantizedNotes.add(
          n.copyWith(startTick: safeStart, durationTicks: clampedDur),
        );
      }

      updatedMeasures.add(m.copyWith(notes: quantizedNotes));
    }

    final updatedScore = currentPkg.score.copyWith(measures: updatedMeasures);
    facade.setActiveScore(updatedScore);

    return McpToolResult.json({
      'quantizedNotesCount': quantizedCount,
      'totalMeasures': updatedScore.totalMeasures,
      'isValidScore': updatedScore.isValidScore,
    });
  }

  Future<McpToolResult> _handleTranspose(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create first.',
      );
    }

    final semitones = (args['semitones'] as num?)?.toInt();
    if (semitones == null || semitones < -24 || semitones > 24) {
      return McpToolResult.error('semitones must be an integer between -24 and 24.');
    }
    final preferFlats = args['preferFlats'] as bool?;

    _history.recordState(currentPkg);
    int transposedCount = 0;

    final updatedMeasures = currentPkg.score.measures.map((measure) {
      final useFlats = preferFlats ?? (measure.keySignatureFifths < 0);
      final updatedNotes = measure.notes.map((note) {
        if (note.isRest ||
            note.noteName.isEmpty ||
            note.noteName == '--' ||
            note.noteName.toLowerCase() == 'rest') {
          return note;
        }
        final parsed = CanonicalPitchNotationCodec.parse(note.noteName);
        if (parsed == null) return note;
        final newMidi = (parsed.midiNumber + semitones).clamp(0, 127);
        final newName = CanonicalPitchNotationCodec.midiToSolfege(
          newMidi,
          preferFlats: useFlats,
        );
        transposedCount++;
        return note.copyWith(noteName: newName);
      }).toList(growable: false);
      return measure.copyWith(notes: updatedNotes);
    }).toList(growable: false);

    final updatedScore = currentPkg.score.copyWith(measures: updatedMeasures);
    facade.setActiveScore(updatedScore);

    return McpToolResult.json({
      'semitones': semitones,
      'totalNotesTransposed': transposedCount,
      'isValidScore': updatedScore.isValidScore,
    });
  }

  Future<McpToolResult> _handleValidate(Map<String, dynamic> args) async {
    final score = facade.activeScore;
    if (score == null) {
      return McpToolResult.error(
        'No active score in session. Call tunner_score_create or import a score first.',
      );
    }

    final targetIndex = (args['measureIndex'] as num?)?.toInt();
    if (targetIndex != null &&
        (targetIndex < 0 || targetIndex >= score.measures.length)) {
      return McpToolResult.error('Invalid measureIndex.');
    }

    final measuresToCheck = targetIndex != null
        ? [score.measures[targetIndex]]
        : score.measures;

    final invalidMeasures = <Map<String, dynamic>>[];
    for (final m in measuresToCheck) {
      if (!m.isValidMeasure) {
        invalidMeasures.add(_describeMeasureValidationError(m));
      }
    }

    return McpToolResult.json({
      'isValidScore': invalidMeasures.isEmpty && score.measures.isNotEmpty,
      'checkedMeasures': measuresToCheck.length,
      'totalMeasures': score.totalMeasures,
      'staffCount': score.staffCount,
      'invalidMeasures': invalidMeasures,
    });
  }

  Future<McpToolResult> _handleUndo(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error('No active score in session.');
    }
    final previous = _history.undo(currentPkg);
    if (previous == null) {
      return McpToolResult.json({
        'applied': false,
        'undoCount': _history.undoCount,
        'redoCount': _history.redoCount,
      });
    }
    facade.setActiveScore(previous.score);
    return McpToolResult.json({
      'applied': true,
      'undoCount': _history.undoCount,
      'redoCount': _history.redoCount,
      'totalMeasures': previous.score.totalMeasures,
    });
  }

  Future<McpToolResult> _handleRedo(Map<String, dynamic> args) async {
    final currentPkg = _currentSongPackage();
    if (currentPkg == null) {
      return McpToolResult.error('No active score in session.');
    }
    final next = _history.redo(currentPkg);
    if (next == null) {
      return McpToolResult.json({
        'applied': false,
        'undoCount': _history.undoCount,
        'redoCount': _history.redoCount,
      });
    }
    facade.setActiveScore(next.score);
    return McpToolResult.json({
      'applied': true,
      'undoCount': _history.undoCount,
      'redoCount': _history.redoCount,
      'totalMeasures': next.score.totalMeasures,
    });
  }

  Future<McpToolResult> _handlePreviewNote(Map<String, dynamic> args) async {
    final noteName = (args['noteName'] as String?)?.trim() ?? '';
    final durationSeconds =
        ((args['durationSeconds'] as num?)?.toDouble() ?? 0.35).clamp(0.05, 5.0);
    final velocity =
        ((args['velocity'] as num?)?.toDouble() ?? 0.8).clamp(0.05, 1.0);

    final midi = ScorePlaybackCoordinator.noteNameToMidi(noteName);
    if (midi < 0) {
      return McpToolResult.error('Unrecognized note name: "$noteName".');
    }

    final freq = CanonicalPitchNotationCodec.midiToFrequency(midi);
    facade.root.scorePlaybackCoordinator.previewNote(
      HierarchicalNote.note(
        startTick: 0,
        durationTicks: 4,
        noteName: noteName,
      ),
      durationSeconds: durationSeconds,
      velocity: velocity,
    );

    return McpToolResult.json({
      'noteName': noteName,
      'midiNumber': midi,
      'frequencyHz': double.parse(freq.toStringAsFixed(4)),
      'played': true,
    });
  }

  Future<McpToolResult> _handleExportMusicXml(Map<String, dynamic> args) async {
    final score = facade.activeScore;
    if (score == null) {
      return McpToolResult.error('No active score in session to export.');
    }

    final title = (args['title'] as String?)?.trim();
    final composer = (args['composer'] as String?)?.trim();
    final outputPath = (args['outputPath'] as String?)?.trim();

    final xml = _musicXmlExporter.exportScore(
      score: score,
      title: (title != null && title.isNotEmpty) ? title : score.title,
      composer: (composer != null && composer.isNotEmpty)
          ? composer
          : _activeComposer,
    );
    final bytes = utf8.encode(xml);

    String? savedPath;
    if (outputPath != null && outputPath.isNotEmpty) {
      savedPath = await _writeWorkspaceBytes(outputPath, bytes);
    }

    return McpToolResult.json({
      'xml': xml,
      'outputPath': ?savedPath,
      'bytesLength': bytes.length,
      'staffCount': score.staffCount,
    });
  }

  Future<McpToolResult> _handleExportMidi(Map<String, dynamic> args) async {
    final score = facade.activeScore;
    if (score == null) {
      return McpToolResult.error('No active score in session to export.');
    }

    final outputPath = (args['outputPath'] as String?)?.trim();
    final programNumber =
        ((args['programNumber'] as num?)?.toInt() ?? 0).clamp(0, 127);
    final bpm = ((args['bpm'] as num?)?.toInt() ?? score.baseBpm).clamp(20, 300);
    final format = (args['format'] as num?)?.toInt();

    Map<int, int>? staffPrograms;
    final rawStaffPrograms = args['staffProgramNumbers'];
    if (rawStaffPrograms is Map) {
      staffPrograms = <int, int>{};
      for (final entry in rawStaffPrograms.entries) {
        final staffKey = int.tryParse(entry.key.toString());
        final progVal = (entry.value as num?)?.toInt();
        if (staffKey != null && progVal != null) {
          staffPrograms[staffKey] = progVal.clamp(0, 127);
        }
      }
    }

    final bytes = _midiExporter.exportScore(
      score: score,
      bpm: bpm,
      trackName: score.title,
      programNumber: programNumber,
      format: format,
      staffProgramNumbers: staffPrograms,
    );

    final actualFormat =
        bytes.length >= 10 ? ((bytes[8] << 8) | bytes[9]) : (format ?? 0);
    final trackCount = bytes.length >= 12 ? ((bytes[10] << 8) | bytes[11]) : 1;

    String? savedPath;
    if (outputPath != null && outputPath.isNotEmpty) {
      savedPath = await _writeWorkspaceBytes(outputPath, bytes);
    }

    return McpToolResult.json({
      'base64': base64Encode(bytes),
      'outputPath': ?savedPath,
      'bytesLength': bytes.length,
      'format': actualFormat,
      'trackCount': trackCount,
    });
  }

  Future<McpToolResult> _handleExportAbc(Map<String, dynamic> args) async {
    final score = facade.activeScore;
    if (score == null) {
      return McpToolResult.error('No active score in session to export.');
    }

    final title = (args['title'] as String?)?.trim();
    final composer = (args['composer'] as String?)?.trim();
    final outputPath = (args['outputPath'] as String?)?.trim();

    final abc = _abcExporter.exportScore(
      score: score,
      title: (title != null && title.isNotEmpty) ? title : score.title,
      composer: (composer != null && composer.isNotEmpty)
          ? composer
          : _activeComposer,
    );
    final bytes = utf8.encode(abc);

    String? savedPath;
    if (outputPath != null && outputPath.isNotEmpty) {
      savedPath = await _writeWorkspaceBytes(outputPath, bytes);
    }

    return McpToolResult.json({
      'abc': abc,
      'outputPath': ?savedPath,
      'bytesLength': bytes.length,
    });
  }

  Future<McpToolResult> _handleExportPdf(Map<String, dynamic> args) async {
    final score = facade.activeScore;
    if (score == null) {
      return McpToolResult.error('No active score in session to export.');
    }

    final title = (args['title'] as String?)?.trim();
    final composer = (args['composer'] as String?)?.trim();
    final outputPath = (args['outputPath'] as String?)?.trim();

    final bytes = _pdfExporter.exportScore(
      score: score,
      title: (title != null && title.isNotEmpty) ? title : score.title,
      composer: (composer != null && composer.isNotEmpty)
          ? composer
          : _activeComposer,
    );

    final totalMeasures = score.measures.isNotEmpty ? score.measures.length : 1;
    final totalSystems =
        (totalMeasures + CanonicalPdfExporter.measuresPerSystem - 1) ~/
            CanonicalPdfExporter.measuresPerSystem;
    final pagesEstimate = math.max(1, (totalSystems + 5) ~/ 6);

    String? savedPath;
    if (outputPath != null && outputPath.isNotEmpty) {
      savedPath = await _writeWorkspaceBytes(outputPath, bytes);
    }

    return McpToolResult.json({
      'base64': base64Encode(bytes),
      'outputPath': ?savedPath,
      'bytesLength': bytes.length,
      'pagesEstimate': pagesEstimate,
    });
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  SongPackage? _currentSongPackage() {
    final score = facade.activeScore;
    if (score == null) return null;
    return SongPackage(
      id: _activeScoreId,
      title: score.title,
      composer: _activeComposer,
      genre: MusicGenre.classical,
      difficulty: SongDifficulty.intermediate,
      defaultBpm: score.baseBpm,
      score: score,
      tracks: const [
        AudioTrack(
          id: 'main_score_track',
          title: 'Main Score',
          instrumentIcon: 'piano',
          volume: 0.9,
        ),
      ],
    );
  }

  static TimeSignature? _parseTimeSignature(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return TimeSignature.commonTime44;
    }
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

  static int _countOccupiedTicks(MeasureEntity measure) {
    final occupied = <int>{};
    for (final note in measure.notes) {
      for (int t = note.startTick; t < note.endTick; t++) {
        if (t >= 0 && t < measure.timeSignature.totalTicks) {
          occupied.add(t);
        }
      }
    }
    return occupied.length;
  }

  static Map<String, dynamic> _describeMeasureValidationError(
    MeasureEntity measure,
  ) {
    final expected = measure.timeSignature.totalTicks;
    final occupied = _countOccupiedTicks(measure);
    bool hasOverflow = false;
    for (final n in measure.notes) {
      if (n.startTick < 0 || n.endTick > expected) {
        hasOverflow = true;
        break;
      }
    }
    final reason = hasOverflow
        ? 'One or more notes overflow the measure bounds [0, $expected).'
        : 'Occupied ticks ($occupied) do not match expected measure ticks ($expected).';
    return {
      'index': measure.index,
      'expectedTicks': expected,
      'occupiedTicks': occupied,
      'reason': reason,
    };
  }

  Future<String> _writeWorkspaceBytes(String rawPath, List<int> bytes) async {
    final resolved = _resolveWorkspacePath(rawPath);
    final file = File(resolved);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return resolved;
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
        'Access denied: output path escapes workspace boundary ($rawPath).',
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
}
