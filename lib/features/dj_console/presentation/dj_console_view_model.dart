import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/dj_audio_processor.dart';
import '../data/dj_keymap_persistence_service.dart';
import '../data/dj_mix_wav_encoder.dart';
import '../domain/bpm_beat_tracker_engine.dart';
import '../domain/dj_action.dart';
import '../domain/dj_channel_fx_entity.dart';
import '../domain/dj_crossfader_entity.dart';
import '../domain/dj_deck_entity.dart';
import '../domain/dj_keymap_profile_entity.dart';
import '../domain/dj_live_mix_recorder_entity.dart';
import '../domain/dj_performance_orchestrator.dart';

/// ViewModel managing state, hardware keyboard event dispatch, and UI reactivity
/// for the Virtual DJ Performance Console.
class DjConsoleViewModel extends ChangeNotifier {
  final DjPerformanceOrchestrator _orchestrator;
  final DjKeymapPersistenceService _persistenceService;
  final DjAudioProcessor _audioProcessor;

  Timer? _playbackTicker;
  double _rotationAngleA = 0.0;
  double _rotationAngleB = 0.0;
  bool _isDisposed = false;
  Uint8List? _lastRecordedWavBytes;

  DjConsoleViewModel({
    DjPerformanceOrchestrator? orchestrator,
    DjKeymapPersistenceService? persistenceService,
    DjAudioProcessor? audioProcessor,
  })  : _orchestrator = orchestrator ?? DjPerformanceOrchestrator(),
        _persistenceService = persistenceService ?? DjKeymapPersistenceService(),
        _audioProcessor = audioProcessor ?? DjAudioProcessor() {
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
        _orchestrator.executeAction(DjAction.deckANudgeForward);
        changed = true;
      }
      if (deckB.isPlaying) {
        _rotationAngleB += (deckB.effectiveBpm / 60.0) * 0.15;
        _orchestrator.executeAction(DjAction.deckBNudgeForward);
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

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final keyLabel = event.logicalKey.keyLabel.isNotEmpty ? event.logicalKey.keyLabel : event.logicalKey.debugName ?? '';
    final action = _orchestrator.keymapProfile.keyBindings[keyLabel];

    if (action != null) {
      executeAction(action);
      return true; // handled
    }
    return false;
  }

  void executeAction(DjAction action) {
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
    final durationMs = ((audioSamples.length / sampleRate) * 1000.0).round();
    _orchestrator.loadTrack(
      deckId,
      title: title,
      artist: artist,
      bpm: estimatedBpm,
      durationMs: durationMs,
    );
    if (!_isDisposed) notifyListeners();
    return estimatedBpm;
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
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    super.dispose();
  }
}
