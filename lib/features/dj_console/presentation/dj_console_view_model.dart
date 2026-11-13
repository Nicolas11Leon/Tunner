import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/dj_keymap_persistence_service.dart';
import '../domain/dj_action.dart';
import '../domain/dj_crossfader_entity.dart';
import '../domain/dj_deck_entity.dart';
import '../domain/dj_keymap_profile_entity.dart';
import '../domain/dj_performance_orchestrator.dart';

/// ViewModel managing state, hardware keyboard event dispatch, and UI reactivity
/// for the Virtual DJ Performance Console.
class DjConsoleViewModel extends ChangeNotifier {
  final DjPerformanceOrchestrator _orchestrator;
  final DjKeymapPersistenceService _persistenceService;

  Timer? _playbackTicker;
  double _rotationAngleA = 0.0;
  double _rotationAngleB = 0.0;
  bool _isDisposed = false;

  DjConsoleViewModel({
    DjPerformanceOrchestrator? orchestrator,
    DjKeymapPersistenceService? persistenceService,
  })  : _orchestrator = orchestrator ?? DjPerformanceOrchestrator(),
        _persistenceService = persistenceService ?? DjKeymapPersistenceService() {
    _initPersistenceAndKeyHandler();
    _startTicker();
  }

  DjDeckEntity get deckA => _orchestrator.deckA;
  DjDeckEntity get deckB => _orchestrator.deckB;
  DjCrossfaderEntity get crossfader => _orchestrator.crossfader;
  DjKeymapProfileEntity get keymapProfile => _orchestrator.keymapProfile;
  double get masterVolume => _orchestrator.masterVolume;
  double get rotationAngleA => _rotationAngleA;
  double get rotationAngleB => _rotationAngleB;

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
