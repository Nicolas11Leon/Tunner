/// Métrica de compás musical (e.g. 4/4, 3/4, 2/4, 6/8).
/// Modelo de dominio inmutable para la representación jerárquica de partituras.
class TimeSignature {
  final int numerator;   // Número de pulsos por compás (e.g. 3, 4, 6)
  final int denominator; // Unidad de figura del pulso (e.g. 4 para negra, 8 para corchea)

  const TimeSignature(this.numerator, this.denominator);

  static const TimeSignature commonTime44 = TimeSignature(4, 4);
  static const TimeSignature waltzTime34 = TimeSignature(3, 4);
  static const TimeSignature marchTime24 = TimeSignature(2, 4);
  static const TimeSignature compoundTime68 = TimeSignature(6, 8);

  /// Cantidad total de sub-ticks (semicorcheas, resolución base = 1/16) en este compás.
  /// Fórmula: numerador * (16 / denominador)
  int get totalTicks => (numerator * (16 ~/ denominator));

  @override
  String toString() => '$numerator/$denominator';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSignature &&
          runtimeType == other.runtimeType &&
          numerator == other.numerator &&
          denominator == other.denominator;

  @override
  int get hashCode => numerator.hashCode ^ denominator.hashCode;
}

/// Figura musical o silencio dentro de un compás jerárquico.
class HierarchicalNote {
  final int startTick;     // Sub-tick de inicio dentro del compás (de 0 a totalTicks - 1)
  final int durationTicks; // Duración en sub-ticks de resolución base (semicorcheas)
  final String noteName;   // Nombre de la nota con octava (ej: "Do4", "Mi4", "Sol#5"). Vacío si es silencio.
  final bool isRest;       // True si representa un silencio musical

  const HierarchicalNote({
    required this.startTick,
    required this.durationTicks,
    required this.noteName,
    this.isRest = false,
  });

  /// Crea una nota afinada regular
  factory HierarchicalNote.note({
    required int startTick,
    required int durationTicks,
    required String noteName,
  }) {
    return HierarchicalNote(
      startTick: startTick,
      durationTicks: durationTicks,
      noteName: noteName,
      isRest: false,
    );
  }

  /// Crea un silencio musical
  factory HierarchicalNote.rest({
    required int startTick,
    required int durationTicks,
  }) {
    return HierarchicalNote(
      startTick: startTick,
      durationTicks: durationTicks,
      noteName: '',
      isRest: true,
    );
  }

  int get endTick => startTick + durationTicks;
}

/// Compás individual dentro de la obra musical.
class MeasureEntity {
  final int index; // Índice correlativo (0, 1, 2...)
  final TimeSignature timeSignature;
  final List<HierarchicalNote> notes;

  const MeasureEntity({
    required this.index,
    required this.timeSignature,
    required this.notes,
  });

  /// Verifica si la suma de duraciones coincide exactamente con la métrica del compás.
  bool get isValidMeasure {
    int totalOccupiedTicks = 0;
    for (final note in notes) {
      totalOccupiedTicks += note.durationTicks;
    }
    return totalOccupiedTicks == timeSignature.totalTicks;
  }
}

/// Obra musical o estudio pedagógico completo.
class HierarchicalScore {
  final String title;
  final int baseBpm;
  final List<MeasureEntity> measures;

  const HierarchicalScore({
    required this.title,
    this.baseBpm = 75,
    required this.measures,
  });

  /// Genera estudios pedagógicos canónicos para validación y práctica interactiva.
  static List<HierarchicalScore> getMockStudies() {
    return [
      HierarchicalScore(
        title: "Estudio Multi-Compás 4/4 (2 Compases)",
        baseBpm: 75,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Do4"), // Negra
              HierarchicalNote.rest(startTick: 4, durationTicks: 4),                   // Silencio negra
              HierarchicalNote.note(startTick: 8, durationTicks: 2, noteName: "Re4"), // Corchea
              HierarchicalNote.note(startTick: 10, durationTicks: 2, noteName: "Mi4"),// Corchea
              HierarchicalNote.note(startTick: 12, durationTicks: 1, noteName: "Fa4"),// Semicorcheas
              HierarchicalNote.note(startTick: 13, durationTicks: 1, noteName: "Sol4"),
              HierarchicalNote.note(startTick: 14, durationTicks: 1, noteName: "La4"),
              HierarchicalNote.note(startTick: 15, durationTicks: 1, noteName: "Si4"),
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: "Do5"), // Blanca
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Sol4"),// Negra
              HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: "Do4"),// Negra resolutiva
            ],
          ),
        ],
      ),
      HierarchicalScore(
        title: "Estudio en 3/4 (Vals Clásico)",
        baseBpm: 90,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.waltzTime34,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Sol4"), // Negra
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "Mi4"),  // Negra
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Do4"),  // Negra
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.waltzTime34,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: "Re4"),  // Negra
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: "Fa4"),  // Negra
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: "Mi4"),  // Negra
            ],
          ),
        ],
      ),
      HierarchicalScore(
        title: "Estudio en 6/8 (Compás Compuesto)",
        baseBpm: 60,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.compoundTime68,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 6, noteName: "La4"), // Negra con puntillo (6 semicorcheas)
              HierarchicalNote.note(startTick: 6, durationTicks: 2, noteName: "Sol4"),// Corchea (2 semicorcheas)
              HierarchicalNote.note(startTick: 8, durationTicks: 2, noteName: "Fa#4"),// Corchea
              HierarchicalNote.note(startTick: 10, durationTicks: 2, noteName: "Mi4"),// Corchea
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.compoundTime68,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 6, noteName: "Re4"), // Negra con puntillo
              HierarchicalNote.rest(startTick: 6, durationTicks: 6),                  // Silencio de negra con puntillo
            ],
          ),
        ],
      ),
    ];
  }
}
