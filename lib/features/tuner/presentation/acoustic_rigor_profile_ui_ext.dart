import 'package:flutter/material.dart';
import '../domain/acoustic_rigor_profile.dart';

/// Extensión de presentación para mapear [AcousticRigorPreset] a su icono Material.
extension AcousticRigorPresetUiExt on AcousticRigorPreset {
  IconData get icon {
    switch (this) {
      case AcousticRigorPreset.beginner:
        return Icons.sentiment_satisfied_alt;
      case AcousticRigorPreset.balancedRehearsal:
        return Icons.music_note;
      case AcousticRigorPreset.studioRecording:
        return Icons.mic;
      case AcousticRigorPreset.noisyStage:
        return Icons.speaker_group;
      case AcousticRigorPreset.conservatoryMastery:
        return Icons.verified;
      case AcousticRigorPreset.custom:
        return Icons.tune;
    }
  }
}
