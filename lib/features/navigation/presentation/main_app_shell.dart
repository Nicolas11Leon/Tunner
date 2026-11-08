import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../tuner_viewmodel.dart';
import 'home_dashboard_screen.dart';
import '../../tuner_screen.dart';
import '../../workspaces/presentation/learning_practice_workspace_view.dart';
import '../../modular_rack/presentation/modular_studio_rack_view.dart';
import '../../workspaces/presentation/composition_notation_workspace_view.dart';
import '../../instrument/presentation/instrument_selector_modal.dart';
import 'pro_command_palette_modal.dart';
import 'keyboard_shortcuts_modal.dart';
import 'quick_action_dock_widget.dart';

/// Intenciones para el sistema de atajos de teclado de grado Photoshop.
class TogglePlayIntent extends Intent {
  const TogglePlayIntent();
}

class ToggleRecordIntent extends Intent {
  const ToggleRecordIntent();
}

class TapTempoIntent extends Intent {
  const TapTempoIntent();
}

class FocusTunerIntent extends Intent {
  const FocusTunerIntent();
}

class FocusMetronomeIntent extends Intent {
  const FocusMetronomeIntent();
}

class FocusScoreIntent extends Intent {
  const FocusScoreIntent();
}

class FocusLessonsIntent extends Intent {
  const FocusLessonsIntent();
}

class FocusStudioIntent extends Intent {
  const FocusStudioIntent();
}

class IncrementBpmIntent extends Intent {
  final int step;
  const IncrementBpmIntent(this.step);
}

class DecrementBpmIntent extends Intent {
  final int step;
  const DecrementBpmIntent(this.step);
}

class CalibrateReferencePitchIntent extends Intent {
  final double deltaHz;
  const CalibrateReferencePitchIntent(this.deltaHz);
}

class PanicMuteIntent extends Intent {
  const PanicMuteIntent();
}

class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

class OpenShortcutsGuideIntent extends Intent {
  const OpenShortcutsGuideIntent();
}

class OpenInstrumentSelectorIntent extends Intent {
  const OpenInstrumentSelectorIntent();
}

class ShowContextualHelpIntent extends Intent {
  final String toolId;
  const ShowContextualHelpIntent(this.toolId);
}

class SwitchTabIntent extends Intent {
  final int tabIndex;
  const SwitchTabIntent(this.tabIndex);
}

/// Contenedor principal de navegación de Tunner (MainAppShell).
/// Gestiona la transición limpia entre el Dashboard de Inicio, el Afinador,
/// el Tutor de Aprendizaje, el Estudio de Grabación y la Biblioteca de Canciones,
/// integrando el Quick Action Dock y el despachador de atajos globales estilo Photoshop.
class MainAppShell extends StatefulWidget {
  final int initialIndex;

  const MainAppShell({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 5) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _openInstrumentSelector(TunerViewModel viewModel) {
    InstrumentSelectorModal.show(context, viewModel);
  }

  void _openCommandPalette(TunerViewModel viewModel) {
    final commands = <CommandItem>[
      CommandItem(
        id: 'toggle_metro',
        title: viewModel.isMetronomeActive ? 'Pausar Metrónomo' : 'Iniciar Metrónomo',
        subtitle: 'Alternar pulso rítmico a ${viewModel.bpm.round()} BPM',
        icon: Icons.access_time,
        category: 'Transporte',
        shortcutLabel: 'M / Espacio',
        onSelect: () => viewModel.toggleMetronome(),
      ),
      CommandItem(
        id: 'toggle_record',
        title: viewModel.isRecording ? 'Detener Grabación' : 'Grabar Toma de Práctica',
        subtitle: 'Capturar audio en vivo para auto-evaluación',
        icon: Icons.fiber_manual_record,
        category: 'Grabación',
        shortcutLabel: 'R',
        onSelect: () {
          if (viewModel.isRecording) {
            viewModel.stopPracticeRecording();
          } else {
            viewModel.startPracticeRecording();
          }
        },
      ),
      CommandItem(
        id: 'tap_tempo',
        title: 'Calcular Tap Tempo',
        subtitle: 'Pulsar tempo al compás de la música',
        icon: Icons.touch_app,
        category: 'Metrónomo',
        shortcutLabel: 'B / T',
        onSelect: () => viewModel.recordTapTempo(),
      ),
      CommandItem(
        id: 'bpm_plus',
        title: 'Aumentar Tempo (+1 BPM)',
        subtitle: 'Acelerar metrónomo un paso',
        icon: Icons.arrow_upward,
        category: 'Metrónomo',
        shortcutLabel: ']',
        onSelect: () => viewModel.incrementBpm(1),
      ),
      CommandItem(
        id: 'bpm_minus',
        title: 'Disminuir Tempo (-1 BPM)',
        subtitle: 'Desacelerar metrónomo un paso',
        icon: Icons.arrow_downward,
        category: 'Metrónomo',
        shortcutLabel: '[',
        onSelect: () => viewModel.decrementBpm(1),
      ),
      CommandItem(
        id: 'tab_tuner',
        title: 'Abrir Afinador Estroboscópico',
        subtitle: 'Afinación de alta precisión de ±0.1 cents',
        icon: Icons.tune,
        category: 'Navegación',
        shortcutLabel: 'A / 2',
        onSelect: () => _navigateToTab(1),
      ),
      CommandItem(
        id: 'tab_learning',
        title: 'Abrir Tutor y Lecciones Guiadas',
        subtitle: 'Ejercicios interactivos con evaluación rushing/dragging',
        icon: Icons.school,
        category: 'Navegación',
        shortcutLabel: 'L / 3',
        onSelect: () => _navigateToTab(2),
      ),
      CommandItem(
        id: 'tab_studio',
        title: 'Abrir Rack Modular de Estudio',
        subtitle: 'Estudio multitarea con instrumentos y matriz de conexiones',
        icon: Icons.view_comfortable,
        category: 'Navegación',
        shortcutLabel: '4',
        onSelect: () => _navigateToTab(3),
      ),
      CommandItem(
        id: 'tab_library',
        title: 'Abrir Biblioteca de Canciones y Partituras',
        subtitle: 'Gestor y reproductor de partituras SMuFL',
        icon: Icons.menu_book,
        category: 'Navegación',
        shortcutLabel: 'S / 5',
        onSelect: () => _navigateToTab(4),
      ),
      CommandItem(
        id: 'select_instrument',
        title: 'Cambiar Instrumento Musical Activo',
        subtitle: 'Seleccionar entre más de 60 instrumentos orquestales y contemporáneos',
        icon: Icons.piano,
        category: 'Instrumento',
        shortcutLabel: 'Cmd+I',
        onSelect: () => _openInstrumentSelector(viewModel),
      ),
      CommandItem(
        id: 'panic_mute',
        title: 'Silencio Total (Panic Mute)',
        subtitle: 'Detener de inmediato todos los sintetizadores y sonidos',
        icon: Icons.volume_off,
        category: 'Audio',
        shortcutLabel: '0',
        onSelect: () {
          if (viewModel.isMetronomeActive) viewModel.toggleMetronome();
          if (viewModel.isRecording) viewModel.stopPracticeRecording();
        },
      ),
    ];

    ProCommandPaletteModal.show(
      context: context,
      palette: viewModel.currentPalette,
      commands: commands,
    );
  }

  void _openShortcutsGuide(TunerViewModel viewModel) {
    KeyboardShortcutsCheatSheetModal.show(
      context: context,
      palette: viewModel.currentPalette,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Transporte y Grabación
        const SingleActivator(LogicalKeyboardKey.space): const TogglePlayIntent(),
        const SingleActivator(LogicalKeyboardKey.keyR): const ToggleRecordIntent(),
        const SingleActivator(LogicalKeyboardKey.keyT): const TapTempoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyB): const TapTempoIntent(),

        // Incremento y decremento fino de tempo
        const SingleActivator(LogicalKeyboardKey.bracketRight): const IncrementBpmIntent(1),
        const SingleActivator(LogicalKeyboardKey.bracketLeft): const DecrementBpmIntent(1),
        const SingleActivator(LogicalKeyboardKey.bracketRight, shift: true): const IncrementBpmIntent(5),
        const SingleActivator(LogicalKeyboardKey.bracketLeft, shift: true): const DecrementBpmIntent(5),

        // Herramientas directas (Single Key Select)
        const SingleActivator(LogicalKeyboardKey.keyA): const FocusTunerIntent(),
        const SingleActivator(LogicalKeyboardKey.keyM): const FocusMetronomeIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS): const FocusScoreIntent(),
        const SingleActivator(LogicalKeyboardKey.keyL): const FocusLessonsIntent(),
        const SingleActivator(LogicalKeyboardKey.digit0): const PanicMuteIntent(),

        // Calibración de Hz
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): const CalibrateReferencePitchIntent(1.0),
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): const CalibrateReferencePitchIntent(-1.0),

        // Modales de sistema
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): const OpenCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const OpenCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): const OpenInstrumentSelectorIntent(),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): const OpenInstrumentSelectorIntent(),
        const SingleActivator(LogicalKeyboardKey.slash, shift: true): const OpenShortcutsGuideIntent(),

        // Pestañas directas
        const SingleActivator(LogicalKeyboardKey.digit1): const SwitchTabIntent(0),
        const SingleActivator(LogicalKeyboardKey.digit2): const SwitchTabIntent(1),
        const SingleActivator(LogicalKeyboardKey.digit3): const SwitchTabIntent(2),
        const SingleActivator(LogicalKeyboardKey.digit4): const SwitchTabIntent(3),
        const SingleActivator(LogicalKeyboardKey.digit5): const SwitchTabIntent(4),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          TogglePlayIntent: CallbackAction<TogglePlayIntent>(
            onInvoke: (_) => viewModel.toggleMetronome(),
          ),
          ToggleRecordIntent: CallbackAction<ToggleRecordIntent>(
            onInvoke: (_) {
              if (viewModel.isRecording) {
                viewModel.stopPracticeRecording();
              } else {
                viewModel.startPracticeRecording();
              }
              return null;
            },
          ),
          TapTempoIntent: CallbackAction<TapTempoIntent>(
            onInvoke: (_) => viewModel.recordTapTempo(),
          ),
          IncrementBpmIntent: CallbackAction<IncrementBpmIntent>(
            onInvoke: (intent) => viewModel.incrementBpm(intent.step),
          ),
          DecrementBpmIntent: CallbackAction<DecrementBpmIntent>(
            onInvoke: (intent) => viewModel.decrementBpm(intent.step),
          ),
          CalibrateReferencePitchIntent: CallbackAction<CalibrateReferencePitchIntent>(
            onInvoke: (intent) => viewModel.setReferencePitch(viewModel.referencePitch + intent.deltaHz),
          ),
          PanicMuteIntent: CallbackAction<PanicMuteIntent>(
            onInvoke: (_) {
              if (viewModel.isMetronomeActive) viewModel.toggleMetronome();
              if (viewModel.isRecording) viewModel.stopPracticeRecording();
              return null;
            },
          ),
          FocusTunerIntent: CallbackAction<FocusTunerIntent>(
            onInvoke: (_) => _navigateToTab(1),
          ),
          FocusMetronomeIntent: CallbackAction<FocusMetronomeIntent>(
            onInvoke: (_) => viewModel.toggleMetronome(),
          ),
          FocusScoreIntent: CallbackAction<FocusScoreIntent>(
            onInvoke: (_) => _navigateToTab(4),
          ),
          FocusLessonsIntent: CallbackAction<FocusLessonsIntent>(
            onInvoke: (_) => _navigateToTab(2),
          ),
          OpenInstrumentSelectorIntent: CallbackAction<OpenInstrumentSelectorIntent>(
            onInvoke: (_) => _openInstrumentSelector(viewModel),
          ),
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) => _openCommandPalette(viewModel),
          ),
          OpenShortcutsGuideIntent: CallbackAction<OpenShortcutsGuideIntent>(
            onInvoke: (_) => _openShortcutsGuide(viewModel),
          ),
          SwitchTabIntent: CallbackAction<SwitchTabIntent>(
            onInvoke: (intent) => _navigateToTab(intent.tabIndex),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: palette.scaffoldBackground,
            body: Stack(
              children: [
                IndexedStack(
                  index: _currentIndex,
                  children: [
                    // 0: Dashboard Principal con Tarjetas y Buscador
                    HomeDashboardScreen(
                      onNavigateToTab: _navigateToTab,
                    ),

                    // 1: Afinador de Precisión & Metrónomo
                    const TunerScreen(),

                    // 2: Tutor Interactivo & Aprendizaje
                    LearningPracticeWorkspaceView(
                      viewModel: viewModel,
                      palette: palette,
                      onOpenInstrumentModal: () => _openInstrumentSelector(viewModel),
                    ),

                    // 3: Rack de Estudio Modular & Consola Multitarea
                    const ModularStudioRackView(),

                    // 4: Biblioteca de Canciones & Partituras
                    CompositionNotationWorkspaceView(
                      viewModel: viewModel,
                      palette: palette,
                      onOpenLibraryModal: () {},
                      onOpenMixerModal: () {},
                    ),
                  ],
                ),

                // Barra Flotante de Acciones Rápidas (Quick Actions Dock)
                QuickActionDockWidget(
                  viewModel: viewModel,
                  palette: palette,
                  onOpenCommandPalette: () => _openCommandPalette(viewModel),
                  onOpenShortcutsGuide: () => _openShortcutsGuide(viewModel),
                  onOpenTunerTab: () => _navigateToTab(1),
                ),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: palette.scaffoldBackground,
                border: Border(
                  top: BorderSide(
                    color: palette.staffLinesColor.withValues(alpha: 0.2),
                    width: 1.0,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: _navigateToTab,
                backgroundColor: palette.scaffoldBackground,
                indicatorColor: palette.primaryAccent.withValues(alpha: 0.18),
                elevation: 0,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(
                    key: const Key('nav_tab_home'),
                    icon: Icon(Icons.home_outlined, color: palette.textMutedColor),
                    selectedIcon: Icon(Icons.home, color: palette.primaryAccent),
                    label: 'Inicio',
                  ),
                  NavigationDestination(
                    key: const Key('nav_tab_tuner'),
                    icon: Icon(Icons.tune_outlined, color: palette.textMutedColor),
                    selectedIcon: Icon(Icons.tune, color: palette.primaryAccent),
                    label: 'Afinador',
                  ),
                  NavigationDestination(
                    key: const Key('nav_tab_learning'),
                    icon: Icon(Icons.school_outlined, color: palette.textMutedColor),
                    selectedIcon: Icon(Icons.school, color: palette.correctPitchColor),
                    label: 'Aprender',
                  ),
                  NavigationDestination(
                    key: const Key('nav_tab_studio'),
                    icon: Icon(Icons.fiber_manual_record_outlined, color: palette.textMutedColor),
                    selectedIcon: Icon(Icons.fiber_manual_record, color: palette.secondaryAccent),
                    label: 'Estudio',
                  ),
                  NavigationDestination(
                    key: const Key('nav_tab_library'),
                    icon: Icon(Icons.menu_book_outlined, color: palette.textMutedColor),
                    selectedIcon: Icon(Icons.menu_book, color: palette.primaryAccent),
                    label: 'Canciones',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
