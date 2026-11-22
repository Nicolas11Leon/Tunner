import '../core/audio/domain/ffi/i_native_dsp_bridge.dart';
import '../core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';
import '../core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../core/audio/infrastructure/studio_audio_engine.dart';
import '../core/audio/infrastructure/studio_audio_hardware_persistence_service.dart';
import '../core/audio/infrastructure/studio_audio_input_engine.dart';
import '../core/audio/infrastructure/studio_master_clock_service.dart';
import '../core/audio/infrastructure/studio_master_dsp_chain.dart';
import '../core/channels/data/studio_patchbay_routing_service.dart';
import '../core/design_system/data/studio_theme_catalog_service.dart';
import '../core/design_system/studio_theme_provider.dart';
import '../core/file_system/data/local_disk_studio_file_system_repository.dart';
import '../core/file_system/data/platform_file_gateway.dart';
import '../core/file_system/data/studio_workspace_file_system_service.dart';
import '../core/file_system/domain/i_platform_file_gateway.dart';
import '../core/logging/infrastructure/studio_debug_logger.dart';
import '../core/packaging/infrastructure/tunner_package_codec_service.dart';
import '../features/tuner_viewmodel.dart';
import '../features/tuner/data/pitch_detector_service.dart';
import '../features/metronome/data/metronome_service.dart';
import '../features/audio_synthesizer/data/audio_synthesizer_service.dart';
import '../features/audio_synthesizer/data/soundfont_synthesizer_service.dart';
import '../features/audio_synthesizer/data/stem_export_persistence_service.dart';
import '../features/persistence/data/json_local_persistence_service.dart';
import '../features/practice_recorder/data/audio_playback_service.dart';
import '../features/practice_recorder/data/practice_recorder_service.dart';
import '../features/universal_importer/data/universal_score_importer_service.dart';
import '../features/dj_console/presentation/dj_console_view_model.dart';
import '../features/dj_console/data/dj_deck_audio_service.dart';
import '../features/dj_console/data/dj_keymap_persistence_service.dart';
import '../features/media_vault/data/universal_media_io_service.dart';
import '../features/media_vault/presentation/media_vault_viewmodel.dart';
import '../features/modular_rack/presentation/modular_rack_viewmodel.dart';
import '../features/project_format/data/local_project_storage_repository.dart';
import '../features/vocal_autotune/data/local_vocal_take_file_gateway.dart';
import 'studio_workspace_seed_provider.dart';

/// Composition Root único de Tunner Studio.
/// Centraliza la instanciación e inyección de dependencias de infraestructura y dominio,
/// evitando acoplamientos directos en la capa de presentación y singletons globales en pruebas.
class StudioCompositionRoot {
  final IPlatformFileGateway platformFileGateway;
  final NativeDspFfiBridge nativeDspBridge;
  final StudioMasterDspChain masterDspChain;
  final StudioAudioEngine audioEngine;
  final StudioAudioInputEngine audioInputEngine;
  final StudioAudioDeviceMatrixService audioMatrixService;
  final StudioMasterClockService masterClockService;
  final StudioWorkspaceFileSystemService fileSystemService;
  final StudioPatchbayRoutingService patchbayService;
  final StudioThemeController themeController;
  final StudioThemeCatalogService themeCatalogService;

  StudioCompositionRoot._({
    required this.platformFileGateway,
    required this.nativeDspBridge,
    required this.masterDspChain,
    required this.audioEngine,
    required this.audioInputEngine,
    required this.audioMatrixService,
    required this.masterClockService,
    required this.fileSystemService,
    required this.patchbayService,
    required this.themeController,
    required this.themeCatalogService,
  });

  /// Construye un grafo completo de dependencias aislado y determinista.
  factory StudioCompositionRoot.create({
    IPlatformFileGateway? platformFileGateway,
    bool isolatedServices = true,
  }) {
    final fileGateway = platformFileGateway ?? const PlatformFileGateway();
    final dspBridge = NativeDspFfiBridge();
    final dspChain = StudioMasterDspChain(bridge: dspBridge);
    final outEngine = isolatedServices
        ? StudioAudioEngine.isolated()
        : StudioAudioEngine();
    final inEngine = StudioAudioInputEngine();
    final matrixService = StudioAudioDeviceMatrixService(
      outputEngine: outEngine,
      inputEngine: inEngine,
      persistenceService: StudioAudioHardwarePersistenceService(),
    );
    final clockService = StudioMasterClockService(initialBpm: 120.0);
    final diskRepo = LocalDiskStudioFileSystemRepository(
      seedProvider: const StudioWorkspaceSeedProvider(),
    );
    final fsService = isolatedServices
        ? StudioWorkspaceFileSystemService.isolated(fileSystemRepository: diskRepo)
        : StudioWorkspaceFileSystemService();
    final patchbay = isolatedServices
        ? StudioPatchbayRoutingService.isolated()
        : StudioPatchbayRoutingService();
    final themeCtrl = StudioThemeController();
    final themeCatalog = isolatedServices
        ? StudioThemeCatalogService.isolated(controller: themeCtrl)
        : StudioThemeCatalogService(controller: themeCtrl);

    return StudioCompositionRoot._(
      platformFileGateway: fileGateway,
      nativeDspBridge: dspBridge,
      masterDspChain: dspChain,
      audioEngine: outEngine,
      audioInputEngine: inEngine,
      audioMatrixService: matrixService,
      masterClockService: clockService,
      fileSystemService: fsService,
      patchbayService: patchbay,
      themeController: themeCtrl,
      themeCatalogService: themeCatalog,
    );
  }

  /// Crea el ViewModel principal con sus dependencias de infraestructura ya inyectadas.
  TunerViewModel createTunerViewModel({bool seedDefaults = true}) {
    return TunerViewModel(
      seedDefaults: seedDefaults,
      audioDeviceMatrixService: audioMatrixService,
      platformFileGateway: platformFileGateway,
      documentsDirectoryProvider: platformFileGateway.getDocumentsDirectoryPath,
      audioSynthesizerService: AudioSynthesizerService(audioEngine: audioEngine),
      playbackService: AudioPlaybackService(audioEngine: audioEngine),
      pitchService: PitchDetectorService(inputEngine: audioInputEngine),
      metronomeService: MetronomeService(),
      recorderService: PracticeRecorderService(),
      persistenceService: JsonLocalPersistenceService(
        documentsPathProvider: platformFileGateway.getDocumentsDirectoryPath,
      ),
      scoreImporterService: const UniversalScoreImporterService(),
      exportPersistenceService: StemExportPersistenceService(
        documentsPathProvider: platformFileGateway.getDocumentsDirectoryPath,
      ),
      soundFontSynthesizer: SoundFontSynthesizerService(),
      packageCodec: const TunnerPackageCodecService(),
      vocalTakeFileGateway: LocalVocalTakeFileGateway(
        platformFileGateway: platformFileGateway,
        logger: StudioDebugLogger.instance,
      ),
      logger: StudioDebugLogger.instance,
    );
  }

  /// Crea el ViewModel de la Consola DJ con motor de audio unificado inyectado.
  DjConsoleViewModel createDjConsoleViewModel() {
    return DjConsoleViewModel(
      deckAudioPlayer: DjDeckAudioService(audioEngine: audioEngine),
      audioSynthesizer: AudioSynthesizerService(audioEngine: audioEngine),
      fileSystemRepository: LocalDiskStudioFileSystemRepository(
        seedProvider: const StudioWorkspaceSeedProvider(),
      ),
      persistenceService: DjKeymapPersistenceService(),
      fileGateway: platformFileGateway,
    );
  }

  /// Crea el ViewModel de la Bóveda Multimedia con servicios de I/O inyectados.
  MediaVaultViewModel createMediaVaultViewModel() {
    return MediaVaultViewModel(
      ioService: const UniversalMediaIoService(),
      fileGateway: platformFileGateway,
      fileSystemRepository: fileSystemService.fileSystemRepository,
    );
  }

  /// Crea el ViewModel del Rack Modular con motores centralizados inyectados.
  ModularRackViewModel createModularRackViewModel() {
    return ModularRackViewModel(
      audioEngine: audioEngine,
      audioInputEngine: audioInputEngine,
      storageRepository: LocalProjectStorageRepository(),
    );
  }

  INativeDspBridge get dspBridge => nativeDspBridge;

  void dispose() {
    masterClockService.dispose();
    audioMatrixService.dispose();
    audioInputEngine.dispose();
    audioEngine.dispose();
    fileSystemService.dispose();
    patchbayService.dispose();
    themeController.dispose();
    nativeDspBridge.dispose();
  }
}
