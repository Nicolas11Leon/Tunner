import 'dart:async';
import 'dart:io';

import '../core/audio/domain/ffi/i_native_dsp_bridge.dart';
import '../core/audio/domain/i_studio_audio_device_matrix_service.dart';
import '../core/audio/domain/i_studio_audio_engine.dart';
import '../core/audio/domain/i_studio_audio_hardware_persistence_service.dart';
import '../core/audio/domain/i_studio_audio_input_engine.dart';
import '../core/audio/domain/i_studio_master_capture_service.dart';
import '../core/audio/domain/i_studio_master_clock_service.dart';
import '../core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';
import '../core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import '../core/audio/infrastructure/memory_studio_audio_engine.dart';
import '../core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import '../core/audio/infrastructure/memory_studio_master_capture_service.dart';
import '../core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../core/audio/infrastructure/studio_master_clock_service.dart';
import '../core/audio/infrastructure/studio_master_dsp_chain.dart';
import '../core/dsl/domain/studio_os_audio_kernel.dart';
import '../core/dsl/infrastructure/studio_os_audio_kernel_bridge.dart';
import '../core/file_system/data/local_disk_studio_file_system_repository.dart';
import '../core/file_system/data/posix_file_gateway.dart';
import '../core/file_system/domain/i_platform_file_gateway.dart';
import '../core/file_system/domain/i_workspace_seed_provider.dart';
import '../core/file_system/domain/studio_file_system_repository.dart';
import '../core/logging/domain/i_studio_logger.dart';
import '../core/logging/infrastructure/studio_stderr_logger.dart';
import '../core/terminal/application/tunner_os_kernel.dart';
import '../features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import '../features/audio_synthesizer/data/stem_export_persistence_service.dart';
import '../features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import '../features/audio_synthesizer/domain/i_stem_export_persistence_service.dart';
import '../features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import '../features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import '../features/dj_console/data/headless_dj_console_blueprint_storage_service.dart';
import '../features/dj_console/data/headless_dj_keymap_persistence_service.dart';
import '../features/persistence/data/atomic_json_file_persistence_service.dart';
import '../features/persistence/domain/i_local_persistence_service.dart';
import '../features/project_format/data/local_project_storage_repository.dart';
import '../features/score_editor/presentation/score_editor_controller.dart';
import '../features/sheet_music/domain/score_playback_coordinator.dart';
import '../features/song_library/domain/song_decomposer_service.dart';
import '../features/universal_importer/data/universal_score_importer_service.dart';
import 'headless_terminal_feature_adapters.dart';

/// Composition Root 100% Pure Dart para ejecucion headless (CLI, servidores MCP y pruebas).
///
/// Ensambla e inyecta el nucleo completo de Tunner Studio sin ninguna dependencia directa
/// ni transitiva de `package:flutter/`, `dart:ui`, `path_provider`, `file_picker`,
/// `audioplayers` ni `record`.
class HeadlessCompositionRoot {
  final Directory workspaceDirectory;
  final IStudioLogger logger;
  final IPlatformFileGateway platformFileGateway;
  final ILocalPersistenceService persistenceService;
  final INativeDspBridge nativeDspBridge;
  final StudioMasterDspChain masterDspChain;
  final IStudioAudioEngine audioEngine;
  final IStudioAudioInputEngine audioInputEngine;
  final IStudioAudioDeviceMatrixService audioMatrixService;
  final IStudioMasterClockService masterClockService;
  final StudioFileSystemRepository fileSystemRepository;
  final PolyphonicVoicePool synthVoicePool;
  final ScorePlaybackCoordinator scorePlaybackCoordinator;
  final StudioOsAudioKernel audioKernel;
  final TunnerOsKernel terminalKernel;
  final UniversalScoreImporterService scoreImporterService;
  final IAudioSynthesizerService audioSynthesizerService;
  final IStemExportPersistenceService exportPersistenceService;
  final ScoreEditorController scoreEditorController;
  final LocalProjectStorageRepository projectStorageRepository;
  final SongDecomposerService songDecomposerService;
  final HeadlessDjConsoleBlueprintStorageService djBlueprintStorageService;
  final HeadlessDjKeymapPersistenceService djKeymapPersistenceService;
  final ScorePlaybackTerminalAdapter scoreTerminalAdapter;
  final EbbinghausTerminalAdapter earTrainingTerminalAdapter;
  final VocalPedagogyTerminalAdapter vocalPedagogyTerminalAdapter;

  final bool _ownsNativeDspBridge;
  bool _isDisposed = false;

  /// Puente DSL-audio enlazado al [terminalKernel].
  StudioOsAudioKernelBridge get kernelBridge => terminalKernel.kernelBridge;

  /// Indica si el grafo ya fue liberado mediante [dispose].
  bool get isDisposed => _isDisposed;

  HeadlessCompositionRoot._({
    required this.workspaceDirectory,
    required this.logger,
    required this.platformFileGateway,
    required this.persistenceService,
    required this.nativeDspBridge,
    required this.masterDspChain,
    required this.audioEngine,
    required this.audioInputEngine,
    required this.audioMatrixService,
    required this.masterClockService,
    required this.fileSystemRepository,
    required this.synthVoicePool,
    required this.scorePlaybackCoordinator,
    required this.audioKernel,
    required this.terminalKernel,
    required this.scoreImporterService,
    required this.audioSynthesizerService,
    required this.exportPersistenceService,
    required this.scoreEditorController,
    required this.projectStorageRepository,
    required this.songDecomposerService,
    required this.djBlueprintStorageService,
    required this.djKeymapPersistenceService,
    required this.scoreTerminalAdapter,
    required this.earTrainingTerminalAdapter,
    required this.vocalPedagogyTerminalAdapter,
    required bool ownsNativeDspBridge,
  }) : _ownsNativeDspBridge = ownsNativeDspBridge;

  /// Construye un grafo completo de dependencias Pure Dart aislado sobre [workspaceDirectory].
  factory HeadlessCompositionRoot({
    required Directory workspaceDirectory,
    IStudioLogger logger = StudioStderrLogger.instance,
    IPlatformFileGateway? platformFileGateway,
    ILocalPersistenceService? persistenceService,
    INativeDspBridge? nativeDspBridge,
    IStudioAudioEngine? audioEngine,
    IStudioAudioInputEngine? audioInputEngine,
    IStudioAudioHardwarePersistenceService? hardwarePersistenceService,
    IStudioMasterCaptureService? masterCaptureService,
    IStudioAudioDeviceMatrixService? audioMatrixService,
    IStudioMasterClockService? masterClockService,
    StudioFileSystemRepository? fileSystemRepository,
    IWorkspaceSeedProvider? workspaceSeedProvider,
    double initialBpm = 120.0,
    void Function()? onScoreEditorNotify,
  }) {
    final fileGateway = platformFileGateway ??
        PosixFileGateway(rootDirectory: workspaceDirectory);
    final localPersistence = persistenceService ??
        AtomicJsonFilePersistenceService(
          directory: workspaceDirectory,
          logger: logger,
        );

    final ownsBridge = nativeDspBridge == null;
    final dspBridge = nativeDspBridge ?? NativeDspFfiBridge();
    final dspChain = StudioMasterDspChain(bridge: dspBridge);

    final outEngine = audioEngine ?? MemoryStudioAudioEngine();
    final inEngine = audioInputEngine ?? MemoryStudioAudioInputEngine();
    final matrix = audioMatrixService ??
        StudioAudioDeviceMatrixService(
          outputEngine: outEngine,
          inputEngine: inEngine,
          persistenceService:
              hardwarePersistenceService ?? MemoryAudioHardwarePersistenceService(),
          captureService:
              masterCaptureService ?? MemoryStudioMasterCaptureService(),
          logger: logger,
          headless: true,
        );
    final clock =
        masterClockService ?? StudioMasterClockService(initialBpm: initialBpm);

    final fsRepo = fileSystemRepository ??
        LocalDiskStudioFileSystemRepository(
          customRootPath: workspaceDirectory.path,
          seedProvider: workspaceSeedProvider,
          logger: logger,
        );

    final voicePool = PolyphonicVoicePool();
    final playbackCoordinator = ScorePlaybackCoordinator(
      voicePool: voicePool,
      initialBpm: initialBpm,
    );

    final scoreAdapter = ScorePlaybackTerminalAdapter(playbackCoordinator);
    final earTrainingAdapter = EbbinghausTerminalAdapter();
    final vocalPedagogyAdapter = const VocalPedagogyTerminalAdapter();

    final dslAudioKernel = StudioOsAudioKernel();
    final osKernel = TunnerOsKernel(
      outputEngine: outEngine,
      inputEngine: inEngine,
      fileSystemRepository: fsRepo,
      matrixService: matrix,
      clockService: clock,
      synthVoicePool: voicePool,
      scorePlaybackCoordinator: scoreAdapter,
      earTrainingEngine: earTrainingAdapter,
      vocalEvaluator: vocalPedagogyAdapter,
      nativeDspBridge: dspBridge,
      masterDspChain: dspChain,
      audioKernel: dslAudioKernel,
    );

    final scoreImporter = UniversalScoreImporterService(logger: logger);
    final synthService = MemoryAudioSynthesizerService();
    final stemExportService = StemExportPersistenceService(
      documentsPathProvider: fileGateway.getDocumentsDirectoryPath,
    );
    final scoreEditor = ScoreEditorController(
      audioSynthesizer: synthService,
      scoreImporterService: scoreImporter,
      stemSynthesizer: const StemAudioSynthesizer(),
      exportPersistenceService: stemExportService,
      logger: logger,
      onNotify: onScoreEditorNotify ?? () {},
    );

    final projectStorage = LocalProjectStorageRepository();
    const songDecomposer = SongDecomposerService();
    final djBlueprints = HeadlessDjConsoleBlueprintStorageService(
      rootDirectory: workspaceDirectory,
      logger: logger,
    );
    final djKeymaps = HeadlessDjKeymapPersistenceService(
      rootDirectory: workspaceDirectory,
      logger: logger,
    );

    return HeadlessCompositionRoot._(
      workspaceDirectory: workspaceDirectory,
      logger: logger,
      platformFileGateway: fileGateway,
      persistenceService: localPersistence,
      nativeDspBridge: dspBridge,
      masterDspChain: dspChain,
      audioEngine: outEngine,
      audioInputEngine: inEngine,
      audioMatrixService: matrix,
      masterClockService: clock,
      fileSystemRepository: fsRepo,
      synthVoicePool: voicePool,
      scorePlaybackCoordinator: playbackCoordinator,
      audioKernel: dslAudioKernel,
      terminalKernel: osKernel,
      scoreImporterService: scoreImporter,
      audioSynthesizerService: synthService,
      exportPersistenceService: stemExportService,
      scoreEditorController: scoreEditor,
      projectStorageRepository: projectStorage,
      songDecomposerService: songDecomposer,
      djBlueprintStorageService: djBlueprints,
      djKeymapPersistenceService: djKeymaps,
      scoreTerminalAdapter: scoreAdapter,
      earTrainingTerminalAdapter: earTrainingAdapter,
      vocalPedagogyTerminalAdapter: vocalPedagogyAdapter,
      ownsNativeDspBridge: ownsBridge,
    );
  }

  /// Libera de forma determinista todos los servicios, streams y temporizadores
  /// del grafo headless sin dejar recursos ni timers pendientes.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    terminalKernel.dispose();
    audioKernel.dispose();
    scorePlaybackCoordinator.dispose();
    masterClockService.dispose();
    audioMatrixService.dispose();
    audioSynthesizerService.dispose();
    audioInputEngine.dispose();
    unawaited(audioEngine.dispose());
    masterDspChain.dispose();
    if (_ownsNativeDspBridge) {
      final bridge = nativeDspBridge;
      if (bridge is NativeDspFfiBridge) {
        bridge.dispose();
      }
    }
  }
}
