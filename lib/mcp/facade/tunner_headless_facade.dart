import 'dart:io';

import '../../app/headless_composition_root.dart';
import '../../core/logging/domain/i_studio_logger.dart';
import '../../core/logging/infrastructure/studio_stderr_logger.dart';
import '../../features/audio_synthesizer/domain/offline_score_wav_renderer.dart';
import '../../features/dj_console/domain/dj_console_headless_controller.dart';
import '../../features/media_vault/domain/media_vault_headless_controller.dart';
import '../../features/metronome/domain/offline_metronome_track_generator.dart';
import '../../features/mixer/domain/mixer_audio_renderer.dart';
import '../../features/modular_rack/domain/modular_rack_headless_controller.dart';
import '../../features/practice_recorder/domain/offline_practice_take_analyzer.dart';
import '../../features/project_format/domain/tunner_project_package.dart';
import '../../features/sheet_music/domain/score_tree.dart';
import '../../features/tuner/domain/offline_pitch_contour_analyzer.dart';

/// Callback signature used to forward live UI synchronization events to the
/// optional local IPC bridge (`TunnerIpcBridge`) without coupling MCP modules
/// to socket transport internals.
typedef McpIpcEventCallback = void Function(
  String event,
  Map<String, dynamic> payload,
);

/// Unified Pure Dart domain gateway consumed by all Tunner MCP Resources, Tools,
/// and Prompts.
///
/// Wraps [HeadlessCompositionRoot] together with the offline acoustic, DJ,
/// modular rack, media vault, mixer, metronome, and practice-take controllers,
/// while maintaining active session state ([activeScore], [activeProject]) and
/// optional live UI IPC notifications ([onIpcEvent]).
class TunnerHeadlessFacade {
  final HeadlessCompositionRoot root;
  final DjConsoleHeadlessController djController;
  final ModularRackHeadlessController modularRackController;
  final MediaVaultHeadlessController mediaVaultController;
  final OfflineScoreWavRenderer offlineScoreWavRenderer;
  final OfflinePitchContourAnalyzer offlinePitchContourAnalyzer;
  final OfflineMetronomeTrackGenerator offlineMetronomeTrackGenerator;
  final OfflinePracticeTakeAnalyzer offlinePracticeTakeAnalyzer;
  final MixerAudioRenderer mixerAudioRenderer;

  final DateTime startedAtUtc;
  McpIpcEventCallback? onIpcEvent;

  HierarchicalScore? _activeScore;
  TunnerProjectPackage? _activeProject;
  bool _isDisposed = false;

  TunnerHeadlessFacade({
    required this.root,
    DjConsoleHeadlessController? djController,
    ModularRackHeadlessController? modularRackController,
    MediaVaultHeadlessController? mediaVaultController,
    OfflineScoreWavRenderer? offlineScoreWavRenderer,
    OfflinePitchContourAnalyzer? offlinePitchContourAnalyzer,
    OfflineMetronomeTrackGenerator? offlineMetronomeTrackGenerator,
    OfflinePracticeTakeAnalyzer? offlinePracticeTakeAnalyzer,
    MixerAudioRenderer? mixerAudioRenderer,
    this.onIpcEvent,
    bool initializeDefaultRack = false,
  })  : djController = djController ?? DjConsoleHeadlessController(),
        modularRackController = modularRackController ??
            ModularRackHeadlessController(
              initializeDefaultRack: initializeDefaultRack,
            ),
        mediaVaultController =
            mediaVaultController ?? MediaVaultHeadlessController(),
        offlineScoreWavRenderer =
            offlineScoreWavRenderer ?? const OfflineScoreWavRenderer(),
        offlinePitchContourAnalyzer =
            offlinePitchContourAnalyzer ?? const OfflinePitchContourAnalyzer(),
        offlineMetronomeTrackGenerator = offlineMetronomeTrackGenerator ??
            const OfflineMetronomeTrackGenerator(),
        offlinePracticeTakeAnalyzer =
            offlinePracticeTakeAnalyzer ?? const OfflinePracticeTakeAnalyzer(),
        mixerAudioRenderer = mixerAudioRenderer ?? const MixerAudioRenderer(),
        startedAtUtc = DateTime.now().toUtc();

  /// Convenience factory that bootstraps [HeadlessCompositionRoot] for
  /// [workspaceDirectory] and assembles all Pure Dart headless controllers.
  factory TunnerHeadlessFacade.create({
    required Directory workspaceDirectory,
    IStudioLogger logger = StudioStderrLogger.instance,
    double initialBpm = 120.0,
    McpIpcEventCallback? onIpcEvent,
    bool initializeDefaultRack = false,
  }) {
    final root = HeadlessCompositionRoot(
      workspaceDirectory: workspaceDirectory,
      logger: logger,
      initialBpm: initialBpm,
    );
    return TunnerHeadlessFacade(
      root: root,
      onIpcEvent: onIpcEvent,
      initializeDefaultRack: initializeDefaultRack,
    );
  }

  Directory get workspaceDirectory => root.workspaceDirectory;
  IStudioLogger get logger => root.logger;
  bool get isDisposed => _isDisposed;
  int get uptimeMs =>
      DateTime.now().toUtc().difference(startedAtUtc).inMilliseconds;

  /// Currently loaded score in the headless MCP session, if any.
  HierarchicalScore? get activeScore => _activeScore;

  /// Currently loaded `.tunner` project package in the headless MCP session.
  TunnerProjectPackage? get activeProject => _activeProject;

  /// Updates [activeScore] and optionally emits a `ui.score.updated` IPC event.
  void setActiveScore(
    HierarchicalScore? score, {
    bool emitEvent = true,
  }) {
    _activeScore = score;
    if (emitEvent) {
      emitIpcEvent('ui.score.updated', {
        'hasActiveScore': score != null,
        'title': score?.title,
        'measuresCount': score?.measures.length ?? 0,
      });
    }
  }

  /// Updates [activeProject] and optionally emits a `workspace.project.updated` IPC event.
  void setActiveProject(
    TunnerProjectPackage? project, {
    bool emitEvent = true,
  }) {
    _activeProject = project;
    if (emitEvent) {
      emitIpcEvent('workspace.project.updated', {
        'hasActiveProject': project != null,
        'projectId': project?.projectId,
        'projectName': project?.projectName,
        'masterBpm': project?.masterBpm,
      });
    }
  }

  /// Safely forwards a live synchronization event to [onIpcEvent] when attached.
  void emitIpcEvent(String event, Map<String, dynamic> payload) {
    final callback = onIpcEvent;
    if (callback == null) return;
    try {
      callback(event, payload);
    } catch (e, st) {
      logger.warning(
        'TunnerHeadlessFacade',
        'IPC event callback threw while emitting "$event"',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Builds a deterministic telemetry snapshot for server status and health checks.
  Map<String, dynamic> getServerStatusSnapshot({
    int registeredResources = 0,
    int registeredTools = 0,
    int registeredPrompts = 0,
    List<String> registeredModules = const [],
    bool headlessOnly = true,
    int? ipcPort,
  }) {
    return {
      'status': _isDisposed ? 'disposed' : 'ready',
      'workspacePath': workspaceDirectory.path,
      'headlessOnly': headlessOnly,
      'ipcPort': ipcPort,
      'ipcAttached': onIpcEvent != null,
      'startedAtUtc': startedAtUtc.toIso8601String(),
      'uptimeMs': uptimeMs,
      'hasActiveScore': _activeScore != null,
      'activeScoreTitle': _activeScore?.title,
      'hasActiveProject': _activeProject != null,
      'activeProjectName': _activeProject?.projectName,
      'registeredCounts': {
        'resources': registeredResources,
        'tools': registeredTools,
        'prompts': registeredPrompts,
        'modules': registeredModules.length,
      },
      'registeredModules': registeredModules,
    };
  }

  /// Deterministically disposes the underlying [HeadlessCompositionRoot].
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    root.dispose();
  }
}
