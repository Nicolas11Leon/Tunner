import '../domain/dj_action.dart';
import '../domain/dj_hardware_skin_entity.dart';
import '../domain/dj_skin_zone_entity.dart';

/// Pre-configured procedural catalog of world-famous DJ hardware controllers.
///
/// All skins use normalized [0.0, 1.0] coordinates for responsive vector rendering.
class DjHardwareCatalog {
  DjHardwareCatalog._();

  /// Pioneer DDJ-FLX4 (The world standard 2-channel entry & club beginner controller).
  static DjHardwareSkinEntity ddjFlx4() {
    final zones = <DjSkinZoneEntity>[
      // === DECK A (Left Deck: X in [0.02, 0.38]) ===
      // Big Jog Wheel A
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_jog',
        label: 'JOG A',
        deckId: 'deckA',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckANudgeForward,
        normalizedX: 0.05,
        normalizedY: 0.15,
        normalizedWidth: 0.28,
        normalizedHeight: 0.45,
        ledColor: 0xFF2979FF,
      ),

      // Deck A Play / Pause (Bottom Left round button)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_play',
        label: 'PLAY',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckAPlayPause,
        normalizedX: 0.04,
        normalizedY: 0.82,
        normalizedWidth: 0.065,
        normalizedHeight: 0.12,
        ledColor: 0xFF00E676,
      ),

      // Deck A Cue (Above Play)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_cue',
        label: 'CUE',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckACue,
        normalizedX: 0.04,
        normalizedY: 0.67,
        normalizedWidth: 0.065,
        normalizedHeight: 0.12,
        ledColor: 0xFFFFAB00,
      ),

      // Deck A Sync
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_sync',
        label: 'SYNC',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckASync,
        normalizedX: 0.04,
        normalizedY: 0.05,
        normalizedWidth: 0.06,
        normalizedHeight: 0.07,
        ledColor: 0xFF00E5FF,
      ),

      // Deck A Pitch Fader (Vertical on right edge of Deck A)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_pitch_fader',
        label: 'TEMPO',
        deckId: 'deckA',
        controlType: DjControlType.fader,
        action: DjAction.deckAPitchUp,
        normalizedX: 0.33,
        normalizedY: 0.18,
        normalizedWidth: 0.035,
        normalizedHeight: 0.42,
        ledColor: 0xFF7C4DFF,
      ),

      // Deck A Performance Pads (4 pads represented in a 2x2 grid)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_pad_1',
        label: 'PAD 1',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue1,
        normalizedX: 0.12,
        normalizedY: 0.68,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFFFF1744,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_pad_2',
        label: 'PAD 2',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue2,
        normalizedX: 0.20,
        normalizedY: 0.68,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFFFF9100,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_pad_3',
        label: 'PAD 3',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue3,
        normalizedX: 0.12,
        normalizedY: 0.82,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFF00E5FF,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_a_pad_4',
        label: 'PAD 4',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue4,
        normalizedX: 0.20,
        normalizedY: 0.82,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFFD500F9,
      ),

      // === MIXER SECTION (Center: X in [0.38, 0.62]) ===
      // Deck A EQ Knobs (Hi, Mid, Low)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_eq_a_hi',
        label: 'HI A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAKillHigh,
        normalizedX: 0.40,
        normalizedY: 0.08,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_eq_a_mid',
        label: 'MID A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAKillMid,
        normalizedX: 0.40,
        normalizedY: 0.19,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_eq_a_low',
        label: 'LOW A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAKillLow,
        normalizedX: 0.40,
        normalizedY: 0.30,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),

      // Deck A Bipolar Filter Knob
      const DjSkinZoneEntity(
        id: 'ddj_flx4_filter_a',
        label: 'FILTER A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAFilterSweepRight,
        normalizedX: 0.40,
        normalizedY: 0.42,
        normalizedWidth: 0.05,
        normalizedHeight: 0.09,
        ledColor: 0xFFFF5252,
      ),

      // Deck B EQ Knobs (Hi, Mid, Low)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_eq_b_hi',
        label: 'HI B',
        deckId: 'deckB',
        controlType: DjControlType.knob,
        action: DjAction.deckBKillHigh,
        normalizedX: 0.55,
        normalizedY: 0.08,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_eq_b_mid',
        label: 'MID B',
        deckId: 'deckB',
        controlType: DjControlType.knob,
        action: DjAction.deckBKillMid,
        normalizedX: 0.55,
        normalizedY: 0.19,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_eq_b_low',
        label: 'LOW B',
        deckId: 'deckB',
        controlType: DjControlType.knob,
        action: DjAction.deckBKillLow,
        normalizedX: 0.55,
        normalizedY: 0.30,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),

      // Deck B Bipolar Filter Knob
      const DjSkinZoneEntity(
        id: 'ddj_flx4_filter_b',
        label: 'FILTER B',
        deckId: 'deckB',
        controlType: DjControlType.knob,
        action: DjAction.deckBFilterSweepRight,
        normalizedX: 0.55,
        normalizedY: 0.42,
        normalizedWidth: 0.05,
        normalizedHeight: 0.09,
        ledColor: 0xFFFF5252,
      ),

      // Channel Fader A
      const DjSkinZoneEntity(
        id: 'ddj_flx4_ch_fader_a',
        label: 'CH 1',
        deckId: 'deckA',
        controlType: DjControlType.fader,
        action: DjAction.deckAToggleDelay,
        normalizedX: 0.41,
        normalizedY: 0.55,
        normalizedWidth: 0.035,
        normalizedHeight: 0.22,
        ledColor: 0xFFEEEEEE,
      ),

      // Channel Fader B
      const DjSkinZoneEntity(
        id: 'ddj_flx4_ch_fader_b',
        label: 'CH 2',
        deckId: 'deckB',
        controlType: DjControlType.fader,
        action: DjAction.deckBToggleDelay,
        normalizedX: 0.555,
        normalizedY: 0.55,
        normalizedWidth: 0.035,
        normalizedHeight: 0.22,
        ledColor: 0xFFEEEEEE,
      ),

      // Crossfader Horizontal
      const DjSkinZoneEntity(
        id: 'ddj_flx4_crossfader',
        label: 'X-FADER',
        controlType: DjControlType.fader,
        action: DjAction.crossfaderCenter,
        normalizedX: 0.40,
        normalizedY: 0.85,
        normalizedWidth: 0.20,
        normalizedHeight: 0.09,
        ledColor: 0xFFFFD700,
      ),

      // Master Record REC Button (Top Center)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_rec_btn',
        label: 'REC',
        controlType: DjControlType.button,
        action: DjAction.toggleMixRecording,
        normalizedX: 0.47,
        normalizedY: 0.03,
        normalizedWidth: 0.06,
        normalizedHeight: 0.05,
        ledColor: 0xFFFF1744,
      ),

      // === DECK B (Right Deck: X in [0.62, 0.98]) ===
      // Big Jog Wheel B
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_jog',
        label: 'JOG B',
        deckId: 'deckB',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckBNudgeForward,
        normalizedX: 0.67,
        normalizedY: 0.15,
        normalizedWidth: 0.28,
        normalizedHeight: 0.45,
        ledColor: 0xFF2979FF,
      ),

      // Deck B Play / Pause
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_play',
        label: 'PLAY',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBPlayPause,
        normalizedX: 0.66,
        normalizedY: 0.82,
        normalizedWidth: 0.065,
        normalizedHeight: 0.12,
        ledColor: 0xFF00E676,
      ),

      // Deck B Cue
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_cue',
        label: 'CUE',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBCue,
        normalizedX: 0.66,
        normalizedY: 0.67,
        normalizedWidth: 0.065,
        normalizedHeight: 0.12,
        ledColor: 0xFFFFAB00,
      ),

      // Deck B Sync
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_sync',
        label: 'SYNC',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBSync,
        normalizedX: 0.66,
        normalizedY: 0.05,
        normalizedWidth: 0.06,
        normalizedHeight: 0.07,
        ledColor: 0xFF00E5FF,
      ),

      // Deck B Pitch Fader (Vertical on right edge of Deck B)
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_pitch_fader',
        label: 'TEMPO',
        deckId: 'deckB',
        controlType: DjControlType.fader,
        action: DjAction.deckBPitchUp,
        normalizedX: 0.94,
        normalizedY: 0.18,
        normalizedWidth: 0.035,
        normalizedHeight: 0.42,
        ledColor: 0xFF7C4DFF,
      ),

      // Deck B Performance Pads
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_pad_1',
        label: 'PAD 1',
        deckId: 'deckB',
        controlType: DjControlType.pad,
        action: DjAction.deckBHotCue1,
        normalizedX: 0.74,
        normalizedY: 0.68,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFFFF1744,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_pad_2',
        label: 'PAD 2',
        deckId: 'deckB',
        controlType: DjControlType.pad,
        action: DjAction.deckBHotCue2,
        normalizedX: 0.82,
        normalizedY: 0.68,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFFFF9100,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_pad_3',
        label: 'PAD 3',
        deckId: 'deckB',
        controlType: DjControlType.pad,
        action: DjAction.deckBHotCue3,
        normalizedX: 0.74,
        normalizedY: 0.82,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFF00E5FF,
      ),
      const DjSkinZoneEntity(
        id: 'ddj_flx4_deck_b_pad_4',
        label: 'PAD 4',
        deckId: 'deckB',
        controlType: DjControlType.pad,
        action: DjAction.deckBHotCue4,
        normalizedX: 0.82,
        normalizedY: 0.82,
        normalizedWidth: 0.065,
        normalizedHeight: 0.11,
        ledColor: 0xFFD500F9,
      ),
    ];

    return DjHardwareSkinEntity(
      id: 'pioneer_ddj_flx4',
      name: 'Pioneer DDJ-FLX4 (Console 2-Channel)',
      manufacturer: 'Pioneer DJ',
      aspectRatio: 2.1,
      chassisColor: 0xFF141416,
      accentColor: 0xFF2979FF,
      zones: zones,
    );
  }

  /// Pioneer CDJ-3000 Club Standard Media Player Setup.
  static DjHardwareSkinEntity cdj3000() {
    final zones = <DjSkinZoneEntity>[
      // Screen waveform banner (top)
      const DjSkinZoneEntity(
        id: 'cdj_3000_screen',
        label: 'TOUCH DISPLAY (WAVE)',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckASync,
        normalizedX: 0.10,
        normalizedY: 0.05,
        normalizedWidth: 0.80,
        normalizedHeight: 0.22,
        ledColor: 0xFF00E5FF,
      ),

      // Hot Cues A-D row directly below screen
      const DjSkinZoneEntity(
        id: 'cdj_3000_hot_a',
        label: 'A',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue1,
        normalizedX: 0.12,
        normalizedY: 0.30,
        normalizedWidth: 0.16,
        normalizedHeight: 0.06,
        ledColor: 0xFFFF1744,
      ),
      const DjSkinZoneEntity(
        id: 'cdj_3000_hot_b',
        label: 'B',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue2,
        normalizedX: 0.31,
        normalizedY: 0.30,
        normalizedWidth: 0.16,
        normalizedHeight: 0.06,
        ledColor: 0xFFFF9100,
      ),
      const DjSkinZoneEntity(
        id: 'cdj_3000_hot_c',
        label: 'C',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue3,
        normalizedX: 0.50,
        normalizedY: 0.30,
        normalizedWidth: 0.16,
        normalizedHeight: 0.06,
        ledColor: 0xFF00E676,
      ),
      const DjSkinZoneEntity(
        id: 'cdj_3000_hot_d',
        label: 'D',
        deckId: 'deckA',
        controlType: DjControlType.pad,
        action: DjAction.deckAHotCue4,
        normalizedX: 0.69,
        normalizedY: 0.30,
        normalizedWidth: 0.16,
        normalizedHeight: 0.06,
        ledColor: 0xFF2979FF,
      ),

      // Giant 206mm Jog Wheel
      const DjSkinZoneEntity(
        id: 'cdj_3000_giant_jog',
        label: 'CDJ JOG 206mm',
        deckId: 'deckA',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckANudgeForward,
        normalizedX: 0.12,
        normalizedY: 0.40,
        normalizedWidth: 0.55,
        normalizedHeight: 0.42,
        ledColor: 0xFFFFFFFF,
      ),

      // Giant Cue
      const DjSkinZoneEntity(
        id: 'cdj_3000_cue',
        label: 'CUE',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckACue,
        normalizedX: 0.10,
        normalizedY: 0.85,
        normalizedWidth: 0.12,
        normalizedHeight: 0.12,
        ledColor: 0xFFFFAB00,
      ),

      // Giant Play / Pause
      const DjSkinZoneEntity(
        id: 'cdj_3000_play',
        label: 'PLAY / PAUSE',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckAPlayPause,
        normalizedX: 0.25,
        normalizedY: 0.85,
        normalizedWidth: 0.12,
        normalizedHeight: 0.12,
        ledColor: 0xFF00E676,
      ),

      // Master Tempo / Pitch Slider
      const DjSkinZoneEntity(
        id: 'cdj_3000_pitch_slider',
        label: 'TEMPO SLIDER',
        deckId: 'deckA',
        controlType: DjControlType.fader,
        action: DjAction.deckAPitchUp,
        normalizedX: 0.82,
        normalizedY: 0.42,
        normalizedWidth: 0.08,
        normalizedHeight: 0.45,
        ledColor: 0xFF7C4DFF,
      ),

      // Sync button
      const DjSkinZoneEntity(
        id: 'cdj_3000_sync',
        label: 'BEAT SYNC',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckASync,
        normalizedX: 0.72,
        normalizedY: 0.42,
        normalizedWidth: 0.08,
        normalizedHeight: 0.08,
        ledColor: 0xFF00E5FF,
      ),
    ];

    return DjHardwareSkinEntity(
      id: 'pioneer_cdj_3000',
      name: 'Pioneer CDJ-3000 (Club Standard Player)',
      manufacturer: 'Pioneer DJ',
      aspectRatio: 1.1,
      chassisColor: 0xFF18181A,
      accentColor: 0xFFFF6D00,
      zones: zones,
    );
  }

  /// Traktor Kontrol S4 MK3 (4-Channel Haptic Drive flagship).
  static DjHardwareSkinEntity traktorKontrolS4() {
    final zones = <DjSkinZoneEntity>[
      // Deck A Haptic Jog
      const DjSkinZoneEntity(
        id: 'traktor_s4_jog_a',
        label: 'HAPTIC JOG A',
        deckId: 'deckA',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckANudgeForward,
        normalizedX: 0.06,
        normalizedY: 0.18,
        normalizedWidth: 0.25,
        normalizedHeight: 0.40,
        ledColor: 0xFF00E5FF,
      ),
      // Play A
      const DjSkinZoneEntity(
        id: 'traktor_s4_play_a',
        label: 'PLAY A',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckAPlayPause,
        normalizedX: 0.06,
        normalizedY: 0.82,
        normalizedWidth: 0.07,
        normalizedHeight: 0.12,
        ledColor: 0xFF00E676,
      ),
      // Cue A
      const DjSkinZoneEntity(
        id: 'traktor_s4_cue_a',
        label: 'CUE A',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckACue,
        normalizedX: 0.06,
        normalizedY: 0.68,
        normalizedWidth: 0.07,
        normalizedHeight: 0.12,
        ledColor: 0xFFFFAB00,
      ),
      // Sync A
      const DjSkinZoneEntity(
        id: 'traktor_s4_sync_a',
        label: 'SYNC A',
        deckId: 'deckA',
        controlType: DjControlType.button,
        action: DjAction.deckASync,
        normalizedX: 0.06,
        normalizedY: 0.06,
        normalizedWidth: 0.06,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),

      // Mixer FX Knob Deck A
      const DjSkinZoneEntity(
        id: 'traktor_s4_mixer_fx_a',
        label: 'MIXER FX A',
        deckId: 'deckA',
        controlType: DjControlType.knob,
        action: DjAction.deckAFilterSweepRight,
        normalizedX: 0.42,
        normalizedY: 0.45,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFFFF4081,
      ),

      // Mixer FX Knob Deck B
      const DjSkinZoneEntity(
        id: 'traktor_s4_mixer_fx_b',
        label: 'MIXER FX B',
        deckId: 'deckB',
        controlType: DjControlType.knob,
        action: DjAction.deckBFilterSweepRight,
        normalizedX: 0.535,
        normalizedY: 0.45,
        normalizedWidth: 0.045,
        normalizedHeight: 0.08,
        ledColor: 0xFFFF4081,
      ),

      // Traktor Crossfader
      const DjSkinZoneEntity(
        id: 'traktor_s4_crossfader',
        label: 'CROSSFADER',
        controlType: DjControlType.fader,
        action: DjAction.crossfaderCenter,
        normalizedX: 0.40,
        normalizedY: 0.85,
        normalizedWidth: 0.20,
        normalizedHeight: 0.09,
        ledColor: 0xFFFFD700,
      ),

      // Deck B Haptic Jog
      const DjSkinZoneEntity(
        id: 'traktor_s4_jog_b',
        label: 'HAPTIC JOG B',
        deckId: 'deckB',
        controlType: DjControlType.jogWheel,
        action: DjAction.deckBNudgeForward,
        normalizedX: 0.69,
        normalizedY: 0.18,
        normalizedWidth: 0.25,
        normalizedHeight: 0.40,
        ledColor: 0xFF00E5FF,
      ),
      // Play B
      const DjSkinZoneEntity(
        id: 'traktor_s4_play_b',
        label: 'PLAY B',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBPlayPause,
        normalizedX: 0.68,
        normalizedY: 0.82,
        normalizedWidth: 0.07,
        normalizedHeight: 0.12,
        ledColor: 0xFF00E676,
      ),
      // Cue B
      const DjSkinZoneEntity(
        id: 'traktor_s4_cue_b',
        label: 'CUE B',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBCue,
        normalizedX: 0.68,
        normalizedY: 0.68,
        normalizedWidth: 0.07,
        normalizedHeight: 0.12,
        ledColor: 0xFFFFAB00,
      ),
      // Sync B
      const DjSkinZoneEntity(
        id: 'traktor_s4_sync_b',
        label: 'SYNC B',
        deckId: 'deckB',
        controlType: DjControlType.button,
        action: DjAction.deckBSync,
        normalizedX: 0.68,
        normalizedY: 0.06,
        normalizedWidth: 0.06,
        normalizedHeight: 0.08,
        ledColor: 0xFF2979FF,
      ),
    ];

    return DjHardwareSkinEntity(
      id: 'traktor_kontrol_s4',
      name: 'Traktor Kontrol S4 MK3 (4-Channel Haptic)',
      manufacturer: 'Native Instruments',
      aspectRatio: 2.0,
      chassisColor: 0xFF101012,
      accentColor: 0xFFFF4081,
      zones: zones,
    );
  }

  /// Returns all built-in hardware skins available.
  static List<DjHardwareSkinEntity> allSkins() => [
        ddjFlx4(),
        cdj3000(),
        traktorKontrolS4(),
      ];

  /// Finds skin by identifier with fallback to DDJ-FLX4.
  static DjHardwareSkinEntity findById(String id) {
    return allSkins().firstWhere(
      (s) => s.id == id,
      orElse: () => ddjFlx4(),
    );
  }
}
