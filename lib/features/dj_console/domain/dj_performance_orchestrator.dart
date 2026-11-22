import 'dart:typed_data';
import 'dj_action.dart';
import 'dj_channel_fx_entity.dart';
import 'dj_crossfader_entity.dart';
import 'dj_cue_monitor_entity.dart';
import 'dj_deck_entity.dart';
import 'dj_harmonic_camelot_engine.dart';
import 'dj_keymap_profile_entity.dart';
import 'dj_live_mix_recorder_entity.dart';
import 'dj_loop_and_slip_engine.dart';
import 'dj_sampler_bank_entity.dart';
import 'dj_smart_automix_engine.dart';
import 'dj_stem_isolation_entity.dart';

/// Pure Dart orchestrator responsible for managing the active state of both DJ decks,
/// the crossfader, volume balances, performance FX, 4-Stems, Camelot harmonic sync,
/// auto-loops with Slip Mode, Sampler bank, Smart Automix, Split-Cue, and live recording.
class DjPerformanceOrchestrator {
  DjDeckEntity _deckA;
  DjDeckEntity _deckB;
  DjCrossfaderEntity _crossfader;
  DjKeymapProfileEntity _keymapProfile;
  double _masterVolume;
  DjChannelFxEntity _fxA;
  DjChannelFxEntity _fxB;
  DjLiveMixRecorderEntity _recorder;
  DjSamplerBankEntity _sampler;
  DjSmartAutomixEngine _automix;
  DjCueMonitorEntity _cueMonitor;

  DjPerformanceOrchestrator({
    DjDeckEntity? deckA,
    DjDeckEntity? deckB,
    DjCrossfaderEntity? crossfader,
    DjKeymapProfileEntity? keymapProfile,
    double masterVolume = 1.0,
    DjChannelFxEntity? fxA,
    DjChannelFxEntity? fxB,
    DjLiveMixRecorderEntity? recorder,
    DjSamplerBankEntity? sampler,
    DjSmartAutomixEngine? automix,
    DjCueMonitorEntity? cueMonitor,
  })  : _deckA = deckA ?? const DjDeckEntity(deckId: 'A', trackTitle: 'Demo Groove A', bpm: 124.0, camelotKey: '8A'),
        _deckB = deckB ?? const DjDeckEntity(deckId: 'B', trackTitle: 'Demo Synthwave B', bpm: 128.0, camelotKey: '9A'),
        _crossfader = crossfader ?? const DjCrossfaderEntity(),
        _keymapProfile = keymapProfile ?? DjKeymapProfileEntity.defaultErgonomic(),
        _masterVolume = masterVolume.clamp(0.0, 1.0),
        _fxA = fxA ?? const DjChannelFxEntity(),
        _fxB = fxB ?? const DjChannelFxEntity(),
        _recorder = recorder ?? const DjLiveMixRecorderEntity(),
        _sampler = sampler ?? const DjSamplerBankEntity(),
        _automix = automix ?? const DjSmartAutomixEngine(),
        _cueMonitor = cueMonitor ?? const DjCueMonitorEntity();

  DjDeckEntity get deckA => _deckA;
  DjDeckEntity get deckB => _deckB;
  DjCrossfaderEntity get crossfader => _crossfader;
  DjKeymapProfileEntity get keymapProfile => _keymapProfile;
  double get masterVolume => _masterVolume;
  DjChannelFxEntity get fxA => _fxA;
  DjChannelFxEntity get fxB => _fxB;
  DjLiveMixRecorderEntity get recorder => _recorder;
  DjSamplerBankEntity get sampler => _sampler;
  DjSmartAutomixEngine get automix => _automix;
  DjCueMonitorEntity get cueMonitor => _cueMonitor;

  /// Evaluates real-time harmonic compatibility between Deck A and Deck B on the Camelot Wheel.
  CamelotCompatibility get harmonicCompatibility {
    return DjHarmonicCamelotEngine.analyzeCompatibility(
      _deckA.effectiveCamelotKey.code,
      _deckB.effectiveCamelotKey.code,
    );
  }

  double get deckAGain => (_crossfader.calculateGains().gainA * _deckA.trim).clamp(0.0, 2.0);
  double get deckBGain => (_crossfader.calculateGains().gainB * _deckB.trim).clamp(0.0, 2.0);
  Float32List consolidateRecordingBuffer() => _recorder.consolidateBuffer();

  /// Returns effective output gains for both decks after factoring channel volume,
  /// trim preamplification, crossfader position, and master volume.
  ({double effectiveGainA, double effectiveGainB}) getEffectiveGains() {
    final xfader = _crossfader.calculateGains();
    final gA = (_deckA.volume * _deckA.trim * xfader.gainA * _masterVolume).clamp(0.0, 1.0);
    final gB = (_deckB.volume * _deckB.trim * xfader.gainB * _masterVolume).clamp(0.0, 1.0);
    return (effectiveGainA: gA, effectiveGainB: gB);
  }

  /// Sets the active keymap profile.
  void setKeymapProfile(DjKeymapProfileEntity profile) {
    _keymapProfile = profile;
  }

  /// Updates crossfader position in range [-1.0, 1.0].
  /// Automatically cancels Smart Automix if user takes manual control.
  void setCrossfaderPosition(double position, {bool fromAutomix = false}) {
    if (!fromAutomix && _automix.isActive) {
      _automix = _automix.cancel();
    }
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

  /// Sets individual channel volume for a deck in range [0.0, 1.0].
  void setDeckVolume(String deckId, double volume) {
    _updateDeck(deckId, (deck) {
      return deck.copyWith(volume: volume.clamp(0.0, 1.0));
    });
  }

  /// Seeks deck playback to a target position in milliseconds.
  void seekDeckPlayback(String deckId, int targetPositionMs) {
    _updateDeck(deckId, (deck) {
      final clampedPos = targetPositionMs.clamp(0, deck.durationMs);
      return deck.copyWith(
        currentPositionMs: clampedPos,
        slipPositionMs: deck.isSlipModeActive ? deck.slipPositionMs : clampedPos,
      );
    });
  }

  /// Loads a track into the specified deck ('A' or 'B').
  void loadTrack(
    String deckId, {
    required String title,
    required String artist,
    required double bpm,
    required int durationMs,
    String? audioPath,
    String camelotKey = '8A',
  }) {
    final newDeck = DjDeckEntity(
      deckId: deckId,
      trackTitle: title,
      artist: artist,
      bpm: bpm,
      durationMs: durationMs,
      audioPath: audioPath,
      camelotKey: camelotKey,
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

  /// Sets preamplification TRIM gain [0.0, 2.0] for the specified deck.
  void setTrim(String deckId, double trim) {
    final clamped = trim.clamp(0.0, 2.0);
    if (deckId == 'A') {
      _deckA = _deckA.copyWith(trim: clamped);
    } else {
      _deckB = _deckB.copyWith(trim: clamped);
    }
  }

  /// Sets pitch multiplier directly for master clock / BPM sync.
  void setPitchMultiplier(String deckId, double multiplier) {
    final clamped = multiplier.clamp(0.5, 2.0);
    if (deckId == 'A') {
      _deckA = _deckA.copyWith(pitchMultiplier: clamped, isSyncActive: true);
    } else {
      _deckB = _deckB.copyWith(pitchMultiplier: clamped, isSyncActive: true);
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

  /// Sets bipolar filter position [-1.0, 1.0] for the specified deck.
  void setChannelFilter(String deckId, double position) {
    if (deckId == 'A') {
      _fxA = _fxA.copyWith(filterPosition: position);
    } else {
      _fxB = _fxB.copyWith(filterPosition: position);
    }
  }

  /// Toggles delay effect on/off for the specified deck.
  void toggleChannelDelay(String deckId) {
    if (deckId == 'A') {
      _fxA = _fxA.copyWith(isDelayActive: !_fxA.isDelayActive);
    } else {
      _fxB = _fxB.copyWith(isDelayActive: !_fxB.isDelayActive);
    }
  }

  /// Sets delay division for the specified deck.
  void setChannelDelayDivision(String deckId, DjDelayDivision division) {
    if (deckId == 'A') {
      _fxA = _fxA.copyWith(delayDivision: division);
    } else {
      _fxB = _fxB.copyWith(delayDivision: division);
    }
  }

  /// Sets delay feedback and dry/wet balance.
  void setChannelDelayParams(String deckId, {double? feedback, double? dryWet}) {
    if (deckId == 'A') {
      _fxA = _fxA.copyWith(delayFeedback: feedback, delayDryWet: dryWet);
    } else {
      _fxB = _fxB.copyWith(delayFeedback: feedback, delayDryWet: dryWet);
    }
  }

  /// Starts live mix recording session.
  void startRecording(int nowMs) {
    _recorder = _recorder.start(nowMs);
  }

  /// Appends an audio chunk to the active recording session.
  void appendRecordingChunk(Float32List chunk, int nowMs) {
    if (_recorder.isRecording) {
      _recorder = _recorder.appendChunk(chunk, nowMs);
    }
  }

  /// Stops live mix recording.
  void stopRecording() {
    _recorder = _recorder.stop();
  }

  /// Clears recorded session.
  void clearRecording() {
    _recorder = _recorder.clear();
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

      // FX & Beat Performance: Deck A
      case DjAction.deckAFilterSweepLeft:
        setChannelFilter('A', _fxA.filterPosition - 0.1);
        break;
      case DjAction.deckAFilterSweepRight:
        setChannelFilter('A', _fxA.filterPosition + 0.1);
        break;
      case DjAction.deckAFilterReset:
        setChannelFilter('A', 0.0);
        break;
      case DjAction.deckAToggleDelay:
        toggleChannelDelay('A');
        break;

      // FX & Beat Performance: Deck B
      case DjAction.deckBFilterSweepLeft:
        setChannelFilter('B', _fxB.filterPosition - 0.1);
        break;
      case DjAction.deckBFilterSweepRight:
        setChannelFilter('B', _fxB.filterPosition + 0.1);
        break;
      case DjAction.deckBFilterReset:
        setChannelFilter('B', 0.0);
        break;
      case DjAction.deckBToggleDelay:
        toggleChannelDelay('B');
        break;

      // Live Mixdown Recording
      case DjAction.toggleMixRecording:
        if (_recorder.isRecording) {
          stopRecording();
        } else {
          startRecording(DateTime.now().millisecondsSinceEpoch);
        }
        break;

      // Pro Workstation: 4-Stems Deck A
      case DjAction.deckAToggleVocalStem:
        toggleStem('A', DjStemType.vocals);
        break;
      case DjAction.deckAToggleDrumsStem:
        toggleStem('A', DjStemType.drums);
        break;
      case DjAction.deckAToggleBassStem:
        toggleStem('A', DjStemType.bass);
        break;
      case DjAction.deckAToggleMelodyStem:
        toggleStem('A', DjStemType.melody);
        break;

      // Pro Workstation: 4-Stems Deck B
      case DjAction.deckBToggleVocalStem:
        toggleStem('B', DjStemType.vocals);
        break;
      case DjAction.deckBToggleDrumsStem:
        toggleStem('B', DjStemType.drums);
        break;
      case DjAction.deckBToggleBassStem:
        toggleStem('B', DjStemType.bass);
        break;
      case DjAction.deckBToggleMelodyStem:
        toggleStem('B', DjStemType.melody);
        break;

      // Pro Workstation: Auto-Loops, Slip & Beat Jump Deck A
      case DjAction.deckALoopToggle:
        toggleLoop('A');
        break;
      case DjAction.deckALoopHalve:
        halveLoop('A');
        break;
      case DjAction.deckALoopDouble:
        doubleLoop('A');
        break;
      case DjAction.deckAToggleSlip:
        toggleSlipMode('A');
        break;
      case DjAction.deckABeatJumpForward:
        beatJump('A', 4.0);
        break;
      case DjAction.deckABeatJumpBack:
        beatJump('A', -4.0);
        break;

      // Pro Workstation: Auto-Loops, Slip & Beat Jump Deck B
      case DjAction.deckBLoopToggle:
        toggleLoop('B');
        break;
      case DjAction.deckBLoopHalve:
        halveLoop('B');
        break;
      case DjAction.deckBLoopDouble:
        doubleLoop('B');
        break;
      case DjAction.deckBToggleSlip:
        toggleSlipMode('B');
        break;
      case DjAction.deckBBeatJumpForward:
        beatJump('B', 4.0);
        break;
      case DjAction.deckBBeatJumpBack:
        beatJump('B', -4.0);
        break;

      // Pro Workstation: Harmonic Key-Sync
      case DjAction.deckAKeySync:
        syncKey('A');
        break;
      case DjAction.deckBKeySync:
        syncKey('B');
        break;

      // Pro Workstation: Sampler Pads & Master Automix / Split-Cue
      case DjAction.triggerSamplerRiser:
        triggerSamplerPad(DjSamplerPadType.whiteNoiseRiser);
        break;
      case DjAction.triggerSamplerDrop:
        triggerSamplerPad(DjSamplerPadType.subBassDrop);
        break;
      case DjAction.triggerSamplerAirhorn:
        triggerSamplerPad(DjSamplerPadType.clubAirhorn);
        break;
      case DjAction.triggerSamplerSiren:
        triggerSamplerPad(DjSamplerPadType.laserDubSiren);
        break;
      case DjAction.toggleSmartAutomix:
        if (_automix.isActive) {
          cancelSmartAutomix();
        } else {
          final dir = _crossfader.position <= 0.0
              ? AutomixDirection.deckAToDeckB
              : AutomixDirection.deckBToDeckA;
          startSmartAutomix(dir);
        }
        break;
      case DjAction.toggleSplitCue:
        toggleSplitCue();
        break;
    }
  }

  // --- Pro Workstation Methods ---

  void _updateDeck(String deckId, DjDeckEntity Function(DjDeckEntity deck) transform) {
    if (deckId == 'A') {
      _deckA = transform(_deckA);
    } else {
      _deckB = transform(_deckB);
    }
  }

  /// Toggles mute on one of the 4 real-time stems (Vocals, Drums, Bass, Melody).
  void toggleStem(String deckId, DjStemType type) {
    _updateDeck(deckId, (deck) => deck.copyWith(stems: deck.stems.toggleMute(type)));
  }

  /// Applies a fast stem performance preset ('acapella', 'instrumental', 'rhythm', 'reset').
  void applyStemPreset(String deckId, String preset) {
    _updateDeck(deckId, (deck) {
      switch (preset) {
        case 'acapella':
          return deck.copyWith(stems: deck.stems.isolateAcapella());
        case 'instrumental':
          return deck.copyWith(stems: deck.stems.isolateInstrumental());
        case 'rhythm':
          return deck.copyWith(stems: deck.stems.isolateRhythm());
        default:
          return deck.copyWith(stems: deck.stems.resetAll());
      }
    });
  }

  /// Updates the detected Camelot key for the deck.
  void setDeckCamelotKey(String deckId, String camelotKey) {
    _updateDeck(deckId, (deck) => deck.copyWith(camelotKey: camelotKey));
  }

  /// Toggles Master Tempo / Key-Lock on the deck.
  void toggleKeyLock(String deckId) {
    _updateDeck(deckId, (deck) => deck.copyWith(isKeyLockEnabled: !deck.isKeyLockEnabled));
  }

  /// Shifts deck musical key by [delta] semitones within [-6, +6].
  void shiftPitchSemitones(String deckId, int delta) {
    _updateDeck(
      deckId,
      (deck) => deck.copyWith(pitchSemitonesShift: deck.pitchSemitonesShift + delta),
    );
  }

  /// Automatically shifts deck key in semitones to match the opposite deck on the Camelot Wheel.
  void syncKey(String deckId) {
    final src = deckId == 'A' ? _deckA : _deckB;
    final dst = deckId == 'A' ? _deckB : _deckA;

    final optimalDelta = DjHarmonicCamelotEngine.calculateOptimalSemitoneShift(
      src.camelotKey,
      dst.effectiveCamelotKey.code,
    );
    _updateDeck(deckId, (deck) => deck.copyWith(pitchSemitonesShift: optimalDelta));
  }

  /// Engages a quantized Auto-Loop of [beats] beats from current position.
  void engageAutoLoop(String deckId, double beats) {
    _updateDeck(deckId, (deck) {
      final startMs = deck.currentPositionMs;
      final loopDuration = DjLoopAndSlipEngine.computeLoopDurationMs(
        beats: beats,
        effectiveBpm: deck.effectiveBpm,
      );
      final endMs = (startMs + loopDuration).clamp(startMs + 15, deck.durationMs);
      return deck.copyWith(
        isLoopActive: true,
        loopStartMs: startMs,
        loopEndMs: endMs,
        loopBeats: beats,
      );
    });
  }

  /// Toggles active Auto-Loop or exits it (restoring slip position if Slip Mode is active).
  void toggleLoop(String deckId) {
    final deck = deckId == 'A' ? _deckA : _deckB;
    if (deck.isLoopActive) {
      exitLoop(deckId);
    } else {
      engageAutoLoop(deckId, deck.loopBeats);
    }
  }

  /// Exits active Auto-Loop; if Slip Mode is enabled, snaps back to phantom timeline.
  void exitLoop(String deckId) {
    _updateDeck(deckId, (deck) {
      final targetPos = deck.isSlipModeActive ? deck.slipPositionMs : deck.currentPositionMs;
      return deck.copyWith(
        isLoopActive: false,
        currentPositionMs: targetPos.clamp(0, deck.durationMs),
      );
    });
  }

  /// Halves current loop size (down to 1/32 beat).
  void halveLoop(String deckId) {
    _updateDeck(deckId, (deck) {
      final nextBeats = DjLoopAndSlipEngine.halveBeats(deck.loopBeats);
      final loopDuration = DjLoopAndSlipEngine.computeLoopDurationMs(
        beats: nextBeats,
        effectiveBpm: deck.effectiveBpm,
      );
      final newEnd = (deck.loopStartMs + loopDuration).clamp(deck.loopStartMs + 15, deck.durationMs);
      return deck.copyWith(
        loopBeats: nextBeats,
        loopEndMs: newEnd,
      );
    });
  }

  /// Doubles current loop size (up to 16 beats).
  void doubleLoop(String deckId) {
    _updateDeck(deckId, (deck) {
      final nextBeats = DjLoopAndSlipEngine.doubleBeats(deck.loopBeats);
      final loopDuration = DjLoopAndSlipEngine.computeLoopDurationMs(
        beats: nextBeats,
        effectiveBpm: deck.effectiveBpm,
      );
      final newEnd = (deck.loopStartMs + loopDuration).clamp(deck.loopStartMs + 15, deck.durationMs);
      return deck.copyWith(
        loopBeats: nextBeats,
        loopEndMs: newEnd,
      );
    });
  }

  /// Jumps playback forward or backward by quantized [beatDelta] beats.
  void beatJump(String deckId, double beatDelta) {
    _updateDeck(deckId, (deck) {
      final nextPos = DjLoopAndSlipEngine.computeBeatJumpPositionMs(
        currentPositionMs: deck.currentPositionMs,
        beatDelta: beatDelta,
        effectiveBpm: deck.effectiveBpm,
        durationMs: deck.durationMs,
      );
      return deck.copyWith(
        currentPositionMs: nextPos,
        slipPositionMs: deck.isSlipModeActive ? deck.slipPositionMs : nextPos,
      );
    });
  }

  /// Toggles Slip Mode (maintains phantom background timeline during loops/scratches).
  void toggleSlipMode(String deckId) {
    _updateDeck(deckId, (deck) {
      final enabling = !deck.isSlipModeActive;
      return deck.copyWith(
        isSlipModeActive: enabling,
        slipPositionMs: deck.currentPositionMs,
      );
    });
  }

  /// Advances deterministic playback for a playing deck, honoring Auto-Loops and Slip Mode.
  void advanceDeckPlayback(String deckId, int elapsedMs) {
    _updateDeck(deckId, (deck) {
      if (!deck.isPlaying) return deck;
      final scaledDelta = (elapsedMs * deck.pitchMultiplier).round();
      var nextPos = (deck.currentPositionMs + scaledDelta).clamp(0, deck.durationMs);
      final nextSlip = (deck.slipPositionMs + scaledDelta).clamp(0, deck.durationMs);

      if (deck.isLoopActive) {
        nextPos = DjLoopAndSlipEngine.wrapLoopPosition(
          nextPositionMs: nextPos,
          loopStartMs: deck.loopStartMs,
          loopEndMs: deck.loopEndMs,
        );
      }

      return deck.copyWith(
        currentPositionMs: nextPos,
        slipPositionMs: deck.isSlipModeActive ? nextSlip : nextPos,
      );
    });
  }

  /// Triggers a performance SFX pad on the 8-pad Sampler bank.
  void triggerSamplerPad(DjSamplerPadType pad) {
    _sampler = _sampler.triggerPad(pad);
  }

  /// Updates Sampler bank output volume in range [0.0, 1.0].
  void setSamplerVolume(double volume) {
    _sampler = _sampler.copyWith(masterVolume: volume.clamp(0.0, 1.0));
  }

  /// Starts Smart Automix with automatic Bass-Swap transition.
  void startSmartAutomix(
    AutomixDirection direction, {
    int durationBars = 8,
    bool enableBassSwap = true,
  }) {
    _automix = _automix.start(
      direction: direction,
      durationBars: durationBars,
      enableBassSwap: enableBassSwap,
    );
    // Ensure both decks are playing during transition
    if (!_deckA.isPlaying) togglePlay('A');
    if (!_deckB.isPlaying) togglePlay('B');
  }

  /// Cancels active Smart Automix.
  void cancelSmartAutomix() {
    _automix = _automix.cancel();
  }

  /// Advances Smart Automix timeline, updating crossfader and Bass-Swap low EQ.
  void advanceAutomix(int elapsedMs) {
    if (!_automix.isActive) return;
    final refBpm = _automix.direction == AutomixDirection.deckAToDeckB
        ? _deckA.effectiveBpm
        : _deckB.effectiveBpm;
    _automix = _automix.advance(elapsedMs: elapsedMs, referenceBpm: refBpm);

    setCrossfaderPosition(_automix.crossfaderPosition, fromAutomix: true);
    if (_automix.enableBassSwap) {
      _deckA = _deckA.copyWith(gainLow: _automix.bassSwapGainLowA);
      _deckB = _deckB.copyWith(gainLow: _automix.bassSwapGainLowB);
    }
  }

  /// Toggles PFL Headphone Cue monitoring on Deck A or B.
  void toggleCueMonitor(String deckId) {
    _cueMonitor = deckId == 'A' ? _cueMonitor.toggleCueA() : _cueMonitor.toggleCueB();
  }

  /// Toggles PC Split-Cue Mono mode (Master L / Cue R).
  void toggleSplitCue() {
    _cueMonitor = _cueMonitor.toggleSplitCue();
  }

  /// Sets headphone monitor blend between Cue (0.0) and Master (1.0).
  void setCueMasterMix(double mix) {
    _cueMonitor = _cueMonitor.copyWith(cueMasterMix: mix);
  }
}
