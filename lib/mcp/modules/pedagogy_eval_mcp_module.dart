import 'dart:io';

import '../../features/pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart';
import '../../features/pedagogy/domain/vocal_stability_evaluator.dart';
import '../../features/pedagogy/infrastructure/pedagogical_certificate_pdf_generator.dart';
import '../../features/pedagogy_profiles/domain/adaptive_scaffolding_engine.dart';
import '../../features/pedagogy_profiles/domain/learner_profile_entity.dart';
import '../../features/pedagogy_report/domain/pedagogical_report_models.dart';
import '../../features/pedagogy_report/domain/pedagogical_report_pdf_generator.dart';
import '../../features/pedagogy_report/domain/pedagogical_session_aggregator.dart';
import '../../features/practice_evaluator/domain/note_evaluation_entity.dart';
import '../../features/practice_evaluator/domain/practice_evaluator_service.dart';
import '../../features/practice_evaluator/domain/practice_report_entity.dart';
import '../../features/sheet_music/domain/score_tree.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing Ebbinghaus spaced repetition, vocal stability
/// evaluation, adaptive learner profiles and scaffolding, multidimensional
/// practice evaluation, pedagogical session aggregation, and Pure Dart PDF
/// certificate/report generation.
class PedagogyEvalMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final EbbinghausSpacedRepetitionEngine _ebbinghaus;
  final AdaptiveScaffoldingEngine _scaffoldingEngine;
  final PracticeEvaluatorService _practiceEvaluator;
  final PedagogicalSessionAggregator _sessionAggregator;
  final PedagogicalReportPdfGenerator _reportPdfGenerator;

  LearnerProfileEntity _activeProfile = LearnerProfileEntity.adult();
  PracticeReportEntity? _latestPracticeReport;
  VocalEvaluationResult? _latestVocalEvaluation;

  PedagogyEvalMcpModule(
    this.facade, {
    EbbinghausSpacedRepetitionEngine? ebbinghausEngine,
    AdaptiveScaffoldingEngine? scaffoldingEngine,
    PracticeEvaluatorService? practiceEvaluator,
    PedagogicalSessionAggregator? sessionAggregator,
    PedagogicalReportPdfGenerator? reportPdfGenerator,
    LearnerProfileEntity? initialProfile,
  })  : _ebbinghaus =
            ebbinghausEngine ?? facade.root.earTrainingTerminalAdapter.engine,
        _scaffoldingEngine =
            scaffoldingEngine ?? const AdaptiveScaffoldingEngine(),
        _practiceEvaluator =
            practiceEvaluator ?? const PracticeEvaluatorService(),
        _sessionAggregator =
            sessionAggregator ?? PedagogicalSessionAggregator(),
        _reportPdfGenerator =
            reportPdfGenerator ?? const PedagogicalReportPdfGenerator() {
    if (initialProfile != null) {
      _activeProfile = initialProfile;
    }
  }

  @override
  String get moduleName => 'pedagogy_eval';

  @override
  void register(McpRegistry registry) {
    _registerResources(registry);
    _registerTools(registry);
    _registerPrompts(registry);
  }

  // ===========================================================================
  // Resources (5)
  // ===========================================================================

  void _registerResources(McpRegistry registry) {
    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://pedagogy/ebbinghaus/bank',
        name: 'Ebbinghaus Spaced Repetition Bank',
        description:
            'Complete state of all spaced repetition items with current cognitive retention R(t) and due status.',
        mimeType: 'application/json',
        reader: () async {
          final now = DateTime.now();
          final items = _ebbinghaus.allItems
              .map(
                (item) => {
                  ...item.toJson(),
                  'retention': item.retentionAt(now),
                  'isDue': item.isDue(now),
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://pedagogy/ebbinghaus/bank',
            data: {
              'count': items.length,
              'overallRetention': _ebbinghaus.overallRetentionAverage(now),
              'evaluatedAt': now.toIso8601String(),
              'items': items,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://pedagogy/ebbinghaus/due',
        name: 'Ebbinghaus Due Review Queue',
        description:
            'Prioritized queue of due ear-training items ordered from lowest to highest cognitive retention R(t).',
        mimeType: 'application/json',
        reader: () async {
          final now = DateTime.now();
          const targetRetention = 0.90;
          final due = _ebbinghaus.getDueItems(
            now: now,
            targetRetention: targetRetention,
          );
          return McpResourceContent.json(
            uri: 'tunner://pedagogy/ebbinghaus/due',
            data: {
              'dueCount': due.length,
              'targetRetention': targetRetention,
              'evaluatedAt': now.toIso8601String(),
              'items': due
                  .map(
                    (item) => {
                      ...item.toJson(),
                      'retention': item.retentionAt(now),
                      'isDue': true,
                    },
                  )
                  .toList(growable: false),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://pedagogy/profiles/presets',
        name: 'Learner Profile Presets',
        description:
            'Official adaptive learner profile presets (childPlayful, adultDeliberate, conservatoryMastery).',
        mimeType: 'application/json',
        reader: () async {
          final presets = [
            LearnerProfileEntity.child().toJson(),
            LearnerProfileEntity.adult().toJson(),
            LearnerProfileEntity.conservatory().toJson(),
          ];
          return McpResourceContent.json(
            uri: 'tunner://pedagogy/profiles/presets',
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
        uri: 'tunner://pedagogy/profiles/active',
        name: 'Active Learner Profile',
        description:
            'Currently active LearnerProfileEntity governing cents tolerance, feedback style, and scaffolding fade-out.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://pedagogy/profiles/active',
            data: _activeProfile.toJson(),
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://practice/reports/latest',
        name: 'Latest Practice Evaluation Report',
        description:
            'Most recent PracticeReportEntity generated in the headless session, including per-note evaluations and critical notes.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://practice/reports/latest',
            data: {
              'hasReport': _latestPracticeReport != null,
              'report': _latestPracticeReport?.toMap(),
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (9)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ebbinghaus_submit_answer',
        description:
            'Records an ear-training answer in EbbinghausSpacedRepetitionEngine and recalculates stability, ease factor, and next review date.',
        inputSchema: const {
          'type': 'object',
          'required': [
            'itemId',
            'isCorrect',
            'centsError',
            'responseTimeSeconds',
          ],
          'properties': {
            'itemId': {'type': 'string'},
            'isCorrect': {'type': 'boolean'},
            'centsError': {'type': 'number'},
            'responseTimeSeconds': {'type': 'number'},
            'timestamp': {
              'type': 'string',
              'description': 'Optional ISO-8601 evaluation timestamp.',
            },
          },
        },
        handler: _handleEbbinghausSubmitAnswer,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ebbinghaus_add_item',
        description:
            'Adds or updates a custom EarTrainingItemEntity in the EbbinghausSpacedRepetitionEngine bank.',
        inputSchema: const {
          'type': 'object',
          'required': ['id', 'name', 'category', 'semitones', 'centsDeviation'],
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
            'category': {
              'type': 'string',
              'enum': ['interval', 'chord', 'microtone', 'pitch'],
            },
            'semitones': {'type': 'number'},
            'centsDeviation': {'type': 'number'},
          },
        },
        handler: _handleEbbinghausAddItem,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_pedagogy_set_active_profile',
        description:
            'Switches the active LearnerProfileEntity by preset name (child, adult, conservatory) or custom JSON profile.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'preset': {
              'type': 'string',
              'enum': ['child', 'adult', 'conservatory'],
            },
            'customProfile': {
              'type': 'object',
              'description': 'Custom LearnerProfileEntity JSON object.',
            },
          },
        },
        handler: _handleSetActiveProfile,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_evaluate_vocal_stability',
        description:
            'Evaluates sustained vocal phonation series (frequenciesHz and amplitudes) for cents deviation, jitter%, shimmer%, vibrato rate/depth, overall score, and SHA-256 verification hash.',
        inputSchema: const {
          'type': 'object',
          'required': ['frequenciesHz', 'amplitudes', 'targetFrequencyHz'],
          'properties': {
            'frequenciesHz': {
              'type': 'array',
              'items': {'type': 'number'},
            },
            'amplitudes': {
              'type': 'array',
              'items': {'type': 'number'},
            },
            'targetFrequencyHz': {'type': 'number'},
            'analysisFrameRateHz': {'type': 'number', 'default': 50.0},
            'evaluationId': {'type': 'string'},
          },
        },
        handler: _handleEvaluateVocalStability,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_scaffolding_evaluate_note',
        description:
            'Runs AdaptiveScaffoldingEngine.evaluateNote() to compute effective tolerance (with fade-out), biomechanical cues, motivational feedback, and BPM adjustment suggestions.',
        inputSchema: const {
          'type': 'object',
          'required': ['centsDeviation'],
          'properties': {
            'centsDeviation': {'type': 'number'},
            'profile': {
              'description':
                  'Optional preset string ("child", "adult", "conservatory") or LearnerProfileEntity JSON object. Defaults to active profile.',
            },
            'consecutiveSuccesses': {'type': 'integer', 'default': 0},
            'consecutiveErrors': {'type': 'integer', 'default': 0},
          },
        },
        handler: _handleScaffoldingEvaluateNote,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_practice_evaluate_session',
        description:
            'Evaluates a full practice session note-by-note against expected score notes via PracticeEvaluatorService and produces a multidimensional PracticeReportEntity.',
        inputSchema: const {
          'type': 'object',
          'required': ['songTitle', 'notes'],
          'properties': {
            'songTitle': {'type': 'string'},
            'instrumentName': {
              'type': 'string',
              'default': 'Instrumento Estandar',
            },
            'toleranceCents': {
              'type': 'number',
              'description': 'Cents tolerance window (defaults to active learner profile tolerance).',
            },
            'notes': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': [
                  'expectedNoteName',
                  'detectedNoteName',
                  'detectedFrequency',
                  'detectedCents',
                  'timingDeltaMs',
                ],
                'properties': {
                  'expectedNoteName': {'type': 'string'},
                  'soundingExpectedNoteName': {'type': 'string'},
                  'isRest': {'type': 'boolean', 'default': false},
                  'startTick': {'type': 'integer', 'default': 0},
                  'durationTicks': {'type': 'integer', 'default': 4},
                  'detectedNoteName': {'type': 'string'},
                  'detectedFrequency': {'type': 'number'},
                  'detectedCents': {'type': 'number'},
                  'timingDeltaMs': {'type': 'integer'},
                  'sustainRatio': {'type': 'number', 'default': 1.0},
                },
              },
            },
            'previousSession': {
              'type': 'object',
              'description': 'Optional previous PracticeReportEntity JSON for trend analysis.',
            },
          },
        },
        handler: _handlePracticeEvaluateSession,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_pedagogy_aggregate_session_report',
        description:
            'Aggregates a PracticeReportEntity and optional spectral/vocal telemetry into a canonical PedagogicalSessionData JSON report via PedagogicalSessionAggregator.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'sessionTitle': {'type': 'string'},
            'useLatestPracticeReport': {'type': 'boolean', 'default': true},
            'practiceReport': {
              'type': 'object',
              'description': 'Optional PracticeReportEntity JSON overriding the latest cached report.',
            },
            'durationSeconds': {'type': 'integer', 'default': 0},
            'spectralCentroidHz': {'type': 'number', 'default': 0.0},
            'thdPercentage': {'type': 'number', 'default': 0.0},
            'harmonicRatios': {
              'type': 'array',
              'items': {'type': 'number'},
            },
            'rhythmMeanBpm': {'type': 'number', 'default': 120.0},
            'includeVocalEvaluation': {'type': 'boolean', 'default': true},
          },
        },
        handler: _handleAggregateSessionReport,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_export_vocal_certificate_pdf',
        description:
            'Generates a Pure Dart ISO 32000-1 PDF 1.4 vocal stability certificate with SHA-256 verification seal and writes it inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'required': ['studentName', 'outputPath'],
          'properties': {
            'studentName': {'type': 'string'},
            'evaluation': {
              'type': 'object',
              'description':
                  'VocalEvaluationResult JSON (optional when tunner_evaluate_vocal_stability was already called).',
            },
            'outputPath': {
              'type': 'string',
              'description': 'Workspace-contained destination path for the PDF file.',
            },
          },
        },
        handler: _handleExportVocalCertificatePdf,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_export_pedagogical_report_pdf',
        description:
            'Compiles a Pure Dart ISO 32000-1 PDF 1.4 analytical pedagogical report (and optional conservatory certificate page) and writes it inside the workspace.',
        inputSchema: const {
          'type': 'object',
          'required': ['outputPath'],
          'properties': {
            'session': {
              'type': 'object',
              'description':
                  'PedagogicalSessionData JSON. If omitted, auto-aggregates from latest PracticeReportEntity or sample data.',
            },
            'config': {
              'type': 'object',
              'description': 'Optional PedagogicalReportConfig JSON.',
            },
            'outputPath': {
              'type': 'string',
              'description': 'Workspace-contained destination path for the PDF file.',
            },
          },
        },
        handler: _handleExportPedagogicalReportPdf,
      ),
    );
  }

  // ===========================================================================
  // Prompts (3)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'conservatory_vocal_exam_and_certification',
        description:
            'Conducts a formal sustained-note vocal stability exam, issues clinical-acoustic feedback, and generates a SHA-256 sealed PDF certificate.',
        arguments: const [
          McpPromptArgument(
            name: 'studentName',
            description: 'Full name of the examinee for the certificate.',
            required: false,
          ),
          McpPromptArgument(
            name: 'targetFrequencyHz',
            description: 'Target sustained pitch in Hz (e.g., 440.0 for A4).',
            required: false,
          ),
        ],
        builder: (args) async {
          final studentName = args['studentName'] ?? 'Estudiante';
          final targetHz = args['targetFrequencyHz'] ?? '440.0';
          return McpPromptResult(
            description: 'Conservatory vocal stability examination and PDF certification workflow.',
            messages: [
              McpPromptMessage.user(
                'Conduct a vocal stability examination for "$studentName" targeting $targetHz Hz:\n'
                '1. Run "tunner_evaluate_vocal_stability" on the captured frequency and amplitude time series.\n'
                '2. Check jitterPercent (<= 1.0%), shimmerPercent (<= 3.5%), and vibrato parameters (4.5-7.0 Hz, 25-75 cents).\n'
                '3. If overallScore >= 65.0, issue an official PDF certificate via "tunner_export_vocal_certificate_pdf".\n'
                '4. If intonation or stability faults are found, diagnose biomechanical corrections using "tunner_scaffolding_evaluate_note".',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'deliberate_practice_post_mortem',
        description:
            'Analyzes a completed score practice session to diagnose rushing/dragging tendencies, critical notes, and corrective drills.',
        arguments: const [
          McpPromptArgument(
            name: 'songTitle',
            description: 'Title of the practiced piece or study.',
            required: false,
          ),
          McpPromptArgument(
            name: 'studentName',
            description: 'Student name for the final PDF report.',
            required: false,
          ),
        ],
        builder: (args) async {
          final songTitle = args['songTitle'] ?? 'Estudio de Practica';
          final studentName = args['studentName'] ?? 'Estudiante';
          return McpPromptResult(
            description: 'Deliberate practice post-mortem and PDF report workflow.',
            messages: [
              McpPromptMessage.user(
                'Perform a deliberate practice post-mortem for "$songTitle" (student: "$studentName"):\n'
                '1. Execute "tunner_practice_evaluate_session" over all captured note events.\n'
                '2. Inspect criticalNotes, rhythmTendency (rushing/dragging/stable), and trendAnalysisText.\n'
                '3. Run "tunner_scaffolding_evaluate_note" for critical cents deviations to derive biomechanical cues and BPM adjustments.\n'
                '4. Aggregate metrics with "tunner_pedagogy_aggregate_session_report" and export the PDF via "tunner_export_pedagogical_report_pdf".',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'ebbinghaus_daily_review_planner',
        description:
            'Plans and tracks a daily ear-training review session prioritized by Ebbinghaus cognitive retention.',
        arguments: const [
          McpPromptArgument(
            name: 'maxItems',
            description: 'Maximum number of due items to schedule (default 5).',
            required: false,
          ),
        ],
        builder: (args) async {
          final maxItems = args['maxItems'] ?? '5';
          return McpPromptResult(
            description: 'Daily Ebbinghaus cognitive retention review planner.',
            messages: [
              McpPromptMessage.user(
                'Plan today\'s auditory review session (up to $maxItems items):\n'
                '1. Read "tunner://pedagogy/ebbinghaus/due" and select the top $maxItems items with the lowest retention.\n'
                '2. For each attempted item, record performance with "tunner_ebbinghaus_submit_answer".\n'
                '3. Read "tunner://pedagogy/ebbinghaus/bank" at the end and report the improvement in overallRetention.',
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

  Future<McpToolResult> _handleEbbinghausSubmitAnswer(
    Map<String, dynamic> args,
  ) async {
    final itemId = _requireString(args, 'itemId');
    final isCorrect = _requireBool(args, 'isCorrect');
    final centsError = _requireDouble(args, 'centsError');
    final responseTimeSeconds = _requireDouble(args, 'responseTimeSeconds');
    final timestampRaw = _optionalString(args, 'timestamp');

    DateTime? timestamp;
    if (timestampRaw != null) {
      timestamp = DateTime.tryParse(timestampRaw);
      if (timestamp == null) {
        throw McpException.invalidParams(
          'Invalid ISO-8601 timestamp: "$timestampRaw".',
        );
      }
    }

    if (_ebbinghaus.getItem(itemId) == null) {
      throw McpException.fileNotFound(
        'Ebbinghaus item not found: "$itemId".',
      );
    }

    final result = _ebbinghaus.submitAnswer(
      itemId,
      isCorrect: isCorrect,
      centsError: centsError,
      responseTimeSeconds: responseTimeSeconds,
      timestamp: timestamp,
    );

    return McpToolResult.json(result.toJson());
  }

  Future<McpToolResult> _handleEbbinghausAddItem(
    Map<String, dynamic> args,
  ) async {
    final id = _requireString(args, 'id');
    final name = _requireString(args, 'name');
    final categoryRaw = _requireString(args, 'category');
    final semitones = _requireDouble(args, 'semitones');
    final centsDeviation = _requireDouble(args, 'centsDeviation');

    final category = _parseEarTrainingCategory(categoryRaw);
    final item = EarTrainingItemEntity(
      id: id,
      name: name,
      category: category,
      semitones: semitones,
      centsDeviation: centsDeviation,
      nextReviewDate: DateTime.now(),
    );
    _ebbinghaus.addItem(item);

    return McpToolResult.json({
      'added': true,
      'item': item.toJson(),
    });
  }

  Future<McpToolResult> _handleSetActiveProfile(
    Map<String, dynamic> args,
  ) async {
    final preset = _optionalString(args, 'preset');
    final customRaw = args['customProfile'];

    if (customRaw is Map<String, dynamic>) {
      _activeProfile = LearnerProfileEntity.fromJson(customRaw);
    } else if (preset != null) {
      _activeProfile = _resolveProfilePreset(preset);
    } else {
      throw const McpException.invalidParams(
        'Provide either "preset" (child, adult, conservatory) or "customProfile".',
      );
    }

    return McpToolResult.json(_activeProfile.toJson());
  }

  Future<McpToolResult> _handleEvaluateVocalStability(
    Map<String, dynamic> args,
  ) async {
    final frequenciesHz = _requireDoubleList(args, 'frequenciesHz');
    final amplitudes = _requireDoubleList(args, 'amplitudes');
    final targetFrequencyHz = _requireDouble(args, 'targetFrequencyHz');
    final analysisFrameRateHz =
        _optionalDouble(args, 'analysisFrameRateHz') ?? 50.0;
    final evaluationId = _optionalString(args, 'evaluationId');

    if (frequenciesHz.length != amplitudes.length) {
      throw const McpException.invalidParams(
        'Parameters "frequenciesHz" and "amplitudes" must have the same length.',
      );
    }
    if (targetFrequencyHz <= 0.0 || analysisFrameRateHz <= 0.0) {
      throw const McpException.invalidParams(
        'Parameters "targetFrequencyHz" and "analysisFrameRateHz" must be strictly positive.',
      );
    }

    final evaluator = VocalStabilityEvaluator(
      analysisFrameRateHz: analysisFrameRateHz,
    );
    final result = evaluator.evaluate(
      frequenciesHz: frequenciesHz,
      amplitudes: amplitudes,
      targetFrequencyHz: targetFrequencyHz,
      evaluationId: evaluationId,
    );

    _latestVocalEvaluation = result;
    _sessionAggregator.setVocalEvaluation(result);

    return McpToolResult.json(result.toJson());
  }

  Future<McpToolResult> _handleScaffoldingEvaluateNote(
    Map<String, dynamic> args,
  ) async {
    final centsDeviation = _requireDouble(args, 'centsDeviation');
    final consecutiveSuccesses =
        (_optionalInt(args, 'consecutiveSuccesses') ?? 0).clamp(0, 10000);
    final consecutiveErrors =
        (_optionalInt(args, 'consecutiveErrors') ?? 0).clamp(0, 10000);

    final profileRaw = args['profile'];
    final LearnerProfileEntity profile;
    if (profileRaw == null) {
      profile = _activeProfile;
    } else if (profileRaw is String) {
      profile = _resolveProfilePreset(profileRaw);
    } else if (profileRaw is Map<String, dynamic>) {
      profile = LearnerProfileEntity.fromJson(profileRaw);
    } else {
      throw const McpException.invalidParams(
        'Parameter "profile" must be a preset string or a LearnerProfileEntity JSON object.',
      );
    }

    final diagnostic = _scaffoldingEngine.evaluateNote(
      centsDeviation: centsDeviation,
      profile: profile,
      consecutiveSuccesses: consecutiveSuccesses,
      consecutiveErrors: consecutiveErrors,
    );

    return McpToolResult.json({
      'isInTune': diagnostic.isInTune,
      'effectiveToleranceCents': diagnostic.effectiveToleranceCents,
      'primaryFeedback': diagnostic.primaryFeedback,
      'biomechanicalCue': diagnostic.biomechanicalCue,
      'motivationalCue': diagnostic.motivationalCue,
      'suggestedBpmAdjustment': diagnostic.suggestedBpmAdjustment,
      'scaffoldingLevel': diagnostic.scaffoldingLevel,
      'profileType': profile.type.name,
    });
  }

  Future<McpToolResult> _handlePracticeEvaluateSession(
    Map<String, dynamic> args,
  ) async {
    final songTitle = _requireString(args, 'songTitle');
    final instrumentName =
        _optionalString(args, 'instrumentName') ?? 'Instrumento Estandar';
    final toleranceCents =
        _optionalDouble(args, 'toleranceCents') ?? _activeProfile.centsTolerance;

    final rawNotes = args['notes'];
    if (rawNotes is! List || rawNotes.isEmpty) {
      throw const McpException.invalidParams(
        'Parameter "notes" must be a non-empty array of note evaluation inputs.',
      );
    }

    PracticeReportEntity? previousSession;
    final prevRaw = args['previousSession'];
    if (prevRaw is Map<String, dynamic>) {
      previousSession = PracticeReportEntity.fromMap(prevRaw);
    }

    final evaluations = <NoteEvaluationEntity>[];
    for (int i = 0; i < rawNotes.length; i++) {
      final entry = rawNotes[i];
      if (entry is! Map<String, dynamic>) {
        throw McpException.invalidParams(
          'Each entry in "notes" must be an object (index $i).',
        );
      }
      final expectedNoteName = _requireString(entry, 'expectedNoteName');
      final soundingExpected = _optionalString(entry, 'soundingExpectedNoteName');
      final isRest = _optionalBool(entry, 'isRest') ?? false;
      final startTick = _optionalInt(entry, 'startTick') ?? (i * 4);
      final durationTicks = _optionalInt(entry, 'durationTicks') ?? 4;
      final detectedNoteName = _requireString(entry, 'detectedNoteName');
      final detectedFrequency = _requireDouble(entry, 'detectedFrequency');
      final detectedCents = _requireDouble(entry, 'detectedCents');
      final timingDeltaMs = _requireInt(entry, 'timingDeltaMs');
      final sustainRatio = _optionalDouble(entry, 'sustainRatio') ?? 1.0;

      final expectedNote = HierarchicalNote(
        startTick: startTick,
        durationTicks: durationTicks,
        noteName: expectedNoteName,
        isRest: isRest,
      );

      final eval = _practiceEvaluator.evaluateNote(
        expectedNote: expectedNote,
        soundingExpectedNoteName: soundingExpected,
        detectedNoteName: detectedNoteName,
        detectedFrequency: detectedFrequency,
        detectedCents: detectedCents,
        timingDeltaMs: timingDeltaMs,
        sustainRatio: sustainRatio,
        toleranceCents: toleranceCents,
      );
      evaluations.add(eval);
      _sessionAggregator.addNoteEvaluation(eval);
    }

    final report = _practiceEvaluator.generateReport(
      songTitle: songTitle,
      instrumentName: instrumentName,
      evaluations: evaluations,
      previousSession: previousSession,
    );

    _latestPracticeReport = report;
    return McpToolResult.json(report.toMap());
  }

  Future<McpToolResult> _handleAggregateSessionReport(
    Map<String, dynamic> args,
  ) async {
    final sessionTitle = _optionalString(args, 'sessionTitle');
    final useLatest = _optionalBool(args, 'useLatestPracticeReport') ?? true;
    final durationSeconds =
        (_optionalInt(args, 'durationSeconds') ?? 0).clamp(0, 86400);
    final spectralCentroidHz = _optionalDouble(args, 'spectralCentroidHz') ?? 0.0;
    final thdPercentage = _optionalDouble(args, 'thdPercentage') ?? 0.0;
    final rhythmMeanBpm = _optionalDouble(args, 'rhythmMeanBpm') ?? 120.0;
    final includeVocal = _optionalBool(args, 'includeVocalEvaluation') ?? true;

    List<double> harmonicRatios = const [
      1.0,
      0.5,
      0.25,
      0.12,
      0.08,
      0.04,
      0.02,
      0.01,
    ];
    final rawRatios = args['harmonicRatios'];
    if (rawRatios is List && rawRatios.isNotEmpty) {
      harmonicRatios = rawRatios
          .map((e) => (e as num).toDouble())
          .toList(growable: false);
    }

    PracticeReportEntity? report;
    final rawReport = args['practiceReport'];
    if (rawReport is Map<String, dynamic>) {
      report = PracticeReportEntity.fromMap(rawReport);
    } else if (useLatest) {
      report = _latestPracticeReport;
    }

    final PedagogicalSessionData sessionData;
    if (report != null) {
      sessionData = PedagogicalSessionAggregator.fromPracticeReport(
        report,
        duration: Duration(seconds: durationSeconds),
        spectralCentroidHz: spectralCentroidHz,
        thdPercentage: thdPercentage,
        harmonicRatios: harmonicRatios,
        rhythmMeanBpm: rhythmMeanBpm,
        vocalEvaluation: includeVocal ? _latestVocalEvaluation : null,
        sessionTitle: sessionTitle,
      );
    } else {
      _sessionAggregator.setSpectralTelemetry(
        spectralCentroidHz: spectralCentroidHz,
        thdPercentage: thdPercentage,
        harmonicRatios: harmonicRatios,
      );
      _sessionAggregator.setRhythmMeanBpm(rhythmMeanBpm);
      sessionData = _sessionAggregator.buildSessionData(
        sessionTitle: sessionTitle ?? 'Sesion Pedagogica Headless',
        duration: Duration(seconds: durationSeconds),
        inTuneThresholdCents: _activeProfile.centsTolerance,
      );
    }

    return McpToolResult.json(sessionData.toJson());
  }

  Future<McpToolResult> _handleExportVocalCertificatePdf(
    Map<String, dynamic> args,
  ) async {
    final studentName = _requireString(args, 'studentName');
    final outputPathRaw = _requireString(args, 'outputPath');
    final outFile = _resolveWorkspaceFile(outputPathRaw);

    final VocalEvaluationResult evaluation;
    final evalRaw = args['evaluation'];
    if (evalRaw is Map<String, dynamic>) {
      evaluation = VocalEvaluationResult.fromJson(evalRaw);
    } else if (_latestVocalEvaluation != null) {
      evaluation = _latestVocalEvaluation!;
    } else {
      throw const McpException.invalidParams(
        'Provide "evaluation" JSON or execute tunner_evaluate_vocal_stability first.',
      );
    }

    final pdfBytes = PedagogicalCertificatePdfGenerator.generateCertificatePdf(
      studentName: studentName,
      evaluation: evaluation,
    );

    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(pdfBytes, flush: true);

    return McpToolResult.json({
      'outputPath': outFile.path,
      'byteLength': pdfBytes.length,
      'payloadHashSha256': evaluation.payloadHashSha256,
      'studentName': studentName,
      'overallScore': evaluation.overallScore,
      'classificationLabel': evaluation.classificationLabel,
    });
  }

  Future<McpToolResult> _handleExportPedagogicalReportPdf(
    Map<String, dynamic> args,
  ) async {
    final outputPathRaw = _requireString(args, 'outputPath');
    final outFile = _resolveWorkspaceFile(outputPathRaw);

    final PedagogicalSessionData session;
    final sessionRaw = args['session'];
    if (sessionRaw is Map<String, dynamic>) {
      session = PedagogicalSessionData.fromJson(sessionRaw);
    } else if (_latestPracticeReport != null) {
      session = PedagogicalSessionAggregator.fromPracticeReport(
        _latestPracticeReport!,
        vocalEvaluation: _latestVocalEvaluation,
      );
    } else {
      session = PedagogicalSessionData.sample();
    }

    final configRaw = args['config'];
    final config = configRaw is Map<String, dynamic>
        ? PedagogicalReportConfig.fromJson(configRaw)
        : const PedagogicalReportConfig();

    final pdfBytes = _reportPdfGenerator.generateReportPdf(
      session: session,
      config: config,
    );

    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(pdfBytes, flush: true);

    return McpToolResult.json({
      'outputPath': outFile.path,
      'byteLength': pdfBytes.length,
      'pages': config.includeCertificate ? 2 : 1,
      'masteryLevel': session.masteryLevel,
      'sessionTitle': session.sessionTitle,
    });
  }

  // ===========================================================================
  // Security & Parsing Helpers
  // ===========================================================================

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

  static LearnerProfileEntity _resolveProfilePreset(String raw) {
    final clean = raw.trim().toLowerCase();
    switch (clean) {
      case 'child':
      case 'childplayful':
        return LearnerProfileEntity.child();
      case 'adult':
      case 'adultdeliberate':
        return LearnerProfileEntity.adult();
      case 'conservatory':
      case 'conservatorymastery':
        return LearnerProfileEntity.conservatory();
      default:
        throw McpException.invalidParams(
          'Unknown learner profile preset "$raw". Supported: child, adult, conservatory.',
        );
    }
  }

  static EarTrainingCategory _parseEarTrainingCategory(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final c in EarTrainingCategory.values) {
      if (c.name.toLowerCase() == clean) return c;
    }
    throw McpException.invalidParams('Unknown EarTrainingCategory: "$raw".');
  }

  static List<double> _requireDoubleList(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! List || v.isEmpty) {
      throw McpException.invalidParams(
        'Parameter "$key" must be a non-empty array of numbers.',
      );
    }
    final result = <double>[];
    for (final item in v) {
      if (item is! num || !item.isFinite) {
        throw McpException.invalidParams(
          'All elements in "$key" must be finite numbers.',
        );
      }
      result.add(item.toDouble());
    }
    return result;
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

  static bool _requireBool(Map<String, dynamic> args, String key) {
    final v = args[key];
    if (v is! bool) {
      throw McpException.invalidParams('Parameter "$key" must be a boolean.');
    }
    return v;
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
