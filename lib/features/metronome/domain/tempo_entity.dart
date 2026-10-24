/// Entidad de dominio pura que representa una marca de tempo musical y su escala italiana.
/// Sin dependencias de Flutter ni librerías de infraestructura.
class TempoMark {
  final String italianName;
  final String description;
  final int minBpm;
  final int maxBpm;

  const TempoMark({
    required this.italianName,
    required this.description,
    required this.minBpm,
    required this.maxBpm,
  });

  /// Mapeo canónico internacional de marcas de tempo según la práctica orquestal estándar.
  static const List<TempoMark> standardMarks = [
    TempoMark(
      italianName: "Larghissimo",
      description: "Extremadamente lento y solemne",
      minBpm: 20,
      maxBpm: 39,
    ),
    TempoMark(
      italianName: "Largo",
      description: "Amplio, pausado y reposado",
      minBpm: 40,
      maxBpm: 59,
    ),
    TempoMark(
      italianName: "Adagio",
      description: "Lento, cómodo y expresivo",
      minBpm: 60,
      maxBpm: 75,
    ),
    TempoMark(
      italianName: "Andante",
      description: "A paso de marcha natural y fluido",
      minBpm: 76,
      maxBpm: 107,
    ),
    TempoMark(
      italianName: "Moderato",
      description: "Velocidad moderada y templada",
      minBpm: 108,
      maxBpm: 119,
    ),
    TempoMark(
      italianName: "Allegro",
      description: "Rápido, animado y brillante",
      minBpm: 120,
      maxBpm: 155,
    ),
    TempoMark(
      italianName: "Presto",
      description: "Muy rápido y ágil",
      minBpm: 156,
      maxBpm: 199,
    ),
    TempoMark(
      italianName: "Prestissimo",
      description: "Velocidad extrema de virtuosismo",
      minBpm: 200,
      maxBpm: 300,
    ),
  ];

  /// Resuelve la marca italiana correspondiente para cualquier BPM dentro de [20, 300].
  static TempoMark fromBpm(int bpm) {
    final clamped = bpm.clamp(20, 300);
    for (final mark in standardMarks) {
      if (clamped >= mark.minBpm && clamped <= mark.maxBpm) {
        return mark;
      }
    }
    return standardMarks.last;
  }
}
