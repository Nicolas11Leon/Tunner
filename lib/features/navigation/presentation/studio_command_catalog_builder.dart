import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../media_vault/domain/wav_pcm_codec.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../ear_training/presentation/blind_ear_trainer_modal.dart';
import '../../guided_lessons/presentation/task_quick_jump_modal.dart';
import '../../harmonic_tutor/presentation/harmonic_tutor_modal.dart';
import '../../harmonic_tutor/presentation/harmonic_tutor_view_model.dart';
import '../../instrument/presentation/universal_master_keyboard_widget.dart';
import '../../media_vault/presentation/media_vault_viewmodel.dart';
import '../../media_vault/presentation/media_vault_workspace_modal.dart';
import '../../metronome/presentation/tap_tempo_modal.dart';
import '../../modular_rack/presentation/modular_rack_viewmodel.dart';
import '../../score_editor/presentation/score_editor_modal.dart';
import '../../song_library/presentation/studio_assets_modals.dart';
import '../../tuner/presentation/tuner_viewmodel.dart';
import 'modals/studio_automations_modal.dart';
import 'modals/studio_customizations_modal.dart';
import 'pro_command_palette_modal.dart';

/// Constructor declarativo del catálogo de comandos de la Command Palette.
/// Desacopla la definición de los 25+ comandos ejecutables del ciclo de vida de [MainAppShell].
class StudioCommandCatalogBuilder {
  const StudioCommandCatalogBuilder._();

  static List<CommandItem> build({
    required BuildContext context,
    required TunerViewModel viewModel,
    required ModularRackViewModel modularRackViewModel,
    required MediaVaultViewModel mediaVaultViewModel,
    required void Function(int tabIndex) onNavigateToTab,
    required VoidCallback onOpenInstrumentSelector,
    required VoidCallback onToggleSidebar,
    required VoidCallback onToggleDualSplit,
    required VoidCallback onToggleTerminal,
    required VoidCallback onOpenShortcutsGuide,
    required VoidCallback onOpenMasterConsole,
  }) {
    return <CommandItem>[
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
        title: viewModel.isAudioRecording ? 'Detener Grabación' : 'Grabar Toma de Práctica',
        subtitle: 'Capturar audio en vivo para auto-evaluación',
        icon: Icons.fiber_manual_record,
        category: 'Grabación',
        shortcutLabel: 'R',
        onSelect: () {
          if (viewModel.isAudioRecording) {
            viewModel.stopPracticeRecording();
          } else {
            viewModel.startPracticeRecording();
          }
        },
      ),
      CommandItem(
        id: 'tap_tempo',
        title: 'Calcular Tap Tempo',
        subtitle: 'Abrir calibrador interactivo de tempo al compás de la música',
        icon: Icons.touch_app,
        category: 'Metrónomo',
        shortcutLabel: 'B / T',
        onSelect: () => TapTempoModal.show(context, viewModel),
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
        id: 'tab_home',
        title: 'Abrir Inicio y Dashboard General',
        subtitle: 'Métricas de práctica, tomas de audio y proyectos recientes',
        icon: Icons.dashboard_rounded,
        category: 'Navegación',
        shortcutLabel: '1 / F1 / Alt+1',
        onSelect: () => onNavigateToTab(0),
      ),
      CommandItem(
        id: 'tab_tuner',
        title: 'Abrir Afinador Estroboscópico',
        subtitle: 'Afinación de alta precisión de ±0.1 cents',
        icon: Icons.tune,
        category: 'Navegación',
        shortcutLabel: '2 / F2 / Alt+2',
        onSelect: () => onNavigateToTab(1),
      ),
      CommandItem(
        id: 'tab_learning',
        title: 'Abrir Tutor y Lecciones Guiadas',
        subtitle: 'Ejercicios interactivos con evaluación rushing/dragging',
        icon: Icons.school,
        category: 'Navegación',
        shortcutLabel: '3 / F3 / Alt+3',
        onSelect: () => onNavigateToTab(2),
      ),
      CommandItem(
        id: 'tab_studio',
        title: 'Abrir Rack Modular de Estudio',
        subtitle: 'Estudio multitarea con instrumentos y matriz de conexiones',
        icon: Icons.view_comfortable,
        category: 'Navegación',
        shortcutLabel: '4 / F4 / Alt+4',
        onSelect: () => onNavigateToTab(3),
      ),
      CommandItem(
        id: 'tab_library',
        title: 'Abrir Biblioteca de Canciones y Partituras',
        subtitle: 'Gestor y reproductor de partituras SMuFL',
        icon: Icons.menu_book,
        category: 'Navegación',
        shortcutLabel: '5 / F5 / Alt+5',
        onSelect: () => onNavigateToTab(4),
      ),
      CommandItem(
        id: 'tab_dj',
        title: 'Abrir Consola DJ Studio & Mezclador Stems',
        subtitle: 'Controlador de doble plato, ecualización y mezcla 4-stems',
        icon: Icons.album_rounded,
        category: 'Navegación',
        shortcutLabel: '6 / F6 / Alt+6',
        onSelect: () => onNavigateToTab(5),
      ),
      CommandItem(
        id: 'select_instrument',
        title: 'Cambiar Instrumento Musical Activo',
        subtitle: 'Seleccionar entre más de 60 instrumentos orquestales y contemporáneos',
        icon: Icons.piano,
        category: 'Instrumento',
        shortcutLabel: 'Cmd+I',
        onSelect: onOpenInstrumentSelector,
      ),
      CommandItem(
        id: 'master_keyboard',
        title: 'Abrir Teclado Maestro Universal',
        subtitle: 'Simulador táctil y polifónico de teclado con afinación tímbrica',
        icon: Icons.piano_rounded,
        category: 'Instrumento',
        shortcutLabel: 'K',
        onSelect: () => UniversalMasterKeyboardWidget.show(
          context,
          customization: modularRackViewModel.customization,
          onUpdated: modularRackViewModel.updateCustomization,
          audioSynthesizer: viewModel.audioSynthesizer,
        ),
      ),
      CommandItem(
        id: 'score_editor',
        title: 'Abrir Estudio de Edición de Partituras SMuFL',
        subtitle: 'Editor matricial de compases, notas, silencios y exportación MusicXML',
        icon: Icons.edit_note_rounded,
        category: 'Composición',
        shortcutLabel: 'E',
        onSelect: () => ScoreEditorModal.show(context),
      ),
      CommandItem(
        id: 'open_harmonic_tutor',
        title: 'Abrir Tutor Armónico (Entonación Justa & Batimentos)',
        subtitle: 'Afinación Justa (JI), roles armónicos y anulación de batimientos en vivo',
        icon: Icons.graphic_eq_rounded,
        category: 'Pedagogía & Conservatorio',
        onSelect: () {
          final tutorVm = HarmonicTutorViewModel(
            onPlayDroneSamples: (samples, sampleRate) {
              final wavBytes = const WavPcmCodec().encodeMono16Bit(
                Float64List.fromList(samples),
                sampleRate: sampleRate,
              );
              unawaited(viewModel.audioSynthesizer.startDroneLoop(wavBytes));
            },
            onStopDrone: () {
              unawaited(viewModel.audioSynthesizer.stopDroneLoop());
            },
          );
          void onTelemetry() {
            final freq = viewModel.telemetryListenable.value.frequency;
            if (freq > 0.0) {
              tutorVm.onPitchDetected(freq);
            }
          }
          viewModel.telemetryListenable.addListener(onTelemetry);
          HarmonicTutorModal.show(
            context,
            viewModel: tutorVm,
            palette: viewModel.currentPalette,
            isMicrophoneActive: () => viewModel.isRecording,
            onToggleMicrophone: viewModel.toggleRecording,
            microphoneListenable: viewModel,
          ).whenComplete(() {
            viewModel.telemetryListenable.removeListener(onTelemetry);
            tutorVm.dispose();
          });
        },
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
          onTaskSelected: (task) {
            viewModel.startPedagogicalTask(task);
            onNavigateToTab(2);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tarea iniciada: ${task.code.formatted} - ${task.title}'),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
      CommandItem(
        id: 'save_session',
        title: 'Guardar Estado de Sesión y Proyecto',
        subtitle: 'Persistir en almacenamiento local todo el estado de trabajo',
        icon: Icons.save_rounded,
        category: 'Archivo',
        shortcutLabel: 'Ctrl+S',
        onSelect: () {
          viewModel.savePersistedState();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Espacio de trabajo guardado correctamente en almacenamiento local.'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
      CommandItem(
        id: 'new_score',
        title: 'Crear Nueva Partitura en Blanco',
        subtitle: 'Iniciar una composición con armadura y métrica limpia',
        icon: Icons.note_add_rounded,
        category: 'Archivo',
        shortcutLabel: 'Ctrl+N',
        onSelect: () => StudioAssetsModals.showNewScoreDialog(
          context: context,
          viewModel: viewModel,
          onNavigateToTab: onNavigateToTab,
        ),
      ),
      CommandItem(
        id: 'import_file',
        title: 'Importar Archivo o Partitura',
        subtitle: 'Cargar archivos MusicXML, MIDI, .tunner o presets',
        icon: Icons.folder_open_rounded,
        category: 'Archivo',
        shortcutLabel: 'Ctrl+O',
        onSelect: () => StudioAssetsModals.showImportScoreDialog(
          context: context,
          viewModel: viewModel,
          onNavigateToTab: onNavigateToTab,
        ),
      ),
      CommandItem(
        id: 'toggle_sidebar',
        title: 'Alternar Barra Lateral y Explorador',
        subtitle: 'Mostrar u ocultar el panel de archivos y herramientas',
        icon: Icons.view_sidebar_rounded,
        category: 'Interfaz',
        shortcutLabel: 'Ctrl+B',
        onSelect: onToggleSidebar,
      ),
      CommandItem(
        id: 'toggle_dual_split',
        title: 'Alternar Vista Dividida Dual',
        subtitle: 'Trabajar en pantalla compartida con dos herramientas en paralelo',
        icon: Icons.vertical_split_rounded,
        category: 'Interfaz',
        shortcutLabel: 'Ctrl+Shift+D',
        onSelect: onToggleDualSplit,
      ),
      CommandItem(
        id: 'toggle_terminal',
        title: 'Alternar Terminal de Comandos OS',
        subtitle: 'Abrir consola Unix de audio DSP y kernel del sistema',
        icon: Icons.terminal_rounded,
        category: 'Sistema',
        shortcutLabel: 'F12 / Ctrl+~',
        onSelect: onToggleTerminal,
      ),
      CommandItem(
        id: 'open_shortcuts',
        title: 'Mapa de Atajos de Teclado',
        subtitle: 'Consultar la guía completa de comandos rápidos de producción',
        icon: Icons.keyboard_rounded,
        category: 'Ayuda',
        shortcutLabel: '?',
        onSelect: onOpenShortcutsGuide,
      ),
      CommandItem(
        id: 'open_customizations',
        title: 'Personalización Técnica DSP',
        subtitle: 'Ajustar motor de detección, precisión en cents y tasa de refresco FPS',
        icon: Icons.tune_rounded,
        category: 'Ajustes',
        onSelect: () => StudioCustomizationsModal.show(context, viewModel),
      ),
      CommandItem(
        id: 'open_automations',
        title: 'Panel de Automatizaciones de Estudio',
        subtitle: 'Programar rampas de BPM y rutinas de calentamiento',
        icon: Icons.access_time_rounded,
        category: 'Ajustes',
        onSelect: () => StudioAutomationsModal.show(context, viewModel),
      ),
      CommandItem(
        id: 'open_matrix',
        title: 'Matriz Universal de Enrutamiento de Audio',
        subtitle: 'Consola maestra con vúmetros dBFS, buffers y reloj maestro',
        icon: Icons.settings_input_component_rounded,
        category: 'Audio',
        shortcutLabel: 'Ctrl+Shift+I',
        onSelect: onOpenMasterConsole,
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
          if (viewModel.isAudioRecording) viewModel.stopPracticeRecording();
        },
      ),
      CommandItem(
        id: 'open_media_vault',
        title: 'Bóveda Multimedia (Media Vault)',
        subtitle: 'Línea de tiempo no lineal DAW, multipista y gestión de assets',
        icon: Icons.video_library_rounded,
        category: 'Producción',
        onSelect: () => MediaVaultWorkspaceModal.show(context, viewModel: mediaVaultViewModel),
      ),
      CommandItem(
        id: 'set_a4_432',
        title: 'Calibrar Referencia A4 = 432 Hz',
        subtitle: 'Ajustar frecuencia maestra del diapasón a 432.0 Hz',
        icon: Icons.tune,
        category: 'Afinación & DSP',
        onSelect: () => viewModel.setReferencePitch(432.0),
      ),
      CommandItem(
        id: 'set_a4_440',
        title: 'Calibrar Referencia A4 = 440 Hz (Estándar ISO 16)',
        subtitle: 'Restaurar frecuencia de concierto internacional a 440.0 Hz',
        icon: Icons.tune,
        category: 'Afinación & DSP',
        onSelect: () => viewModel.setReferencePitch(440.0),
      ),
      CommandItem(
        id: 'set_a4_442',
        title: 'Calibrar Referencia A4 = 442 Hz (Orquesta Sinfónica)',
        subtitle: 'Ajustar frecuencia filarmónica europea a 442.0 Hz',
        icon: Icons.tune,
        category: 'Afinación & DSP',
        onSelect: () => viewModel.setReferencePitch(442.0),
      ),
      for (int i = 0; i < viewModel.workspaceScores.length; i++)
        CommandItem(
          id: 'open_project_score_$i',
          title: 'Partitura del Proyecto: ${viewModel.workspaceScores[i].title}',
          subtitle: 'Cargar partitura de ${viewModel.workspaceScores[i].composer} en el atril SMuFL',
          icon: Icons.library_music_rounded,
          category: 'Archivos & Partituras',
          onSelect: () {
            viewModel.loadSongPackage(viewModel.workspaceScores[i]);
            onNavigateToTab(4);
          },
        ),
    ];
  }
}
