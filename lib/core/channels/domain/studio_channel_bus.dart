import 'dart:typed_data';

/// Representación canónica de un Bus de Canal Nombrable y Personalizado de Estudio.
/// Soporta metadatos del canal, estado de ruteo y bus reactivo full-duplex de parámetros
/// de reproducción (BPM, tonalidad Camelot, título, transporte y flujo PCM de audio).
class StudioChannelBus {
  final String id;
  final String name;
  final String shortCode;
  final int colorHex;
  final double gain; // 0.0 a 2.0 (1.0 = 0dB unitario)
  final bool isMuted;
  final bool isSolo;
  final double currentPeakRms;

  // Parámetros de reproducción reactivos en vivo (Full-Duplex Parameter Bus)
  final String activeTrackTitle;
  final double activeBpm;
  final String activeCamelotKey;
  final bool isPlaying;
  final int positionMs;
  final Float32List? livePcmBuffer;

  const StudioChannelBus({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.colorHex,
    this.gain = 1.0,
    this.isMuted = false,
    this.isSolo = false,
    this.currentPeakRms = 0.0,
    this.activeTrackTitle = '',
    this.activeBpm = 120.0,
    this.activeCamelotKey = '8B',
    this.isPlaying = false,
    this.positionMs = 0,
    this.livePcmBuffer,
  });

  /// Los 4 Canales Troncales Clásicos de Estudio (Canal A, Canal B, Canal C, Canal D).
  static List<StudioChannelBus> defaultTrunkChannels() {
    return const [
      StudioChannelBus(
        id: 'canal_a',
        name: 'Canal A (Melodía & Score)',
        shortCode: 'CH A',
        colorHex: 0xFF00E5FF, // Cian neón
        activeTrackTitle: 'Melodía Principal',
        activeBpm: 120.0,
        activeCamelotKey: '8B',
      ),
      StudioChannelBus(
        id: 'canal_b',
        name: 'Canal B (Percusión & Rhythm)',
        shortCode: 'CH B',
        colorHex: 0xFFFFAB00, // Ámbar cálido
        activeTrackTitle: 'Base Rítmica',
        activeBpm: 126.0,
        activeCamelotKey: '9A',
      ),
      StudioChannelBus(
        id: 'canal_c',
        name: 'Canal C (Voz & Micrófono)',
        shortCode: 'CH C',
        colorHex: 0xFF10B981, // Esmeralda club
        activeTrackTitle: 'Toma de Voz',
        activeBpm: 120.0,
        activeCamelotKey: '8B',
      ),
      StudioChannelBus(
        id: 'canal_d',
        name: 'Canal D (Master FX & Synth)',
        shortCode: 'CH D',
        colorHex: 0xFF8B5CF6, // Púrpura synthwave
        activeTrackTitle: 'Master Mix',
        activeBpm: 124.0,
        activeCamelotKey: '11B',
      ),
    ];
  }

  /// Crea una nueva instancia de canal personalizado con nombre y color definidos por el usuario.
  factory StudioChannelBus.createCustom({
    required String id,
    required String name,
    String? shortCode,
    int? colorHex,
  }) {
    final code = shortCode ?? (name.length > 4 ? name.substring(0, 4).toUpperCase() : name.toUpperCase());
    return StudioChannelBus(
      id: id,
      name: name,
      shortCode: code,
      colorHex: colorHex ?? 0xFF00E5FF,
    );
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
    String? activeTrackTitle,
    double? activeBpm,
    String? activeCamelotKey,
    bool? isPlaying,
    int? positionMs,
    Float32List? livePcmBuffer,
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
      activeTrackTitle: activeTrackTitle ?? this.activeTrackTitle,
      activeBpm: activeBpm ?? this.activeBpm,
      activeCamelotKey: activeCamelotKey ?? this.activeCamelotKey,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      livePcmBuffer: livePcmBuffer ?? this.livePcmBuffer,
    );
  }

  /// Actualiza los parámetros dinámicos de reproducción manteniendo intacta la identidad y configuración del canal.
  StudioChannelBus withPlaybackParameters({
    String? title,
    double? bpm,
    String? key,
    bool? isPlaying,
    int? positionMs,
    Float32List? pcmBuffer,
  }) {
    return copyWith(
      activeTrackTitle: title,
      activeBpm: bpm,
      activeCamelotKey: key,
      isPlaying: isPlaying,
      positionMs: positionMs,
      livePcmBuffer: pcmBuffer,
    );
  }

  /// Actualiza el nombre y código corto visible del canal.
  StudioChannelBus withName(String newName) {
    final code = newName.length > 4 ? newName.substring(0, 4).toUpperCase() : newName.toUpperCase();
    return copyWith(name: newName, shortCode: code);
  }
}
