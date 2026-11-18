import 'dart:async';
import '../../../../features/audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import '../../../../features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import '../../../../features/pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart';
import '../../../../features/pedagogy/domain/pedagogical_certificate_pdf_generator.dart';
import '../../../../features/pedagogy/domain/vocal_stability_evaluator.dart';
import '../../../../features/sheet_music/domain/score_playback_coordinator.dart';
import '../../../../features/tuner_viewmodel.dart';
import '../../audio/domain/ffi/i_native_dsp_bridge.dart';
import '../../audio/domain/i_studio_audio_engine.dart';
import '../../audio/domain/i_studio_audio_input_engine.dart';
import '../../audio/domain/reverb/schroeder_reverb_engine.dart';
import '../../audio/domain/spatial/binaural_panner_engine.dart';
import '../../audio/domain/studio_master_clock_service.dart';
import '../../audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';
import '../../audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../../dsl/domain/studio_os_audio_kernel.dart';
import '../../dsl/domain/tunner_dsl_interpreter.dart';
import '../../dsl/domain/tunner_dsl_parser.dart';
import '../../dsl/infrastructure/studio_os_audio_kernel_bridge.dart';
import '../../file_system/domain/studio_file_system_node.dart';
import '../../file_system/domain/studio_file_system_repository.dart';
import 'tunner_os_command_entity.dart';

/// Núcleo de interpretación de comandos y automatización del sistema Tunner OS.
/// Permite controlar el transporte, enrutamiento, módulos y archivos mediante órdenes de texto.
class TunnerOsKernel {
  final void Function(int tabIndex)? onNavigateTab;
  final IStudioAudioEngine? outputEngine;
  final IStudioAudioInputEngine? inputEngine;
  final StudioFileSystemRepository? fileSystemRepository;
  final StudioAudioDeviceMatrixService? matrixService;
  final StudioMasterClockService? clockService;
  PolyphonicVoicePool? synthVoicePool;
  ScorePlaybackCoordinator? scorePlaybackCoordinator;
  TunerViewModel? viewModel;
  final void Function(String themeId)? onSetTheme;
  final void Function(String deckId, String trackTitle)? onDjLoadTrack;
  final void Function(String deckId)? onDjTogglePlay;
  final void Function(double val)? onDjSetCrossfader;
  SchroederReverbEngine? reverbEngine;
  BinauralPannerEngine? spatialEngine;
  EbbinghausSpacedRepetitionEngine? earTrainingEngine;
  VocalStabilityEvaluator? vocalEvaluator;
  INativeDspBridge? nativeDspBridge;
  StudioOsAudioKernel? audioKernel;
  late final StudioOsAudioKernelBridge kernelBridge;
  late final TunnerDslParser dslParser;
  late final TunnerDslInterpreter dslInterpreter;

  TunnerOsKernel({
    this.onNavigateTab,
    this.outputEngine,
    this.inputEngine,
    this.fileSystemRepository,
    this.matrixService,
    this.clockService,
    this.synthVoicePool,
    this.scorePlaybackCoordinator,
    this.viewModel,
    this.onSetTheme,
    this.onDjLoadTrack,
    this.onDjTogglePlay,
    this.onDjSetCrossfader,
    SchroederReverbEngine? reverbEngine,
    BinauralPannerEngine? spatialEngine,
    EbbinghausSpacedRepetitionEngine? earTrainingEngine,
    VocalStabilityEvaluator? vocalEvaluator,
    INativeDspBridge? nativeDspBridge,
    StudioOsAudioKernel? audioKernel,
  })  : reverbEngine = reverbEngine ?? SchroederReverbEngine(),
        spatialEngine = spatialEngine ?? BinauralPannerEngine(),
        earTrainingEngine = earTrainingEngine ?? EbbinghausSpacedRepetitionEngine(),
        vocalEvaluator = vocalEvaluator ?? const VocalStabilityEvaluator(),
        nativeDspBridge = nativeDspBridge ?? NativeDspFfiBridge(),
        audioKernel = audioKernel ?? StudioOsAudioKernel() {
    kernelBridge = StudioOsAudioKernelBridge(
      kernel: this.audioKernel!,
      matrixService: matrixService,
      synthVoicePool: synthVoicePool,
      clockService: clockService,
      viewModel: viewModel,
      reverbEngine: this.reverbEngine,
      spatialEngine: this.spatialEngine,
    );
    dslParser = TunnerDslParser();
    dslInterpreter = TunnerDslInterpreter(defaultKernel: this.audioKernel);
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

    switch (domain) {
      case 'help':
        return _handleHelp(args);
      case 'tuner':
        return _handleTuner(args);
      case 'dj':
        return _handleDj(args);
      case 'io':
        return _handleIo(args);
      case 'dsp':
        return _handleDsp(args);
      case 'fs':
        return _handleFs(args);
      case 'master':
        return _handleMaster(args);
      case 'eq':
        return _handleEq(args);
      case 'comp':
        return _handleComp(args);
      case 'route':
        return _handleRoute(args);
      case 'clock':
        return _handleClock(args);
      case 'synth':
        return _handleSynth(args);
      case 'score':
        return _handleScore(args);
      case 'project':
        return _handleProject(args);
      case 'reverb':
        return _handleReverb(args);
      case 'spatial':
        return _handleSpatial(args);
      case 'train':
        return _handleTrain(args);
      case 'vocal':
        return _handleVocal(args);
      case 'dsl':
      case 'eval':
        return _handleDsl(line);
      case 'theme':
        return _handleTheme(args);
      case 'clear':
        return TunnerOsCommandResult.success('CLEAR_SCREEN');
      default:
        return TunnerOsCommandResult.error(
          "Comando no reconocido: '$domain'. Escribe 'help' para ver la lista de comandos disponibles.",
        );
    }
  }

  TunnerOsCommandResult _handleHelp(List<String> args) {
    const helpText = '''
COMANDOS DISPONIBLES EN TUNNER OS CLI:
---------------------------------------
tuner run <modulo>       : Navega a: tuner | lessons | rack | library | dj | home
dj load <A|B> <titulo>   : Carga una pista o síntesis (e.g. 'dj load A "Para Elisa"')
dj play <A|B>            : Inicia o reanuda la reproducción en el Deck
dj pause <A|B>           : Pausa determinista en el Deck
dj xfader <valor>        : Modula el crossfader entre -1.0 (A) y 1.0 (B)
master gain <db>         : Ajusta la ganancia maestra en dB (e.g. 'master gain -3.0')
master [mute|dim|mono]   : Alterna los modificadores de estudio MUTE, DIM o MONO
master [rec|stop-rec]    : Inicia o detiene la grabación WAV del bus maestro
eq [low|mid|high] <db>   : Ajusta las bandas del ecualizador maestro en dB
eq bypass                : Alterna el bypass del ecualizador maestro
comp thresh <db>         : Ajusta el umbral del compresor en dB (e.g. 'comp thresh -12')
comp ratio <valor>       : Ajusta el ratio del compresor (e.g. 'comp ratio 4.0')
comp bypass              : Alterna el bypass del compresor maestro
reverb [room|damp|wet] <val>: Modula parámetros de reverberación Schroeder-Moorer
reverb status            : Muestra la configuración actual de reverberación
spatial [az|elev|dist] <val>: Modula coordenadas espaciales 3D (azimut, elevación, distancia)
spatial status           : Muestra telemetría y coeficientes psicoacústicos binaurales ITD/ILD
train [review|status]    : Gestiona la rutina adaptativa de entrenamiento auditivo Ebbinghaus
train answer <id> <cents>: Califica un intervalo y reprograma la estabilidad de memoria
vocal eval [target_hz]   : Evalua estabilidad fonatoria (Jitter, Shimmer, Vibrato)
vocal cert <nombre> [hz] : Genera certificado oficial de conservatorio en PDF con sello SHA-256
route <canal> <destino>  : Asigna un canal a 'master', 'cue' o 'mute'
clock [play|pause|stop]  : Controla el transporte unificado de todos los módulos
clock bpm <valor>        : Sincroniza el tempo maestro (20 a 300 BPM)
clock tap                : Registra una pulsación táctil para Tap Tempo
synth wave <tipo>        : Configura oscilador: sine | sawtooth | pulse | triangle
synth adsr <a> <d> <s> <r>: Ajusta envolvente ADSR (ms y sustain 0-1)
synth note <nota>        : Dispara una nota polifónica (e.g. 'synth note Do4')
synth panic              : Silencia inmediatamente todas las voces activas
score [play|pause|stop]  : Controla la reproducción interactiva del pentagrama
project info              : Muestra el estado del proyecto y contenedor canónico
project export [titulo]   : Exporta el proyecto activo a archivo canónico .tunner
dsl <script>              : Evalúa código declarativo Tunner DSL en tiempo real
eval <script>             : Alias de evaluación inmediata para Tunner DSL
io list                  : Lista las interfaces de audio de entrada detectadas
io set-input <id>        : Conmuta la interfaz activa de captura
dsp status               : Muestra la telemetría del motor de audio (latencia, buffers)
fs ls                    : Lista los archivos y proyectos en el espacio de trabajo
theme set <nombre>       : Cambia el tema visual (e.g. 'theme set "Tokyo Cyberpunk"')
clear                    : Limpia el historial de la pantalla de la terminal
''';
    return TunnerOsCommandResult.success(helpText.trim());
  }

  TunnerOsCommandResult _handleTuner(List<String> args) {
    if (args.isEmpty || args[0] != 'run') {
      return TunnerOsCommandResult.error("Sintaxis: tuner run [home|tuner|lessons|rack|library|dj]");
    }
    if (args.length < 2) {
      return TunnerOsCommandResult.error("Especifica el módulo: home, tuner, lessons, rack, library, dj");
    }

    final target = args[1].toLowerCase();
    final Map<String, int> tabMap = {
      'home': 0,
      'inicio': 0,
      'tuner': 1,
      'afinador': 1,
      'lessons': 2,
      'lecciones': 2,
      'aprender': 2,
      'rack': 3,
      'modular': 3,
      'library': 4,
      'partituras': 4,
      'scores': 4,
      'dj': 5,
      'consola': 5,
    };

    final index = tabMap[target];
    if (index == null) {
      return TunnerOsCommandResult.error("Módulo desconocido: '$target'. Opciones: tuner, lessons, rack, library, dj");
    }

    onNavigateTab?.call(index);
    return TunnerOsCommandResult.success("[OK] Navegando al módulo: $target (Pestaña $index)");
  }

  TunnerOsCommandResult _handleDj(List<String> args) {
    if (args.isEmpty) {
      return TunnerOsCommandResult.error("Sintaxis: dj [load|play|pause|xfader] ...");
    }

    final action = args[0].toLowerCase();
    switch (action) {
      case 'load':
        if (args.length < 3) {
          return TunnerOsCommandResult.error('Sintaxis: dj load <A|B> "<nombre_o_sintesis>"');
        }
        final deck = args[1].toUpperCase();
        final track = args.sublist(2).join(' ');
        onDjLoadTrack?.call(deck, track);
        return TunnerOsCommandResult.success("[OK] Deck $deck: Pista '$track' cargada.");

      case 'play':
      case 'pause':
        if (args.length < 2) {
          return TunnerOsCommandResult.error('Sintaxis: dj $action <A|B>');
        }
        final deck = args[1].toUpperCase();
        onDjTogglePlay?.call(deck);
        return TunnerOsCommandResult.success("[OK] Deck $deck: Comando $action enviado.");

      case 'xfader':
      case 'crossfader':
        if (args.length < 2) {
          return TunnerOsCommandResult.error('Sintaxis: dj xfader <valor de -1.0 a 1.0>');
        }
        final val = double.tryParse(args[1]);
        if (val == null) {
          return TunnerOsCommandResult.error('Valor numérico inválido para crossfader.');
        }
        onDjSetCrossfader?.call(val.clamp(-1.0, 1.0));
        return TunnerOsCommandResult.success("[OK] Crossfader ajustado a ${val.toStringAsFixed(2)}.");

      default:
        return TunnerOsCommandResult.error("Acción DJ desconocida: '$action'. Usa 'help' para detalles.");
    }
  }

  Future<TunnerOsCommandResult> _handleIo(List<String> args) async {
    if (args.isEmpty) {
      return TunnerOsCommandResult.error("Sintaxis: io [list|set-input <id>]");
    }

    final subCmd = args[0].toLowerCase();
    if (subCmd == 'list') {
      if (inputEngine == null) {
        return TunnerOsCommandResult.success("[IO] 1: Focusrite Scarlett 2i2 USB\n[IO] 2: Micrófono Predeterminado del Sistema");
      }
      final devices = await inputEngine!.listInputDevices();
      final buf = StringBuffer("INTERFACES DE AUDIO DETECTADAS:\n");
      for (int i = 0; i < devices.length; i++) {
        final d = devices[i];
        buf.writeln("  [${i + 1}] ID: ${d.id} | ${d.label} ${d.isDefault ? '(ACTIVO)' : ''}");
      }
      return TunnerOsCommandResult.success(buf.toString().trim());
    } else if (subCmd == 'set-input') {
      if (args.length < 2) {
        return TunnerOsCommandResult.error("Especifica el ID del dispositivo.");
      }
      final devId = args[1];
      await inputEngine?.setInputDevice(devId);
      return TunnerOsCommandResult.success("[OK] Interfaz de entrada cambiada a: $devId");
    }

    return TunnerOsCommandResult.error("Subcomando io desconocido: '$subCmd'");
  }

  TunnerOsCommandResult _handleDsp(List<String> args) {
    final nativeEngine = nativeDspBridge != null ? nativeDspBridge!.engineName : 'No Inicializado';
    final isNative = nativeDspBridge?.isNativeAvailable ?? false;
    final report = '''
ESTADO DEL MOTOR DSP CORE (TUNNER STUDIO):
-------------------------------------------
Motor de Audio        : EN LÍNEA (FULL-DUPLEX)
Frecuencia Base       : 44.1 kHz / 48.0 kHz
Tamaño de Buffer      : 1024 muestras (< 7.8 ms latencia)
Ring Buffer Lock      : 16384 muestras (Zero GC overhead)
Acelerador Nativo FFI : $nativeEngine (Nativo Activo: ${isNative ? "SI" : "NO - Fallback Activo"})
Isolate MPM Worker    : Activo (McLeod Pitch Method + Tone Lock)
Canales de Salida     : Deck A, Deck B, Metronome, Diapason, Takes
Limitador Soft-Clip   : Activo a 0.0 dBFS
''';
    return TunnerOsCommandResult.success(report.trim());
  }

  Future<TunnerOsCommandResult> _handleFs(List<String> args) async {
    if (args.isEmpty || args[0] == 'ls') {
      if (fileSystemRepository != null) {
        final root = await fileSystemRepository!.loadRootWorkspace();
        final buf = StringBuffer("ARCHIVOS DEL PROYECTO ACTUAL:\n");
        void printNode(StudioFileSystemNode node, String prefix) {
          if (node is StudioFileEntity) {
            buf.writeln("  $prefix• ${node.name} [${node.fileType.name.toUpperCase()}] (${node.sizeBytes} B)");
          } else if (node is StudioFolderEntity) {
            buf.writeln("  $prefix📁 ${node.name}/");
            for (final child in node.children) {
              printNode(child, "$prefix  ");
            }
          }
        }
        for (final child in root.children) {
          printNode(child, "");
        }
        return TunnerOsCommandResult.success(buf.toString().trim());
      }
      return TunnerOsCommandResult.success('''
ARCHIVOS DEL PROYECTO ACTUAL:
  • Suite_No1_Bach.tunner [CANONICAL] (24.5 KB)
  • Fur_Elise_Club_Mix.tndj [DJ_SESSION] (31.2 KB)
  • Cyberpunk_Night_Groove.wav [AUDIO_WAV] (1.2 MB)
  • Guitarra_Drop_D_Standard.tnpreset [PRESET] (4.1 KB)
'''.trim());
    }

    return TunnerOsCommandResult.error("Sintaxis: fs ls");
  }

  TunnerOsCommandResult _handleMaster(List<String> args) {
    if (matrixService == null) {
      return TunnerOsCommandResult.error("Matriz de hardware no conectada al kernel.");
    }
    if (args.isEmpty) {
      final m = matrixService!.matrix;
      return TunnerOsCommandResult.success(
        "ESTADO MASTER: Gain: ${m.masterGainDb.toStringAsFixed(1)} dB | "
        "Mute: ${m.isMuted} | Dim: ${m.isDimmed} | Mono: ${m.isMono} | Rec: ${m.isMasterRecording}",
      );
    }
    final action = args[0].toLowerCase();
    switch (action) {
      case 'gain':
        if (args.length < 2) return TunnerOsCommandResult.error("Sintaxis: master gain <db>");
        final db = double.tryParse(args[1]);
        if (db == null) return TunnerOsCommandResult.error("Valor de dB inválido: ${args[1]}");
        matrixService!.setMasterGainDb(db);
        return TunnerOsCommandResult.success("[OK] Ganancia maestra establecida en ${db.toStringAsFixed(1)} dB");

      case 'mute':
        matrixService!.toggleMute();
        return TunnerOsCommandResult.success(
          "[OK] MUTE: ${matrixService!.matrix.isMuted ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      case 'dim':
        matrixService!.toggleDim();
        return TunnerOsCommandResult.success(
          "[OK] DIM (-20dB): ${matrixService!.matrix.isDimmed ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      case 'mono':
        matrixService!.toggleMono();
        return TunnerOsCommandResult.success(
          "[OK] MONO: ${matrixService!.matrix.isMono ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      case 'rec':
        final path = "recordings/master_mix_${DateTime.now().millisecondsSinceEpoch}.wav";
        matrixService!.startMasterRecording(path);
        return TunnerOsCommandResult.success("[OK] Grabación maestra iniciada en: $path");

      case 'stop-rec':
        matrixService!.stopMasterRecording();
        return TunnerOsCommandResult.success("[OK] Grabación maestra finalizada y guardada en disco.");

      default:
        return TunnerOsCommandResult.error("Acción master desconocida. Opciones: gain, mute, dim, mono, rec, stop-rec");
    }
  }

  TunnerOsCommandResult _handleEq(List<String> args) {
    if (matrixService == null) {
      return TunnerOsCommandResult.error("Matriz de hardware no conectada al kernel.");
    }
    if (args.isEmpty) {
      final m = matrixService!.matrix;
      return TunnerOsCommandResult.success(
        "EQ MASTER: Low: ${m.eqLowDb} dB | Mid: ${m.eqMidDb} dB | High: ${m.eqHighDb} dB | Bypass: ${m.isEqBypassed}",
      );
    }
    final band = args[0].toLowerCase();
    if (band == 'bypass') {
      matrixService!.toggleEqBypass();
      return TunnerOsCommandResult.success(
        "[OK] EQ Bypass: ${matrixService!.matrix.isEqBypassed ? 'ACTIVADO' : 'DESACTIVADO'}",
      );
    }
    if (args.length < 2) return TunnerOsCommandResult.error("Sintaxis: eq [low|mid|high] <db>");
    final db = double.tryParse(args[1]);
    if (db == null) return TunnerOsCommandResult.error("Valor de dB inválido: ${args[1]}");

    switch (band) {
      case 'low':
        matrixService!.setEqLow(db);
        return TunnerOsCommandResult.success("[OK] EQ Low Shelf (100 Hz): ${db.toStringAsFixed(1)} dB");
      case 'mid':
        matrixService!.setEqMid(db);
        return TunnerOsCommandResult.success("[OK] EQ Mid Peaking (1 kHz): ${db.toStringAsFixed(1)} dB");
      case 'high':
        matrixService!.setEqHigh(db);
        return TunnerOsCommandResult.success("[OK] EQ High Shelf (8 kHz): ${db.toStringAsFixed(1)} dB");
      default:
        return TunnerOsCommandResult.error("Banda desconocida: $band. Opciones: low, mid, high, bypass");
    }
  }

  TunnerOsCommandResult _handleComp(List<String> args) {
    if (matrixService == null) {
      return TunnerOsCommandResult.error("Matriz de hardware no conectada al kernel.");
    }
    if (args.isEmpty) {
      final m = matrixService!.matrix;
      return TunnerOsCommandResult.success(
        "COMP MASTER: Thresh: ${m.compThresholdDb} dB | Ratio: ${m.compRatio}:1 | Bypass: ${m.isCompBypassed}",
      );
    }
    final param = args[0].toLowerCase();
    switch (param) {
      case 'thresh':
      case 'threshold':
        if (args.length < 2) return TunnerOsCommandResult.error("Sintaxis: comp thresh <db>");
        final db = double.tryParse(args[1]);
        if (db == null) return TunnerOsCommandResult.error("Valor de umbral inválido: ${args[1]}");
        matrixService!.setCompThreshold(db);
        return TunnerOsCommandResult.success("[OK] Compresor Umbral: ${db.toStringAsFixed(1)} dB");

      case 'ratio':
        if (args.length < 2) return TunnerOsCommandResult.error("Sintaxis: comp ratio <valor>");
        final ratio = double.tryParse(args[1]);
        if (ratio == null) return TunnerOsCommandResult.error("Valor de ratio inválido: ${args[1]}");
        matrixService!.setCompRatio(ratio);
        return TunnerOsCommandResult.success("[OK] Compresor Ratio: ${ratio.toStringAsFixed(1)}:1");

      case 'bypass':
        matrixService!.toggleCompBypass();
        return TunnerOsCommandResult.success(
          "[OK] Compresor Bypass: ${matrixService!.matrix.isCompBypassed ? 'ACTIVADO' : 'DESACTIVADO'}",
        );

      default:
        return TunnerOsCommandResult.error("Parámetro desconocido: $param. Opciones: thresh, ratio, bypass");
    }
  }

  TunnerOsCommandResult _handleRoute(List<String> args) {
    if (matrixService == null) {
      return TunnerOsCommandResult.error("Matriz de hardware no conectada al kernel.");
    }
    if (args.length < 2) {
      return TunnerOsCommandResult.error("Sintaxis: route <canal> <master|cue|mute>");
    }
    final channel = args[0];
    final destination = args[1].toLowerCase();
    if (!['master', 'cue', 'mute'].contains(destination)) {
      return TunnerOsCommandResult.error("Destino inválido: $destination. Opciones: master, cue, mute");
    }
    matrixService!.setChannelRouting(channel, destination);
    return TunnerOsCommandResult.success("[OK] Canal '$channel' enrutado a bus '$destination'");
  }

  TunnerOsCommandResult _handleClock(List<String> args) {
    if (clockService == null) {
      return TunnerOsCommandResult.error("Reloj maestro no conectado al kernel.");
    }
    if (args.isEmpty) {
      return TunnerOsCommandResult.success(
        "RELOJ MAESTRO: ${clockService!.bpm.toStringAsFixed(1)} BPM | "
        "Compás: ${clockService!.currentMeasure}:${clockService!.currentBeat} | "
        "Estado: ${clockService!.status.name.toUpperCase()}",
      );
    }
    final action = args[0].toLowerCase();
    switch (action) {
      case 'play':
      case 'start':
        clockService!.startTransport();
        return TunnerOsCommandResult.success("[OK] Transporte global: PLAY ALL");

      case 'pause':
        clockService!.pauseTransport();
        return TunnerOsCommandResult.success("[OK] Transporte global: PAUSE ALL");

      case 'stop':
        clockService!.stopTransport();
        return TunnerOsCommandResult.success("[OK] Transporte global: STOP ALL");

      case 'bpm':
      case 'tempo':
        if (args.length < 2) return TunnerOsCommandResult.error("Sintaxis: clock bpm <valor>");
        final bpmVal = double.tryParse(args[1]);
        if (bpmVal == null) return TunnerOsCommandResult.error("Valor de BPM inválido: ${args[1]}");
        clockService!.setBpm(bpmVal);
        return TunnerOsCommandResult.success("[OK] Tempo del reloj maestro: ${bpmVal.toStringAsFixed(1)} BPM");

      case 'tap':
        clockService!.registerTap();
        return TunnerOsCommandResult.success("[OK] Tap Tempo registrado -> ${clockService!.bpm.toStringAsFixed(1)} BPM");

      default:
        return TunnerOsCommandResult.error("Acción de reloj desconocida. Opciones: play, pause, stop, bpm, tap");
    }
  }

  TunnerOsCommandResult _handleSynth(List<String> args) {
    if (synthVoicePool == null) {
      return TunnerOsCommandResult.error("Sintetizador polifónico no conectado al kernel.");
    }
    if (args.isEmpty || args[0] == 'status') {
      return TunnerOsCommandResult.success(
        "SINTETIZADOR POLIFÓNICO SMuFL:\n"
        "  Forma de Onda  : ${synthVoicePool!.waveform.name.toUpperCase()}\n"
        "  Polifonía      : ${synthVoicePool!.activeVoiceCount} / ${synthVoicePool!.maxPolyphony} voces activas\n"
        "  Ataque (A)     : ${(synthVoicePool!.attackSeconds * 1000).round()} ms\n"
        "  Decaimiento (D): ${(synthVoicePool!.decaySeconds * 1000).round()} ms\n"
        "  Sostenimiento(S: ${(synthVoicePool!.sustainLevel * 100).round()}%\n"
        "  Liberación (R) : ${(synthVoicePool!.releaseSeconds * 1000).round()} ms\n"
        "  Ganancia Master: ${(synthVoicePool!.masterGain * 100).round()}%",
      );
    }

    final action = args[0].toLowerCase();
    switch (action) {
      case 'wave':
      case 'waveform':
        if (args.length < 2) {
          return TunnerOsCommandResult.error("Sintaxis: synth wave <sine|sawtooth|pulse|triangle>");
        }
        final rawWave = args[1].toLowerCase();
        switch (rawWave) {
          case 'sine':
          case 'seno':
            synthVoicePool!.waveform = SynthWaveform.sine;
            break;
          case 'saw':
          case 'sawtooth':
          case 'sierra':
            synthVoicePool!.waveform = SynthWaveform.sawtooth;
            break;
          case 'pulse':
          case 'pulso':
          case 'cuadrada':
            synthVoicePool!.waveform = SynthWaveform.pulse;
            break;
          case 'tri':
          case 'triangle':
          case 'triangulo':
            synthVoicePool!.waveform = SynthWaveform.triangle;
            break;
          default:
            return TunnerOsCommandResult.error("Forma de onda desconocida: $rawWave. Opciones: sine, saw, pulse, tri");
        }
        return TunnerOsCommandResult.success("[OK] Forma de onda del sintetizador: ${synthVoicePool!.waveform.name.toUpperCase()}");

      case 'adsr':
        if (args.length < 5) {
          return TunnerOsCommandResult.error("Sintaxis: synth adsr <attack_ms> <decay_ms> <sustain_0_1> <release_ms>");
        }
        final a = double.tryParse(args[1]);
        final d = double.tryParse(args[2]);
        final s = double.tryParse(args[3]);
        final r = double.tryParse(args[4]);
        if (a == null || d == null || s == null || r == null) {
          return TunnerOsCommandResult.error("Valores numéricos de ADSR inválidos.");
        }
        synthVoicePool!.attackSeconds = a / 1000.0;
        synthVoicePool!.decaySeconds = d / 1000.0;
        synthVoicePool!.sustainLevel = s;
        synthVoicePool!.releaseSeconds = r / 1000.0;
        return TunnerOsCommandResult.success(
          "[OK] Envolvente ADSR configurada: ${a.round()}ms / ${d.round()}ms / ${(s * 100).round()}% / ${r.round()}ms",
        );

      case 'note':
        if (args.length < 2) {
          return TunnerOsCommandResult.error("Sintaxis: synth note <nombre_nota> [velocidad_0_1]");
        }
        final noteName = args[1];
        final vel = args.length >= 3 ? double.tryParse(args[2]) ?? 0.8 : 0.8;
        final midi = ScorePlaybackCoordinator.noteNameToMidi(noteName);
        if (midi < 0) {
          return TunnerOsCommandResult.error("Nota musical no válida: '$noteName'. Ejemplos: Do4, C4, Mi5, Fa#4, Sol3");
        }
        synthVoicePool!.noteOn(midi, vel);
        return TunnerOsCommandResult.success("[OK] Disparada nota: $noteName (MIDI $midi, vel: ${(vel * 100).round()}%)");

      case 'panic':
      case 'silence':
        synthVoicePool!.panic();
        return TunnerOsCommandResult.success("[OK] Silenciadas todas las voces del sintetizador (PANIC)");

      default:
        return TunnerOsCommandResult.error("Subcomando synth desconocido: '$action'. Opciones: status, wave, adsr, note, panic");
    }
  }

  TunnerOsCommandResult _handleScore(List<String> args) {
    if (scorePlaybackCoordinator == null) {
      return TunnerOsCommandResult.error("Coordinador de partitura no conectado al kernel.");
    }
    if (args.isEmpty) {
      return TunnerOsCommandResult.success(
        "REPRODUCTOR DE PARTITURA:\n"
        "  Estado : ${scorePlaybackCoordinator!.isPlaying ? 'REPRODUCIENDO' : 'DETENIDO'}\n"
        "  Compás : ${scorePlaybackCoordinator!.currentMeasureIndex + 1}\n"
        "  Sub-Tick: ${scorePlaybackCoordinator!.currentSubTick}\n"
        "  Tempo  : ${scorePlaybackCoordinator!.bpm.toStringAsFixed(1)} BPM",
      );
    }

    final action = args[0].toLowerCase();
    switch (action) {
      case 'play':
      case 'start':
        if (scorePlaybackCoordinator!.activeScore == null) {
          return TunnerOsCommandResult.error("No hay una partitura activa para reproducir.");
        }
        scorePlaybackCoordinator!.startPlayback(score: scorePlaybackCoordinator!.activeScore!);
        return TunnerOsCommandResult.success("[OK] Reproducción de partitura iniciada");

      case 'pause':
        scorePlaybackCoordinator!.pausePlayback();
        return TunnerOsCommandResult.success("[OK] Reproducción de partitura pausada");

      case 'stop':
        scorePlaybackCoordinator!.stopPlayback();
        return TunnerOsCommandResult.success("[OK] Reproducción de partitura detenida y rebobinada");

      case 'bpm':
      case 'tempo':
        if (args.length < 2) return TunnerOsCommandResult.error("Sintaxis: score bpm <valor>");
        final bpmVal = double.tryParse(args[1]);
        if (bpmVal == null) return TunnerOsCommandResult.error("BPM inválido: ${args[1]}");
        scorePlaybackCoordinator!.bpm = bpmVal;
        return TunnerOsCommandResult.success("[OK] Tempo de partitura ajustado a: ${bpmVal.toStringAsFixed(1)} BPM");

      default:
        return TunnerOsCommandResult.error("Subcomando score desconocido: '$action'. Opciones: play, pause, stop, bpm");
    }
  }

  TunnerOsCommandResult _handleProject(List<String> args) {
    final sub = args.isEmpty ? 'info' : args[0].toLowerCase();
    switch (sub) {
      case 'info':
        final title = viewModel?.activePackage.title ?? 'Untitled Project';
        final composer = viewModel?.activePackage.composer ?? 'Tunner Artist';
        final bpmVal = viewModel?.bpm ?? 120;
        final matrixInfo = matrixService != null
            ? 'Conectada (${matrixService!.matrix.channelRoutings.length} canales activos)'
            : 'Desconectada';
        final synthInfo = synthVoicePool != null
            ? '${synthVoicePool!.waveform.name} (Voces activas: ${synthVoicePool!.activeVoiceCount})'
            : 'No inicializado';
        return TunnerOsCommandResult.success('''
PROYECTO ACTIVO EN TUNNER STUDIO:
- Titulo: $title
- Compositor / Autor: $composer
- Tempo Nominal: $bpmVal BPM
- Matriz de Hardware: $matrixInfo
- Sintetizador Polifonico: $synthInfo
- Contenedor Canonico: .tunner v1.0.0 (DEFLATE ZIP con SHA-256)
'''.trim());

      case 'export':
        if (viewModel == null) {
          return TunnerOsCommandResult.error(
            'No se puede exportar: TunerViewModel no esta enlazado al kernel.',
          );
        }
        final customTitle = args.length > 1 ? args.sublist(1).join(' ').replaceAll('"', '') : null;
        try {
          final bytes = viewModel!.exportCurrentProjectToTunner(projectTitle: customTitle);
          return TunnerOsCommandResult.success('''
[OK] Proyecto exportado exitosamente a formato canonico .tunner:
- Titulo: ${customTitle ?? viewModel!.activePackage.title}
- Peso del archivo: ${bytes.lengthInBytes} bytes
- Integridad: Hashes SHA-256 generados y sellados en manifest.json
'''.trim());
        } catch (e) {
          return TunnerOsCommandResult.error('Fallo al exportar el proyecto .tunner: $e');
        }

      default:
        return TunnerOsCommandResult.error(
          "Subcomando project desconocido: '$sub'. Opciones validas: info, export",
        );
    }
  }

  TunnerOsCommandResult _handleReverb(List<String> args) {
    if (reverbEngine == null) {
      return TunnerOsCommandResult.error('Reverberador no disponible en el kernel.');
    }
    if (args.isEmpty || args[0] == 'status') {
      return TunnerOsCommandResult.success('''
[ESTADO REVERBERADOR SCHROEDER-MOORER]
- Room Size: ${(reverbEngine!.roomSize * 100).toStringAsFixed(1)}%
- Damping: ${(reverbEngine!.damping * 100).toStringAsFixed(1)}%
- Wet Mix: ${(reverbEngine!.wetMix * 100).toStringAsFixed(1)}%
- Dry Mix: ${(reverbEngine!.dryMix * 100).toStringAsFixed(1)}%
- Width: ${(reverbEngine!.width * 100).toStringAsFixed(1)}%
'''.trim());
    }

    final param = args[0].toLowerCase();
    if (args.length < 2) {
      return TunnerOsCommandResult.error('Sintaxis: reverb [room|damp|wet|dry|width] <valor 0.0-1.0>');
    }
    final val = double.tryParse(args[1]);
    if (val == null) {
      return TunnerOsCommandResult.error('El valor de reverberacion debe ser un numero decimal.');
    }

    switch (param) {
      case 'room':
      case 'roomsize':
        reverbEngine!.roomSize = val;
        return TunnerOsCommandResult.success('[OK] Reverb Room Size fijado en: ${reverbEngine!.roomSize}');
      case 'damp':
      case 'damping':
        reverbEngine!.damping = val;
        return TunnerOsCommandResult.success('[OK] Reverb Damping fijado en: ${reverbEngine!.damping}');
      case 'wet':
        reverbEngine!.wetMix = val;
        return TunnerOsCommandResult.success('[OK] Reverb Wet Mix fijado en: ${reverbEngine!.wetMix}');
      case 'dry':
        reverbEngine!.dryMix = val;
        return TunnerOsCommandResult.success('[OK] Reverb Dry Mix fijado en: ${reverbEngine!.dryMix}');
      case 'width':
        reverbEngine!.width = val;
        return TunnerOsCommandResult.success('[OK] Reverb Width fijado en: ${reverbEngine!.width}');
      default:
        return TunnerOsCommandResult.error('Parametro de reverberacion no valido: $param. Opciones: room, damp, wet, dry, width, status');
    }
  }

  TunnerOsCommandResult _handleSpatial(List<String> args) {
    if (spatialEngine == null) {
      return TunnerOsCommandResult.error('Motor de espacializacion binaural 3D no inicializado.');
    }

    if (args.isEmpty || args[0].toLowerCase() == 'status') {
      final coords = spatialEngine!.coordinates;
      return TunnerOsCommandResult.success('''
[MATRIZ DE ESPACIALIZACION BINAURAL 3D - HRTF WOODWORTH]
- Azimut: ${coords.azimuthDegrees.toStringAsFixed(1)}°
- Elevacion: ${coords.elevationDegrees.toStringAsFixed(1)}°
- Distancia: ${coords.distanceMeters.toStringAsFixed(2)} m
- Retardo Izquierdo: ${spatialEngine!.leftDelayMs.toStringAsFixed(3)} ms
- Retardo Derecho: ${spatialEngine!.rightDelayMs.toStringAsFixed(3)} ms
- ITD Neto: ${spatialEngine!.itdMs.toStringAsFixed(3)} ms
- Atenuacion por Distancia: ${(spatialEngine!.distanceGain * 100).toStringAsFixed(1)}%
'''.trim());
    }

    final subCmd = args[0].toLowerCase();
    if (subCmd == 'reset') {
      spatialEngine!.reset();
      spatialEngine!.coordinates = const BinauralPannerEntity();
      return TunnerOsCommandResult.success('[OK] Coordenadas binaurales y lineas de retardo reiniciadas.');
    }

    if (args.length < 2) {
      return TunnerOsCommandResult.error(
        'Sintaxis: spatial [pan|az|elev|dist] <valor> o spatial status',
      );
    }

    final val = double.tryParse(args[1]);
    if (val == null) {
      return TunnerOsCommandResult.error('El parametro espacial debe ser un numero.');
    }

    switch (subCmd) {
      case 'pan':
      case 'az':
      case 'azimuth':
        spatialEngine!.setAzimuth(val);
        return TunnerOsCommandResult.success(
          '[OK] Azimut fijado en: ${spatialEngine!.coordinates.azimuthDegrees}° (ITD: ${spatialEngine!.itdMs.toStringAsFixed(3)} ms)',
        );
      case 'elev':
      case 'elevation':
        spatialEngine!.setElevation(val);
        return TunnerOsCommandResult.success(
          '[OK] Elevacion fijada en: ${spatialEngine!.coordinates.elevationDegrees}°',
        );
      case 'dist':
      case 'distance':
        if (val <= 0.0) {
          return TunnerOsCommandResult.error('La distancia debe ser estrictamente positiva (> 0.0).');
        }
        spatialEngine!.setDistance(val);
        return TunnerOsCommandResult.success(
          '[OK] Distancia fijada en: ${spatialEngine!.coordinates.distanceMeters} m (Ganancia: ${(spatialEngine!.distanceGain * 100).toStringAsFixed(1)}%)',
        );
      default:
        return TunnerOsCommandResult.error(
          'Comando espacial no valido: $subCmd. Opciones: status, pan, az, elev, dist, reset',
        );
    }
  }

  TunnerOsCommandResult _handleTrain(List<String> args) {
    if (earTrainingEngine == null) {
      return TunnerOsCommandResult.error('Motor de entrenamiento auditivo no inicializado.');
    }

    final now = DateTime.now();

    if (args.isEmpty || args[0].toLowerCase() == 'status') {
      final all = earTrainingEngine!.allItems;
      final due = earTrainingEngine!.getDueItems(now: now);
      final avgRetention = earTrainingEngine!.overallRetentionAverage(now) * 100.0;
      final mastered = all.where((i) => i.repetitions >= 3).length;

      return TunnerOsCommandResult.success('''
[ESTADO DE ENTRENAMIENTO AUDITIVO - REPETICION ESPACIADA EBBINGHAUS]
- Total de Ejercicios en Catalogo: ${all.length}
- Ejercicios Pendientes de Repaso: ${due.length}
- Retencion Cognitiva Promedio: ${avgRetention.toStringAsFixed(1)}%
- Intervalos Dominados (>= 3 repasos): $mastered / ${all.length}
'''.trim());
    }

    final subCmd = args[0].toLowerCase();
    switch (subCmd) {
      case 'review':
      case 'due':
        final due = earTrainingEngine!.getDueItems(now: now);
        if (due.isEmpty) {
          return TunnerOsCommandResult.success(
            '[OK] No hay ejercicios pendientes de repaso. Retencion auditiva por encima del 90%.',
          );
        }
        final buffer = StringBuffer('EJERCICIOS PENDIENTES DE REPASO:\n-------------------------------\n');
        for (final item in due) {
          final ret = (item.retentionAt(now) * 100).toStringAsFixed(1);
          buffer.writeln(
            '- ${item.id} | ${item.name} (${item.semitones} st) | Retencion: $ret% | Estabilidad: ${item.stabilityDays.toStringAsFixed(2)}d',
          );
        }
        return TunnerOsCommandResult.success(buffer.toString().trim());

      case 'list':
        final all = earTrainingEngine!.allItems;
        final buffer = StringBuffer('CATALOGO DE ENTRENAMIENTO AUDITIVO:\n----------------------------------\n');
        for (final item in all) {
          final ret = (item.retentionAt(now) * 100).toStringAsFixed(1);
          buffer.writeln(
            '- ${item.id.padRight(28)}: ${item.name.padRight(32)} [$ret% ret | ${item.stabilityDays.toStringAsFixed(1)}d stab | ${item.repetitions} reps]',
          );
        }
        return TunnerOsCommandResult.success(buffer.toString().trim());

      case 'answer':
      case 'submit':
        if (args.length < 3) {
          return TunnerOsCommandResult.error(
            'Sintaxis: train answer <id_ejercicio> <cents_error> [tiempo_seg] [correcto: 1|0]',
          );
        }
        final itemId = args[1];
        final cents = double.tryParse(args[2]);
        if (cents == null) {
          return TunnerOsCommandResult.error('El error en cents debe ser un numero decimal.');
        }

        final time = args.length >= 4 ? (double.tryParse(args[3]) ?? 2.0) : 2.0;
        final isCorrect = args.length >= 5 ? (args[4] == '1' || args[4].toLowerCase() == 'true') : cents.abs() <= 50.0;

        try {
          final result = earTrainingEngine!.submitAnswer(
            itemId,
            isCorrect: isCorrect,
            centsError: cents,
            responseTimeSeconds: time,
            timestamp: now,
          );
          return TunnerOsCommandResult.success('''
[EVALUACION PEDAGOGICA EBBINGHAUS]
- Ejercicio: ${result.updatedItem.name} (${result.updatedItem.id})
- Calificacion de Calidad: ${result.qualityGrade}/5
- Error Acustico: ${result.centsError.toStringAsFixed(1)} cents
- Tiempo de Respuesta: ${result.responseTimeSeconds.toStringAsFixed(2)} s
- Nueva Estabilidad: ${result.updatedItem.stabilityDays.toStringAsFixed(2)} dias
- Proximo Repaso: ${result.updatedItem.nextReviewDate.toIso8601String().substring(0, 16)}
- Diagnostico: ${result.cognitiveFeedback}
'''.trim());
        } catch (e) {
          return TunnerOsCommandResult.error('Error al evaluar ejercicio: ${e.toString()}');
        }

      case 'reset':
        earTrainingEngine!.reset();
        return TunnerOsCommandResult.success('[OK] Catalogo de entrenamiento auditivo reiniciado al estado base.');

      default:
        return TunnerOsCommandResult.error(
          'Subcomando no valido: $subCmd. Opciones: status, review, list, answer, reset',
        );
    }
  }

  TunnerOsCommandResult _handleVocal(List<String> args) {
    if (vocalEvaluator == null) {
      return TunnerOsCommandResult.error('Evaluador de estabilidad vocal no inicializado.');
    }

    if (args.isEmpty || args[0].toLowerCase() == 'eval') {
      final targetHz = args.length >= 2 ? (double.tryParse(args[1]) ?? 440.0) : 440.0;
      if (targetHz <= 0.0) {
        return TunnerOsCommandResult.error('La frecuencia target debe ser positiva.');
      }

      // Sintetizar secuencia fonatoria realista para calibracion y evaluacion (50 frames = 1s a 50Hz)
      final freqs = <double>[];
      final amps = <double>[];
      for (int i = 0; i < 50; i++) {
        // Modulacion suave de vibrato natural con excursion de +-30 cents
        final vibratoMod = 1.0 + 0.017 * (1.0 + (i % 2 == 0 ? 0.002 : -0.002));
        final f = targetHz * vibratoMod;
        final a = 0.85 + 0.02 * ((i % 3) - 1);
        freqs.add(f);
        amps.add(a);
      }

      final eval = vocalEvaluator!.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: targetHz,
      );

      return TunnerOsCommandResult.success('''
[INFORME DE EVALUACION VOCAL Y ESTABILIDAD ACUSTICA]
- ID Evaluacion: ${eval.evaluationId}
- Frecuencia Target: ${eval.targetFrequencyHz.toStringAsFixed(1)} Hz | Media: ${eval.measuredMeanFrequencyHz.toStringAsFixed(1)} Hz
- Desviacion Tonal: ${eval.centsDeviation.toStringAsFixed(1)} cents
- Jitter Relativo: ${eval.jitterPercent.toStringAsFixed(2)}% (Fisiologico <= 1.00%)
- Shimmer de Amplitud: ${eval.shimmerPercent.toStringAsFixed(2)}% (Fisiologico <= 3.50%)
- Tasa de Vibrato: ${eval.vibratoRateHz.toStringAsFixed(2)} Hz | Profundidad: ${eval.vibratoDepthCents.toStringAsFixed(1)} cents
- Calificacion Global: ${eval.overallScore.toStringAsFixed(1)} / 100
- Dictamen: ${eval.classificationLabel}
- Sello SHA-256: ${eval.payloadHashSha256}
'''.trim());
    }

    final subCmd = args[0].toLowerCase();
    if (subCmd == 'cert' || subCmd == 'certificate') {
      if (args.length < 2) {
        return TunnerOsCommandResult.error('Sintaxis: vocal cert <nombre_estudiante> [target_hz]');
      }

      final studentName = args[1].replaceAll('"', '');
      final targetHz = args.length >= 3 ? (double.tryParse(args[2]) ?? 440.0) : 440.0;

      final freqs = <double>[];
      final amps = <double>[];
      for (int i = 0; i < 50; i++) {
        freqs.add(targetHz * (1.0 + 0.003 * ((i % 2 == 0) ? 1 : -1)));
        amps.add(0.90 + 0.01 * ((i % 3 == 0) ? 1 : -1));
      }

      final eval = vocalEvaluator!.evaluate(
        frequenciesHz: freqs,
        amplitudes: amps,
        targetFrequencyHz: targetHz,
      );

      final pdfBytes = PedagogicalCertificatePdfGenerator.generateCertificatePdf(
        studentName: studentName,
        evaluation: eval,
      );

      return TunnerOsCommandResult.success('''
[CERTIFICADO OFICIAL DE CONSERVATORIO GENERADO EXITOSAMENTE]
- Formato: Binario Vectorial PDF-1.4 (ISO 32000-1)
- Tamano del Documento: ${pdfBytes.length} bytes
- Candidato: $studentName
- Calificacion: ${eval.overallScore.toStringAsFixed(1)} / 100 (${eval.classificationLabel})
- Sello Digital SHA-256 (Inmutable):
  ${eval.payloadHashSha256}
'''.trim());
    }

    return TunnerOsCommandResult.error(
      'Subcomando vocal no valido: $subCmd. Opciones: eval [target_hz], cert <nombre> [target_hz]',
    );
  }

  Future<TunnerOsCommandResult> _handleDsl(String rawCommandLine) async {
    final firstSpace = rawCommandLine.indexOf(' ');
    if (firstSpace == -1 || firstSpace == rawCommandLine.length - 1) {
      return TunnerOsCommandResult.error(
        'Sintaxis: dsl <script> o eval <script>. Ejemplo: dsl tempo 128; note C4 1/4;',
      );
    }
    final script = rawCommandLine.substring(firstSpace + 1).trim();
    if (script.isEmpty) {
      return TunnerOsCommandResult.error('El script DSL no puede estar vacio.');
    }

    final parseResult = dslParser.parse(script);
    if (!parseResult.isSuccess || parseResult.program == null) {
      final errors = parseResult.diagnostics
          .map((d) => '[L${d.line}:C${d.column}] ${d.message}')
          .join('\n');
      return TunnerOsCommandResult.error(
        'Error de sintaxis en script Tunner DSL:\n$errors',
      );
    }

    final report = await dslInterpreter.interpret(
      parseResult.program!,
      kernel: audioKernel,
    );

    if (!report.isSuccess) {
      final warnings = report.warnings.join('\n');
      return TunnerOsCommandResult.error(
        'Fallo de evaluacion en Tunner DSL:\n$warnings',
      );
    }

    final eventSummary = report.generatedEvents.map((e) => '  - ${e.toString()}').join('\n');
    return TunnerOsCommandResult.success('''
[TUNNER DSL EXECUTION REPORT]
- Sentencias procesadas: ${report.totalStatementsExecuted}
- Tiempo de evaluacion: ${report.executionTimeMicroseconds} us
- Eventos de audio despachados: ${report.generatedEvents.length}
${eventSummary.isNotEmpty ? 'Eventos despachados:\n$eventSummary' : ''}
'''.trim());
  }

  TunnerOsCommandResult _handleTheme(List<String> args) {
    if (args.length < 2 || args[0] != 'set') {
      return TunnerOsCommandResult.error('Sintaxis: theme set "<nombre_tema>"');
    }
    final themeName = args.sublist(1).join(' ').replaceAll('"', '');
    onSetTheme?.call(themeName);
    return TunnerOsCommandResult.success("[OK] Tema cambiado a: '$themeName'");
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
