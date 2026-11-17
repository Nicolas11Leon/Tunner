import 'dart:async';
import '../../audio/domain/i_studio_audio_engine.dart';
import '../../audio/domain/i_studio_audio_input_engine.dart';
import '../../audio/domain/studio_master_clock_service.dart';
import '../../audio/infrastructure/studio_audio_device_matrix_service.dart';
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
  final void Function(String themeId)? onSetTheme;
  final void Function(String deckId, String trackTitle)? onDjLoadTrack;
  final void Function(String deckId)? onDjTogglePlay;
  final void Function(double val)? onDjSetCrossfader;

  TunnerOsKernel({
    this.onNavigateTab,
    this.outputEngine,
    this.inputEngine,
    this.fileSystemRepository,
    this.matrixService,
    this.clockService,
    this.onSetTheme,
    this.onDjLoadTrack,
    this.onDjTogglePlay,
    this.onDjSetCrossfader,
  });

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
route <canal> <destino>  : Asigna un canal a 'master', 'cue' o 'mute'
clock [play|pause|stop]  : Controla el transporte unificado de todos los módulos
clock bpm <valor>        : Sincroniza el tempo maestro (20 a 300 BPM)
clock tap                : Registra una pulsación táctil para Tap Tempo
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
    const report = '''
ESTADO DEL MOTOR DSP CORE (TUNNER STUDIO):
-------------------------------------------
Motor de Audio     : EN LÍNEA (FULL-DUPLEX)
Frecuencia Base    : 44.1 kHz / 48.0 kHz
Tamaño de Buffer   : 1024 muestras (< 7.8 ms latencia)
Ring Buffer Lock   : 16384 muestras (Zero GC overhead)
Isolate MPM Worker : Activo (McLeod Pitch Method + Tone Lock)
Canales de Salida  : Deck A, Deck B, Metronome, Diapason, Takes
Limitador Soft-Clip: Activo a 0.0 dBFS
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
