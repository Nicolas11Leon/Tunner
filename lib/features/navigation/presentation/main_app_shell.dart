import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/studio_composition_root.dart';
import '../../tuner_viewmodel.dart';
import 'studio_keyboard_intents.dart';
import 'studio_prompt_suggestions_builder.dart';
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
import 'modals/studio_automations_modal.dart';
import 'modals/studio_customizations_modal.dart';
import 'modals/studio_settings_modal.dart';
import '../../../core/file_system/domain/i_studio_workspace_file_system.dart';
import '../../../core/file_system/domain/studio_file_system_node.dart';
import '../../../core/file_system/domain/studio_file_type.dart';
import '../../../core/file_system/presentation/studio_vscode_explorer_widget.dart';
import '../../../core/terminal/application/tunner_os_kernel.dart';
import '../../../core/terminal/presentation/tunner_os_terminal_drawer.dart';
import '../../../core/audio/infrastructure/studio_master_clock_service.dart';
import '../../../core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../../../core/audio/infrastructure/studio_audio_engine.dart';
import '../../../core/audio/infrastructure/studio_audio_hardware_persistence_service.dart';
import '../../../core/audio/infrastructure/studio_audio_input_engine.dart';
import '../../../core/audio/presentation/studio_master_hardware_console_widget.dart';
import '../../../core/audio/presentation/studio_master_meter_mini_pill_widget.dart';

export 'studio_keyboard_intents.dart';
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
  late final IStudioWorkspaceFileSystem _fileSystemService;
  late final StudioAudioDeviceMatrixService _audioMatrixService;
  StudioAudioInputEngine? _ownedAudioInput;
  bool _ownsAudioMatrixService = false;
  bool _ownsClockService = false;
  late final StudioMasterClockService _masterClockService;
  bool _isTerminalOpen = false;
  late final TunnerOsKernel _terminalKernel;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    StudioCompositionRoot? root;
    try {
      root = context.read<StudioCompositionRoot>();
    } catch (_) {
      root = null;
    }

    _modularRackViewModel = root != null
        ? root.createModularRackViewModel()
        : ModularRackViewModel();
    _djConsoleViewModel = root != null
        ? root.createDjConsoleViewModel()
        : DjConsoleViewModel();

    _fileSystemService = root?.fileSystemService ?? NoOpStudioWorkspaceFileSystem();
    _fileSystemService.onOpenFile = _handleOpenFile;
    _fileSystemService.initializeWorkspace();

    TunerViewModel? existingVm;
    try {
      existingVm = context.read<TunerViewModel>();
    } catch (_) {
      existingVm = null;
    }

    if (root != null) {
      _audioMatrixService = root.audioMatrixService;
      _ownsAudioMatrixService = false;
      _masterClockService = root.masterClockService;
      _ownsClockService = false;
    } else if (existingVm?.audioDeviceMatrixService != null) {
      _audioMatrixService = existingVm!.audioDeviceMatrixService!;
      _ownsAudioMatrixService = false;
      _masterClockService = StudioMasterClockService(initialBpm: 120.0);
      _ownsClockService = true;
    } else {
      final audioEngine = StudioAudioEngine();
      final audioInput = StudioAudioInputEngine();
      final audioPersistence = StudioAudioHardwarePersistenceService();
      _ownedAudioInput = audioInput;
      _audioMatrixService = StudioAudioDeviceMatrixService(
        outputEngine: audioEngine,
        inputEngine: audioInput,
        persistenceService: audioPersistence,
      );
      _ownsAudioMatrixService = true;
      _masterClockService = StudioMasterClockService(initialBpm: 120.0);
      _ownsClockService = true;
    }
    _masterClockService.onPlayAll = () {
      final vm = context.read<TunerViewModel>();
      if (!vm.isMetronomeActive) vm.toggleMetronome();
      _djConsoleViewModel.playDeck('A');
    };
    _masterClockService.onPauseAll = () {
      final vm = context.read<TunerViewModel>();
      if (vm.isMetronomeActive) vm.toggleMetronome();
      _djConsoleViewModel.pauseDeck('A');
    };
    _masterClockService.onStopAll = () {
      final vm = context.read<TunerViewModel>();
      if (vm.isMetronomeActive) vm.toggleMetronome();
      _djConsoleViewModel.stopAll();
    };
    _masterClockService.onBpmChanged = (bpm) {
      final vm = context.read<TunerViewModel>();
      vm.updateBpm(bpm.round());
      _djConsoleViewModel.syncDeckToBpm('A', bpm);
      _djConsoleViewModel.syncDeckToBpm('B', bpm);
    };

    _terminalKernel = TunnerOsKernel(
      onNavigateTab: _navigateToTab,
      matrixService: _audioMatrixService,
      clockService: _masterClockService,
      onDjLoadTrack: (deckId, track) {
        if (track.toLowerCase().contains('elisa')) {
          _djConsoleViewModel.loadCuratedSong(deckId, 'elisa');
        } else {
          _djConsoleViewModel.loadPresetTrack(deckId, track);
        }
      },
      onDjTogglePlay: (deckId) => _djConsoleViewModel.togglePlay(deckId),
      onDjPlayDeck: (deckId) => _djConsoleViewModel.playDeck(deckId),
      onDjPauseDeck: (deckId) => _djConsoleViewModel.pauseDeck(deckId),
      onDjSetCrossfader: (val) => _djConsoleViewModel.setCrossfaderPosition(val),
      onSetTheme: (themeId) {
        final vm = context.read<TunerViewModel>();
        vm.setPaletteById(themeId);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<TunerViewModel>();
    _terminalKernel.synthVoicePool = vm.polyphonicVoicePool;
    _terminalKernel.scorePlaybackCoordinator = vm.scorePlaybackCoordinator;
    _terminalKernel.viewModel = vm;
  }

  void _handleOpenFile(StudioFileEntity file) {
    switch (file.fileType) {
      case StudioFileType.score:
        _navigateToTab(4);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Partitura abierta en el Editor: ${file.name}'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.audioWav:
        _navigateToTab(5);
        _djConsoleViewModel.loadDeckTrack(
          deckId: 'A',
          filePath: file.relativePath,
          wavBytes: file.payload is Uint8List ? file.payload as Uint8List : null,
          title: file.name,
          bpm: 124.0,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio cargado en Deck A de la Consola DJ: ${file.name}'),
            backgroundColor: const Color(0xFF00E5FF),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.tuningPreset:
        _navigateToTab(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preset de afinación activado: ${file.name}'),
            backgroundColor: const Color(0xFFFFAB00),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.rackTool:
        _navigateToTab(3);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Módulo de rack cargado: ${file.name}'),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.djBlueprint:
        _navigateToTab(5);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Modelo de consola DJ aplicado: ${file.name}'),
            backgroundColor: const Color(0xFF3D5AFE),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.project:
        _navigateToTab(0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proyecto Tunner restaurado íntegramente: ${file.name}'),
            backgroundColor: const Color(0xFF00E5FF),
            duration: const Duration(seconds: 3),
          ),
        );
        break;
      case StudioFileType.genericFile:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo cargado: ${file.name} (${file.formattedSize})'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  @override
  void dispose() {
    if (_fileSystemService.onOpenFile == _handleOpenFile) {
      _fileSystemService.onOpenFile = null;
    }
    _terminalKernel.dispose();
    _modularRackViewModel.dispose();
    _djConsoleViewModel.dispose();
    if (_ownsAudioMatrixService) {
      _audioMatrixService.dispose();
    }
    _ownedAudioInput?.dispose();
    if (_ownsClockService) {
      _masterClockService.dispose();
    }
    super.dispose();
  }

  void _openMasterConsole() {
    StudioMasterHardwareConsoleWidget.show(
      context,
      matrixService: _audioMatrixService,
      clockService: _masterClockService,
    );
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 6) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context != null) {
      if (context.widget is EditableText) return true;
      if (context.findAncestorWidgetOfExactType<EditableText>() != null) return true;
    }
    return false;
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
    return StudioPromptSuggestionsBuilder.build(
      context: context,
      viewModel: viewModel,
      onNavigateTab: _navigateToTab,
      onParseAndSetBpm: (raw) => _parseAndSetBpm(raw, viewModel),
      onParseAndSetPitch: (raw) => _parseAndSetPitch(raw, viewModel),
      onToggleTerminal: () => setState(() => _isTerminalOpen = !_isTerminalOpen),
      onOpenMasterConsole: _openMasterConsole,
      onOpenInstrumentSelector: () => _openInstrumentSelector(viewModel),
      onMasterTogglePlayPause: _masterClockService.togglePlayPause,
      onMasterStop: _masterClockService.stopTransport,
    );
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
                    onSelect: () {
                      _navigateToTab(5);
                      _djConsoleViewModel.loadDeckTrack(
                        deckId: 'A',
                        filePath: rec.filePath,
                        title: rec.songTitle,
                        bpm: rec.bpm.toDouble(),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Toma cargada en Deck A de la Consola DJ: ${rec.songTitle}'),
                          backgroundColor: const Color(0xFF00E5FF),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
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
    final bool isDjActive = _currentIndex == 5;

    final Map<ShortcutActivator, Intent> activeShortcuts = isDjActive
        ? <ShortcutActivator, Intent>{
            // En modo DJ Pro, aislamos el teclado para que todas las teclas de mezcla (W, Q, E, A, S, D, I, U, O, J, K, L, Z, X, C, B, N, V, 1..4, 7..0, Space)
            // se transmitan al motor DJ sin ser secuestradas por el transporte global.
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): const OpenCommandPaletteIntent(),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const OpenCommandPaletteIntent(),
            const SingleActivator(LogicalKeyboardKey.slash, shift: true): const OpenShortcutsGuideIntent(),
            const SingleActivator(LogicalKeyboardKey.backquote, control: true): const ToggleTerminalIntent(),
            const SingleActivator(LogicalKeyboardKey.digit1, alt: true): const SwitchTabIntent(0),
            const SingleActivator(LogicalKeyboardKey.digit2, alt: true): const SwitchTabIntent(1),
            const SingleActivator(LogicalKeyboardKey.digit3, alt: true): const SwitchTabIntent(2),
            const SingleActivator(LogicalKeyboardKey.digit4, alt: true): const SwitchTabIntent(3),
            const SingleActivator(LogicalKeyboardKey.digit5, alt: true): const SwitchTabIntent(4),
            const SingleActivator(LogicalKeyboardKey.digit6, alt: true): const SwitchTabIntent(5),
          }
        : <ShortcutActivator, Intent>{
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
            const SingleActivator(LogicalKeyboardKey.keyI, control: true, shift: true): const OpenMasterConsoleIntent(),
            const SingleActivator(LogicalKeyboardKey.keyI, meta: true, shift: true): const OpenMasterConsoleIntent(),
            const SingleActivator(LogicalKeyboardKey.slash, shift: true): const OpenShortcutsGuideIntent(),
            const SingleActivator(LogicalKeyboardKey.backquote, control: true): const ToggleTerminalIntent(),
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
            const SingleActivator(LogicalKeyboardKey.digit6): const SwitchTabIntent(5),
          };

    return Shortcuts(
      shortcuts: activeShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          TogglePlayIntent: _GuardedShortcutAction<TogglePlayIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.toggleMetronome();
              return null;
            },
          ),
          RewindToStartIntent: _GuardedShortcutAction<RewindToStartIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.resetSongState();
              viewModel.selectMeasure(0);
              return null;
            },
          ),
          ToggleCycleLoopIntent: _GuardedShortcutAction<ToggleCycleLoopIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.togglePracticeMode();
              return null;
            },
          ),
          NudgeMeasureBackIntent: _GuardedShortcutAction<NudgeMeasureBackIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.previousMeasure();
              return null;
            },
          ),
          NudgeMeasureForwardIntent: _GuardedShortcutAction<NudgeMeasureForwardIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.nextMeasure();
              return null;
            },
          ),
          ToggleRecordIntent: _GuardedShortcutAction<ToggleRecordIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              if (viewModel.isRecording) {
                viewModel.stopPracticeRecording();
              } else {
                viewModel.startPracticeRecording();
              }
              return null;
            },
          ),
          TapTempoIntent: _GuardedShortcutAction<TapTempoIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.recordTapTempo();
              return null;
            },
          ),
          IncrementBpmIntent: _GuardedShortcutAction<IncrementBpmIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (intent) {
              viewModel.incrementBpm(intent.step);
              return null;
            },
          ),
          DecrementBpmIntent: _GuardedShortcutAction<DecrementBpmIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (intent) {
              viewModel.decrementBpm(intent.step);
              return null;
            },
          ),
          CalibrateReferencePitchIntent: CallbackAction<CalibrateReferencePitchIntent>(
            onInvoke: (intent) => viewModel.setReferencePitch(viewModel.referencePitch + intent.deltaHz),
          ),
          PanicMuteIntent: _GuardedShortcutAction<PanicMuteIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              if (viewModel.isMetronomeActive) viewModel.toggleMetronome();
              if (viewModel.isRecording) viewModel.stopPracticeRecording();
              return null;
            },
          ),
          FocusTunerIntent: _GuardedShortcutAction<FocusTunerIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              _navigateToTab(1);
              return null;
            },
          ),
          FocusMetronomeIntent: _GuardedShortcutAction<FocusMetronomeIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.toggleMetronome();
              return null;
            },
          ),
          FocusScoreIntent: _GuardedShortcutAction<FocusScoreIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              _navigateToTab(4);
              return null;
            },
          ),
          FocusLessonsIntent: _GuardedShortcutAction<FocusLessonsIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              _navigateToTab(2);
              return null;
            },
          ),
          OpenInstrumentSelectorIntent: CallbackAction<OpenInstrumentSelectorIntent>(
            onInvoke: (_) => _openInstrumentSelector(viewModel),
          ),
          OpenMasterConsoleIntent: CallbackAction<OpenMasterConsoleIntent>(
            onInvoke: (_) {
              _openMasterConsole();
              return null;
            },
          ),
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) => _openCommandPalette(viewModel),
          ),
          OpenShortcutsGuideIntent: _GuardedShortcutAction<OpenShortcutsGuideIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) => _openShortcutsGuide(viewModel),
          ),
          ToggleTerminalIntent: CallbackAction<ToggleTerminalIntent>(
            onInvoke: (_) => setState(() => _isTerminalOpen = !_isTerminalOpen),
          ),
          OpenEarTrainerIntent: _GuardedShortcutAction<OpenEarTrainerIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) => BlindEarTrainerModal.show(context, viewModel),
          ),
          OpenChordAnalyzerIntent: _GuardedShortcutAction<OpenChordAnalyzerIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) => ChordAnalyzerModal.show(context, viewModel),
          ),
          JumpToTaskIntent: _GuardedShortcutAction<JumpToTaskIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              TaskQuickJumpModal.show(
                context: context,
                palette: viewModel.currentPalette,
              );
              return null;
            },
          ),
          SwitchTabIntent: _GuardedShortcutAction<SwitchTabIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (intent) {
              _navigateToTab(intent.tabIndex);
              return null;
            },
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
                  HomeDashboardScreen(
                    onNavigateToTab: _navigateToTab,
                    onOpenTerminal: () => setState(() => _isTerminalOpen = !_isTerminalOpen),
                  ),
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
                return Stack(
                  children: [
                    StudioDesktopAppShell(
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
                      onOpenMasterConsole: _openMasterConsole,
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
                      onCommandSubmitted: (cmd) {
                        _terminalKernel.execute(cmd);
                        setState(() => _isTerminalOpen = true);
                      },
                      isRecording: viewModel.isRecording,
                      onToggleRecording: () {
                        if (viewModel.isRecording) {
                          viewModel.stopPracticeRecording();
                        } else {
                          viewModel.startPracticeRecording();
                        }
                      },
                      customStatusItems: [
                        StudioMasterMeterMiniPillWidget(
                          matrixService: _audioMatrixService,
                          onTap: _openMasterConsole,
                        ),
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
                      customSidebarExplorer: StudioVsCodeExplorerWidget(
                        service: _fileSystemService,
                      ),
                    ),
                    if (_isTerminalOpen)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: TunnerOsTerminalDrawer(
                          kernel: _terminalKernel,
                          onClose: () => setState(() => _isTerminalOpen = false),
                        ),
                      ),
                  ],
                );
              }

              // Vista móvil / compacta
              return Stack(
                children: [
                  Scaffold(
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
                        selectedIndex: _currentIndex.clamp(0, 5),
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
                            label: 'Partituras',
                          ),
                          NavigationDestination(
                            key: const Key('nav_tab_dj'),
                            icon: Icon(Icons.album_outlined, color: palette.textMutedColor),
                            selectedIcon: Icon(Icons.album, color: const Color(0xFF00E5FF)),
                            label: 'Mesa DJ',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isTerminalOpen)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: TunnerOsTerminalDrawer(
                        kernel: _terminalKernel,
                        onClose: () => setState(() => _isTerminalOpen = false),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GuardedShortcutAction<T extends Intent> extends Action<T> {
  final bool Function() isEnabledCheck;
  final Object? Function(T intent) onInvokeAction;

  _GuardedShortcutAction({
    required this.isEnabledCheck,
    required this.onInvokeAction,
  });

  @override
  bool isEnabled(T intent) => isEnabledCheck();

  @override
  bool consumesKey(T intent) => isEnabledCheck();

  @override
  Object? invoke(T intent) => onInvokeAction(intent);
}
