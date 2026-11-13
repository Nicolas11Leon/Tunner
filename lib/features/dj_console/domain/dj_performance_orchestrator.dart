import 'dj_action.dart';
import 'dj_crossfader_entity.dart';
import 'dj_deck_entity.dart';
import 'dj_keymap_profile_entity.dart';

/// Pure Dart orchestrator responsible for managing the active state of both DJ decks,
/// the crossfader, volume balances, and dispatching discrete DJ performance actions.
class DjPerformanceOrchestrator {
  DjDeckEntity _deckA;
  DjDeckEntity _deckB;
  DjCrossfaderEntity _crossfader;
  DjKeymapProfileEntity _keymapProfile;
  double _masterVolume;

  DjPerformanceOrchestrator({
    DjDeckEntity? deckA,
    DjDeckEntity? deckB,
    DjCrossfaderEntity? crossfader,
    DjKeymapProfileEntity? keymapProfile,
    double masterVolume = 1.0,
  })  : _deckA = deckA ?? const DjDeckEntity(deckId: 'A', trackTitle: 'Demo Groove A', bpm: 124.0),
        _deckB = deckB ?? const DjDeckEntity(deckId: 'B', trackTitle: 'Demo Synthwave B', bpm: 128.0),
        _crossfader = crossfader ?? const DjCrossfaderEntity(),
        _keymapProfile = keymapProfile ?? DjKeymapProfileEntity.defaultErgonomic(),
        _masterVolume = masterVolume.clamp(0.0, 1.0);

  DjDeckEntity get deckA => _deckA;
  DjDeckEntity get deckB => _deckB;
  DjCrossfaderEntity get crossfader => _crossfader;
  DjKeymapProfileEntity get keymapProfile => _keymapProfile;
  double get masterVolume => _masterVolume;

  /// Returns effective output gains for both decks after factoring channel volume,
  /// crossfader position, and master volume.
  ({double effectiveGainA, double effectiveGainB}) getEffectiveGains() {
    final xfader = _crossfader.calculateGains();
    final gA = (_deckA.volume * xfader.gainA * _masterVolume).clamp(0.0, 1.0);
    final gB = (_deckB.volume * xfader.gainB * _masterVolume).clamp(0.0, 1.0);
    return (effectiveGainA: gA, effectiveGainB: gB);
  }

  /// Sets the active keymap profile.
  void setKeymapProfile(DjKeymapProfileEntity profile) {
    _keymapProfile = profile;
  }

  /// Updates crossfader position in range [-1.0, 1.0].
  void setCrossfaderPosition(double position) {
    _crossfader = _crossfader.copyWith(position: position);
  }

  /// Updates crossfader attenuation curve.
  void setCrossfaderCurve(CrossfaderCurve curve) {
    _crossfader = _crossfader.copyWith(curve: curve);
  }

  /// Updates master output volume in range [0.0, 1.0].
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
  }

  /// Loads a track into the specified deck ('A' or 'B').
  void loadTrack(
    String deckId, {
    required String title,
    required String artist,
    required double bpm,
    required int durationMs,
    String? audioPath,
  }) {
    final newDeck = DjDeckEntity(
      deckId: deckId,
      trackTitle: title,
      artist: artist,
      bpm: bpm,
      durationMs: durationMs,
      audioPath: audioPath,
      currentPositionMs: 0,
      isPlaying: false,
    );
    if (deckId == 'A') {
      _deckA = newDeck;
    } else {
      _deckB = newDeck;
    }
  }

  /// Toggles playback for the specified deck.
  void togglePlay(String deckId) {
    if (deckId == 'A') {
      _deckA = _deckA.copyWith(isPlaying: !_deckA.isPlaying);
    } else {
      _deckB = _deckB.copyWith(isPlaying: !_deckB.isPlaying);
    }
  }

  /// Executes standard Cue behavior:
  /// - If playing: pauses and seeks to active Cue point.
  /// - If paused: sets Cue point to current position.
  void triggerCue(String deckId) {
    if (deckId == 'A') {
      if (_deckA.isPlaying) {
        _deckA = _deckA.copyWith(
          isPlaying: false,
          currentPositionMs: _deckA.cuePositionMs,
        );
      } else {
        _deckA = _deckA.copyWith(cuePositionMs: _deckA.currentPositionMs);
      }
    } else {
      if (_deckB.isPlaying) {
        _deckB = _deckB.copyWith(
          isPlaying: false,
          currentPositionMs: _deckB.cuePositionMs,
        );
      } else {
        _deckB = _deckB.copyWith(cuePositionMs: _deckB.currentPositionMs);
      }
    }
  }

  /// Synchronizes target deck BPM to the opposite deck's effective BPM.
  void syncBpm(String targetDeckId) {
    if (targetDeckId == 'A') {
      final targetBpm = _deckB.effectiveBpm;
      if (_deckA.bpm > 0) {
        final multiplier = (targetBpm / _deckA.bpm).clamp(0.5, 2.0);
        _deckA = _deckA.copyWith(pitchMultiplier: multiplier, isSyncActive: true);
      }
    } else {
      final targetBpm = _deckA.effectiveBpm;
      if (_deckB.bpm > 0) {
        final multiplier = (targetBpm / _deckB.bpm).clamp(0.5, 2.0);
        _deckB = _deckB.copyWith(pitchMultiplier: multiplier, isSyncActive: true);
      }
    }
  }

  /// Adjusts pitch multiplier relative to current value.
  void adjustPitch(String deckId, double delta) {
    if (deckId == 'A') {
      final newMult = (_deckA.pitchMultiplier + delta).clamp(0.5, 2.0);
      _deckA = _deckA.copyWith(pitchMultiplier: newMult, isSyncActive: false);
    } else {
      final newMult = (_deckB.pitchMultiplier + delta).clamp(0.5, 2.0);
      _deckB = _deckB.copyWith(pitchMultiplier: newMult, isSyncActive: false);
    }
  }

  /// Resets pitch multiplier to unity (1.0).
  void resetPitch(String deckId) {
    if (deckId == 'A') {
      _deckA = _deckA.copyWith(pitchMultiplier: 1.0, isSyncActive: false);
    } else {
      _deckB = _deckB.copyWith(pitchMultiplier: 1.0, isSyncActive: false);
    }
  }

  /// Sets or jumps to a Hot Cue point (index 1..4).
  void triggerHotCue(String deckId, int cueIndex) {
    if (deckId == 'A') {
      final existing = _deckA.hotCues[cueIndex];
      if (existing != null) {
        _deckA = _deckA.copyWith(currentPositionMs: existing, isPlaying: true);
      } else {
        final updatedCues = Map<int, int>.from(_deckA.hotCues);
        updatedCues[cueIndex] = _deckA.currentPositionMs;
        _deckA = _deckA.copyWith(hotCues: updatedCues);
      }
    } else {
      final existing = _deckB.hotCues[cueIndex];
      if (existing != null) {
        _deckB = _deckB.copyWith(currentPositionMs: existing, isPlaying: true);
      } else {
        final updatedCues = Map<int, int>.from(_deckB.hotCues);
        updatedCues[cueIndex] = _deckB.currentPositionMs;
        _deckB = _deckB.copyWith(hotCues: updatedCues);
      }
    }
  }

  /// Clears a Hot Cue point.
  void clearHotCue(String deckId, int cueIndex) {
    if (deckId == 'A') {
      final updated = Map<int, int>.from(_deckA.hotCues);
      updated.remove(cueIndex);
      _deckA = _deckA.copyWith(hotCues: updated);
    } else {
      final updated = Map<int, int>.from(_deckB.hotCues);
      updated.remove(cueIndex);
      _deckB = _deckB.copyWith(hotCues: updated);
    }
  }

  /// Toggles an EQ kill switch (low, mid, high).
  void toggleEqKill(String deckId, String band) {
    if (deckId == 'A') {
      switch (band.toLowerCase()) {
        case 'low':
          _deckA = _deckA.copyWith(isKillLow: !_deckA.isKillLow);
          break;
        case 'mid':
          _deckA = _deckA.copyWith(isKillMid: !_deckA.isKillMid);
          break;
        case 'high':
          _deckA = _deckA.copyWith(isKillHigh: !_deckA.isKillHigh);
          break;
      }
    } else {
      switch (band.toLowerCase()) {
        case 'low':
          _deckB = _deckB.copyWith(isKillLow: !_deckB.isKillLow);
          break;
        case 'mid':
          _deckB = _deckB.copyWith(isKillMid: !_deckB.isKillMid);
          break;
        case 'high':
          _deckB = _deckB.copyWith(isKillHigh: !_deckB.isKillHigh);
          break;
      }
    }
  }

  /// Updates EQ band gains.
  void setEqGains(String deckId, {double? low, double? mid, double? high}) {
    if (deckId == 'A') {
      _deckA = _deckA.copyWith(
        gainLow: low?.clamp(0.0, 1.5),
        gainMid: mid?.clamp(0.0, 1.5),
        gainHigh: high?.clamp(0.0, 1.5),
      );
    } else {
      _deckB = _deckB.copyWith(
        gainLow: low?.clamp(0.0, 1.5),
        gainMid: mid?.clamp(0.0, 1.5),
        gainHigh: high?.clamp(0.0, 1.5),
      );
    }
  }

  /// Dispatches and executes a discrete [DjAction].
  void executeAction(DjAction action) {
    switch (action) {
      // Deck A
      case DjAction.deckAPlayPause:
        togglePlay('A');
        break;
      case DjAction.deckACue:
        triggerCue('A');
        break;
      case DjAction.deckASync:
        syncBpm('A');
        break;
      case DjAction.deckAPitchUp:
        adjustPitch('A', 0.005);
        break;
      case DjAction.deckAPitchDown:
        adjustPitch('A', -0.005);
        break;
      case DjAction.deckAPitchReset:
        resetPitch('A');
        break;
      case DjAction.deckANudgeForward:
        _deckA = _deckA.copyWith(
          currentPositionMs: (_deckA.currentPositionMs + 50).clamp(0, _deckA.durationMs),
        );
        break;
      case DjAction.deckANudgeBackward:
        _deckA = _deckA.copyWith(
          currentPositionMs: (_deckA.currentPositionMs - 50).clamp(0, _deckA.durationMs),
        );
        break;
      case DjAction.deckAHotCue1:
        triggerHotCue('A', 1);
        break;
      case DjAction.deckAHotCue2:
        triggerHotCue('A', 2);
        break;
      case DjAction.deckAHotCue3:
        triggerHotCue('A', 3);
        break;
      case DjAction.deckAHotCue4:
        triggerHotCue('A', 4);
        break;
      case DjAction.deckAKillLow:
        toggleEqKill('A', 'low');
        break;
      case DjAction.deckAKillMid:
        toggleEqKill('A', 'mid');
        break;
      case DjAction.deckAKillHigh:
        toggleEqKill('A', 'high');
        break;

      // Deck B
      case DjAction.deckBPlayPause:
        togglePlay('B');
        break;
      case DjAction.deckBCue:
        triggerCue('B');
        break;
      case DjAction.deckBSync:
        syncBpm('B');
        break;
      case DjAction.deckBPitchUp:
        adjustPitch('B', 0.005);
        break;
      case DjAction.deckBPitchDown:
        adjustPitch('B', -0.005);
        break;
      case DjAction.deckBPitchReset:
        resetPitch('B');
        break;
      case DjAction.deckBNudgeForward:
        _deckB = _deckB.copyWith(
          currentPositionMs: (_deckB.currentPositionMs + 50).clamp(0, _deckB.durationMs),
        );
        break;
      case DjAction.deckBNudgeBackward:
        _deckB = _deckB.copyWith(
          currentPositionMs: (_deckB.currentPositionMs - 50).clamp(0, _deckB.durationMs),
        );
        break;
      case DjAction.deckBHotCue1:
        triggerHotCue('B', 1);
        break;
      case DjAction.deckBHotCue2:
        triggerHotCue('B', 2);
        break;
      case DjAction.deckBHotCue3:
        triggerHotCue('B', 3);
        break;
      case DjAction.deckBHotCue4:
        triggerHotCue('B', 4);
        break;
      case DjAction.deckBKillLow:
        toggleEqKill('B', 'low');
        break;
      case DjAction.deckBKillMid:
        toggleEqKill('B', 'mid');
        break;
      case DjAction.deckBKillHigh:
        toggleEqKill('B', 'high');
        break;

      // Crossfader
      case DjAction.crossfaderShiftLeft:
        setCrossfaderPosition(_crossfader.position - 0.1);
        break;
      case DjAction.crossfaderShiftRight:
        setCrossfaderPosition(_crossfader.position + 0.1);
        break;
      case DjAction.crossfaderCenter:
        setCrossfaderPosition(0.0);
        break;
      case DjAction.crossfaderHardLeft:
        setCrossfaderPosition(-1.0);
        break;
      case DjAction.crossfaderHardRight:
        setCrossfaderPosition(1.0);
        break;

      // Master Volume
      case DjAction.masterVolumeUp:
        setMasterVolume(_masterVolume + 0.05);
        break;
      case DjAction.masterVolumeDown:
        setMasterVolume(_masterVolume - 0.05);
        break;
    }
  }
}
