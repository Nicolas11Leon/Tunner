/// Enumerate all discrete actions executable on the Virtual DJ Console.
///
/// Designed to be decoupled from concrete input devices (QWERTY, MIDI, Touch).
enum DjAction {
  // Deck A Transport & Pitch
  deckAPlayPause,
  deckACue,
  deckASync,
  deckAPitchUp,
  deckAPitchDown,
  deckAPitchReset,
  deckANudgeForward,
  deckANudgeBackward,

  // Deck A Hot Cues
  deckAHotCue1,
  deckAHotCue2,
  deckAHotCue3,
  deckAHotCue4,

  // Deck A EQ Kills
  deckAKillLow,
  deckAKillMid,
  deckAKillHigh,

  // Deck A Performance FX
  deckAFilterSweepLeft,
  deckAFilterSweepRight,
  deckAFilterReset,
  deckAToggleDelay,

  // Deck B Transport & Pitch
  deckBPlayPause,
  deckBCue,
  deckBSync,
  deckBPitchUp,
  deckBPitchDown,
  deckBPitchReset,
  deckBNudgeForward,
  deckBNudgeBackward,

  // Deck B Hot Cues
  deckBHotCue1,
  deckBHotCue2,
  deckBHotCue3,
  deckBHotCue4,

  // Deck B EQ Kills
  deckBKillLow,
  deckBKillMid,
  deckBKillHigh,

  // Deck B Performance FX
  deckBFilterSweepLeft,
  deckBFilterSweepRight,
  deckBFilterReset,
  deckBToggleDelay,

  // Crossfader
  crossfaderShiftLeft,
  crossfaderShiftRight,
  crossfaderCenter,
  crossfaderHardLeft,
  crossfaderHardRight,

  // Master & Recording
  masterVolumeUp,
  masterVolumeDown,
  toggleMixRecording,

  // Pro Workstation: 4-Stems Deck A & B
  deckAToggleVocalStem,
  deckAToggleDrumsStem,
  deckAToggleBassStem,
  deckAToggleMelodyStem,
  deckBToggleVocalStem,
  deckBToggleDrumsStem,
  deckBToggleBassStem,
  deckBToggleMelodyStem,

  // Pro Workstation: Auto-Loops, Slip & Beat Jump
  deckALoopToggle,
  deckALoopHalve,
  deckALoopDouble,
  deckAToggleSlip,
  deckABeatJumpForward,
  deckABeatJumpBack,
  deckBLoopToggle,
  deckBLoopHalve,
  deckBLoopDouble,
  deckBToggleSlip,
  deckBBeatJumpForward,
  deckBBeatJumpBack,

  // Pro Workstation: Harmonic Key-Sync
  deckAKeySync,
  deckBKeySync,

  // Pro Workstation: Sampler Pads & Master Automix / Split-Cue
  triggerSamplerRiser,
  triggerSamplerDrop,
  triggerSamplerAirhorn,
  triggerSamplerSiren,
  toggleSmartAutomix,
  toggleSplitCue,
}

extension DjActionExtension on DjAction {
  String get displayName {
    switch (this) {
      case DjAction.deckAPlayPause:
        return 'Deck A: Play / Pausa';
      case DjAction.deckACue:
        return 'Deck A: Cue';
      case DjAction.deckASync:
        return 'Deck A: Sync BPM';
      case DjAction.deckAPitchUp:
        return 'Deck A: Acelerar Pitch (+0.5%)';
      case DjAction.deckAPitchDown:
        return 'Deck A: Desacelerar Pitch (-0.5%)';
      case DjAction.deckAPitchReset:
        return 'Deck A: Reset Pitch (0%)';
      case DjAction.deckANudgeForward:
        return 'Deck A: Nudge Adelante';
      case DjAction.deckANudgeBackward:
        return 'Deck A: Nudge Atras';
      case DjAction.deckAHotCue1:
        return 'Deck A: Hot Cue 1';
      case DjAction.deckAHotCue2:
        return 'Deck A: Hot Cue 2';
      case DjAction.deckAHotCue3:
        return 'Deck A: Hot Cue 3';
      case DjAction.deckAHotCue4:
        return 'Deck A: Hot Cue 4';
      case DjAction.deckAKillLow:
        return 'Deck A: Kill Low EQ';
      case DjAction.deckAKillMid:
        return 'Deck A: Kill Mid EQ';
      case DjAction.deckAKillHigh:
        return 'Deck A: Kill High EQ';
      case DjAction.deckAFilterSweepLeft:
        return 'Deck A: Filtro Low-Pass (-0.1)';
      case DjAction.deckAFilterSweepRight:
        return 'Deck A: Filtro High-Pass (+0.1)';
      case DjAction.deckAFilterReset:
        return 'Deck A: Reset Filtro (Bypass)';
      case DjAction.deckAToggleDelay:
        return 'Deck A: Activar / Desactivar Delay';

      case DjAction.deckBPlayPause:
        return 'Deck B: Play / Pausa';
      case DjAction.deckBCue:
        return 'Deck B: Cue';
      case DjAction.deckBSync:
        return 'Deck B: Sync BPM';
      case DjAction.deckBPitchUp:
        return 'Deck B: Acelerar Pitch (+0.5%)';
      case DjAction.deckBPitchDown:
        return 'Deck B: Desacelerar Pitch (-0.5%)';
      case DjAction.deckBPitchReset:
        return 'Deck B: Reset Pitch (0%)';
      case DjAction.deckBNudgeForward:
        return 'Deck B: Nudge Adelante';
      case DjAction.deckBNudgeBackward:
        return 'Deck B: Nudge Atras';
      case DjAction.deckBHotCue1:
        return 'Deck B: Hot Cue 1';
      case DjAction.deckBHotCue2:
        return 'Deck B: Hot Cue 2';
      case DjAction.deckBHotCue3:
        return 'Deck B: Hot Cue 3';
      case DjAction.deckBHotCue4:
        return 'Deck B: Hot Cue 4';
      case DjAction.deckBKillLow:
        return 'Deck B: Kill Low EQ';
      case DjAction.deckBKillMid:
        return 'Deck B: Kill Mid EQ';
      case DjAction.deckBKillHigh:
        return 'Deck B: Kill High EQ';
      case DjAction.deckBFilterSweepLeft:
        return 'Deck B: Filtro Low-Pass (-0.1)';
      case DjAction.deckBFilterSweepRight:
        return 'Deck B: Filtro High-Pass (+0.1)';
      case DjAction.deckBFilterReset:
        return 'Deck B: Reset Filtro (Bypass)';
      case DjAction.deckBToggleDelay:
        return 'Deck B: Activar / Desactivar Delay';

      case DjAction.crossfaderShiftLeft:
        return 'Crossfader: Desplazar a Izquierda';
      case DjAction.crossfaderShiftRight:
        return 'Crossfader: Desplazar a Derecha';
      case DjAction.crossfaderCenter:
        return 'Crossfader: Centrar';
      case DjAction.crossfaderHardLeft:
        return 'Crossfader: Corte a Deck A (100%)';
      case DjAction.crossfaderHardRight:
        return 'Crossfader: Corte a Deck B (100%)';

      case DjAction.masterVolumeUp:
        return 'Master: Subir Volumen';
      case DjAction.masterVolumeDown:
        return 'Master: Bajar Volumen';
      case DjAction.toggleMixRecording:
        return 'Master: Iniciar / Detener Grabacion REC';
      case DjAction.deckAToggleVocalStem:
        return 'Deck A: Stem Vocal';
      case DjAction.deckAToggleDrumsStem:
        return 'Deck A: Stem Drums';
      case DjAction.deckAToggleBassStem:
        return 'Deck A: Stem Bass';
      case DjAction.deckAToggleMelodyStem:
        return 'Deck A: Stem Melody';
      case DjAction.deckBToggleVocalStem:
        return 'Deck B: Stem Vocal';
      case DjAction.deckBToggleDrumsStem:
        return 'Deck B: Stem Drums';
      case DjAction.deckBToggleBassStem:
        return 'Deck B: Stem Bass';
      case DjAction.deckBToggleMelodyStem:
        return 'Deck B: Stem Melody';
      case DjAction.deckALoopToggle:
        return 'Deck A: Auto-Loop Toggle';
      case DjAction.deckALoopHalve:
        return 'Deck A: Loop 1/2x';
      case DjAction.deckALoopDouble:
        return 'Deck A: Loop 2x';
      case DjAction.deckAToggleSlip:
        return 'Deck A: Slip Mode';
      case DjAction.deckABeatJumpForward:
        return 'Deck A: Beat Jump +4';
      case DjAction.deckABeatJumpBack:
        return 'Deck A: Beat Jump -4';
      case DjAction.deckBLoopToggle:
        return 'Deck B: Auto-Loop Toggle';
      case DjAction.deckBLoopHalve:
        return 'Deck B: Loop 1/2x';
      case DjAction.deckBLoopDouble:
        return 'Deck B: Loop 2x';
      case DjAction.deckBToggleSlip:
        return 'Deck B: Slip Mode';
      case DjAction.deckBBeatJumpForward:
        return 'Deck B: Beat Jump +4';
      case DjAction.deckBBeatJumpBack:
        return 'Deck B: Beat Jump -4';
      case DjAction.deckAKeySync:
        return 'Deck A: Harmonic Key-Sync';
      case DjAction.deckBKeySync:
        return 'Deck B: Harmonic Key-Sync';
      case DjAction.triggerSamplerRiser:
        return 'Sampler: White Noise Riser';
      case DjAction.triggerSamplerDrop:
        return 'Sampler: Sub-Bass Drop';
      case DjAction.triggerSamplerAirhorn:
        return 'Sampler: Club Airhorn';
      case DjAction.triggerSamplerSiren:
        return 'Sampler: Laser Dub Siren';
      case DjAction.toggleSmartAutomix:
        return 'Master: Smart Automix (Bass-Swap)';
      case DjAction.toggleSplitCue:
        return 'Master: Split-Cue Mono (PC Audifonos)';
    }
  }

  String get category {
    if (name.startsWith('deckA')) return 'Deck A';
    if (name.startsWith('deckB')) return 'Deck B';
    if (name.startsWith('crossfader')) return 'Crossfader';
    return 'Master';
  }
}
