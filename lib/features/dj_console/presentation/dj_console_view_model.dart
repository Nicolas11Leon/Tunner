import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../audio_synthesizer/data/audio_synthesizer_service.dart';
import '../../audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import '../../audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import '../../instrument/data/procedural_instrument_synthesizer.dart';
import '../../song_library/data/song_decomposer_service.dart';
import '../data/dj_audio_processor.dart';
import '../data/dj_deck_audio_service.dart';
import '../data/dj_gamepad_input_service.dart';
import '../data/dj_hardware_catalog.dart';
import '../data/dj_keymap_persistence_service.dart';
import '../data/dj_mix_wav_encoder.dart';
import '../data/dj_transition_sfx_synthesizer.dart';
import '../data/memory_dj_deck_audio_player.dart';
import '../domain/bpm_beat_tracker_engine.dart';
import '../domain/dj_action.dart';
import '../domain/dj_channel_fx_entity.dart';
import '../domain/dj_controller_profile_entity.dart';
import '../domain/dj_crossfader_entity.dart';
import '../domain/dj_cue_monitor_entity.dart';
import '../domain/dj_deck_entity.dart';
import '../domain/dj_harmonic_camelot_engine.dart';
import '../domain/dj_hardware_skin_entity.dart';
import '../domain/dj_keymap_profile_entity.dart';
import '../domain/dj_live_mix_recorder_entity.dart';
import '../domain/dj_performance_orchestrator.dart';
import '../domain/dj_sampler_bank_entity.dart';
import '../domain/dj_skin_zone_entity.dart';
import '../domain/dj_smart_automix_engine.dart';
import '../domain/dj_stem_isolation_entity.dart';
import '../domain/i_dj_deck_audio_player.dart';

/// ViewModel managing state, hardware keyboard event dispatch, and UI reactivity
/// for the Virtual DJ Performance Console with Hardware Skins and Gamepad support.
class DjConsoleViewModel extends ChangeNotifier {
  final DjPerformanceOrchestrator _orchestrator;
  final DjKeymapPersistenceService _persistenceService;
  final DjAudioProcessor _audioProcessor;
  final IDjDeckAudioPlayer _deckAudioPlayer;
  final IAudioSynthesizerService _audioSynthesizer;
  late final DjGamepadInputService _inputService;

  Timer? _playbackTicker;
  Timer? _momentaryLedTimer;
  Timer? _scratchTimerA;
  Timer? _scratchTimerB;
  DjAction? _momentaryLitAction;
  double _rotationAngleA = 0.0;
  double _rotationAngleB = 0.0;
  bool _isDisposed = false;
  Uint8List? _lastRecordedWavBytes;

  static bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  // Hardware Skins & Gamepad Mapping
  DjHardwareSkinEntity _activeSkin = DjHardwareCatalog.ddjFlx4();
  bool _isHardwareViewActive = false;
  bool _isProWorkstationActive = false;
  bool _showKeyBadges = true;
  bool _isLearnModeActive = false;
  DjSkinZoneEntity? _selectedZoneForMapping;
  String? _lastCapturedInputToken;

  // Spectral RGB Waveforms & Last Sampler Buffer
  List<SpectralWaveformBucket> _waveformA =
      DjTransitionSfxSynthesizer.generateSyntheticTrackWaveform(bpm: 124.0);
  List<SpectralWaveformBucket> _waveformB =
      DjTransitionSfxSynthesizer.generateSyntheticTrackWaveform(bpm: 128.0);
  Float32List? _lastSamplerBuffer;

  // Showcase / Auto-Demo Routine (15s)
  bool _isShowcaseRunning = false;
  Timer? _showcaseTimer;
  int _showcaseStep = 0;

  DjConsoleViewModel({
    DjPerformanceOrchestrator? orchestrator,
    DjKeymapPersistenceService? persistenceService,
    DjAudioProcessor? audioProcessor,
    DjGamepadInputService? inputService,
    IDjDeckAudioPlayer? deckAudioPlayer,
    IAudioSynthesizerService? audioSynthesizer,
  })  : _orchestrator = orchestrator ?? DjPerformanceOrchestrator(),
        _persistenceService = persistenceService ?? DjKeymapPersistenceService(),
        _audioProcessor = audioProcessor ?? DjAudioProcessor(),
        _deckAudioPlayer = deckAudioPlayer ??
            (_isTestEnvironment ? MemoryDjDeckAudioPlayer() : DjDeckAudioService()),
        _audioSynthesizer = audioSynthesizer ??
            (_isTestEnvironment ? MemoryAudioSynthesizerService() : AudioSynthesizerService()) {
    _inputService = inputService ??
        DjGamepadInputService(
          profile: DjControllerProfileEntity.defaultUnified(),
        );

    _inputService.onActionTriggered = (action) {
      executeAction(action);
    };

    _inputService.onInputCaptured = (inputToken) {
      _handleCapturedInput(inputToken);
    };

    _initPersistenceAndKeyHandler();
    _startTicker();
    _initAudioEngine();
  }

  IDjDeckAudioPlayer get deckAudioPlayer => _deckAudioPlayer;
  IAudioSynthesizerService get audioSynthesizer => _audioSynthesizer;

  void _initAudioEngine() {
    _deckAudioPlayer.loadDeckTrack('A');
    _deckAudioPlayer.loadDeckTrack('B');
    _syncAudioVolumes();
  }

  void _syncAudioVolumes() {
    final gains = _orchestrator.getEffectiveGains();
    _deckAudioPlayer.setDeckVolume('A', gains.effectiveGainA);
    _deckAudioPlayer.setDeckVolume('B', gains.effectiveGainB);
  }

  DjDeckEntity get deckA => _orchestrator.deckA;
  DjDeckEntity get deckB => _orchestrator.deckB;
  DjCrossfaderEntity get crossfader => _orchestrator.crossfader;
  DjKeymapProfileEntity get keymapProfile => _orchestrator.keymapProfile;
  DjChannelFxEntity get fxA => _orchestrator.fxA;
  DjChannelFxEntity get fxB => _orchestrator.fxB;
  DjLiveMixRecorderEntity get recorder => _orchestrator.recorder;
  double get masterVolume => _orchestrator.masterVolume;
  double get rotationAngleA => _rotationAngleA;
  double get rotationAngleB => _rotationAngleB;
  Uint8List? get lastRecordedWavBytes => _lastRecordedWavBytes;

  // Hardware skins & Pro Workstation getters
  DjHardwareSkinEntity get activeSkin => _activeSkin.withActiveActions(activeLitActions);
  bool get isHardwareViewActive => _isHardwareViewActive;
  bool get isProWorkstationActive => _isProWorkstationActive;
  bool get showKeyBadges => _showKeyBadges;
  bool get isLearnModeActive => _isLearnModeActive;
  DjSkinZoneEntity? get selectedZoneForMapping => _selectedZoneForMapping;
  String? get lastCapturedInputToken => _lastCapturedInputToken;
  DjControllerProfileEntity get controllerProfile => _inputService.profile;
  DjSamplerBankEntity get sampler => _orchestrator.sampler;
  DjSmartAutomixEngine get automix => _orchestrator.automix;
  DjCueMonitorEntity get cueMonitor => _orchestrator.cueMonitor;
  CamelotCompatibility get harmonicCompatibility => _orchestrator.harmonicCompatibility;
  List<SpectralWaveformBucket> get waveformA => _waveformA;
  List<SpectralWaveformBucket> get waveformB => _waveformB;
  Float32List? get lastSamplerBuffer => _lastSamplerBuffer;
  bool get isShowcaseRunning => _isShowcaseRunning;
  int get showcaseStep => _showcaseStep;

  DjAction? get momentaryLitAction => _momentaryLitAction;

  /// Returns the set of active actions currently illuminating physical LEDs.
  Set<DjAction> get activeLitActions {
    final lit = <DjAction>{};
    if (deckA.isPlaying) lit.add(DjAction.deckAPlayPause);
    if (deckB.isPlaying) lit.add(DjAction.deckBPlayPause);
    if (deckA.isSyncActive) lit.add(DjAction.deckASync);
    if (deckB.isSyncActive) lit.add(DjAction.deckBSync);
    if (deckA.isLoopActive) lit.add(DjAction.deckALoopToggle);
    if (deckB.isLoopActive) lit.add(DjAction.deckBLoopToggle);
    if (recorder.isRecording) lit.add(DjAction.toggleMixRecording);
    if (fxA.isDelayActive) lit.add(DjAction.deckAToggleDelay);
    if (fxB.isDelayActive) lit.add(DjAction.deckBToggleDelay);
    if (fxA.filterPosition.abs() > 0.05) lit.add(DjAction.deckAFilterReset);
    if (fxB.filterPosition.abs() > 0.05) lit.add(DjAction.deckBFilterReset);

    // Hot Cues LEDs (Deck A)
    if (deckA.hotCues[0] != null || deckA.hotCues[1] != null) lit.add(DjAction.deckAHotCue1);
    if (deckA.hotCues[2] != null || (deckA.hotCues[1] != null && deckA.hotCues[0] != null)) lit.add(DjAction.deckAHotCue2);
    if (deckA.hotCues[3] != null || (deckA.hotCues[2] != null && deckA.hotCues[0] != null)) lit.add(DjAction.deckAHotCue3);
    if (deckA.hotCues[4] != null || (deckA.hotCues[3] != null && deckA.hotCues[0] != null)) lit.add(DjAction.deckAHotCue4);

    // Hot Cues LEDs (Deck B)
    if (deckB.hotCues[0] != null || deckB.hotCues[1] != null) lit.add(DjAction.deckBHotCue1);
    if (deckB.hotCues[2] != null || (deckB.hotCues[1] != null && deckB.hotCues[0] != null)) lit.add(DjAction.deckBHotCue2);
    if (deckB.hotCues[3] != null || (deckB.hotCues[2] != null && deckB.hotCues[0] != null)) lit.add(DjAction.deckBHotCue3);
    if (deckB.hotCues[4] != null || (deckB.hotCues[3] != null && deckB.hotCues[0] != null)) lit.add(DjAction.deckBHotCue4);

    // Momentary action pulse (e.g. CUE hit, pad hit)
    if (_momentaryLitAction != null) {
      lit.add(_momentaryLitAction!);
    }

    return lit;
  }

  void _triggerMomentaryPulse(DjAction action) {
    _momentaryLitAction = action;
    _momentaryLedTimer?.cancel();
    _momentaryLedTimer = Timer(const Duration(milliseconds: 140), () {
      if (!_isDisposed) {
        _momentaryLitAction = null;
        notifyListeners();
      }
    });
  }

  Future<void> _initPersistenceAndKeyHandler() async {
    final profile = await _persistenceService.loadActiveProfile();
    _orchestrator.setKeymapProfile(profile);
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    if (!_isDisposed) notifyListeners();
  }

  void _startTicker() {
    // 30 Hz timer to advance jog wheel angle and playback progress deterministically
    _playbackTicker = Timer.periodic(const Duration(milliseconds: 33), (_) {
      bool changed = false;
      if (deckA.isPlaying) {
        final prevPos = deckA.currentPositionMs;
        _rotationAngleA += (deckA.effectiveBpm / 60.0) * 0.15;
        _orchestrator.advanceDeckPlayback('A', 33);
        if (deckA.isLoopActive && deckA.currentPositionMs < prevPos) {
          _deckAudioPlayer.seekDeck('A', Duration(milliseconds: deckA.loopStartMs));
        }
        changed = true;
      }
      if (deckB.isPlaying) {
        final prevPos = deckB.currentPositionMs;
        _rotationAngleB += (deckB.effectiveBpm / 60.0) * 0.15;
        _orchestrator.advanceDeckPlayback('B', 33);
        if (deckB.isLoopActive && deckB.currentPositionMs < prevPos) {
          _deckAudioPlayer.seekDeck('B', Duration(milliseconds: deckB.loopStartMs));
        }
        changed = true;
      }
      if (_orchestrator.automix.isActive) {
        _orchestrator.advanceAutomix(33);
        _syncAudioVolumes();
        changed = true;
      }

      // If recording is active, capture audio slice
      if (recorder.isRecording) {
        final sampleRate = _audioProcessor.sampleRate;
        final sliceLength = (sampleRate * 0.033).round();
        final dummyBufferA = Float32List(sliceLength);
        final dummyBufferB = Float32List(sliceLength);

        final mixedChunk = _audioProcessor.mixBuffers(
          bufferA: dummyBufferA,
          bufferB: dummyBufferB,
          gainA: _orchestrator.deckAGain,
          gainB: _orchestrator.deckBGain,
          eqLowA: deckA.gainLow,
          eqMidA: deckA.gainMid,
          eqHighA: deckA.gainHigh,
          eqLowB: deckB.gainLow,
          eqMidB: deckB.gainMid,
          eqHighB: deckB.gainHigh,
          filterA: fxA.filterPosition,
          filterB: fxB.filterPosition,
          delayActiveA: fxA.isDelayActive,
          delaySamplesA: fxA.calculateDelaySamples(bpm: deckA.effectiveBpm, sampleRate: sampleRate),
          delayFeedbackA: fxA.delayFeedback,
          delayDryWetA: fxA.delayDryWet,
          delayActiveB: fxB.isDelayActive,
          delaySamplesB: fxB.calculateDelaySamples(bpm: deckB.effectiveBpm, sampleRate: sampleRate),
          delayFeedbackB: fxB.delayFeedback,
          delayDryWetB: fxB.delayDryWet,
        );

        _orchestrator.appendRecordingChunk(mixedChunk, DateTime.now().millisecondsSinceEpoch);
        changed = true;
      }

      if (changed && !_isDisposed) {
        notifyListeners();
      }
    });
  }

  void toggleShowKeyBadges([bool? val]) {
    _showKeyBadges = val ?? !_showKeyBadges;
    if (!_isDisposed) notifyListeners();
  }

  void setKeymapProfile(DjKeymapProfileEntity profile) {
    _orchestrator.setKeymapProfile(profile);
    _persistenceService.saveProfile(profile);
    if (!_isDisposed) notifyListeners();
  }

  bool handleKeyEvent(KeyEvent event) {
    return _handleHardwareKeyEvent(event);
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final keyLabel = event.logicalKey.keyLabel.isNotEmpty
        ? event.logicalKey.keyLabel
        : event.logicalKey.debugName ?? '';

    if (_isLearnModeActive) {
      _inputService.handleInputDown(keyLabel);
      return true;
    }

    // Try unified input service first (keyboard + gamepad)
    if (_inputService.handleInputDown(keyLabel)) {
      return true;
    }

    final action = _orchestrator.keymapProfile.resolveAction(keyLabel) ??
        _orchestrator.keymapProfile.keyBindings[keyLabel];
    if (action != null) {
      executeAction(action);
      return true;
    }
    return false;
  }

  void _handleCapturedInput(String inputToken) {
    _lastCapturedInputToken = inputToken;
    if (_selectedZoneForMapping != null) {
      // Bind input token to selected zone's action
      bindInputToZone(inputToken, _selectedZoneForMapping!);
    }
    if (!_isDisposed) notifyListeners();
  }

  // --- Hardware Skin & Mapping Control ---
  void selectSkin(String skinId) {
    _activeSkin = DjHardwareCatalog.findById(skinId);
    if (!_isDisposed) notifyListeners();
  }

  void toggleHardwareView() {
    _isHardwareViewActive = !_isHardwareViewActive;
    if (!_isDisposed) notifyListeners();
  }

  void toggleProWorkstation() {
    _isProWorkstationActive = !_isProWorkstationActive;
    if (!_isDisposed) notifyListeners();
  }

  // --- Pro Workstation Controls ---
  void toggleStem(String deckId, DjStemType type) {
    _orchestrator.toggleStem(deckId, type);
    if (!_isDisposed) notifyListeners();
  }

  void applyStemPreset(String deckId, String preset) {
    _orchestrator.applyStemPreset(deckId, preset);
    if (!_isDisposed) notifyListeners();
  }

  void toggleKeyLock(String deckId) {
    _orchestrator.toggleKeyLock(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void syncKey(String deckId) {
    _orchestrator.syncKey(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void toggleLoop(String deckId) {
    final wasActive = (deckId == 'A' ? deckA : deckB).isLoopActive;
    _orchestrator.toggleLoop(deckId);
    final deck = deckId == 'A' ? deckA : deckB;
    if (wasActive && !deck.isLoopActive && deck.isSlipModeActive) {
      _deckAudioPlayer.seekDeck(deckId, Duration(milliseconds: deck.currentPositionMs));
    }
    if (!_isDisposed) notifyListeners();
  }

  void halveLoop(String deckId) {
    _orchestrator.halveLoop(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void doubleLoop(String deckId) {
    _orchestrator.doubleLoop(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void toggleSlipMode(String deckId) {
    _orchestrator.toggleSlipMode(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void beatJump(String deckId, double beats) {
    _orchestrator.beatJump(deckId, beats);
    final deck = deckId == 'A' ? deckA : deckB;
    _deckAudioPlayer.seekDeck(deckId, Duration(milliseconds: deck.currentPositionMs));
    if (!_isDisposed) notifyListeners();
  }

  void triggerSamplerPad(DjSamplerPadType pad) {
    _orchestrator.triggerSamplerPad(pad);
    _playSamplerPadSound(pad);
    if (!_isDisposed) notifyListeners();
  }

  void _playSamplerPadSound(DjSamplerPadType pad) {
    final buffer = DjTransitionSfxSynthesizer.generatePadBuffer(
      pad,
      sampleRate: _audioProcessor.sampleRate,
    );
    _lastSamplerBuffer = buffer;
    final wavBytes = ProceduralInstrumentSynthesizer.floatBufferToWavBytes(
      buffer,
      sampleRate: _audioProcessor.sampleRate,
    );
    _audioSynthesizer.playPcmWav(wavBytes, volume: 0.85);
  }

  void startSmartAutomix(AutomixDirection dir, {int durationBars = 8}) {
    _orchestrator.startSmartAutomix(dir, durationBars: durationBars);
    if (!_isDisposed) notifyListeners();
  }

  void cancelSmartAutomix() {
    _orchestrator.cancelSmartAutomix();
    if (!_isDisposed) notifyListeners();
  }

  void toggleCueMonitor(String deckId) {
    _orchestrator.toggleCueMonitor(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void toggleSplitCue() {
    _orchestrator.toggleSplitCue();
    if (!_isDisposed) notifyListeners();
  }

  /// Ejecuta una coreografía automatizada de 15 segundos para pruebas integrales de todos los subsistemas.
  void runShowcaseRoutine() {
    if (_isShowcaseRunning) {
      cancelShowcaseRoutine();
      return;
    }
    _isShowcaseRunning = true;
    _showcaseStep = 0;
    notifyListeners();

    // t = 0s: Configurar Crossfader a Deck A y reproducir Deck A
    setCrossfaderPosition(-1.0);
    if (!deckA.isPlaying) togglePlay('A');

    _showcaseTimer?.cancel();
    _showcaseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !_isShowcaseRunning) {
        timer.cancel();
        return;
      }
      _showcaseStep++;

      switch (_showcaseStep) {
        case 2:
          // Disparo de Riser
          triggerSamplerPad(DjSamplerPadType.whiteNoiseRiser);
          break;
        case 4:
          // Auto-Loop de 4 beats y disparo de Airhorn
          toggleLoop('A');
          triggerSamplerPad(DjSamplerPadType.clubAirhorn);
          break;
        case 6:
          // Sincronizar BPM y reproducir Deck B
          syncBpm('B');
          if (!deckB.isPlaying) togglePlay('B');
          break;
        case 8:
          // Salir del bucle en Deck A y mover crossfader suavemente
          if (deckA.isLoopActive) toggleLoop('A');
          setCrossfaderPosition(-0.5);
          break;
        case 10:
          // Mezcla en centro
          setCrossfaderPosition(0.0);
          break;
        case 12:
          // Beat jump en Deck B (+4 compases) y desplazar crossfader hacia B
          beatJump('B', 4.0);
          setCrossfaderPosition(0.5);
          break;
        case 14:
          // Transición total a Deck B y golpe de Sub Bass Drop
          setCrossfaderPosition(1.0);
          triggerSamplerPad(DjSamplerPadType.subBassDrop);
          break;
        case 15:
          // Fin del showcase
          cancelShowcaseRoutine();
          break;
      }
    });
  }

  /// Cancela la rutina de demostración y limpia temporizadores asociados.
  void cancelShowcaseRoutine() {
    _showcaseTimer?.cancel();
    _showcaseTimer = null;
    _isShowcaseRunning = false;
    _showcaseStep = 0;
    if (!_isDisposed) notifyListeners();
  }

  void toggleLearnMode() {
    _isLearnModeActive = !_isLearnModeActive;
    _inputService.setLearnMode(_isLearnModeActive);
    if (!_isLearnModeActive) {
      _selectedZoneForMapping = null;
      _lastCapturedInputToken = null;
    }
    if (!_isDisposed) notifyListeners();
  }

  void selectZoneForMapping(DjSkinZoneEntity? zone) {
    _selectedZoneForMapping = zone;
    if (!_isDisposed) notifyListeners();
  }

  void bindInputToZone(String inputToken, DjSkinZoneEntity zone) {
    _inputService.bindInput(inputToken, zone.action);
    // Also bind in traditional keymap if applicable
    bindKey(inputToken, zone.action);
    if (!_isDisposed) notifyListeners();
  }

  void injectGamepadInput(String token, {bool isDown = true}) {
    _inputService.injectGamepadButton(token, isDown: isDown);
    if (!_isDisposed) notifyListeners();
  }

  void executeAction(DjAction action) {
    _triggerMomentaryPulse(action);
    _orchestrator.executeAction(action);
    if (action == DjAction.deckAPlayPause) {
      if (deckA.isPlaying) {
        _deckAudioPlayer.playDeck('A');
      } else {
        _deckAudioPlayer.pauseDeck('A');
      }
    } else if (action == DjAction.deckBPlayPause) {
      if (deckB.isPlaying) {
        _deckAudioPlayer.playDeck('B');
      } else {
        _deckAudioPlayer.pauseDeck('B');
      }
    } else if (action == DjAction.deckACue) {
      _deckAudioPlayer.seekDeck('A', Duration(milliseconds: deckA.cuePositionMs));
      if (!deckA.isPlaying) _deckAudioPlayer.pauseDeck('A');
    } else if (action == DjAction.deckBCue) {
      _deckAudioPlayer.seekDeck('B', Duration(milliseconds: deckB.cuePositionMs));
      if (!deckB.isPlaying) _deckAudioPlayer.pauseDeck('B');
    } else if (action == DjAction.deckAHotCue1 ||
        action == DjAction.deckAHotCue2 ||
        action == DjAction.deckAHotCue3 ||
        action == DjAction.deckAHotCue4) {
      _deckAudioPlayer.seekDeck('A', Duration(milliseconds: deckA.currentPositionMs));
      if (deckA.isPlaying) _deckAudioPlayer.playDeck('A');
    } else if (action == DjAction.deckBHotCue1 ||
        action == DjAction.deckBHotCue2 ||
        action == DjAction.deckBHotCue3 ||
        action == DjAction.deckBHotCue4) {
      _deckAudioPlayer.seekDeck('B', Duration(milliseconds: deckB.currentPositionMs));
      if (deckB.isPlaying) _deckAudioPlayer.playDeck('B');
    } else if (action == DjAction.deckABeatJumpForward || action == DjAction.deckABeatJumpBack) {
      _deckAudioPlayer.seekDeck('A', Duration(milliseconds: deckA.currentPositionMs));
    } else if (action == DjAction.deckBBeatJumpForward || action == DjAction.deckBBeatJumpBack) {
      _deckAudioPlayer.seekDeck('B', Duration(milliseconds: deckB.currentPositionMs));
    } else if (action == DjAction.triggerSamplerRiser) {
      _playSamplerPadSound(DjSamplerPadType.whiteNoiseRiser);
    } else if (action == DjAction.triggerSamplerDrop) {
      _playSamplerPadSound(DjSamplerPadType.subBassDrop);
    } else if (action == DjAction.triggerSamplerAirhorn) {
      _playSamplerPadSound(DjSamplerPadType.clubAirhorn);
    } else if (action == DjAction.triggerSamplerSiren) {
      _playSamplerPadSound(DjSamplerPadType.laserDubSiren);
    }
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  void setCrossfaderPosition(double position) {
    _orchestrator.setCrossfaderPosition(position);
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  void setCrossfaderCurve(CrossfaderCurve curve) {
    _orchestrator.setCrossfaderCurve(curve);
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  void setMasterVolume(double volume) {
    _orchestrator.setMasterVolume(volume);
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  void togglePlay(String deckId) {
    _orchestrator.togglePlay(deckId);
    final isPlaying = deckId == 'A' ? deckA.isPlaying : deckB.isPlaying;
    if (isPlaying) {
      _deckAudioPlayer.playDeck(deckId);
    } else {
      _deckAudioPlayer.pauseDeck(deckId);
    }
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  void triggerCue(String deckId) {
    _triggerMomentaryPulse(deckId == 'A' ? DjAction.deckACue : DjAction.deckBCue);
    _orchestrator.triggerCue(deckId);
    final deck = deckId == 'A' ? deckA : deckB;
    _deckAudioPlayer.seekDeck(deckId, Duration(milliseconds: deck.cuePositionMs));
    if (deck.isPlaying) {
      _deckAudioPlayer.playDeck(deckId);
    } else {
      _deckAudioPlayer.pauseDeck(deckId);
    }
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  void syncBpm(String deckId) {
    _orchestrator.syncBpm(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void adjustPitch(String deckId, double delta) {
    _orchestrator.adjustPitch(deckId, delta);
    final deck = deckId == 'A' ? deckA : deckB;
    final rate = deck.pitchMultiplier.clamp(0.5, 2.0);
    _deckAudioPlayer.setDeckPlaybackRate(deckId, rate);
    if (!_isDisposed) notifyListeners();
  }

  void resetPitch(String deckId) {
    _orchestrator.resetPitch(deckId);
    _deckAudioPlayer.setDeckPlaybackRate(deckId, 1.0);
    if (!_isDisposed) notifyListeners();
  }

  /// Sincroniza la velocidad de reproducción y BPM del deck con el tempo objetivo del reloj maestro.
  void syncDeckToBpm(String deckId, double targetBpm) {
    final deck = deckId == 'A' ? deckA : deckB;
    if (deck.bpm <= 0) return;
    final multiplier = (targetBpm / deck.bpm).clamp(0.5, 2.0);
    _orchestrator.setPitchMultiplier(deckId, multiplier);
    _deckAudioPlayer.setDeckPlaybackRate(deckId, multiplier);
    if (!_isDisposed) notifyListeners();
  }

  void triggerHotCue(String deckId, int index) {
    final actions = deckId == 'A'
        ? [DjAction.deckAHotCue1, DjAction.deckAHotCue2, DjAction.deckAHotCue3, DjAction.deckAHotCue4]
        : [DjAction.deckBHotCue1, DjAction.deckBHotCue2, DjAction.deckBHotCue3, DjAction.deckBHotCue4];
    if (index >= 0 && index < actions.length) {
      _triggerMomentaryPulse(actions[index]);
    }
    final deckBefore = deckId == 'A' ? deckA : deckB;
    final hadExistingCue = deckBefore.hotCues.containsKey(index);
    _orchestrator.triggerHotCue(deckId, index);
    final deckAfter = deckId == 'A' ? deckA : deckB;
    if (hadExistingCue) {
      _deckAudioPlayer.seekDeck(deckId, Duration(milliseconds: deckAfter.currentPositionMs));
      _deckAudioPlayer.playDeck(deckId);
    }
    if (!_isDisposed) notifyListeners();
  }

  void clearHotCue(String deckId, int index) {
    _orchestrator.clearHotCue(deckId, index);
    if (!_isDisposed) notifyListeners();
  }

  void toggleEqKill(String deckId, String band) {
    _orchestrator.toggleEqKill(deckId, band);
    if (!_isDisposed) notifyListeners();
  }

  void setEqGains(String deckId, {double? low, double? mid, double? high}) {
    _orchestrator.setEqGains(deckId, low: low, mid: mid, high: high);
    if (!_isDisposed) notifyListeners();
  }

  // FX: Filter & Delay
  void setChannelFilter(String deckId, double position) {
    _orchestrator.setChannelFilter(deckId, position);
    if (!_isDisposed) notifyListeners();
  }

  void toggleChannelDelay(String deckId) {
    _orchestrator.toggleChannelDelay(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void setChannelDelayDivision(String deckId, DjDelayDivision division) {
    _orchestrator.setChannelDelayDivision(deckId, division);
    if (!_isDisposed) notifyListeners();
  }

  void setChannelDelayParams(String deckId, {double? feedback, double? dryWet}) {
    _orchestrator.setChannelDelayParams(deckId, feedback: feedback, dryWet: dryWet);
    if (!_isDisposed) notifyListeners();
  }

  // Live Mixdown Recording
  void startRecording() {
    _orchestrator.startRecording(DateTime.now().millisecondsSinceEpoch);
    if (!_isDisposed) notifyListeners();
  }

  Uint8List? stopRecording() {
    _orchestrator.stopRecording();
    final consolidated = _orchestrator.consolidateRecordingBuffer();
    if (consolidated.isNotEmpty) {
      _lastRecordedWavBytes = DjMixWavEncoder.encode(
        samples: consolidated,
        sampleRate: _audioProcessor.sampleRate,
        numChannels: 2,
      );
    }
    if (!_isDisposed) notifyListeners();
    return _lastRecordedWavBytes;
  }

  void clearRecording() {
    _orchestrator.clearRecording();
    _lastRecordedWavBytes = null;
    if (!_isDisposed) notifyListeners();
  }

  /// Automatically estimates BPM from audio samples using [BpmBeatTrackerEngine]
  /// and loads the track into the deck.
  double loadTrackWithBeatTracking(
    String deckId, {
    required String title,
    required String artist,
    required Float32List audioSamples,
    int sampleRate = 44100,
  }) {
    final estimatedBpm = BpmBeatTrackerEngine.estimateBpm(
      samples: audioSamples,
      sampleRate: sampleRate,
    );
    final estimatedKey = DjHarmonicCamelotEngine.estimateCamelotKeyFromSamples(
      audioSamples,
      sampleRate: sampleRate,
    );
    final spectralSummary = DjTransitionSfxSynthesizer.computeSpectralWaveformSummary(
      audioSamples,
      sampleRate: sampleRate,
    );
    if (deckId == 'A') {
      _waveformA = spectralSummary;
    } else {
      _waveformB = spectralSummary;
    }
    final durationMs = ((audioSamples.length / sampleRate) * 1000.0).round();
    _orchestrator.loadTrack(
      deckId,
      title: title,
      artist: artist,
      bpm: estimatedBpm,
      durationMs: durationMs,
      camelotKey: estimatedKey.code,
    );
    final wavBytes = ProceduralInstrumentSynthesizer.floatBufferToWavBytes(
      audioSamples,
      sampleRate: sampleRate,
    );
    _deckAudioPlayer.loadDeckTrack(
      deckId,
      wavBytes: wavBytes,
      title: title,
      bpm: estimatedBpm,
    );
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
    return estimatedBpm;
  }

  /// Carga una canción curada de la biblioteca oficial en la pletina especificada,
  /// sintetizando su partitura polifónica y extrayendo su cuadrícula de compás rítmico.
  void loadCuratedSong(String deckId, String songQuery) {
    final query = songQuery.toLowerCase();
    final curated = SongDecomposerService.getCuratedLibrary();
    final song = curated.firstWhere(
      (s) => s.id.toLowerCase().contains(query) || s.title.toLowerCase().contains(query),
      orElse: () => curated.first,
    );
    final samples = _audioProcessor.synthesizeSongPackageTrack(
      song,
      deckId: deckId,
      durationMs: 16000,
    );
    loadTrackWithBeatTracking(
      deckId,
      title: song.title,
      artist: song.composer,
      audioSamples: samples,
    );
  }

  /// Carga una pista de preset o canción por nombre o identificador textual.
  void loadPresetTrack(String deckId, String trackName) {
    loadCuratedSong(deckId, trackName);
  }

  /// Carga directa de pista con metadatos de canal (Score, WAV, Mic) y síntesis espectral reactiva.
  void loadTrackSimple(
    String deckId, {
    required String title,
    required double bpm,
    String camelotKey = '8B',
    String artist = 'Estudio',
    bool reloadAudioPlayer = true,
  }) {
    _orchestrator.loadTrack(
      deckId,
      title: title,
      artist: artist,
      bpm: bpm,
      durationMs: 180000,
      camelotKey: camelotKey,
    );
    if (deckId == 'A') {
      _waveformA = DjTransitionSfxSynthesizer.generateSyntheticTrackWaveform(bpm: bpm);
    } else {
      _waveformB = DjTransitionSfxSynthesizer.generateSyntheticTrackWaveform(bpm: bpm);
    }
    if (reloadAudioPlayer) {
      _deckAudioPlayer.loadDeckTrack(
        deckId,
        title: title,
        bpm: bpm,
      );
    }
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  /// Carga explícita de archivo local o buffer WAV en el motor de audio y orquestador.
  Future<void> loadDeckTrack({
    required String deckId,
    String? filePath,
    Uint8List? wavBytes,
    String? title,
    String? artist,
    double? bpm,
  }) async {
    final finalTitle = title ?? (filePath != null ? filePath.split('/').last : 'Track $deckId');
    final finalBpm = bpm ?? 124.0;
    await _deckAudioPlayer.loadDeckTrack(
      deckId,
      filePath: filePath,
      wavBytes: wavBytes,
      title: finalTitle,
      bpm: finalBpm,
    );
    loadTrackSimple(
      deckId,
      title: finalTitle,
      bpm: finalBpm,
      artist: artist ?? 'Estudio',
      reloadAudioPlayer: false,
    );
    _syncAudioVolumes();
  }

  /// Sets individual channel volume for a deck in range [0.0, 1.0].
  void setDeckVolume(String deckId, double volume) {
    _orchestrator.setDeckVolume(deckId, volume);
    _syncAudioVolumes();
    if (!_isDisposed) notifyListeners();
  }

  /// Seeks deck playback to a target position in milliseconds.
  void seekDeck(String deckId, int positionMs) {
    _orchestrator.seekDeckPlayback(deckId, positionMs);
    _deckAudioPlayer.seekDeck(deckId, Duration(milliseconds: positionMs));
    if (!_isDisposed) notifyListeners();
  }

  void scratchDeck(String deckId, double deltaRadians) {
    final isDeckA = deckId.toUpperCase() == 'A';

    // 1. Desplazamiento angular visual continuo
    if (isDeckA) {
      _rotationAngleA += deltaRadians;
    } else {
      _rotationAngleB += deltaRadians;
    }

    // 2. Rebobinado / Avance temporal: Nudge fino en micropulsos (<=0.6 rad) y Scrub continuo en giros
    final deck = isDeckA ? deckA : deckB;
    if (deltaRadians.abs() <= 0.6) {
      _orchestrator.executeAction(
        deltaRadians > 0
            ? (isDeckA ? DjAction.deckANudgeForward : DjAction.deckBNudgeForward)
            : (isDeckA ? DjAction.deckANudgeBackward : DjAction.deckBNudgeBackward),
      );
    } else {
      final scrubMs = (deltaRadians * 800.0).round();
      final newPos = (deck.currentPositionMs + scrubMs).clamp(0, deck.durationMs);
      _orchestrator.seekDeckPlayback(deckId, newPos);
    }

    final updatedDeck = isDeckA ? deckA : deckB;
    _deckAudioPlayer.seekDeck(deckId, Duration(milliseconds: updatedDeck.currentPositionMs));

    // 3. Modulación táctil de velocidad de reproducción (scrub audio)
    final scrubRate = (deck.pitchMultiplier + (deltaRadians * 2.0)).clamp(0.2, 3.0);
    _deckAudioPlayer.setDeckPlaybackRate(deckId, scrubRate);

    if (isDeckA) {
      _scratchTimerA?.cancel();
      _scratchTimerA = Timer(const Duration(milliseconds: 140), () {
        if (!_isDisposed) {
          _deckAudioPlayer.setDeckPlaybackRate('A', deckA.pitchMultiplier);
        }
      });
    } else {
      _scratchTimerB?.cancel();
      _scratchTimerB = Timer(const Duration(milliseconds: 140), () {
        if (!_isDisposed) {
          _deckAudioPlayer.setDeckPlaybackRate('B', deckB.pitchMultiplier);
        }
      });
    }

    if (!_isDisposed) notifyListeners();
  }

  /// Rebobina rápidamente la pista de forma suave e intuitiva (por defecto 5 segundos).
  void rewindDeck(String deckId, {int milliseconds = 5000}) {
    final deck = deckId.toUpperCase() == 'A' ? deckA : deckB;
    final newPos = (deck.currentPositionMs - milliseconds).clamp(0, deck.durationMs);
    seekDeck(deckId, newPos);
    if (deckId.toUpperCase() == 'A') {
      _rotationAngleA -= 1.8;
    } else {
      _rotationAngleB -= 1.8;
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Avanza rápidamente la pista de forma suave e intuitiva (por defecto 5 segundos).
  void fastForwardDeck(String deckId, {int milliseconds = 5000}) {
    final deck = deckId.toUpperCase() == 'A' ? deckA : deckB;
    final newPos = (deck.currentPositionMs + milliseconds).clamp(0, deck.durationMs);
    seekDeck(deckId, newPos);
    if (deckId.toUpperCase() == 'A') {
      _rotationAngleA += 1.8;
    } else {
      _rotationAngleB += 1.8;
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Salta instantáneamente al inicio de la pista (00:00).
  void jumpToStart(String deckId) {
    seekDeck(deckId, 0);
    if (deckId.toUpperCase() == 'A') {
      _rotationAngleA = 0.0;
    } else {
      _rotationAngleB = 0.0;
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Ajusta el volumen de un deck de forma incremental (+ / - delta) para control por botones táctiles o scroll.
  void adjustDeckVolume(String deckId, double delta) {
    final deck = deckId.toUpperCase() == 'A' ? deckA : deckB;
    final newVol = (deck.volume + delta).clamp(0.0, 1.0);
    setDeckVolume(deckId, newVol);
  }

  Future<void> bindKey(String keyLabel, DjAction action) async {
    final updated = _orchestrator.keymapProfile.bindKey(keyLabel, action);
    _orchestrator.setKeymapProfile(updated);
    await _persistenceService.saveProfile(updated);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> resetKeymapToDefault() async {
    await _persistenceService.resetToDefault();
    final def = DjKeymapProfileEntity.defaultErgonomic();
    _orchestrator.setKeymapProfile(def);
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    cancelShowcaseRoutine();
    _playbackTicker?.cancel();
    _momentaryLedTimer?.cancel();
    _scratchTimerA?.cancel();
    _scratchTimerB?.cancel();
    _inputService.dispose();
    _deckAudioPlayer.dispose();
    _audioSynthesizer.dispose();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    super.dispose();
  }
}
