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
import '../core/file_system/data/platform_file_gateway.dart';
import '../core/file_system/data/studio_workspace_file_system_service.dart';
import '../core/file_system/domain/i_platform_file_gateway.dart';
import '../features/tuner_viewmodel.dart';

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
    final fsService = isolatedServices
        ? StudioWorkspaceFileSystemService.isolated()
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
