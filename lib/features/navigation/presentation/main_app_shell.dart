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
import '../../ear_training/presentation/blind_ear_trainer_modal.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../guided_lessons/presentation/task_quick_jump_modal.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import '../../drone/presentation/harmonic_drone_modal.dart';
import '../../song_library/presentation/studio_assets_modals.dart';
import '../../song_library/presentation/song_decomposer_modal.dart';
import '../../modular_rack/presentation/modular_rack_viewmodel.dart';
import '../../dj_console/presentation/dj_studio_workstation_view.dart';
import '../../dj_console/presentation/dj_console_view_model.dart';
import '../../../core/design_system/molecules/studio_automations_modal.dart';
import '../../../core/design_system/molecules/studio_customizations_modal.dart';
import '../../../core/design_system/molecules/studio_settings_modal.dart';

/// Intenciones para el sistema de atajos de teclado de grado profesional y memoria muscular (DAWs).
class TogglePlayIntent extends Intent {
  const TogglePlayIntent();
}

class RewindToStartIntent extends Intent {
  const RewindToStartIntent();
}

class ToggleCycleLoopIntent extends Intent {
  const ToggleCycleLoopIntent();
}

class NudgeMeasureBackIntent extends Intent {
  const NudgeMeasureBackIntent();
}

class NudgeMeasureForwardIntent extends Intent {
  const NudgeMeasureForwardIntent();
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

class OpenEarTrainerIntent extends Intent {
  const OpenEarTrainerIntent();
}

class OpenChordAnalyzerIntent extends Intent {
  const OpenChordAnalyzerIntent();
}

class JumpToTaskIntent extends Intent {
  const JumpToTaskIntent();
}

class SwitchTabIntent extends Intent {
  final int tabIndex;
  const SwitchTabIntent(this.tabIndex);
}

/// Contenedor principal de navegación de Tunner (MainAppShell).
/// Gestiona la transición limpia entre el Dashboard de Inicio, el Afinador,
/// el Tutor de Aprendizaje, el Estudio de Grabación y la Biblioteca de Canciones,
/// integrando el Quick Action Dock y el despachador de atajos globales de memoria muscular.
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
  late final ModularRackViewModel _modularRackViewModel;
  late final DjConsoleViewModel _djConsoleViewModel;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _modularRackViewModel = ModularRackViewModel();
    _djConsoleViewModel = DjConsoleViewModel();
  }

  @override
  void dispose() {
    _modularRackViewModel.dispose();
    _djConsoleViewModel.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 6) {
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
        shortcutLabel: 'Espacio / M',
        onSelect: () => viewModel.toggleMetronome(),
      ),
      CommandItem(
        id: 'rewind_start',
        title: 'Rebobinar al Inicio',
        subtitle: 'Volver al compás 1 de la partitura',
        icon: Icons.skip_previous,
        category: 'Transporte',
        shortcutLabel: 'Enter / Return',
        onSelect: () => viewModel.resetSongState(),
      ),
      CommandItem(
        id: 'toggle_loop',
        title: 'Alternar Modo Bucle / Práctica',
        subtitle: 'Repetición cíclica continua de la partitura',
        icon: Icons.repeat,
        category: 'Transporte',
        shortcutLabel: 'C',
        onSelect: () => viewModel.togglePracticeMode(),
      ),
      CommandItem(
        id: 'nudge_prev',
        title: 'Retroceder Compás (-1 Compás)',
        subtitle: 'Desplazar el cursor al compás anterior',
        icon: Icons.arrow_back,
        category: 'Navegación',
        shortcutLabel: ',',
        onSelect: () => viewModel.previousMeasure(),
      ),
      CommandItem(
        id: 'nudge_next',
        title: 'Avanzar Compás (+1 Compás)',
        subtitle: 'Desplazar el cursor al compás siguiente',
        icon: Icons.arrow_forward,
        category: 'Navegación',
        shortcutLabel: '.',
        onSelect: () => viewModel.nextMeasure(),
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
        id: 'open_ear_trainer',
        title: 'Entrenador Auditivo a Ciegas (Intervalos)',
        subtitle: 'Práctica de discriminación auditiva y afinación sin apoyo visual',
        icon: Icons.hearing,
        category: 'Entrenamiento',
        shortcutLabel: 'Shift+E',
        onSelect: () => BlindEarTrainerModal.show(context, viewModel),
      ),
      CommandItem(
        id: 'open_chord_analyzer',
        title: 'Visualizador Polifónico de Acordes y Armónicos',
        subtitle: 'Descomposición de acordes en tiempo real y serie armónica H1-H8',
        icon: Icons.piano,
        category: 'Armonía',
        shortcutLabel: 'Shift+C',
        onSelect: () => ChordAnalyzerModal.show(context, viewModel),
      ),
      CommandItem(
        id: 'jump_to_task',
        title: 'Salto Rápido a Tarea (TTC)',
        subtitle: 'Buscar y saltar al instante a cualquier ejercicio por código o palabra',
        icon: Icons.flash_on,
        category: 'Navegación',
        shortcutLabel: 'J',
        onSelect: () => TaskQuickJumpModal.show(
          context: context,
          palette: viewModel.currentPalette,
        ),
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

  void _parseAndSetBpm(String rawInput, TunerViewModel viewModel) {
    final parts = rawInput.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      final val = int.tryParse(parts[1]);
      if (val != null && val >= 30 && val <= 300) {
        viewModel.updateBpm(val);
        return;
      }
    }
    viewModel.toggleMetronome();
  }

  void _parseAndSetPitch(String rawInput, TunerViewModel viewModel) {
    final parts = rawInput.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      final val = double.tryParse(parts[1]);
      if (val != null && val >= 380 && val <= 480) {
        viewModel.setReferencePitch(val);
      }
    }
  }

  List<PromptSuggestion> _buildPromptSuggestions(TunerViewModel viewModel) {
    return [
      PromptSuggestion(
        id: 'cmd_tuner',
        trigger: '/',
        command: '/afinar',
        title: 'Afinador Estroboscópico de Precisión',
        description: 'Afinación en tiempo real con aguja centesimal ±0.1c',
        category: 'Afinación',
        shortcut: 'A',
        icon: Icons.tune_rounded,
        onExecute: (_) => _navigateToTab(1),
      ),
      PromptSuggestion(
        id: 'cmd_metro',
        trigger: '/',
        command: '/metro',
        title: viewModel.isMetronomeActive ? 'Pausar Metrónomo' : 'Iniciar Metrónomo Continuo',
        description: 'Alternar pulso rítmico acústico a ${viewModel.bpm.round()} BPM',
        category: 'Transporte',
        shortcut: 'Espacio',
        icon: Icons.access_time_rounded,
        onExecute: (_) => viewModel.toggleMetronome(),
      ),
      PromptSuggestion(
        id: 'cmd_bpm',
        trigger: '/',
        command: '/bpm',
        title: 'Ajustar Tempo (BPM)',
        description: 'Establecer tempo del metrónomo (ej. /bpm 120)',
        category: 'Metrónomo',
        shortcut: '[ / ]',
        icon: Icons.speed_rounded,
        onExecute: (raw) => _parseAndSetBpm(raw, viewModel),
      ),
      PromptSuggestion(
        id: 'cmd_calibrar',
        trigger: '/',
        command: '/calibrar',
        title: 'Calibrar Tono A4 (Hz)',
        description: 'Calibrar frecuencia de referencia (ej. /calibrar 442)',
        category: 'Afinación',
        shortcut: 'Alt+↑',
        icon: Icons.waves_rounded,
        onExecute: (raw) => _parseAndSetPitch(raw, viewModel),
      ),
      PromptSuggestion(
        id: 'cmd_record',
        trigger: '/',
        command: '/grabar',
        title: viewModel.isRecording ? 'Detener Grabación WAV' : 'Grabar Toma de Práctica',
        description: 'Capturar audio en vivo para autoevaluación',
        category: 'Grabación',
        shortcut: 'R',
        icon: Icons.fiber_manual_record_rounded,
        onExecute: (_) {
          if (viewModel.isRecording) {
            viewModel.stopPracticeRecording();
          } else {
            viewModel.startPracticeRecording();
          }
        },
      ),
      PromptSuggestion(
        id: 'cmd_spectrogram',
        trigger: '/',
        command: '/espectrograma',
        title: 'Espectrograma FFT en Vivo',
        description: 'Distribución armónica y densidad espectral',
        category: 'Laboratorio',
        icon: Icons.analytics_outlined,
        onExecute: (_) => HarmonicSpectrogramModal.show(context),
      ),
      PromptSuggestion(
        id: 'cmd_drone',
        trigger: '/',
        command: '/dron',
        title: 'Dron Armónico & Temperamentos',
        description: 'Tono sinusoidal continuo para práctica pura',
        category: 'Afinación',
        icon: Icons.volume_up_outlined,
        onExecute: (_) => HarmonicDroneModal.show(context, viewModel),
      ),
      PromptSuggestion(
        id: 'cmd_chords',
        trigger: '/',
        command: '/acordes',
        title: 'Analizador Polifónico de Acordes',
        description: 'Detección simultánea de tríadas y extensiones',
        category: 'Laboratorio',
        shortcut: 'Shift+C',
        icon: Icons.stacked_bar_chart_rounded,
        onExecute: (_) => ChordAnalyzerModal.show(context, viewModel),
      ),
      PromptSuggestion(
        id: 'cmd_ear',
        trigger: '/',
        command: '/oido',
        title: 'Entrenador Auditivo a Ciegas',
        description: 'Discriminación de intervalos armónicos',
        category: 'Conservatorio',
        shortcut: 'Shift+E',
        icon: Icons.hearing_outlined,
        onExecute: (_) => BlindEarTrainerModal.show(context, viewModel),
      ),
      PromptSuggestion(
        id: 'cmd_rack',
        trigger: '/',
        command: '/rack',
        title: 'Rack Modular de Pedales DSP',
        description: 'Estudio de efectos encadenados en tiempo real',
        category: 'Estudio',
        shortcut: '4',
        icon: Icons.view_agenda_outlined,
        onExecute: (_) => _navigateToTab(3),
      ),
      PromptSuggestion(
        id: 'cmd_scores',
        trigger: '/',
        command: '/partituras',
        title: 'Biblioteca & Notación MusicXML',
        description: 'Lector, visor interactivo y stems de obras',
        category: 'Composición',
        shortcut: '5',
        icon: Icons.menu_book_outlined,
        onExecute: (_) => _navigateToTab(4),
      ),
      PromptSuggestion(
        id: 'cmd_instrument',
        trigger: '/',
        command: '/instrumento',
        title: 'Seleccionar Instrumento Musical',
        description: 'Cambiar familia, clave y transposición',
        category: 'Configuración',
        shortcut: 'Ctrl+I',
        icon: Icons.music_note_rounded,
        onExecute: (_) => _openInstrumentSelector(viewModel),
      ),
      PromptSuggestion(
        id: 'cmd_mute',
        trigger: '/',
        command: '/mute',
        title: 'Silencio de Pánico (Panic Mute)',
        description: 'Detener metrónomo y grabación de inmediato',
        category: 'Transporte',
        shortcut: '0',
        icon: Icons.volume_off_rounded,
        onExecute: (_) {
          if (viewModel.isMetronomeActive) viewModel.toggleMetronome();
          if (viewModel.isRecording) viewModel.stopPracticeRecording();
        },
      ),
      PromptSuggestion(
        id: 'cmd_import',
        trigger: '/',
        command: '/importar',
        title: 'Importar Archivo Universal',
        description: 'Importar archivos MusicXML, MIDI, ABC, PDF o WAV',
        category: 'Archivos',
        shortcut: 'Ctrl+O',
        icon: Icons.file_open_outlined,
        onExecute: (_) => StudioAssetsModals.showImportScoreDialog(
          context: context,
          viewModel: viewModel,
          onNavigateToTab: _navigateToTab,
        ),
      ),
      PromptSuggestion(
        id: 'cmd_nueva_partitura',
        trigger: '/',
        command: '/nueva',
        title: 'Crear Nueva Partitura',
        description: 'Inicializar partitura en blanco en el espacio de trabajo',
        category: 'Composición',
        shortcut: 'Ctrl+N',
        icon: Icons.post_add_rounded,
        onExecute: (_) => StudioAssetsModals.showNewScoreDialog(
          context: context,
          viewModel: viewModel,
          onNavigateToTab: _navigateToTab,
        ),
      ),
      PromptSuggestion(
        id: 'cmd_save_preset',
        trigger: '/',
        command: '/preset',
        title: 'Guardar Preset de Afinación',
        description: 'Almacenar afinación actual en biblioteca local',
        category: 'Afinación',
        icon: Icons.bookmark_add_outlined,
        onExecute: (_) => StudioAssetsModals.showNewTuningPresetDialog(
          context: context,
          viewModel: viewModel,
        ),
      ),
      PromptSuggestion(
        id: 'cmd_help',
        trigger: '/',
        command: '/help',
        title: 'Ayuda Universal & Matriz de Comandos',
        description: 'Catálogo exhaustivo de comandos y atajos de memoria muscular',
        category: 'Sistema',
        shortcut: '?',
        icon: Icons.help_outline_rounded,
        onExecute: (_) => _openShortcutsGuide(viewModel),
      ),

      // Accesos a Módulos con @
      PromptSuggestion(
        id: 'mod_tuner',
        trigger: '@',
        command: '@afinador',
        title: 'Espacio de Afinación Orquestal',
        description: 'Navegar al afinador estroboscópico',
        category: 'Módulos',
        shortcut: 'Alt+1',
        icon: Icons.tune_rounded,
        onExecute: (_) => _navigateToTab(1),
      ),
      PromptSuggestion(
        id: 'mod_metronome',
        trigger: '@',
        command: '@metronomo',
        title: 'Metrónomo Determinista',
        description: 'Navegar al panel de control de tempo y pulso',
        category: 'Módulos',
        shortcut: 'Alt+0',
        icon: Icons.access_time_rounded,
        onExecute: (_) => _navigateToTab(0),
      ),
      PromptSuggestion(
        id: 'mod_studio',
        trigger: '@',
        command: '@rack',
        title: 'Espacio de Producción & Rack Modular',
        description: 'Navegar a la consola modular de efectos',
        category: 'Módulos',
        shortcut: 'Alt+4',
        icon: Icons.view_agenda_outlined,
        onExecute: (_) => _navigateToTab(3),
      ),
      PromptSuggestion(
        id: 'mod_conservatory',
        trigger: '@',
        command: '@conservatorio',
        title: 'Espacio de Aprendizaje & Pedagogía',
        description: 'Navegar al tutor guiado de compás y entonación',
        category: 'Módulos',
        shortcut: 'Alt+3',
        icon: Icons.school_outlined,
        onExecute: (_) => _navigateToTab(2),
      ),
      PromptSuggestion(
        id: 'mod_scores',
        trigger: '@',
        command: '@partituras',
        title: 'Espacio de Biblioteca & Partituras',
        description: 'Navegar al visor de notación musical',
        category: 'Módulos',
        shortcut: 'Alt+5',
        icon: Icons.menu_book_outlined,
        onExecute: (_) => _navigateToTab(4),
      ),
      PromptSuggestion(
        id: 'mod_acoustics',
        trigger: '@',
        command: '@laboratorio',
        title: 'Espacio de Laboratorio Acústico',
        description: 'Abrir espectrograma FFT armónico',
        category: 'Módulos',
        icon: Icons.analytics_outlined,
        onExecute: (_) => HarmonicSpectrogramModal.show(context),
      ),
      PromptSuggestion(
        id: 'mod_chords',
        trigger: '@',
        command: '@acordes',
        title: 'Analizador Polifónico de Acordes',
        description: 'Abrir analizador de acordes simultáneos',
        category: 'Módulos',
        icon: Icons.stacked_bar_chart_rounded,
        onExecute: (_) => ChordAnalyzerModal.show(context, viewModel),
      ),
    ];
  }

  String _buildCurrentBreadcrumb() {
    switch (_currentIndex) {
      case 0:
        return 'tunner / Inicio / Dashboard de Rendimiento';
      case 1:
        return 'tunner / Afinación / Afinador Estroboscópico de Precisión';
      case 2:
        return 'tunner / Conservatorio / Tutor de Compás & Detección Rushing';
      case 3:
        return 'tunner / Estudio & Grabación / Rack Modular de Efectos DSP';
      case 4:
        return 'tunner / Biblioteca / Editor & Reproductor MusicXML';
      case 5:
        return 'tunner / Consola DJ Studio / Mezclador de Grado Club & 4-Stems';
      default:
        return 'tunner / Espacio de Trabajo Activo';
    }
  }

  String _buildCurrentActiveItemId() {
    switch (_currentIndex) {
      case 0:
        return 'item_home';
      case 1:
        return 'item_tuner';
      case 2:
        return 'item_learning';
      case 3:
        return 'item_rack';
      case 4:
        return 'item_composition';
      case 5:
        return 'item_dj';
      default:
        return 'item_home';
    }
  }

  List<StudioTreeSection> _buildNavigationSections(TunerViewModel viewModel) {
    final palette = viewModel.currentPalette;

    return [
      // SECCIÓN 1: DOCUMENTOS DEL PROYECTO (100% PURO PARA ASSETS DEL USUARIO)
      StudioTreeSection(
        title: 'Documentos del Proyecto',
        folders: [
          // 1. Partituras del Proyecto
          StudioTreeFolder(
            id: 'folder_scores',
            title: 'Partituras & Notación (${viewModel.workspaceScores.length})',
            accentColor: palette.primaryAccent,
            headerAction: IconButton(
              icon: Icon(Icons.add, size: 13, color: palette.primaryAccent),
              tooltip: 'Crear nueva partitura',
              splashRadius: 10,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              onPressed: () => StudioAssetsModals.showNewScoreDialog(
                context: context,
                viewModel: viewModel,
                onNavigateToTab: _navigateToTab,
              ),
            ),
            items: viewModel.workspaceScores
                .map(
                  (score) => StudioTreeItem(
                    id: score.id,
                    title: score.title,
                    icon: Icons.article_outlined,
                    timestamp: '${score.defaultBpm} BPM',
                    onSelect: () {
                      viewModel.loadSongPackage(score);
                      _navigateToTab(4);
                    },
                  ),
                )
                .toList(),
            emptyActions: [
              StudioTreeItem(
                id: 'act_new_score',
                title: '[+] Nueva Partitura en Blanco...',
                icon: Icons.note_add_outlined,
                onSelect: () => StudioAssetsModals.showNewScoreDialog(
                  context: context,
                  viewModel: viewModel,
                  onNavigateToTab: _navigateToTab,
                ),
              ),
              StudioTreeItem(
                id: 'act_imp_score',
                title: '[⬇] Importar MusicXML / Archivo...',
                icon: Icons.file_download_outlined,
                onSelect: () => StudioAssetsModals.showImportScoreDialog(
                  context: context,
                  viewModel: viewModel,
                  onNavigateToTab: _navigateToTab,
                ),
              ),
            ],
          ),

          // 2. Tomas de Grabación WAV (Solo audios y tomas grabadas)
          StudioTreeFolder(
            id: 'folder_studio',
            title: 'Tomas de Audio & WAV (${viewModel.recordingHistory.length})',
            accentColor: Colors.redAccent,
            headerAction: IconButton(
              icon: Icon(Icons.fiber_manual_record, size: 12, color: Colors.redAccent),
              tooltip: viewModel.isRecording ? 'Detener toma' : 'Iniciar nueva toma',
              splashRadius: 10,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              onPressed: () {
                if (viewModel.isRecording) {
                  viewModel.stopPracticeRecording();
                } else {
                  viewModel.startPracticeRecording();
                }
              },
            ),
            items: viewModel.recordingHistory
                .map(
                  (rec) => StudioTreeItem(
                    id: rec.id,
                    title: rec.songTitle,
                    icon: Icons.audio_file_outlined,
                    timestamp: '${rec.duration.inSeconds}s',
                    onSelect: () => _navigateToTab(3),
                  ),
                )
                .toList(),
            emptyActions: [
              StudioTreeItem(
                id: 'act_new_rec',
                title: viewModel.isRecording ? 'Detener Grabación WAV' : '[+] Iniciar Nueva Toma WAV...',
                icon: Icons.fiber_manual_record_outlined,
                badge: viewModel.isRecording ? 'REC' : null,
                badgeColor: Colors.redAccent,
                onSelect: () {
                  if (viewModel.isRecording) {
                    viewModel.stopPracticeRecording();
                  } else {
                    viewModel.startPracticeRecording();
                  }
                },
              ),
            ],
          ),

          // 3. Presets de Afinación Personalizados
          StudioTreeFolder(
            id: 'folder_tunings',
            title: 'Presets de Afinación (${viewModel.customTuningPresets.length})',
            accentColor: palette.secondaryAccent,
            headerAction: IconButton(
              icon: Icon(Icons.add, size: 13, color: palette.secondaryAccent),
              tooltip: 'Guardar preset',
              splashRadius: 10,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              onPressed: () => StudioAssetsModals.showNewTuningPresetDialog(
                context: context,
                viewModel: viewModel,
              ),
            ),
            items: viewModel.customTuningPresets
                .map(
                  (preset) => StudioTreeItem(
                    id: preset.id,
                    title: preset.name,
                    icon: Icons.bookmark_outline_rounded,
                    timestamp: '${preset.referencePitchHz.toInt()} Hz',
                    onSelect: () {
                      viewModel.applyTuningPreset(preset);
                      _navigateToTab(1);
                    },
                  ),
                )
                .toList(),
            emptyActions: [
              StudioTreeItem(
                id: 'act_new_preset',
                title: '[+] Guardar Calibración A4 Actual...',
                icon: Icons.bookmark_add_outlined,
                onSelect: () => StudioAssetsModals.showNewTuningPresetDialog(
                  context: context,
                  viewModel: viewModel,
                ),
              ),
            ],
          ),
        ],
      ),

      // SECCIÓN 2: SUITE DE HERRAMIENTAS (CLASIFICADAS POR DISCIPLINA TÉCNICA)
      StudioTreeSection(
        title: 'Suite de Herramientas',
        folders: [
          // 1. Afinación & Entonación
          StudioTreeFolder(
            id: 'folder_tuning_tools',
            title: 'Afinación & Entonación',
            accentColor: Colors.blueAccent,
            items: [
              StudioTreeItem(
                id: 'item_tuner',
                title: 'Afinador Estroboscópico Pro',
                icon: Icons.tune_rounded,
                timestamp: '${viewModel.referencePitch.toInt()} Hz',
                statusDotColor: Colors.blueAccent,
                hasDragHandle: _currentIndex == 1,
                onSelect: () => _navigateToTab(1),
              ),
              StudioTreeItem(
                id: 'item_drone',
                title: 'Dron Armónico & Temperamentos',
                icon: Icons.volume_up_outlined,
                timestamp: 'Tono puro',
                onSelect: () => HarmonicDroneModal.show(context, viewModel),
              ),
              StudioTreeItem(
                id: 'item_home',
                title: 'Dashboard de Rendimiento',
                icon: Icons.dashboard_outlined,
                timestamp: 'DSP Ready',
                hasDragHandle: _currentIndex == 0,
                onSelect: () => _navigateToTab(0),
              ),
            ],
          ),

          // 2. Análisis Acústico & Laboratorio
          StudioTreeFolder(
            id: 'folder_acoustics',
            title: 'Análisis Acústico & Laboratorio',
            accentColor: Colors.amberAccent,
            items: [
              StudioTreeItem(
                id: 'item_spectrogram',
                title: 'Espectrograma FFT en Vivo',
                icon: Icons.analytics_outlined,
                timestamp: '4096 bins',
                onSelect: () => HarmonicSpectrogramModal.show(context),
              ),
              StudioTreeItem(
                id: 'item_chords',
                title: 'Analizador Polifónico de Acordes',
                icon: Icons.stacked_bar_chart_rounded,
                timestamp: 'Shift+C',
                onSelect: () => ChordAnalyzerModal.show(context, viewModel),
              ),
            ],
          ),

          // 3. Pedagogía & Conservatorio
          StudioTreeFolder(
            id: 'folder_conservatory',
            title: 'Pedagogía & Conservatorio',
            accentColor: Colors.tealAccent,
            items: [
              StudioTreeItem(
                id: 'item_learning',
                title: 'Tutor de Compás y Rushing',
                icon: Icons.school_outlined,
                timestamp: '${viewModel.bpm.round()} BPM',
                hasDragHandle: _currentIndex == 2,
                onSelect: () => _navigateToTab(2),
              ),
              StudioTreeItem(
                id: 'item_ear',
                title: 'Entrenador Auditivo a Ciegas',
                icon: Icons.hearing_outlined,
                timestamp: 'Shift+E',
                onSelect: () => BlindEarTrainerModal.show(context, viewModel),
              ),
            ],
          ),

          // 4. Producción & Enrutamiento
          StudioTreeFolder(
            id: 'folder_production',
            title: 'Producción & Enrutamiento',
            accentColor: Colors.purpleAccent,
            items: [
              StudioTreeItem(
                id: 'item_rack',
                title: 'Rack Modular de Pedales DSP',
                icon: Icons.view_agenda_outlined,
                timestamp: 'DSP Rack',
                statusDotColor: Colors.purpleAccent,
                hasDragHandle: _currentIndex == 3,
                onSelect: () => _navigateToTab(3),
              ),
              StudioTreeItem(
                id: 'item_dj',
                title: 'Consola DJ Pro Studio',
                icon: Icons.album_rounded,
                timestamp: 'Club Mixer',
                statusDotColor: Colors.cyanAccent,
                hasDragHandle: _currentIndex == 5,
                onSelect: () => _navigateToTab(5),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // Transporte Universal (Ableton / Logic / Pro Tools)
        const SingleActivator(LogicalKeyboardKey.space): const TogglePlayIntent(),
        const SingleActivator(LogicalKeyboardKey.enter): const RewindToStartIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const RewindToStartIntent(),
        const SingleActivator(LogicalKeyboardKey.keyC): const ToggleCycleLoopIntent(),
        const SingleActivator(LogicalKeyboardKey.comma): const NudgeMeasureBackIntent(),
        const SingleActivator(LogicalKeyboardKey.period): const NudgeMeasureForwardIntent(),

        // Grabación y Tap Tempo
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

        // Modales de sistema y búsqueda global (Cmd+K y Cmd+F)
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): const OpenCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const OpenCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const OpenCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const OpenCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyI, control: true): const OpenInstrumentSelectorIntent(),
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true): const OpenInstrumentSelectorIntent(),
        const SingleActivator(LogicalKeyboardKey.slash, shift: true): const OpenShortcutsGuideIntent(),
        const SingleActivator(LogicalKeyboardKey.keyE, shift: true): const OpenEarTrainerIntent(),
        const SingleActivator(LogicalKeyboardKey.keyC, shift: true): const OpenChordAnalyzerIntent(),
        const SingleActivator(LogicalKeyboardKey.keyJ): const JumpToTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.keyJ, control: true): const JumpToTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.keyJ, meta: true): const JumpToTaskIntent(),

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
          RewindToStartIntent: CallbackAction<RewindToStartIntent>(
            onInvoke: (_) {
              viewModel.resetSongState();
              viewModel.selectMeasure(0);
              return null;
            },
          ),
          ToggleCycleLoopIntent: CallbackAction<ToggleCycleLoopIntent>(
            onInvoke: (_) => viewModel.togglePracticeMode(),
          ),
          NudgeMeasureBackIntent: CallbackAction<NudgeMeasureBackIntent>(
            onInvoke: (_) => viewModel.previousMeasure(),
          ),
          NudgeMeasureForwardIntent: CallbackAction<NudgeMeasureForwardIntent>(
            onInvoke: (_) => viewModel.nextMeasure(),
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
          OpenEarTrainerIntent: CallbackAction<OpenEarTrainerIntent>(
            onInvoke: (_) => BlindEarTrainerModal.show(context, viewModel),
          ),
          OpenChordAnalyzerIntent: CallbackAction<OpenChordAnalyzerIntent>(
            onInvoke: (_) => ChordAnalyzerModal.show(context, viewModel),
          ),
          JumpToTaskIntent: CallbackAction<JumpToTaskIntent>(
            onInvoke: (_) => TaskQuickJumpModal.show(
              context: context,
              palette: viewModel.currentPalette,
            ),
          ),
          SwitchTabIntent: CallbackAction<SwitchTabIntent>(
            onInvoke: (intent) => _navigateToTab(intent.tabIndex),
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              final viewportContent = IndexedStack(
                index: _currentIndex,
                children: [
                  HomeDashboardScreen(onNavigateToTab: _navigateToTab),
                  const TunerScreen(),
                  LearningPracticeWorkspaceView(
                    viewModel: viewModel,
                    palette: palette,
                    onOpenInstrumentModal: () => _openInstrumentSelector(viewModel),
                  ),
                  ModularStudioRackView(viewModel: _modularRackViewModel),
                  CompositionNotationWorkspaceView(
                    viewModel: viewModel,
                    palette: palette,
                    onOpenLibraryModal: () => StudioAssetsModals.showImportScoreDialog(
                      context: context,
                      viewModel: viewModel,
                      onNavigateToTab: _navigateToTab,
                    ),
                    onOpenMixerModal: () => SongDecomposerModal.show(context, viewModel),
                  ),
                  DjStudioWorkstationView(viewModel: _djConsoleViewModel),
                ],
              );

              if (isDesktop) {
                return StudioDesktopAppShell(
                  currentBreadcrumb: _buildCurrentBreadcrumb(),
                  navigationSections: _buildNavigationSections(viewModel),
                  activeItemId: _buildCurrentActiveItemId(),
                  currentTabIndex: _currentIndex,
                  activeView: viewportContent,
                  secondaryView: ModularStudioRackView(viewModel: _modularRackViewModel),
                  onOpenSearch: () => _openCommandPalette(viewModel),
                  onOpenShortcuts: () => _openShortcutsGuide(viewModel),
                  onOpenHelp: () => _openShortcutsGuide(viewModel),
                  onOpenAutomations: () => StudioAutomationsModal.show(context, viewModel),
                  onOpenCustomizations: () => StudioCustomizationsModal.show(context, viewModel),
                  onOpenSettings: () => StudioSettingsModal.show(context, viewModel),
                  onMenuNewScore: () => StudioAssetsModals.showNewScoreDialog(
                    context: context,
                    viewModel: viewModel,
                    onNavigateToTab: _navigateToTab,
                  ),
                  onMenuImportFile: () => StudioAssetsModals.showImportScoreDialog(
                    context: context,
                    viewModel: viewModel,
                    onNavigateToTab: _navigateToTab,
                  ),
                  onMenuNewPreset: () => StudioAssetsModals.showNewTuningPresetDialog(
                    context: context,
                    viewModel: viewModel,
                  ),
                  onMenuSaveWorkspace: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Espacio de trabajo guardado correctamente en almacenamiento local.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  onMenuResetWorkspace: () => viewModel.resetSongState(),
                  onMenuToggleRack: () => _navigateToTab(3),
                  onNavigateToTabIndex: (idx) => _navigateToTab(idx),
                  onOpenSpectrogram: () => HarmonicSpectrogramModal.show(context),
                  promptSuggestions: _buildPromptSuggestions(viewModel),
                  isRecording: viewModel.isRecording,
                  onToggleRecording: () {
                    if (viewModel.isRecording) {
                      viewModel.stopPracticeRecording();
                    } else {
                      viewModel.startPracticeRecording();
                    }
                  },
                  customStatusItems: [
                    Text(
                      'A4 = ${viewModel.referencePitch.toInt()} Hz',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 9.0,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'TEMPO: ${viewModel.bpm.round()} BPM',
                      style: TextStyle(
                        color: palette.textMutedColor,
                        fontSize: 9.0,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'INSTRUMENTO: ${viewModel.activeInstrument.name.toUpperCase()}',
                      style: TextStyle(
                        color: palette.primaryAccent,
                        fontSize: 9.0,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  sidebarFooter: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: palette.cardBackground,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: palette.primaryAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            viewModel.activeInstrument.clef.symbol,
                            style: TextStyle(
                              color: palette.primaryAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                viewModel.activeInstrument.name,
                                style: TextStyle(
                                  color: palette.textColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${viewModel.activeInstrument.family.displayName} • ${viewModel.activeInstrument.key.displayName}',
                                style: TextStyle(
                                  color: palette.textMutedColor,
                                  fontSize: 9,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _openInstrumentSelector(viewModel),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.primaryAccent,
                            side: BorderSide(
                              color: palette.primaryAccent.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('Cambiar', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Vista móvil / compacta
              return Scaffold(
                backgroundColor: palette.scaffoldBackground,
                body: Stack(
                  children: [
                    viewportContent,
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
              );
            },
          ),
        ),
      ),
    );
  }
}
