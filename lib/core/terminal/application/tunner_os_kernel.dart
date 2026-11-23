import 'dart:async';
import '../../audio/domain/ffi/i_native_dsp_bridge.dart';
import '../../audio/domain/i_studio_audio_engine.dart';
import '../../audio/domain/i_studio_audio_input_engine.dart';
import '../../audio/domain/reverb/schroeder_reverb_engine.dart';
import '../../audio/domain/spatial/binaural_panner_engine.dart';
import '../../audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';
import '../../audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../../audio/infrastructure/studio_master_clock_service.dart';
import '../../audio/infrastructure/studio_master_dsp_chain.dart';
import '../../dsl/domain/i_synth_voice_pool_port.dart';
import '../../dsl/domain/studio_os_audio_kernel.dart';
import '../../dsl/domain/tunner_dsl_interpreter.dart';
import '../../dsl/domain/tunner_dsl_parser.dart';
import '../../dsl/infrastructure/studio_os_audio_kernel_bridge.dart';
import '../../file_system/domain/studio_file_system_repository.dart';
import '../domain/i_terminal_command_handler.dart';
import '../domain/i_terminal_feature_ports.dart';
import '../domain/tunner_os_command_entity.dart';
import 'handlers/audio_dsp_command_handler.dart';
import 'handlers/dj_media_command_handler.dart';
import 'handlers/fs_workspace_command_handler.dart';
import 'handlers/nav_theme_command_handler.dart';

/// Núcleo de interpretación de comandos y automatización del sistema Tunner OS.
/// Despacha comandos en tiempo constante $O(1)$ hacia manejadores modulares
/// que implementan [ITerminalCommandHandler], garantizando veracidad operativa.
class TunnerOsKernel {
  final void Function(int tabIndex)? onNavigateTab;
  final IStudioAudioEngine? outputEngine;
  final IStudioAudioInputEngine? inputEngine;
  final StudioFileSystemRepository? fileSystemRepository;
  final StudioAudioDeviceMatrixService? matrixService;
  final StudioMasterClockService? clockService;
  ISynthVoicePoolPort? _synthVoicePool;
  ITerminalScorePort? scorePlaybackCoordinator;
  ITerminalProjectPort? _projectPort;
  final void Function(String themeId)? onSetTheme;
  final void Function(String deckId, String trackTitle)? onDjLoadTrack;
  final void Function(String deckId)? onDjTogglePlay;
  final void Function(String deckId)? onDjPlayDeck;
  final void Function(String deckId)? onDjPauseDeck;
  final void Function(double val)? onDjSetCrossfader;
  Future<void> Function(int midiNote, double velocity)? onTriggerSynthNote;
  List<double> Function()? onReadCapturedFrequencies;
  List<double> Function()? onReadCapturedAmplitudes;
  SchroederReverbEngine? reverbEngine;
  BinauralPannerEngine? spatialEngine;
  ITerminalEarTrainingPort? earTrainingEngine;
  ITerminalVocalPedagogyPort? vocalEvaluator;
  INativeDspBridge? nativeDspBridge;
  StudioMasterDspChain? masterDspChain;
  StudioOsAudioKernel? audioKernel;
  final bool _ownsNativeDspBridge;
  final bool _ownsAudioKernel;
  late final StudioOsAudioKernelBridge kernelBridge;
  late final TunnerDslParser dslParser;
  late final TunnerDslInterpreter dslInterpreter;
  final Map<String, ITerminalCommandHandler> _handlers = {};

  ISynthVoicePoolPort? get synthVoicePool => _synthVoicePool;
  set synthVoicePool(ISynthVoicePoolPort? value) {
    _synthVoicePool = value;
    kernelBridge.synthVoicePool = value;
  }

  ITerminalProjectPort? get projectPort => _projectPort;
  set projectPort(ITerminalProjectPort? value) {
    _projectPort = value;
    kernelBridge.onBpmUpdate = value != null ? (bpm) => value.updateBpm(bpm.round()) : null;
  }

  TunnerOsKernel({
    this.onNavigateTab,
    this.outputEngine,
    this.inputEngine,
    this.fileSystemRepository,
    this.matrixService,
    this.clockService,
    ISynthVoicePoolPort? synthVoicePool,
    this.scorePlaybackCoordinator,
    ITerminalProjectPort? projectPort,
    this.onSetTheme,
    this.onDjLoadTrack,
    this.onDjTogglePlay,
    this.onDjPlayDeck,
    this.onDjPauseDeck,
    this.onDjSetCrossfader,
    this.onTriggerSynthNote,
    this.onReadCapturedFrequencies,
    this.onReadCapturedAmplitudes,
    SchroederReverbEngine? reverbEngine,
    BinauralPannerEngine? spatialEngine,
    this.earTrainingEngine,
    this.vocalEvaluator,
    INativeDspBridge? nativeDspBridge,
    StudioMasterDspChain? masterDspChain,
    StudioOsAudioKernel? audioKernel,
    List<ITerminalCommandHandler>? customHandlers,
  })  : _synthVoicePool = synthVoicePool,
        _projectPort = projectPort,
        _ownsNativeDspBridge = nativeDspBridge == null && masterDspChain == null,
        _ownsAudioKernel = audioKernel == null,
        reverbEngine = reverbEngine ?? SchroederReverbEngine(),
        spatialEngine = spatialEngine ?? BinauralPannerEngine(),
        nativeDspBridge = nativeDspBridge ?? (masterDspChain?.bridge ?? NativeDspFfiBridge()),
        audioKernel = audioKernel ?? StudioOsAudioKernel() {
    // Asegurar que masterDspChain reutilice exactamente la misma instancia cuando fue creada internamente.
    this.masterDspChain = masterDspChain ?? StudioMasterDspChain(bridge: this.nativeDspBridge);
    kernelBridge = StudioOsAudioKernelBridge(
      kernel: this.audioKernel!,
      matrixService: matrixService,
      synthVoicePool: _synthVoicePool,
      clockService: clockService,
      onBpmUpdate: _projectPort != null ? (bpm) => _projectPort!.updateBpm(bpm.round()) : null,
      reverbEngine: this.reverbEngine,
      spatialEngine: this.spatialEngine,
    );
    dslParser = TunnerDslParser();
    dslInterpreter = TunnerDslInterpreter(defaultKernel: this.audioKernel);

    _registerBuiltInHandlers();

    if (customHandlers != null) {
      for (final h in customHandlers) {
        registerHandler(h);
      }
    }
  }

  void _registerBuiltInHandlers() {
    registerHandler(
      AudioDspCommandHandler(
        getOutputEngine: () => outputEngine,
        getInputEngine: () => inputEngine,
        getMatrixService: () => matrixService,
        getClockService: () => clockService,
        getReverbEngine: () => reverbEngine,
        getSpatialEngine: () => spatialEngine,
        getNativeDspBridge: () => nativeDspBridge,
        getMasterDspChain: () => masterDspChain,
      ),
    );
    registerHandler(
      FsWorkspaceCommandHandler(
        getFileSystemRepository: () => fileSystemRepository,
        getProjectPort: () => _projectPort,
        getMatrixService: () => matrixService,
        getSynthVoicePool: () => _synthVoicePool,
        getEarTrainingEngine: () => earTrainingEngine,
        getVocalEvaluator: () => vocalEvaluator,
        getOnReadCapturedFrequencies: () => onReadCapturedFrequencies,
        getOnReadCapturedAmplitudes: () => onReadCapturedAmplitudes,
        getAudioKernel: () => audioKernel,
        getDslParser: () => dslParser,
        getDslInterpreter: () => dslInterpreter,
      ),
    );
    registerHandler(
      DjMediaCommandHandler(
        getOnDjLoadTrack: () => onDjLoadTrack,
        getOnDjTogglePlay: () => onDjTogglePlay,
        getOnDjPlayDeck: () => onDjPlayDeck,
        getOnDjPauseDeck: () => onDjPauseDeck,
        getOnDjSetCrossfader: () => onDjSetCrossfader,
        getSynthVoicePool: () => _synthVoicePool,
        getOnTriggerSynthNote: () => onTriggerSynthNote,
        getScorePlaybackCoordinator: () => scorePlaybackCoordinator,
      ),
    );
    registerHandler(
      NavThemeCommandHandler(
        getOnNavigateTab: () => onNavigateTab,
        getOnSetTheme: () => onSetTheme,
      ),
    );
  }

  /// Registra dinámicamente un manejador modular de comandos en el mapa $O(1)$.
  void registerHandler(ITerminalCommandHandler handler) {
    for (final domain in handler.supportedDomains) {
      _handlers[domain.toLowerCase()] = handler;
    }
  }

  /// Retorna el conjunto inmutable de dominios actualmente registrados en el despachador $O(1)$.
  Set<String> get registeredDomains => Set<String>.unmodifiable(_handlers.keys);

  /// Libera los recursos asociados al puente DSL, kernel de audio y puente DSP nativo propios.
  void dispose() {
    kernelBridge.dispose();
    if (_ownsAudioKernel) {
      audioKernel?.dispose();
    }
    if (_ownsNativeDspBridge) {
      final bridge = nativeDspBridge;
      if (bridge is NativeDspFfiBridge) {
        bridge.dispose();
      }
    }
  }

  /// Analiza y ejecuta una línea de comando de la terminal Tunner OS.
  Future<TunnerOsCommandResult> execute(String rawCommandLine) async {
    final line = rawCommandLine.trim();
    if (line.isEmpty) {
      return TunnerOsCommandResult.success('');
    }

    final tokens = _tokenize(line);
    if (tokens.isEmpty) {
      return TunnerOsCommandResult.success('');
    }

    final domain = tokens[0].toLowerCase();
    final args = tokens.sublist(1);

    final handler = _handlers[domain];
    if (handler != null) {
      return await handler.execute(domain, args, line);
    }

    return TunnerOsCommandResult.error(
      "Comando no reconocido: '$domain'. Escribe 'help' para ver la lista de comandos disponibles.",
    );
  }

  List<String> _tokenize(String input) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool insideQuotes = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"' || char == "'") {
        insideQuotes = !insideQuotes;
      } else if (char == ' ' && !insideQuotes) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(char);
      }
    }
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }
    return tokens;
  }
}
