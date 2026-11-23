import '../../features/ear_training/domain/blind_ear_headless_session_controller.dart';
import '../../features/ear_training/domain/blind_ear_trainer_engine.dart';
import '../../features/ear_training/domain/musical_interval.dart';
import '../../features/exercise_generator/domain/algorithmic_exercise_generator.dart';
import '../../features/guided_lessons/domain/curated_guided_lessons.dart';
import '../../features/guided_lessons/domain/guided_lesson_entity.dart';
import '../../features/guided_lessons/domain/guided_lesson_evaluator.dart';
import '../../features/guided_lessons/domain/instrument_pedagogy_adapter_engine.dart';
import '../../features/guided_lessons/domain/pedagogical_task_contract.dart';
import '../../features/guided_lessons/domain/task_catalog_index.dart';
import '../../features/guided_lessons/domain/task_taxonomy_code.dart';
import '../../features/instrument/domain/instrument_profile_entity.dart';
import '../facade/tunner_headless_facade.dart';
import '../protocol/mcp_error_codes.dart';
import '../protocol/mcp_primitives.dart';
import '../protocol/mcp_registry.dart';

/// MCP feature module exposing headless blind ear-training sessions synchronized
/// with Ebbinghaus spaced repetition, algorithmic conservatory exercise generation,
/// instrument-adapted guided lessons, and the TTC pedagogical task catalog.
class EarTrainingMcpModule implements IMcpFeatureModule {
  final TunnerHeadlessFacade facade;
  final BlindEarHeadlessSessionController _sessionController;
  final AlgorithmicExerciseGenerator _exerciseGenerator;
  final GuidedLessonEvaluator _lessonEvaluator;
  final InstrumentPedagogyAdapterEngine _pedagogyAdapter;
  final TaskCatalogIndex _taskCatalog;

  EarTrainingMcpModule(
    this.facade, {
    BlindEarHeadlessSessionController? sessionController,
    AlgorithmicExerciseGenerator? exerciseGenerator,
    GuidedLessonEvaluator? lessonEvaluator,
    InstrumentPedagogyAdapterEngine? pedagogyAdapter,
    TaskCatalogIndex? taskCatalog,
  })  : _sessionController = sessionController ??
            BlindEarHeadlessSessionController(
              ebbinghausEngine: facade.root.earTrainingTerminalAdapter.engine,
            ),
        _exerciseGenerator =
            exerciseGenerator ?? const AlgorithmicExerciseGenerator(),
        _lessonEvaluator = lessonEvaluator ?? GuidedLessonEvaluator(),
        _pedagogyAdapter =
            pedagogyAdapter ?? const InstrumentPedagogyAdapterEngine(),
        _taskCatalog = taskCatalog ?? TaskCatalogIndex();

  @override
  String get moduleName => 'ear_training';

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
        uri: 'tunner://ear-training/intervals',
        name: 'Canonical Musical Intervals Catalog',
        description:
            'Catalog of all 13 chromatic MusicalInterval entries with 12-EDO and Just Intonation ratios and cents.',
        mimeType: 'application/json',
        reader: () async {
          final intervals = MusicalInterval.values
              .map(
                (i) => {
                  'id': i.name,
                  'semitones': i.semitones,
                  'shortName': i.shortName,
                  'displayName': i.displayName,
                  'equalTemperamentRatio': i.equalTemperamentRatio,
                  'equalTemperamentCents': i.equalTemperamentCents,
                  'justRatio': '${i.justRatioNumerator}/${i.justRatioDenominator}',
                  'justRatioDecimal': i.justRatio,
                  'justCents': i.justCents,
                  'centDifferenceJustVsEqual': i.centDifferenceJustVsEqual,
                },
              )
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://ear-training/intervals',
            data: {
              'count': intervals.length,
              'intervals': intervals,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://ear-training/session/state',
        name: 'Active Ear Training Session State',
        description:
            'Live state and performance metrics of the active BlindEarHeadlessSessionController.',
        mimeType: 'application/json',
        reader: () async {
          return McpResourceContent.json(
            uri: 'tunner://ear-training/session/state',
            data: {
              ..._sessionController.toJson(hideCorrectOption: false),
              'config': _serializeEarConfig(_sessionController.engine.config),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://lessons/curated',
        name: 'Curated Guided Lessons Catalog',
        description:
            'Complete catalog of curated interactive guided lessons (CuratedGuidedLessons.all).',
        mimeType: 'application/json',
        reader: () async {
          final lessons = CuratedGuidedLessons.all
              .map((l) => l.toJson())
              .toList(growable: false);
          return McpResourceContent.json(
            uri: 'tunner://lessons/curated',
            data: {
              'count': lessons.length,
              'lessons': lessons,
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://lessons/session/progress',
        name: 'Active Guided Lesson Progress',
        description:
            'Real-time progress state of the active GuidedLessonEvaluator session.',
        mimeType: 'application/json',
        reader: () async {
          final progress = _lessonEvaluator.activeProgress;
          return McpResourceContent.json(
            uri: 'tunner://lessons/session/progress',
            data: {
              'hasActiveLesson': _lessonEvaluator.hasActiveLesson,
              'lessonId': progress?.lesson.id,
              'currentStepIndex': progress?.currentStepIndex,
              'sustainedSeconds': progress?.sustainedSeconds,
              'stepProgressRatio': progress?.stepProgressRatio,
              'overallLessonProgressRatio': progress?.overallLessonProgressRatio,
              'isStepComplete': progress?.isStepComplete ?? false,
              'isLessonComplete': progress?.isLessonComplete ?? false,
              'totalAccumulatedAccuracy': progress?.totalAccumulatedAccuracy,
              'progress': progress?.toJson(),
            },
          );
        },
      ),
    );

    registry.registerResource(
      McpResourceDefinition(
        uri: 'tunner://tasks/catalog',
        name: 'Pedagogical Task Taxonomy Catalog (TTC)',
        description:
            'Complete in-memory TaskCatalogIndex ordered by canonical TTC code ([DOM].[LVL].[SUB].[SEQ]).',
        mimeType: 'application/json',
        reader: () async {
          final tasks = _taskCatalog.allTasks;
          final multiToolCount = tasks.where((t) => t.isMultiTool).length;
          return McpResourceContent.json(
            uri: 'tunner://tasks/catalog',
            data: {
              'count': tasks.length,
              'multiToolCount': multiToolCount,
              'tasks': tasks.map((t) => t.toJson()).toList(growable: false),
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Tools (10)
  // ===========================================================================

  void _registerTools(McpRegistry registry) {
    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ear_training_configure',
        description:
            'Configures the headless BlindEarTrainerEngine session parameters (intervals, direction, Just Intonation, base frequency range, or preset).',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'preset': {
              'type': 'string',
              'enum': ['beginner', 'full'],
              'description': 'Optional preset configuration.',
            },
            'activeIntervals': {
              'type': 'array',
              'items': {'type': 'string'},
              'description':
                  'List of MusicalInterval names (e.g., majorThird, perfectFifth) or shortNames (e.g., 3M, 5J).',
            },
            'onlyAscending': {'type': 'boolean'},
            'useJustIntonation': {'type': 'boolean'},
            'minBaseFrequencyHz': {'type': 'number'},
            'maxBaseFrequencyHz': {'type': 'number'},
            'resetSession': {
              'type': 'boolean',
              'default': false,
              'description': 'When true, resets streak, score, and history.',
            },
          },
        },
        handler: _handleEarTrainingConfigure,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ear_training_next_question',
        description:
            'Generates the next ear-training interval question, prioritizing due items from EbbinghausSpacedRepetitionEngine when enabled.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'prioritizeEbbinghausDue': {
              'type': 'boolean',
              'default': true,
              'description':
                  'Prioritize due intervals with lowest cognitive retention R(t).',
            },
            'blindMode': {
              'type': 'boolean',
              'default': false,
              'description': 'When true, omits correctOptionIndex from response.',
            },
            'targetRetention': {
              'type': 'number',
              'default': 0.90,
            },
          },
        },
        handler: _handleEarTrainingNextQuestion,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ear_training_submit_choice',
        description:
            'Submits an explicit interval choice for the current ear-training question and synchronizes the outcome with EbbinghausSpacedRepetitionEngine.',
        inputSchema: const {
          'type': 'object',
          'required': ['selectedInterval'],
          'properties': {
            'selectedInterval': {
              'type': 'string',
              'description': 'MusicalInterval enum name or shortName (e.g., perfectFifth, 5J).',
            },
            'responseTimeMs': {
              'type': 'integer',
              'default': 1200,
            },
            'centsDeviation': {
              'type': 'number',
              'default': 0.0,
            },
            'hasAcousticCents': {
              'type': 'boolean',
              'default': true,
            },
          },
        },
        handler: _handleEarTrainingSubmitChoice,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_ear_training_submit_sung_pitch',
        description:
            'Evaluates a sung or played pitch frequency against the current ear-training question, optionally applying the 3-sample vocal stability window, and syncs with Ebbinghaus.',
        inputSchema: const {
          'type': 'object',
          'required': ['sungFrequencyHz'],
          'properties': {
            'sungFrequencyHz': {
              'type': 'number',
              'description': 'Detected sung or played frequency in Hz.',
            },
            'responseTimeMs': {
              'type': 'integer',
              'default': 1800,
            },
            'useStabilityFilter': {
              'type': 'boolean',
              'default': false,
              'description':
                  'When true, feeds ingestSungFrequencySample() requiring 3 consecutive stable samples.',
            },
          },
        },
        handler: _handleEarTrainingSubmitSungPitch,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_generate_exercise',
        description:
            'Generates a deterministic conservatory technical exercise (scale, arpeggio, thirds, long tones) via AlgorithmicExerciseGenerator.',
        inputSchema: const {
          'type': 'object',
          'required': ['rootNote', 'type'],
          'properties': {
            'rootNote': {
              'type': 'string',
              'description': 'Starting root note in solfege or scientific pitch (e.g., Do4, C4, Fa#4).',
            },
            'type': {
              'type': 'string',
              'enum': [
                'majorScale',
                'naturalMinorScale',
                'harmonicMinorScale',
                'melodicMinorScale',
                'pentatonicScale',
                'majorArpeggio',
                'minorArpeggio',
                'thirdsIntervals',
                'longTones',
              ],
            },
            'rhythm': {
              'type': 'string',
              'enum': ['quarter', 'eighth', 'sixteenth', 'half', 'whole'],
              'default': 'quarter',
            },
            'bpm': {
              'type': 'integer',
              'default': 80,
            },
            'loadIntoActiveScore': {
              'type': 'boolean',
              'default': false,
              'description':
                  'When true, sets the generated HierarchicalScore as facade.activeScore.',
            },
          },
        },
        handler: _handleGenerateExercise,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_adapt_lesson_to_instrument',
        description:
            'Adapts a curated GuidedLessonEntity to a target instrument tessitura, transposition, and acoustic family biomechanics via InstrumentPedagogyAdapterEngine.',
        inputSchema: const {
          'type': 'object',
          'required': ['lessonId', 'instrumentId'],
          'properties': {
            'lessonId': {
              'type': 'string',
              'description': 'Curated lesson identifier (e.g., lesson_01_master_notes).',
            },
            'instrumentId': {
              'type': 'string',
              'description': 'InstrumentProfileEntity id (e.g., flute, bb_trumpet, violin, voice).',
            },
          },
        },
        handler: _handleAdaptLessonToInstrument,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_guided_lesson_start',
        description:
            'Starts a guided lesson evaluation session in GuidedLessonEvaluator from a curated lessonId or customLesson payload, with optional instrument adaptation and custom cents tolerance.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'lessonId': {
              'type': 'string',
              'description': 'Curated lesson ID from CuratedGuidedLessons.',
            },
            'customLesson': {
              'type': 'object',
              'description': 'Custom GuidedLessonEntity JSON payload.',
            },
            'instrumentId': {
              'type': 'string',
              'description': 'Optional InstrumentProfileEntity ID to adapt tessitura and tips.',
            },
            'customToleranceCents': {
              'type': 'number',
              'description': 'Optional tolerance override in cents (e.g., from active learner profile).',
            },
          },
        },
        handler: _handleGuidedLessonStart,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_guided_lesson_evaluate_sample',
        description:
            'Feeds a real-time or simulated pitch sample into GuidedLessonEvaluator and returns updated sustain progress and step/lesson completion status.',
        inputSchema: const {
          'type': 'object',
          'required': ['frequencyHz', 'cents', 'detectedNoteName', 'deltaSeconds'],
          'properties': {
            'frequencyHz': {'type': 'number'},
            'cents': {'type': 'number'},
            'detectedNoteName': {'type': 'string'},
            'deltaSeconds': {'type': 'number'},
          },
        },
        handler: _handleGuidedLessonEvaluateSample,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_tasks_search',
        description:
            'Searches and filters the TaskCatalogIndex by free-text query, domain, level, status, instrumentId, or multi-tool synergy flag.',
        inputSchema: const {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
            'domain': {
              'type': 'string',
              'description': 'TaskDomain code (EAR, RHY, PCH, SGT, HRM, TEC) or enum name.',
            },
            'level': {
              'type': 'integer',
              'description': 'TaskLevel numeric value (1..5).',
            },
            'status': {
              'type': 'string',
              'description': 'TaskCompletionStatus id (not_started, in_progress, completed, mastered).',
            },
            'instrumentId': {'type': 'string'},
            'multiToolOnly': {'type': 'boolean', 'default': false},
            'limit': {'type': 'integer', 'default': 20},
          },
        },
        handler: _handleTasksSearch,
      ),
    );

    registry.registerTool(
      McpToolDefinition(
        name: 'tunner_tasks_get_by_code',
        description:
            'Retrieves full details of a pedagogical task by its canonical TTC code (e.g., EAR.01.INTV.001), including steps and multi-tool interconnection links.',
        inputSchema: const {
          'type': 'object',
          'required': ['code'],
          'properties': {
            'code': {
              'type': 'string',
              'description': 'Canonical TTC code in [DOM].[LVL].[SUB].[SEQ] format.',
            },
          },
        },
        handler: _handleTasksGetByCode,
      ),
    );
  }

  // ===========================================================================
  // Prompts (3)
  // ===========================================================================

  void _registerPrompts(McpRegistry registry) {
    registry.registerPrompt(
      McpPromptDefinition(
        name: 'adaptive_ear_training_session',
        description:
            'Conducts an adaptive ear-training session driven by Ebbinghaus spaced repetition due items.',
        arguments: const [
          McpPromptArgument(
            name: 'questionCount',
            description: 'Target number of questions in the session (default 10).',
            required: false,
          ),
          McpPromptArgument(
            name: 'focusCategory',
            description: 'Optional focus intervals or preset (beginner/full).',
            required: false,
          ),
        ],
        builder: (args) async {
          final count = args['questionCount'] ?? '10';
          final focus = args['focusCategory'] ?? 'full';
          return McpPromptResult(
            description: 'Ebbinghaus-driven adaptive ear-training session workflow.',
            messages: [
              McpPromptMessage.user(
                'Conduct an adaptive ear-training session of $count questions (focus: $focus):\n'
                '1. Read "tunner://pedagogy/ebbinghaus/due" to identify due intervals with lowest cognitive retention R(t).\n'
                '2. Configure the engine via "tunner_ear_training_configure".\n'
                '3. Loop $count times: call "tunner_ear_training_next_question" (prioritizeEbbinghausDue=true), collect the learner response, and evaluate with "tunner_ear_training_submit_choice" or "tunner_ear_training_submit_sung_pitch".\n'
                '4. Summarize accuracyPercentage, bestStreak, averageCentsDeviation, and updated Ebbinghaus retention.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'instrument_calibrated_warmup_generator',
        description:
            'Builds a personalized warmup routine calibrated to the student instrument and active learner profile.',
        arguments: const [
          McpPromptArgument(
            name: 'instrumentId',
            description: 'Target instrument ID (e.g., flute, bb_trumpet, violin, voice).',
            required: false,
          ),
          McpPromptArgument(
            name: 'rootNote',
            description: 'Root note for the technical warmup (e.g., Do4, Sol3).',
            required: false,
          ),
          McpPromptArgument(
            name: 'bpm',
            description: 'Starting tempo in BPM (default 72).',
            required: false,
          ),
        ],
        builder: (args) async {
          final instrumentId = args['instrumentId'] ?? 'flute';
          final rootNote = args['rootNote'] ?? 'Do4';
          final bpm = args['bpm'] ?? '72';
          return McpPromptResult(
            description: 'Instrument-calibrated warmup generation workflow.',
            messages: [
              McpPromptMessage.user(
                'Create a calibrated warmup routine for instrument "$instrumentId" starting on $rootNote at $bpm BPM:\n'
                '1. Read "tunner://pedagogy/profiles/active" to retrieve the active centsTolerance.\n'
                '2. Generate a long-tones or major-scale study using "tunner_generate_exercise".\n'
                '3. Adapt a curated lesson with "tunner_adapt_lesson_to_instrument" for "$instrumentId".\n'
                '4. Start the guided session via "tunner_guided_lesson_start" applying the profile tolerance.',
              ),
            ],
          );
        },
      ),
    );

    registry.registerPrompt(
      McpPromptDefinition(
        name: 'ttc_curriculum_navigator',
        description:
            'Recommends the next conservatory curriculum task from TaskCatalogIndex based on domain, level, and weaknesses.',
        arguments: const [
          McpPromptArgument(
            name: 'domain',
            description: 'Target TTC domain (EAR, RHY, PCH, SGT, HRM, TEC).',
            required: false,
          ),
          McpPromptArgument(
            name: 'level',
            description: 'Target difficulty level (1..5).',
            required: false,
          ),
          McpPromptArgument(
            name: 'instrumentId',
            description: 'Optional instrument ID filter.',
            required: false,
          ),
        ],
        builder: (args) async {
          final domain = args['domain'] ?? 'EAR';
          final level = args['level'] ?? '1';
          final instrumentId = args['instrumentId'] ?? 'any';
          return McpPromptResult(
            description: 'TTC curriculum recommendation workflow.',
            messages: [
              McpPromptMessage.user(
                'Recommend the next pedagogical task for domain "$domain", level $level, instrument "$instrumentId":\n'
                '1. Query "tunner_tasks_search" with the requested domain, level, and instrumentId.\n'
                '2. Inspect the top candidate with "tunner_tasks_get_by_code".\n'
                '3. Present its steps, estimatedDurationMinutes, and if isMultiTool == true explain the interconnectionLinks.',
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

  Future<McpToolResult> _handleEarTrainingConfigure(
    Map<String, dynamic> args,
  ) async {
    final preset = _optionalString(args, 'preset');
    final resetSession = _optionalBool(args, 'resetSession') ?? false;

    EarTrainingConfig base = _sessionController.engine.config;
    if (preset == 'beginner') {
      base = EarTrainingConfig.beginner();
    } else if (preset == 'full') {
      base = const EarTrainingConfig();
    } else if (preset != null) {
      throw McpException.invalidParams(
        'Invalid preset "$preset". Supported: beginner, full.',
      );
    }

    List<MusicalInterval> activeIntervals = base.activeIntervals;
    final rawIntervals = args['activeIntervals'];
    if (rawIntervals != null) {
      if (rawIntervals is! List || rawIntervals.isEmpty) {
        throw const McpException.invalidParams(
          'Parameter "activeIntervals" must be a non-empty array of interval names.',
        );
      }
      activeIntervals = rawIntervals
          .map((e) => _parseMusicalInterval(e.toString()))
          .toList(growable: false);
    }

    final onlyAscending =
        _optionalBool(args, 'onlyAscending') ?? base.onlyAscending;
    final useJustIntonation =
        _optionalBool(args, 'useJustIntonation') ?? base.useJustIntonation;
    final minHz =
        _optionalDouble(args, 'minBaseFrequencyHz') ?? base.minBaseFrequencyHz;
    final maxHz =
        _optionalDouble(args, 'maxBaseFrequencyHz') ?? base.maxBaseFrequencyHz;

    if (minHz <= 0.0 || maxHz <= 0.0 || minHz > maxHz) {
      throw const McpException.invalidParams(
        'Frequency bounds must be positive with minBaseFrequencyHz <= maxBaseFrequencyHz.',
      );
    }

    final nextConfig = EarTrainingConfig(
      activeIntervals: activeIntervals,
      onlyAscending: onlyAscending,
      useJustIntonation: useJustIntonation,
      minBaseFrequencyHz: minHz,
      maxBaseFrequencyHz: maxHz,
    );
    _sessionController.engine.config = nextConfig;
    if (resetSession) {
      _sessionController.resetSession();
    }

    return McpToolResult.json({
      'configured': true,
      'resetSession': resetSession,
      'config': _serializeEarConfig(nextConfig),
    });
  }

  Future<McpToolResult> _handleEarTrainingNextQuestion(
    Map<String, dynamic> args,
  ) async {
    final prioritizeDue = _optionalBool(args, 'prioritizeEbbinghausDue') ?? true;
    final blindMode = _optionalBool(args, 'blindMode') ?? false;
    final targetRetention =
        (_optionalDouble(args, 'targetRetention') ?? 0.90).clamp(0.1, 0.99);

    final question = _sessionController.generateNextQuestion(
      prioritizeDue: prioritizeDue,
      targetRetention: targetRetention,
    );

    return McpToolResult.json({
      ...question.toJson(hideCorrectOption: blindMode),
      'prioritizeEbbinghausDue': prioritizeDue,
      'blindMode': blindMode,
    });
  }

  Future<McpToolResult> _handleEarTrainingSubmitChoice(
    Map<String, dynamic> args,
  ) async {
    if (_sessionController.currentQuestion == null) {
      throw const McpException.invalidRequest(
        'No active ear-training question. Call tunner_ear_training_next_question first.',
      );
    }

    final selected = _parseMusicalInterval(
      _requireString(args, 'selectedInterval'),
    );
    final responseTimeMs = (_optionalInt(args, 'responseTimeMs') ?? 1200).clamp(0, 600000);
    final centsDeviation = _optionalDouble(args, 'centsDeviation') ?? 0.0;
    final hasAcousticCents = _optionalBool(args, 'hasAcousticCents') ?? true;

    final result = _sessionController.submitChoice(
      selected,
      responseTimeMs: responseTimeMs,
      centsDeviation: centsDeviation,
      hasAcousticCents: hasAcousticCents,
    );

    return McpToolResult.json({
      ...result.toJson(),
      'ebbinghausUpdate': _sessionController.lastEbbinghausEvaluation?.toJson(),
      'sessionStats': {
        'totalQuestionsAnswered': _sessionController.engine.totalQuestionsAnswered,
        'correctAnswersCount': _sessionController.engine.correctAnswersCount,
        'accuracyPercentage': _sessionController.engine.accuracyPercentage,
        'currentStreak': _sessionController.engine.currentStreak,
        'bestStreak': _sessionController.engine.bestStreak,
        'totalScore': _sessionController.engine.totalScore,
      },
    });
  }

  Future<McpToolResult> _handleEarTrainingSubmitSungPitch(
    Map<String, dynamic> args,
  ) async {
    if (_sessionController.currentQuestion == null) {
      throw const McpException.invalidRequest(
        'No active ear-training question. Call tunner_ear_training_next_question first.',
      );
    }

    final sungHz = _requireDouble(args, 'sungFrequencyHz');
    final responseTimeMs = (_optionalInt(args, 'responseTimeMs') ?? 1800).clamp(0, 600000);
    final useStabilityFilter = _optionalBool(args, 'useStabilityFilter') ?? false;

    if (useStabilityFilter) {
      final maybeResult = _sessionController.ingestSungFrequencySample(
        sungHz,
        responseTimeMs: responseTimeMs,
      );
      if (maybeResult == null) {
        return McpToolResult.json({
          'confirmed': false,
          'consecutiveStableSampleCount':
              _sessionController.consecutiveStableSampleCount,
          'stabilityWindowSize': _sessionController.stabilityWindowSize,
          'lastDetectedFrequencyHz': _sessionController.lastDetectedFrequencyHz,
        });
      }
      return McpToolResult.json({
        'confirmed': true,
        ...maybeResult.toJson(),
        'detectedInterval': maybeResult.selectedInterval.name,
        'ebbinghausUpdate': _sessionController.lastEbbinghausEvaluation?.toJson(),
      });
    }

    final result = _sessionController.submitSungFrequency(
      sungHz,
      responseTimeMs: responseTimeMs,
    );

    return McpToolResult.json({
      'confirmed': true,
      ...result.toJson(),
      'detectedInterval': result.selectedInterval.name,
      'ebbinghausUpdate': _sessionController.lastEbbinghausEvaluation?.toJson(),
    });
  }

  Future<McpToolResult> _handleGenerateExercise(
    Map<String, dynamic> args,
  ) async {
    final rootNote = _requireString(args, 'rootNote');
    final type = _parseExerciseType(_requireString(args, 'type'));
    final rhythmRaw = _optionalString(args, 'rhythm');
    final rhythm = rhythmRaw != null
        ? _parseExerciseRhythm(rhythmRaw)
        : ExerciseRhythm.quarter;
    final bpm = (_optionalInt(args, 'bpm') ?? 80).clamp(20, 300);
    final loadIntoActiveScore =
        _optionalBool(args, 'loadIntoActiveScore') ?? false;

    final songPkg = _exerciseGenerator.generate(
      rootNote: rootNote,
      type: type,
      rhythm: rhythm,
      bpm: bpm,
    );

    if (loadIntoActiveScore) {
      facade.setActiveScore(songPkg.score);
    }

    final notes = <Map<String, dynamic>>[];
    for (final measure in songPkg.score.measures) {
      for (final note in measure.notes) {
        notes.add({
          'measure': measure.index,
          'startTick': note.startTick,
          'durationTicks': note.durationTicks,
          'noteName': note.noteName,
          'isRest': note.isRest,
        });
      }
    }

    return McpToolResult.json({
      'id': songPkg.id,
      'title': songPkg.title,
      'composer': songPkg.composer,
      'difficulty': songPkg.difficulty.name,
      'defaultBpm': songPkg.defaultBpm,
      'exerciseType': type.name,
      'rhythm': rhythm.name,
      'measureCount': songPkg.score.measures.length,
      'noteCount': notes.where((n) => n['isRest'] == false).length,
      'loadedIntoActiveScore': loadIntoActiveScore,
      'notes': notes,
    });
  }

  Future<McpToolResult> _handleAdaptLessonToInstrument(
    Map<String, dynamic> args,
  ) async {
    final lessonId = _requireString(args, 'lessonId');
    final instrumentId = _requireString(args, 'instrumentId');

    final lesson = _findCuratedLesson(lessonId);
    final instrument = _findInstrumentProfile(instrumentId);
    final adapted = _pedagogyAdapter.adaptLesson(lesson, instrument);

    return McpToolResult.json({
      'instrument': {
        'id': instrument.id,
        'name': instrument.name,
        'family': instrument.family.name,
        'transpositionSemitones': instrument.transpositionSemitones,
        'minFrequencyHz': instrument.minFrequencyHz,
        'maxFrequencyHz': instrument.maxFrequencyHz,
      },
      'lesson': adapted.toJson(),
    });
  }

  Future<McpToolResult> _handleGuidedLessonStart(
    Map<String, dynamic> args,
  ) async {
    final lessonId = _optionalString(args, 'lessonId');
    final customLessonRaw = args['customLesson'];
    final instrumentId = _optionalString(args, 'instrumentId');
    final customToleranceCents = _optionalDouble(args, 'customToleranceCents');

    GuidedLessonEntity lesson;
    if (customLessonRaw is Map<String, dynamic>) {
      lesson = GuidedLessonEntity.fromJson(customLessonRaw);
      if (lesson.steps.isEmpty) {
        throw const McpException.invalidParams(
          'Parameter "customLesson" must contain at least one step.',
        );
      }
    } else if (lessonId != null) {
      lesson = _findCuratedLesson(lessonId);
    } else {
      throw const McpException.invalidParams(
        'Provide either "lessonId" or "customLesson".',
      );
    }

    if (instrumentId != null) {
      final instrument = _findInstrumentProfile(instrumentId);
      lesson = _pedagogyAdapter.adaptLesson(lesson, instrument);
    }

    final progress = _lessonEvaluator.startLesson(
      lesson,
      customToleranceCents: customToleranceCents,
    );

    return McpToolResult.json(progress.toJson());
  }

  Future<McpToolResult> _handleGuidedLessonEvaluateSample(
    Map<String, dynamic> args,
  ) async {
    if (_lessonEvaluator.activeProgress == null) {
      throw const McpException.invalidRequest(
        'No active guided lesson. Call tunner_guided_lesson_start first.',
      );
    }

    final frequencyHz = _requireDouble(args, 'frequencyHz');
    final cents = _requireDouble(args, 'cents');
    final detectedNoteName = _requireString(args, 'detectedNoteName');
    final deltaSeconds = _requireDouble(args, 'deltaSeconds');

    if (deltaSeconds < 0.0) {
      throw const McpException.invalidParams(
        'Parameter "deltaSeconds" must be non-negative.',
      );
    }

    final progress = _lessonEvaluator.evaluateSample(
      frequencyHz: frequencyHz,
      cents: cents,
      detectedNoteName: detectedNoteName,
      deltaSeconds: deltaSeconds,
    );

    return McpToolResult.json(progress!.toJson());
  }

  Future<McpToolResult> _handleTasksSearch(Map<String, dynamic> args) async {
    final query = _optionalString(args, 'query');
    final domainRaw = _optionalString(args, 'domain');
    final levelRaw = _optionalInt(args, 'level');
    final statusRaw = _optionalString(args, 'status');
    final instrumentId = _optionalString(args, 'instrumentId');
    final multiToolOnly = _optionalBool(args, 'multiToolOnly') ?? false;
    final limit = (_optionalInt(args, 'limit') ?? 20).clamp(1, 200);

    final TaskDomain? domain = domainRaw != null ? _parseTaskDomain(domainRaw) : null;
    final TaskLevel? level = levelRaw != null ? _parseTaskLevel(levelRaw) : null;
    final TaskCompletionStatus? status =
        statusRaw != null ? _parseTaskStatus(statusRaw) : null;

    List<PedagogicalTaskEntity> results;
    if (query != null) {
      results = _taskCatalog.searchByQuery(query, limit: _taskCatalog.count);
    } else if (multiToolOnly) {
      results = _taskCatalog.getMultiToolJointTasks();
    } else {
      results = _taskCatalog.filter(
        domain: domain,
        level: level,
        status: status,
        instrumentId: instrumentId,
      );
    }

    // Apply remaining facet filters consistently when combined with query/multiToolOnly.
    Iterable<PedagogicalTaskEntity> filtered = results;
    if (domain != null) {
      filtered = filtered.where((t) => t.code.domain == domain);
    }
    if (level != null) {
      filtered = filtered.where((t) => t.code.level == level);
    }
    if (status != null) {
      filtered = filtered.where((t) => t.status == status);
    }
    if (instrumentId != null) {
      filtered = filtered.where(
        (t) => t.targetInstrumentId == null || t.targetInstrumentId == instrumentId,
      );
    }
    if (multiToolOnly) {
      filtered = filtered.where((t) => t.isMultiTool);
    }

    final limited = filtered.take(limit).toList(growable: false);

    return McpToolResult.json({
      'total': limited.length,
      'tasks': limited.map((t) => t.toJson()).toList(growable: false),
    });
  }

  Future<McpToolResult> _handleTasksGetByCode(Map<String, dynamic> args) async {
    final code = _requireString(args, 'code');
    final task = _taskCatalog.getByCodeString(code);
    if (task == null) {
      throw McpException.fileNotFound('Pedagogical task not found for TTC code: "$code".');
    }
    return McpToolResult.json(task.toJson());
  }

  // ===========================================================================
  // Parsing & Serialization Helpers
  // ===========================================================================

  static Map<String, dynamic> _serializeEarConfig(EarTrainingConfig cfg) {
    return {
      'activeIntervals':
          cfg.activeIntervals.map((i) => i.name).toList(growable: false),
      'onlyAscending': cfg.onlyAscending,
      'useJustIntonation': cfg.useJustIntonation,
      'minBaseFrequencyHz': cfg.minBaseFrequencyHz,
      'maxBaseFrequencyHz': cfg.maxBaseFrequencyHz,
    };
  }

  static MusicalInterval _parseMusicalInterval(String raw) {
    final clean = raw.trim();
    for (final interval in MusicalInterval.values) {
      if (interval.name == clean ||
          interval.shortName.toLowerCase() == clean.toLowerCase()) {
        return interval;
      }
    }
    throw McpException.invalidMusicTheory('Unknown MusicalInterval: "$raw".');
  }

  static ExerciseType _parseExerciseType(String raw) {
    final clean = raw.trim();
    for (final t in ExerciseType.values) {
      if (t.name == clean) return t;
    }
    throw McpException.invalidMusicTheory('Unknown ExerciseType: "$raw".');
  }

  static ExerciseRhythm _parseExerciseRhythm(String raw) {
    final clean = raw.trim();
    for (final r in ExerciseRhythm.values) {
      if (r.name == clean) return r;
    }
    throw McpException.invalidMusicTheory('Unknown ExerciseRhythm: "$raw".');
  }

  static GuidedLessonEntity _findCuratedLesson(String lessonId) {
    for (final lesson in CuratedGuidedLessons.all) {
      if (lesson.id == lessonId) return lesson;
    }
    throw McpException.fileNotFound('Curated lesson not found: "$lessonId".');
  }

  static InstrumentProfileEntity _findInstrumentProfile(String instrumentId) {
    final clean = instrumentId.trim().toLowerCase();
    for (final inst in InstrumentProfileEntity.standardInstruments) {
      if (inst.id.toLowerCase() == clean) return inst;
    }
    throw McpException.fileNotFound(
      'Instrument profile not found: "$instrumentId".',
    );
  }

  static TaskDomain _parseTaskDomain(String raw) {
    final byCode = TaskDomain.fromCode(raw);
    if (byCode != null) return byCode;
    final lower = raw.trim().toLowerCase();
    for (final d in TaskDomain.values) {
      if (d.name.toLowerCase() == lower) return d;
    }
    throw McpException.invalidParams('Unknown TaskDomain: "$raw".');
  }

  static TaskLevel _parseTaskLevel(int value) {
    final level = TaskLevel.fromNumeric(value);
    if (level == null) {
      throw McpException.invalidParams('Invalid TaskLevel "$value". Expected 1..5.');
    }
    return level;
  }

  static TaskCompletionStatus _parseTaskStatus(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final s in TaskCompletionStatus.values) {
      if (s.id == clean || s.name.toLowerCase() == clean) return s;
    }
    throw McpException.invalidParams('Unknown TaskCompletionStatus: "$raw".');
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
