import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/studio_composition_root.dart';
import '../../../core/logging/infrastructure/studio_debug_logger.dart';
import '../../dj_console/domain/dj_sampler_bank_entity.dart';
import '../../media_vault/domain/media_asset_entity.dart';
import '../../media_vault/domain/media_synergy_target.dart';
import '../../tuner_viewmodel.dart';
import '../../song_library/domain/song_package_entity.dart';
import '../../instrument/domain/instrument_customization_profile.dart';
import 'studio_keyboard_intents.dart';
import 'studio_prompt_suggestions_builder.dart';
import 'home_dashboard_screen.dart';
import '../../tuner_screen.dart';
import '../../workspaces/presentation/learning_practice_workspace_view.dart';
import '../../modular_rack/presentation/modular_studio_rack_view.dart';
import '../../workspaces/presentation/composition_notation_workspace_view.dart';
import '../../instrument/presentation/instrument_selector_modal.dart';
import 'pro_command_palette_modal.dart';
import 'studio_command_catalog_builder.dart';
import 'keyboard_shortcuts_modal.dart';
import 'quick_action_dock_widget.dart';
import '../../ear_training/presentation/blind_ear_trainer_modal.dart';
import '../../chord_analyzer/presentation/chord_analyzer_modal.dart';
import '../../guided_lessons/presentation/task_quick_jump_modal.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../acoustic_lab/presentation/harmonic_spectrogram_modal.dart';
import '../../drone/presentation/harmonic_drone_modal.dart';
import '../../song_library/presentation/studio_assets_modals.dart';
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
import '../../../core/terminal/domain/tunner_os_command_entity.dart';
import '../../../core/terminal/presentation/tunner_os_terminal_drawer.dart';
import '../../../core/audio/domain/i_audio_transcoder_port.dart';
import '../../../core/audio/infrastructure/ffmpeg_audio_transcoder_service.dart';
import '../../../core/audio/infrastructure/studio_master_clock_service.dart';
import '../../../core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import '../../../core/audio/infrastructure/studio_audio_engine.dart';
import '../../../core/audio/infrastructure/studio_audio_hardware_persistence_service.dart';
import '../../../core/audio/infrastructure/studio_audio_input_engine.dart';
import '../../../core/audio/presentation/studio_master_hardware_console_widget.dart';
import '../../../core/audio/presentation/studio_master_meter_mini_pill_widget.dart';
import '../../tuner/presentation/stem_mixer_modal.dart';
import '../../../app/terminal_feature_adapters.dart';
import '../../../core/channels/domain/studio_patchbay_routing_service.dart';
import '../../media_vault/presentation/media_vault_viewmodel.dart';

export 'studio_keyboard_intents.dart';
/// el Tutor de Aprendizaje, el Estudio de Grabación y la Biblioteca de Canciones,
/// integrando el Quick Action Dock y el despachador de atajos globales de memoria muscular.
class MainAppShell extends StatefulWidget {
  final int initialIndex;
  final IStudioWorkspaceFileSystem? fileSystemService;
  final IAudioTranscoderPort? audioTranscoder;

  const MainAppShell({
    super.key,
    this.initialIndex = 0,
    this.fileSystemService,
    this.audioTranscoder,
  });

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  late int _currentIndex;
  late final ModularRackViewModel _modularRackViewModel;
  late final DjConsoleViewModel _djConsoleViewModel;
  late final MediaVaultViewModel _mediaVaultViewModel;
  late final IStudioWorkspaceFileSystem _fileSystemService;
  late final IAudioTranscoderPort _audioTranscoder;
  late final StudioAudioDeviceMatrixService _audioMatrixService;
  StudioAudioInputEngine? _ownedAudioInput;
  bool _ownsAudioMatrixService = false;
  bool _ownsClockService = false;
  late final StudioMasterClockService _masterClockService;
  bool _isTerminalOpen = false;
  late final TunnerOsKernel _terminalKernel;
  final List<TunnerOsCommandHistoryItem> _terminalExternalHistory =
      <TunnerOsCommandHistoryItem>[];
  final GlobalKey<StudioDesktopAppShellState> _desktopShellKey = GlobalKey<StudioDesktopAppShellState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    StudioCompositionRoot? root;
    try {
      root = context.read<StudioCompositionRoot>();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'MainAppShell',
        'StudioCompositionRoot opcional no montado en contexto: $e',
        error: e,
        stackTrace: st,
      );
      root = null;
    }

    _modularRackViewModel = root != null
        ? root.createModularRackViewModel()
        : ModularRackViewModel();
    _djConsoleViewModel = root != null
        ? root.createDjConsoleViewModel()
        : DjConsoleViewModel();
    _mediaVaultViewModel = root != null
        ? root.createMediaVaultViewModel()
        : MediaVaultViewModel();
    _mediaVaultViewModel.onDispatchToTool = (asset, target) {
      final samples = (asset.pcmSamples != null && asset.pcmSamples!.isNotEmpty)
          ? Float32List.fromList(asset.pcmSamples!)
          : Float32List(4410);
      switch (target) {
        case MediaSynergyTarget.djDeckA:
        case MediaSynergyTarget.djDeckB:
          final deckId = target == MediaSynergyTarget.djDeckA ? 'A' : 'B';
          _djConsoleViewModel.loadTrackWithBeatTracking(
            deckId,
            title: asset.title,
            artist: asset.kind.displayName,
            audioSamples: samples,
            sampleRate: asset.sampleRate,
          );
          break;
        case MediaSynergyTarget.djSamplerPad:
          _djConsoleViewModel.triggerSamplerPad(DjSamplerPadType.values.first);
          break;
        case MediaSynergyTarget.scoreEditor:
          TunerViewModel? tunerVm;
          try {
            tunerVm = context.read<TunerViewModel>();
          } catch (_) {
            tunerVm = null;
          }
          if (tunerVm != null && asset.rawBytes != null) {
            unawaited(
              tunerVm.importScoreFromBytes(
                asset.rawBytes!,
                asset.fileName,
              ),
            );
          }
          break;
        case MediaSynergyTarget.mixerChannel:
          StudioPatchbayRoutingService().publishChannelParameters(
            'canal_c',
            title: asset.title,
            bpm: asset.bpm,
            key: asset.camelotKey,
            isPlaying: true,
            pcmBuffer: samples,
          );
          break;
      }
    };

    IStudioWorkspaceFileSystem? injectedFileSystem;
    if (widget.fileSystemService != null) {
      injectedFileSystem = widget.fileSystemService;
    } else {
      try {
        injectedFileSystem = context.read<IStudioWorkspaceFileSystem>();
      } catch (_) {
        injectedFileSystem = null;
      }
    }
    _fileSystemService = injectedFileSystem ?? root?.fileSystemService ?? NoOpStudioWorkspaceFileSystem();
    _fileSystemService.onOpenFile = _handleOpenFile;
    _fileSystemService.onFileMusicalAction = _handleFileMusicalAction;
    _fileSystemService.initializeWorkspace();

    TunerViewModel? existingVm;
    try {
      existingVm = context.read<TunerViewModel>();
    } catch (e, st) {
      StudioDebugLogger.instance.warning(
        'MainAppShell',
        'TunerViewModel opcional no montado en contexto: $e',
        error: e,
        stackTrace: st,
      );
      existingVm = null;
    }

    _audioTranscoder = widget.audioTranscoder ??
        root?.audioTranscoder ??
        ((existingVm != null && existingVm.audioTranscoder is! NoOpAudioTranscoderPort)
            ? existingVm.audioTranscoder
            : const FfmpegAudioTranscoderService());

    if (root != null) {
      _audioMatrixService = root.audioMatrixService;
      _ownsAudioMatrixService = false;
      _masterClockService = root.masterClockService;
      _ownsClockService = false;
    } else if (existingVm?.audioDeviceMatrixService is StudioAudioDeviceMatrixService) {
      _audioMatrixService = existingVm!.audioDeviceMatrixService! as StudioAudioDeviceMatrixService;
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
      inputEngine: _audioMatrixService.inputEngine,
      outputEngine: _audioMatrixService.outputEngine,
      fileSystemRepository: _fileSystemService.fileSystemRepository,
      matrixService: _audioMatrixService,
      clockService: _masterClockService,
      earTrainingEngine: EbbinghausTerminalAdapter(),
      vocalEvaluator: const VocalPedagogyTerminalAdapter(),
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
        vm.setActiveStudioThemeId(themeId);
        StudioThemeScope.controllerOf(context)?.selectById(themeId);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = context.read<TunerViewModel>();
    _modularRackViewModel.bindTunerViewModel(vm);
    _terminalKernel.synthVoicePool = vm.polyphonicVoicePool;
    _terminalKernel.scorePlaybackCoordinator = ScorePlaybackTerminalAdapter(vm.scorePlaybackCoordinator);
    _terminalKernel.projectPort = TunerProjectTerminalAdapter(vm);
    _terminalKernel.onTriggerSynthNote = (midi, vel) => vm.playMidiNoteTone(midi);
    _terminalKernel.onReadCapturedFrequencies =
        () => vm.frequency > 0 ? List<double>.filled(10, vm.frequency) : const <double>[];
    _terminalKernel.onReadCapturedAmplitudes =
        () => vm.frequency > 0 ? const <double>[0.85, 0.85, 0.85, 0.85, 0.85, 0.85, 0.85, 0.85, 0.85, 0.85] : const <double>[];
  }

  Future<Uint8List?> _resolveFileBytes(StudioFileEntity file) async {
    Uint8List? resolvedBytes;
    if (file.payload is Uint8List) {
      resolvedBytes = file.payload as Uint8List;
    } else if (file.payload is String) {
      resolvedBytes = Uint8List.fromList(utf8.encode(file.payload as String));
    }

    final bool hasStructuredPayload = file.payload is SongPackage ||
        file.payload is Map<String, dynamic> ||
        file.payload is InstrumentCustomizationProfile;

    if (!hasStructuredPayload && (resolvedBytes == null || resolvedBytes.isEmpty)) {
      try {
        resolvedBytes = await _fileSystemService.fileSystemRepository.readFile(file.relativePath);
      } catch (e, st) {
        StudioDebugLogger.instance.warning(
          'MainAppShell',
          'No se pudieron leer bytes en disco para ${file.relativePath}: $e',
          error: e,
          stackTrace: st,
        );
      }
    }
    return resolvedBytes;
  }

  Future<({Uint8List? wavBytes, String wavFileName})> _prepareAudioForDjAndScore(
    StudioFileEntity file,
    Uint8List resolvedBytes,
  ) async {
    final dotIdx = file.name.lastIndexOf('.');
    final ext = dotIdx >= 0 ? file.name.substring(dotIdx + 1).toLowerCase() : '';
    final bool hasRiffHeader = resolvedBytes.length >= 12 &&
        resolvedBytes[0] == 0x52 &&
        resolvedBytes[1] == 0x49 &&
        resolvedBytes[2] == 0x46 &&
        resolvedBytes[3] == 0x46;

    Uint8List? wavBytes = hasRiffHeader ? resolvedBytes : null;
    String wavFileName = file.name;
    if (!hasRiffHeader && _audioTranscoder.isSupportedCompressedExtension(ext)) {
      final transcoded = await _audioTranscoder.transcodeToWav16BitPcm(
        resolvedBytes,
        fileExtension: ext,
      );
      if (transcoded != null && transcoded.isNotEmpty) {
        wavBytes = transcoded;
        final baseName = dotIdx >= 0 ? file.name.substring(0, dotIdx) : file.name;
        wavFileName = '$baseName.wav';
      }
    }
    return (wavBytes: wavBytes, wavFileName: wavFileName);
  }

  Future<void> _handleFileMusicalAction(
    StudioFileEntity file,
    StudioFileMusicalAction action,
  ) async {
    if (action == StudioFileMusicalAction.openInScoreEditor ||
        action == StudioFileMusicalAction.openDefault) {
      await _handleOpenFile(file);
      return;
    }

    final vm = context.read<TunerViewModel>();
    final tokens = StudioThemeScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final resolvedBytes = await _resolveFileBytes(file);
    if (!mounted) return;

    if (resolvedBytes == null || resolvedBytes.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudieron leer los bytes de audio: ${file.name}'),
          backgroundColor: tokens.accentWarning,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    switch (action) {
      case StudioFileMusicalAction.transformToScoreAndStems:
        _navigateToTab(4);
        await vm.importScoreFromBytes(resolvedBytes, file.name);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Audio transformado a Partitura y 4 Stems: ${file.name}'),
            backgroundColor: tokens.accentSuccess,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileMusicalAction.loadInDjDeckA:
      case StudioFileMusicalAction.loadInDjDeckB:
        final deckId = action == StudioFileMusicalAction.loadInDjDeckA ? 'A' : 'B';
        final prepared = await _prepareAudioForDjAndScore(file, resolvedBytes);
        if (!mounted) return;
        _navigateToTab(5);
        await _djConsoleViewModel.loadDeckTrack(
          deckId: deckId,
          filePath: file.relativePath,
          wavBytes: prepared.wavBytes,
          title: file.name,
          bpm: vm.bpm.toDouble(),
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Audio cargado en Deck $deckId de la Consola DJ: ${file.name}'),
            backgroundColor: tokens.elevatedSurface,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileMusicalAction.openInScoreEditor:
      case StudioFileMusicalAction.openDefault:
        break;
    }
  }

  Future<void> _handleOpenFile(StudioFileEntity file) async {
    final vm = context.read<TunerViewModel>();
    final tokens = StudioThemeScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final resolvedBytes = await _resolveFileBytes(file);
    if (!mounted) return;

    switch (file.fileType) {
      case StudioFileType.score:
        _navigateToTab(4);
        bool scoreLoaded = false;
        if (file.payload is SongPackage) {
          vm.loadSongPackage(file.payload as SongPackage);
          scoreLoaded = true;
        } else if (resolvedBytes != null && resolvedBytes.isNotEmpty) {
          final parsed = await vm.importScoreFromBytes(resolvedBytes, file.name);
          if (!mounted) return;
          scoreLoaded = parsed != null;
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              scoreLoaded
                  ? 'Partitura cargada en el Editor: ${file.name}'
                  : 'No se pudo cargar la partitura: ${file.name}',
            ),
            backgroundColor: scoreLoaded ? tokens.accentSuccess : tokens.accentWarning,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.audioWav:
        if (resolvedBytes == null || resolvedBytes.isEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('No se pudieron leer los bytes de audio: ${file.name}'),
              backgroundColor: tokens.accentWarning,
              duration: const Duration(seconds: 2),
            ),
          );
          break;
        }

        final prepared = await _prepareAudioForDjAndScore(file, resolvedBytes);
        if (!mounted) return;
        final Uint8List? wavBytesForDj = prepared.wavBytes;
        final String scoreImportFileName = prepared.wavFileName;

        await _djConsoleViewModel.loadDeckTrack(
          deckId: 'A',
          filePath: file.relativePath,
          wavBytes: wavBytesForDj,
          title: file.name,
          bpm: vm.bpm.toDouble(),
        );
        if (!mounted) return;

        await vm.importScoreFromBytes(wavBytesForDj ?? resolvedBytes, scoreImportFileName);
        if (!mounted) return;

        final bool keepNotationTab = _currentIndex == 4 || _currentIndex == 2;
        if (!keepNotationTab) {
          _navigateToTab(5);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              keepNotationTab
                  ? 'Audio transcrito a partitura y cargado en Deck A: ${file.name}'
                  : 'Audio cargado en Deck A de la Consola DJ y transcrito a partitura: ${file.name}',
            ),
            backgroundColor: tokens.elevatedSurface,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.tuningPreset:
        _navigateToTab(1);
        Map<String, dynamic>? presetMap;
        if (file.payload is Map<String, dynamic>) {
          presetMap = file.payload as Map<String, dynamic>;
        } else {
          final String? rawJson = file.payload is String
              ? file.payload as String
              : (resolvedBytes != null && resolvedBytes.isNotEmpty
                  ? utf8.decode(resolvedBytes, allowMalformed: true)
                  : null);
          if (rawJson != null && rawJson.trim().isNotEmpty) {
            try {
              final decoded = jsonDecode(rawJson);
              if (decoded is Map<String, dynamic>) {
                presetMap = decoded;
              }
            } catch (e, st) {
              StudioDebugLogger.instance.warning(
                'MainAppShell',
                'Error decodificando preset de afinacion: $e',
                error: e,
                stackTrace: st,
              );
            }
          }
        }
        if (presetMap != null) {
          final pitch = (presetMap['referencePitch'] as num?)?.toDouble();
          if (pitch != null) vm.setReferencePitch(pitch);
          final temperamentId = presetMap['temperamentId'] as String?;
          if (temperamentId != null) vm.setTemperament(temperamentId);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Preset de afinación activado: ${file.name}'),
            backgroundColor: tokens.accentWarning,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.rackTool:
        _navigateToTab(3);
        if (file.payload is InstrumentCustomizationProfile) {
          _modularRackViewModel.updateCustomization(file.payload as InstrumentCustomizationProfile);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Módulo de rack cargado: ${file.name}'),
            backgroundColor: tokens.elevatedSurface,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.djBlueprint:
        _navigateToTab(5);
        final String? rawBlueprint = file.payload is String
            ? file.payload as String
            : (resolvedBytes != null && resolvedBytes.isNotEmpty
                ? utf8.decode(resolvedBytes, allowMalformed: true)
                : null);
        if (rawBlueprint != null && rawBlueprint.trim().isNotEmpty) {
          final trimmed = rawBlueprint.trim();
          String? skinId;
          if (trimmed.startsWith('{')) {
            try {
              final decoded = jsonDecode(trimmed);
              if (decoded is Map<String, dynamic>) {
                skinId = (decoded['skinId'] ?? decoded['id']) as String?;
              }
            } catch (e, st) {
              StudioDebugLogger.instance.warning(
                'MainAppShell',
                'Error decodificando blueprint DJ: $e',
                error: e,
                stackTrace: st,
              );
            }
          } else {
            skinId = trimmed;
          }
          if (skinId != null && skinId.isNotEmpty) {
            _djConsoleViewModel.selectSkin(skinId);
          }
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Modelo de consola DJ aplicado: ${file.name}'),
            backgroundColor: tokens.elevatedSurface,
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      case StudioFileType.project:
        _navigateToTab(0);
        if (resolvedBytes != null && resolvedBytes.isNotEmpty) {
          vm.importProjectFromTunnerBytes(resolvedBytes);
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text('Proyecto Tunner restaurado íntegramente: ${file.name}'),
            backgroundColor: tokens.accentSuccess,
            duration: const Duration(seconds: 3),
          ),
        );
        break;
      case StudioFileType.genericFile:
        messenger.showSnackBar(
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
    if (_fileSystemService.onFileMusicalAction == _handleFileMusicalAction) {
      _fileSystemService.onFileMusicalAction = null;
    }
    _masterClockService.onPlayAll = null;
    _masterClockService.onPauseAll = null;
    _masterClockService.onStopAll = null;
    _masterClockService.onBpmChanged = null;
    _terminalKernel.dispose();
    _modularRackViewModel.dispose();
    _djConsoleViewModel.dispose();
    _mediaVaultViewModel.dispose();
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
    if (index >= 0 && index < StudioWorkspaceTabSpec.canonicalTabs.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Future<void> _handlePromptCommandSubmitted(String cmd) async {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return;
    setState(() => _isTerminalOpen = true);
    final result = await _terminalKernel.execute(trimmed);
    if (!mounted) return;
    setState(() {
      if (result.message == 'CLEAR_SCREEN') {
        _terminalExternalHistory.clear();
      } else {
        _terminalExternalHistory.add(
          TunnerOsCommandHistoryItem(
            commandLine: trimmed,
            result: result,
          ),
        );
      }
    });
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
    final commands = StudioCommandCatalogBuilder.build(
      context: context,
      viewModel: viewModel,
      modularRackViewModel: _modularRackViewModel,
      mediaVaultViewModel: _mediaVaultViewModel,
      onNavigateToTab: _navigateToTab,
      onOpenInstrumentSelector: () => _openInstrumentSelector(viewModel),
      onToggleSidebar: () => _desktopShellKey.currentState?.toggleSidebar(),
      onToggleDualSplit: () => _desktopShellKey.currentState?.toggleDualSplit(),
      onToggleTerminal: () => setState(() => _isTerminalOpen = !_isTerminalOpen),
      onOpenShortcutsGuide: () => _openShortcutsGuide(viewModel),
      onOpenMasterConsole: _openMasterConsole,
    );

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
    return StudioWorkspaceTabSpec.byIndex(_currentIndex).breadcrumb;
  }

  String _buildCurrentActiveItemId() {
    return StudioWorkspaceTabSpec.byIndex(_currentIndex).activeItemId;
  }

  Widget _buildContextualRightInspectorContent(
    BuildContext context,
    TunerViewModel viewModel,
    StudioDesignTokens tokens,
  ) {
    return Container(
      key: const Key('main_shell_live_inspector_context_card'),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: tokens.borderHairline,
          width: tokens.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Obra: ${viewModel.activePackage.title}',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 10.0,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6.0),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('inspector_quick_a4_442_btn'),
                  onPressed: () => viewModel.setReferencePitch(442.0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.accentPrimary,
                    side: BorderSide(
                      color: tokens.borderHairline,
                      width: tokens.borderWidth,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'A4 = 442 Hz',
                    style: TextStyle(fontSize: 9.5, fontFamily: 'monospace'),
                  ),
                ),
              ),
              const SizedBox(width: 6.0),
              Expanded(
                child: OutlinedButton(
                  key: const Key('inspector_quick_a4_440_btn'),
                  onPressed: () => viewModel.setReferencePitch(440.0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                    side: BorderSide(
                      color: tokens.borderHairline,
                      width: tokens.borderWidth,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'A4 = 440 Hz',
                    style: TextStyle(fontSize: 9.5, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          OutlinedButton(
            key: const Key('inspector_quick_toggle_drone_btn'),
            onPressed: () => viewModel.toggleDrone(),
            style: OutlinedButton.styleFrom(
              foregroundColor: viewModel.isDronePlaying
                  ? tokens.accentPrimary
                  : tokens.textSecondary,
              side: BorderSide(
                color: viewModel.isDronePlaying
                    ? tokens.accentPrimary
                    : tokens.borderHairline,
                width: tokens.borderWidth,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              viewModel.isDronePlaying ? 'Detener Dron' : 'Activar Dron',
              style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
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
                          backgroundColor: StudioThemeScope.of(context).elevatedSurface,
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
            // En modo DJ Pro, aislamos el teclado para que todas las teclas de mezcla
            // se transmitan al motor DJ sin ser secuestradas por el transporte global.
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): const OpenCommandPaletteIntent(),
            const SingleActivator(LogicalKeyboardKey.keyK, meta: true): const OpenCommandPaletteIntent(),
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): const OpenCommandPaletteIntent(),
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const OpenCommandPaletteIntent(),
            const SingleActivator(LogicalKeyboardKey.slash, shift: true): const OpenShortcutsGuideIntent(),
            const SingleActivator(LogicalKeyboardKey.f1): const OpenShortcutsGuideIntent(),
            const SingleActivator(LogicalKeyboardKey.f12): const ToggleTerminalIntent(),
            const SingleActivator(LogicalKeyboardKey.backquote, control: true): const ToggleTerminalIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): const SaveSessionIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): const SaveSessionIntent(),
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): const OpenFileIntent(),
            const SingleActivator(LogicalKeyboardKey.keyO, meta: true): const OpenFileIntent(),
            const SingleActivator(LogicalKeyboardKey.keyB, control: true): const ToggleSidebarIntent(),
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true): const ToggleSidebarIntent(),
            const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): const ToggleDualSplitIntent(),
            const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true): const ToggleDualSplitIntent(),
            const SingleActivator(LogicalKeyboardKey.digit1, alt: true): const SwitchTabIntent(0),
            const SingleActivator(LogicalKeyboardKey.digit2, alt: true): const SwitchTabIntent(1),
            const SingleActivator(LogicalKeyboardKey.digit3, alt: true): const SwitchTabIntent(2),
            const SingleActivator(LogicalKeyboardKey.digit4, alt: true): const SwitchTabIntent(3),
            const SingleActivator(LogicalKeyboardKey.digit5, alt: true): const SwitchTabIntent(4),
            const SingleActivator(LogicalKeyboardKey.digit6, alt: true): const SwitchTabIntent(5),
            const SingleActivator(LogicalKeyboardKey.f2): const SwitchTabIntent(1),
            const SingleActivator(LogicalKeyboardKey.f3): const SwitchTabIntent(2),
            const SingleActivator(LogicalKeyboardKey.f4): const SwitchTabIntent(3),
            const SingleActivator(LogicalKeyboardKey.f5): const SwitchTabIntent(4),
            const SingleActivator(LogicalKeyboardKey.f6): const SwitchTabIntent(5),
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
            const SingleActivator(LogicalKeyboardKey.f1): const OpenShortcutsGuideIntent(),
            const SingleActivator(LogicalKeyboardKey.f12): const ToggleTerminalIntent(),
            const SingleActivator(LogicalKeyboardKey.backquote, control: true): const ToggleTerminalIntent(),
            const SingleActivator(LogicalKeyboardKey.keyE, shift: true): const OpenEarTrainerIntent(),
            const SingleActivator(LogicalKeyboardKey.keyC, shift: true): const OpenChordAnalyzerIntent(),
            const SingleActivator(LogicalKeyboardKey.keyJ): const JumpToTaskIntent(),
            const SingleActivator(LogicalKeyboardKey.keyJ, control: true): const JumpToTaskIntent(),
            const SingleActivator(LogicalKeyboardKey.keyJ, meta: true): const JumpToTaskIntent(),

            // Atajos de gestión de archivos y DAW
            const SingleActivator(LogicalKeyboardKey.keyS, control: true): const SaveSessionIntent(),
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): const SaveSessionIntent(),
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): const OpenFileIntent(),
            const SingleActivator(LogicalKeyboardKey.keyO, meta: true): const OpenFileIntent(),
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): const NewProjectIntent(),
            const SingleActivator(LogicalKeyboardKey.keyN, meta: true): const NewProjectIntent(),
            const SingleActivator(LogicalKeyboardKey.keyB, control: true): const ToggleSidebarIntent(),
            const SingleActivator(LogicalKeyboardKey.keyB, meta: true): const ToggleSidebarIntent(),
            const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): const ToggleDualSplitIntent(),
            const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true): const ToggleDualSplitIntent(),

            // Pestañas directas
            const SingleActivator(LogicalKeyboardKey.digit1): const SwitchTabIntent(0),
            const SingleActivator(LogicalKeyboardKey.digit2): const SwitchTabIntent(1),
            const SingleActivator(LogicalKeyboardKey.digit3): const SwitchTabIntent(2),
            const SingleActivator(LogicalKeyboardKey.digit4): const SwitchTabIntent(3),
            const SingleActivator(LogicalKeyboardKey.digit5): const SwitchTabIntent(4),
            const SingleActivator(LogicalKeyboardKey.digit6): const SwitchTabIntent(5),

            // Pestañas Alt+1..6 y F2..F6
            const SingleActivator(LogicalKeyboardKey.digit1, alt: true): const SwitchTabIntent(0),
            const SingleActivator(LogicalKeyboardKey.digit2, alt: true): const SwitchTabIntent(1),
            const SingleActivator(LogicalKeyboardKey.digit3, alt: true): const SwitchTabIntent(2),
            const SingleActivator(LogicalKeyboardKey.digit4, alt: true): const SwitchTabIntent(3),
            const SingleActivator(LogicalKeyboardKey.digit5, alt: true): const SwitchTabIntent(4),
            const SingleActivator(LogicalKeyboardKey.digit6, alt: true): const SwitchTabIntent(5),
            const SingleActivator(LogicalKeyboardKey.f2): const SwitchTabIntent(1),
            const SingleActivator(LogicalKeyboardKey.f3): const SwitchTabIntent(2),
            const SingleActivator(LogicalKeyboardKey.f4): const SwitchTabIntent(3),
            const SingleActivator(LogicalKeyboardKey.f5): const SwitchTabIntent(4),
            const SingleActivator(LogicalKeyboardKey.f6): const SwitchTabIntent(5),
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
              if (viewModel.isAudioRecording) {
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
                onTaskSelected: (task) {
                  viewModel.startPedagogicalTask(task);
                  _navigateToTab(2);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tarea iniciada: ${task.code.formatted} - ${task.title}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
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
          SaveSessionIntent: _GuardedShortcutAction<SaveSessionIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              viewModel.savePersistedState();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sesión de trabajo guardada correctamente en almacenamiento local.'),
                  duration: Duration(seconds: 2),
                ),
              );
              return null;
            },
          ),
          OpenFileIntent: _GuardedShortcutAction<OpenFileIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              StudioAssetsModals.showImportScoreDialog(
                context: context,
                viewModel: viewModel,
                onNavigateToTab: _navigateToTab,
              );
              return null;
            },
          ),
          NewProjectIntent: _GuardedShortcutAction<NewProjectIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              StudioAssetsModals.showNewScoreDialog(
                context: context,
                viewModel: viewModel,
                onNavigateToTab: _navigateToTab,
              );
              return null;
            },
          ),
          ToggleSidebarIntent: _GuardedShortcutAction<ToggleSidebarIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              _desktopShellKey.currentState?.toggleSidebar();
              return null;
            },
          ),
          ToggleDualSplitIntent: _GuardedShortcutAction<ToggleDualSplitIntent>(
            isEnabledCheck: () => !_isTextInputFocused(),
            onInvokeAction: (_) {
              _desktopShellKey.currentState?.toggleDualSplit();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              final tokens = StudioThemeScope.of(context);

              final viewportContent = IndexedStack(
                index: _currentIndex,
                children: [
                  HomeDashboardScreen(
                    onNavigateToTab: _navigateToTab,
                    onOpenTerminal: () => setState(() => _isTerminalOpen = !_isTerminalOpen),
                    onOpenUniversalCommandPalette: () => _openCommandPalette(viewModel),
                    onLoadDjTemplate: (deckId, songKey) {
                      _djConsoleViewModel.loadCuratedSong(deckId, songKey);
                      _djConsoleViewModel.syncDeckToBpm(deckId, 126.0);
                    },
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
                    onOpenMixerModal: () => StemMixerModal.show(context, viewModel),
                  ),
                  DjStudioWorkstationView(viewModel: _djConsoleViewModel),
                ],
              );

              if (isDesktop) {
                return Stack(
                  children: [
                    StudioDesktopAppShell(
                      key: _desktopShellKey,
                      currentBreadcrumb: _buildCurrentBreadcrumb(),
                      a4Hz: viewModel.referencePitch,
                      tempoBpm: viewModel.bpm.toDouble(),
                      activeInstrumentName: viewModel.activeInstrument.name,
                      activeTabId: StudioWorkspaceTabSpec
                          .canonicalTabs[_currentIndex.clamp(
                            0,
                            StudioWorkspaceTabSpec.canonicalTabs.length - 1,
                          )]
                          .windowMenuTitle,
                      rightInspectorContent: _buildContextualRightInspectorContent(
                        context,
                        viewModel,
                        tokens,
                      ),
                      bufferLatencyLabel: () {
                        final m = _audioMatrixService.matrix;
                        final latencyMs = (m.bufferSize / m.sampleRate * 1000.0).toStringAsFixed(1);
                        return 'BUFFER: ${m.bufferSize} • LATENCIA: $latencyMs ms (${(m.sampleRate / 1000).toStringAsFixed(1)} kHz)';
                      }(),
                      navigationSections: _buildNavigationSections(viewModel),
                      activeItemId: _buildCurrentActiveItemId(),
                      currentTabIndex: _currentIndex,
                      activeView: viewportContent,
                      secondaryView: _currentIndex == 3
                          ? const TunerScreen()
                          : ModularStudioRackView(viewModel: _modularRackViewModel),
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
                        viewModel.savePersistedState();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Espacio de trabajo guardado correctamente en almacenamiento local.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      onMenuSaveAs: () => StudioAssetsModals.showSaveAsDialog(
                        context: context,
                        viewModel: viewModel,
                        fileSystemService: _fileSystemService,
                      ),
                      onMenuExport: () => StudioAssetsModals.showExportDialog(
                        context: context,
                        viewModel: viewModel,
                        fileSystemService: _fileSystemService,
                      ),
                      onMenuOpenWorkspaceInExplorer: () => _fileSystemService.openInSystemExplorer('/'),
                      onMenuResetWorkspace: () => viewModel.resetSongState(),
                      onMenuToggleRack: () => _navigateToTab(3),
                      onNavigateToTabIndex: (idx) => _navigateToTab(idx),
                      onOpenSpectrogram: () => HarmonicSpectrogramModal.show(context),
                      promptSuggestions: _buildPromptSuggestions(viewModel),
                      onCommandSubmitted: (cmd) {
                        unawaited(_handlePromptCommandSubmitted(cmd));
                      },
                      isRecording: viewModel.isAudioRecording,
                      onToggleRecording: () {
                        if (viewModel.isAudioRecording) {
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
                          externalHistory: List<TunnerOsCommandHistoryItem>.unmodifiable(
                            _terminalExternalHistory,
                          ),
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
                    backgroundColor: tokens.canvasBackground,
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
                        color: tokens.panelBackground,
                        border: Border(
                          top: BorderSide(
                            color: tokens.borderHairline,
                            width: tokens.borderWidth,
                          ),
                        ),
                      ),
                      child: NavigationBar(
                        selectedIndex: _currentIndex.clamp(
                          0,
                          StudioWorkspaceTabSpec.canonicalTabs.length - 1,
                        ),
                        onDestinationSelected: _navigateToTab,
                        backgroundColor: tokens.panelBackground,
                        indicatorColor: tokens.elevatedSurface,
                        elevation: 0,
                        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                        destinations: StudioWorkspaceTabSpec.canonicalTabs
                            .map(
                              (spec) => NavigationDestination(
                                key: Key(spec.navKey),
                                icon: StudioIcon(
                                  spec.iconId,
                                  size: 20,
                                  color: tokens.textMuted,
                                  tintCustomAsset: true,
                                ),
                                selectedIcon: StudioIcon(
                                  spec.iconId,
                                  size: 20,
                                  color: tokens.accentPrimary,
                                  tintCustomAsset: true,
                                ),
                                label: spec.mobileLabel,
                              ),
                            )
                            .toList(growable: false),
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
                        externalHistory: List<TunnerOsCommandHistoryItem>.unmodifiable(
                          _terminalExternalHistory,
                        ),
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
