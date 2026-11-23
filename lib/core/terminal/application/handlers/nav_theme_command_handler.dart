import '../../domain/i_terminal_command_handler.dart';
import '../../domain/tunner_os_command_entity.dart';

/// Manejador modular de comandos de navegacion, tema visual, ayuda y limpieza de terminal.
class NavThemeCommandHandler implements ITerminalCommandHandler {
  final void Function(int tabIndex)? Function() _getOnNavigateTab;
  final void Function(String themeId)? Function() _getOnSetTheme;

  const NavThemeCommandHandler({
    required void Function(int tabIndex)? Function() getOnNavigateTab,
    required void Function(String themeId)? Function() getOnSetTheme,
  })  : _getOnNavigateTab = getOnNavigateTab,
        _getOnSetTheme = getOnSetTheme;

  @override
  Set<String> get supportedDomains => const {
        'help',
        'tuner',
        'theme',
        'clear',
      };

  @override
  TunnerOsCommandResult execute(
    String domain,
    List<String> args,
    String rawCommandLine,
  ) {
    switch (domain) {
      case 'help':
        return _handleHelp(args);
      case 'tuner':
        return _handleTuner(args);
      case 'theme':
        return _handleTheme(args);
      case 'clear':
        return TunnerOsCommandResult.success('CLEAR_SCREEN');
      default:
        return TunnerOsCommandResult.error("[ERROR] Dominio de navegacion no soportado: '$domain'.");
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
dsl list                  : Lista las plantillas canónicas Tunner DSL disponibles
dsl load <plantilla>      : Carga y ejecuta una plantilla canónica (.tun)
eval <script>             : Alias de evaluación inmediata para Tunner DSL
io list                  : Lista las interfaces de audio de entrada detectadas
io set-input <id>        : Conmuta la interfaz activa de captura
dsp status               : Muestra la telemetría del motor de audio (latencia, buffers)
dsp bench [iter] [bloque]: Ejecuta el benchmark de rendimiento SIMD vs Fallback
fs ls                    : Lista los archivos y proyectos en el espacio de trabajo
theme set <nombre>       : Cambia el tema visual (e.g. 'theme set "Tokyo Cyberpunk"')
clear                    : Limpia el historial de la pantalla de la terminal
''';
    return TunnerOsCommandResult.success(helpText.trim());
  }

  TunnerOsCommandResult _handleTuner(List<String> args) {
    if (args.isEmpty || args[0] != 'run') {
      return TunnerOsCommandResult.error('Sintaxis: tuner run [home|tuner|lessons|rack|library|dj]');
    }
    if (args.length < 2) {
      return TunnerOsCommandResult.error('Especifica el módulo: home, tuner, lessons, rack, library, dj');
    }

    final target = args[1].toLowerCase();
    const Map<String, int> tabMap = {
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
      return TunnerOsCommandResult.error(
        "Módulo desconocido: '$target'. Opciones: tuner, lessons, rack, library, dj",
      );
    }

    final onNavigateTab = _getOnNavigateTab();
    if (onNavigateTab == null) {
      return TunnerOsCommandResult.error(
        '[ERROR] Controlador de navegacion (onNavigateTab) no conectado al kernel.',
      );
    }
    onNavigateTab(index);
    return TunnerOsCommandResult.success('[OK] Navegando al módulo: $target (Pestaña $index)');
  }

  TunnerOsCommandResult _handleTheme(List<String> args) {
    if (args.length < 2 || args[0] != 'set') {
      return TunnerOsCommandResult.error('Sintaxis: theme set "<nombre_tema>"');
    }
    final onSetTheme = _getOnSetTheme();
    if (onSetTheme == null) {
      return TunnerOsCommandResult.error(
        '[ERROR] Controlador de temas visuales (onSetTheme) no conectado al kernel.',
      );
    }
    final themeName = args.sublist(1).join(' ').replaceAll('"', '');
    onSetTheme(themeName);
    return TunnerOsCommandResult.success("[OK] Tema cambiado a: '$themeName'");
  }
}
