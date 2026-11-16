import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/dj_audio_processor.dart';
import '../data/dj_gamepad_input_service.dart';
import '../data/dj_hardware_catalog.dart';
import '../data/dj_keymap_persistence_service.dart';
import '../data/dj_mix_wav_encoder.dart';
import '../data/dj_transition_sfx_synthesizer.dart';
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

/// ViewModel managing state, hardware keyboard event dispatch, and UI reactivity
/// for the Virtual DJ Performance Console with Hardware Skins and Gamepad support.
class DjConsoleViewModel extends ChangeNotifier {
  final DjPerformanceOrchestrator _orchestrator;
  final DjKeymapPersistenceService _persistenceService;
  final DjAudioProcessor _audioProcessor;
  late final DjGamepadInputService _inputService;

  Timer? _playbackTicker;
  Timer? _momentaryLedTimer;
  DjAction? _momentaryLitAction;
  double _rotationAngleA = 0.0;
  double _rotationAngleB = 0.0;
  bool _isDisposed = false;
  Uint8List? _lastRecordedWavBytes;

  // Hardware Skins & Gamepad Mapping
  DjHardwareSkinEntity _activeSkin = DjHardwareCatalog.ddjFlx4();
  bool _isHardwareViewActive = true;
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

  DjConsoleViewModel({
    DjPerformanceOrchestrator? orchestrator,
    DjKeymapPersistenceService? persistenceService,
    DjAudioProcessor? audioProcessor,
    DjGamepadInputService? inputService,
  })  : _orchestrator = orchestrator ?? DjPerformanceOrchestrator(),
        _persistenceService = persistenceService ?? DjKeymapPersistenceService(),
        _audioProcessor = audioProcessor ?? DjAudioProcessor() {
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
    if (deckA.hotCues.isNotEmpty && deckA.hotCues[0] != null) lit.add(DjAction.deckAHotCue1);
    if (deckA.hotCues.length > 1 && deckA.hotCues[1] != null) lit.add(DjAction.deckAHotCue2);
    if (deckA.hotCues.length > 2 && deckA.hotCues[2] != null) lit.add(DjAction.deckAHotCue3);
    if (deckA.hotCues.length > 3 && deckA.hotCues[3] != null) lit.add(DjAction.deckAHotCue4);

    // Hot Cues LEDs (Deck B)
    if (deckB.hotCues.isNotEmpty && deckB.hotCues[0] != null) lit.add(DjAction.deckBHotCue1);
    if (deckB.hotCues.length > 1 && deckB.hotCues[1] != null) lit.add(DjAction.deckBHotCue2);
    if (deckB.hotCues.length > 2 && deckB.hotCues[2] != null) lit.add(DjAction.deckBHotCue3);
    if (deckB.hotCues.length > 3 && deckB.hotCues[3] != null) lit.add(DjAction.deckBHotCue4);

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
        _rotationAngleA += (deckA.effectiveBpm / 60.0) * 0.15;
        _orchestrator.advanceDeckPlayback('A', 33);
        changed = true;
      }
      if (deckB.isPlaying) {
        _rotationAngleB += (deckB.effectiveBpm / 60.0) * 0.15;
        _orchestrator.advanceDeckPlayback('B', 33);
        changed = true;
      }
      if (_orchestrator.automix.isActive) {
        _orchestrator.advanceAutomix(33);
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
    _orchestrator.toggleLoop(deckId);
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
    if (!_isDisposed) notifyListeners();
  }

  void triggerSamplerPad(DjSamplerPadType pad) {
    _orchestrator.triggerSamplerPad(pad);
    _lastSamplerBuffer = DjTransitionSfxSynthesizer.generatePadBuffer(
      pad,
      sampleRate: _audioProcessor.sampleRate,
    );
    if (!_isDisposed) notifyListeners();
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
    if (!_isDisposed) notifyListeners();
  }

  void setCrossfaderPosition(double position) {
    _orchestrator.setCrossfaderPosition(position);
    if (!_isDisposed) notifyListeners();
  }

  void setCrossfaderCurve(CrossfaderCurve curve) {
    _orchestrator.setCrossfaderCurve(curve);
    if (!_isDisposed) notifyListeners();
  }

  void setMasterVolume(double volume) {
    _orchestrator.setMasterVolume(volume);
    if (!_isDisposed) notifyListeners();
  }

  void togglePlay(String deckId) {
    _orchestrator.togglePlay(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void triggerCue(String deckId) {
    _triggerMomentaryPulse(deckId == 'A' ? DjAction.deckACue : DjAction.deckBCue);
    _orchestrator.triggerCue(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void syncBpm(String deckId) {
    _orchestrator.syncBpm(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void adjustPitch(String deckId, double delta) {
    _orchestrator.adjustPitch(deckId, delta);
    if (!_isDisposed) notifyListeners();
  }

  void resetPitch(String deckId) {
    _orchestrator.resetPitch(deckId);
    if (!_isDisposed) notifyListeners();
  }

  void triggerHotCue(String deckId, int index) {
    final actions = deckId == 'A'
        ? [DjAction.deckAHotCue1, DjAction.deckAHotCue2, DjAction.deckAHotCue3, DjAction.deckAHotCue4]
        : [DjAction.deckBHotCue1, DjAction.deckBHotCue2, DjAction.deckBHotCue3, DjAction.deckBHotCue4];
    if (index >= 0 && index < actions.length) {
      _triggerMomentaryPulse(actions[index]);
    }
    _orchestrator.triggerHotCue(deckId, index);
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
    if (!_isDisposed) notifyListeners();
    return estimatedBpm;
  }

  /// Carga directa de pista con metadatos de canal (Score, WAV, Mic) y síntesis espectral reactiva.
  void loadTrackSimple(
    String deckId, {
    required String title,
    required double bpm,
    String camelotKey = '8B',
    String artist = 'Estudio',
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
    if (!_isDisposed) notifyListeners();
  }

  void scratchDeck(String deckId, double deltaRadians) {
    if (deckId == 'A') {
      _rotationAngleA += deltaRadians;
      _orchestrator.executeAction(deltaRadians > 0 ? DjAction.deckANudgeForward : DjAction.deckANudgeBackward);
    } else {
      _rotationAngleB += deltaRadians;
      _orchestrator.executeAction(deltaRadians > 0 ? DjAction.deckBNudgeForward : DjAction.deckBNudgeBackward);
    }
    if (!_isDisposed) notifyListeners();
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
    _playbackTicker?.cancel();
    _momentaryLedTimer?.cancel();
    _inputService.dispose();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    super.dispose();
  }
}
