/// Representación canónica de un Bus de Canal Troncal de Estudio (Canal A, B, C, D).
class StudioChannelBus {
  final String id;
  final String name;
  final String shortCode;
  final int colorHex;
  final double gain; // 0.0 a 2.0 (1.0 = 0dB unitario)
  final bool isMuted;
  final bool isSolo;
  final double currentPeakRms;

  const StudioChannelBus({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.colorHex,
    this.gain = 1.0,
    this.isMuted = false,
    this.isSolo = false,
    this.currentPeakRms = 0.0,
  });

  /// Los 4 Canales Troncales Clásicos de Estudio (Canal A, Canal B, Canal C, Canal D).
  static List<StudioChannelBus> defaultTrunkChannels() {
    return const [
      StudioChannelBus(
        id: 'canal_a',
        name: 'Canal A (Melodía & Score)',
        shortCode: 'CH A',
        colorHex: 0xFF00E5FF, // Cian neón
      ),
      StudioChannelBus(
        id: 'canal_b',
        name: 'Canal B (Percusión & Rhythm)',
        shortCode: 'CH B',
        colorHex: 0xFFFFAB00, // Ámbar cálido
      ),
      StudioChannelBus(
        id: 'canal_c',
        name: 'Canal C (Voz & Micrófono)',
        shortCode: 'CH C',
        colorHex: 0xFF10B981, // Esmeralda club
      ),
      StudioChannelBus(
        id: 'canal_d',
        name: 'Canal D (Master FX & Synth)',
        shortCode: 'CH D',
        colorHex: 0xFF8B5CF6, // Púrpura synthwave
      ),
    ];
  }

  StudioChannelBus copyWith({
    String? id,
    String? name,
    String? shortCode,
    int? colorHex,
    double? gain,
    bool? isMuted,
    bool? isSolo,
    double? currentPeakRms,
  }) {
    return StudioChannelBus(
      id: id ?? this.id,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      colorHex: colorHex ?? this.colorHex,
      gain: gain ?? this.gain,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
      currentPeakRms: currentPeakRms ?? this.currentPeakRms,
    );
  }
}
