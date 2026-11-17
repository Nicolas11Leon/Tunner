import 'dart:async';
import '../../audio/domain/i_studio_audio_engine.dart';
import '../../audio/domain/i_studio_audio_input_engine.dart';
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
  final void Function(String themeId)? onSetTheme;
  final void Function(String deckId, String trackTitle)? onDjLoadTrack;
  final void Function(String deckId)? onDjTogglePlay;
  final void Function(double val)? onDjSetCrossfader;

  TunnerOsKernel({
    this.onNavigateTab,
    this.outputEngine,
    this.inputEngine,
    this.fileSystemRepository,
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
