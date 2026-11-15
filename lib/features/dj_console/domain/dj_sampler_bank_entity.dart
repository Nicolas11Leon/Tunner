/// Procedural club transition & performance SFX pad identifiers.
enum DjSamplerPadType {
  whiteNoiseRiser,
  subBassDrop,
  clubAirhorn,
  laserDubSiren,
  vinylBrake,
  backspin,
  stadiumImpact,
  vocalStutter,
}

extension DjSamplerPadTypeExtension on DjSamplerPadType {
  String get label {
    switch (this) {
      case DjSamplerPadType.whiteNoiseRiser:
        return 'RISER';
      case DjSamplerPadType.subBassDrop:
        return 'SUB DROP';
      case DjSamplerPadType.clubAirhorn:
        return 'AIRHORN';
      case DjSamplerPadType.laserDubSiren:
        return 'SIREN';
      case DjSamplerPadType.vinylBrake:
        return 'VINYL BRK';
      case DjSamplerPadType.backspin:
        return 'BACKSPIN';
      case DjSamplerPadType.stadiumImpact:
        return 'IMPACT';
      case DjSamplerPadType.vocalStutter:
        return 'STUTTER';
    }
  }

  int get colorHex {
    switch (this) {
      case DjSamplerPadType.whiteNoiseRiser:
        return 0xFF00E5FF;
      case DjSamplerPadType.subBassDrop:
        return 0xFFFF1744;
      case DjSamplerPadType.clubAirhorn:
        return 0xFFFF9100;
      case DjSamplerPadType.laserDubSiren:
        return 0xFF00E676;
      case DjSamplerPadType.vinylBrake:
        return 0xFFD500F9;
      case DjSamplerPadType.backspin:
        return 0xFF2979FF;
      case DjSamplerPadType.stadiumImpact:
        return 0xFFFFD700;
      case DjSamplerPadType.vocalStutter:
        return 0xFFFF4081;
    }
  }
}

/// Immutable state for the 8-Pad independent DJ Sampler bank.
class DjSamplerBankEntity {
  final double masterVolume;
  final DjSamplerPadType? lastTriggeredPad;
  final int triggerSequence;

  const DjSamplerBankEntity({
    this.masterVolume = 0.85,
    this.lastTriggeredPad,
    this.triggerSequence = 0,
  });

  DjSamplerBankEntity triggerPad(DjSamplerPadType pad) {
    return DjSamplerBankEntity(
      masterVolume: masterVolume,
      lastTriggeredPad: pad,
      triggerSequence: triggerSequence + 1,
    );
  }

  DjSamplerBankEntity copyWith({
    double? masterVolume,
    DjSamplerPadType? lastTriggeredPad,
    int? triggerSequence,
  }) {
    return DjSamplerBankEntity(
      masterVolume: masterVolume ?? this.masterVolume,
      lastTriggeredPad: lastTriggeredPad ?? this.lastTriggeredPad,
      triggerSequence: triggerSequence ?? this.triggerSequence,
    );
  }
}
