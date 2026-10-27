import 'dart:math' as math;

/// Entidad inmutable que modela un sistema de temperamento musical.
class MusicalTemperament {
  final String id;
  final String name;
  final String historicalEra;
  final String description;

  /// Lista de 12 desviaciones en cents relativas al Temperamento Igual (12-EDO),
  /// ordenadas cromáticamente a partir de la tónica (índice 0 a 11).
  final List<double> centsOffsets;

  const MusicalTemperament({
    required this.id,
    required this.name,
    required this.historicalEra,
    required this.description,
    required this.centsOffsets,
  });
}

/// Motor determinista de cálculo de afinación de temperamentos históricos y microtonales.
///
/// Todas las operaciones son puras en Dart, con complejidad temporal O(1)
/// y sin asignaciones innecesarias de memoria en bucles de audio.
class TemperamentEngine {
  const TemperamentEngine();

  // Nombres estándar de notas cromáticas (base Do = 0)
  static const List<String> chromaticNoteNames = [
    'Do', 'Do#', 'Re', 'Mib', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'Sib', 'Si'
  ];

  static const List<String> chromaticNoteNamesEnglish = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B'
  ];

  /// Colección canónica de los 8 temperamentos de conservatorio y música antigua.
  static const List<MusicalTemperament> allTemperaments = [
    MusicalTemperament(
      id: 'equal',
      name: 'Temperamento Igual (12-EDO)',
      historicalEra: 'Siglo XIX - Contemporáneo',
      description: 'Estándar moderno: 12 semitonos exactamente iguales de 100 cents.',
      centsOffsets: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    MusicalTemperament(
      id: 'pythagorean',
      name: 'Pitagórico (Pythagorean)',
      historicalEra: 'Antigua Grecia & Medieval',
      description: 'Basado en quintas puras 3:2 (701.96 cents). Terceras mayores muy abiertas (407.8 cents).',
      centsOffsets: [0.0, -9.78, 3.91, -5.87, 7.82, -1.96, 11.73, 1.96, -7.82, 5.87, -3.91, 9.78],
    ),
    MusicalTemperament(
      id: 'just_intonation',
      name: 'Entonación Justa (5-Limit Just)',
      historicalEra: 'Renacimiento & Coros',
      description: 'Terceras mayores puras 5:4 (386.31 cents) y quintas 3:2. Máxima consonancia sin batimento.',
      centsOffsets: [0.0, 11.73, 3.91, 15.64, -13.69, -1.96, -9.78, 1.96, 13.69, -15.64, -3.91, -11.73],
    ),
    MusicalTemperament(
      id: 'meantone_quarter',
      name: 'Mesotónico 1/4 de Coma (Aron 1523)',
      historicalEra: 'Renacimiento & Primer Barroco',
      description: 'Terceras mayores acústicamente puras; quintas reducidas en 1/4 de coma sintónica.',
      centsOffsets: [0.0, -24.0, -7.0, 10.0, -14.0, 3.0, -21.0, -3.5, -27.5, -10.5, 7.0, -17.5],
    ),
    MusicalTemperament(
      id: 'werckmeister_iii',
      name: 'Werckmeister III (1691)',
      historicalEra: 'Barroco Tardío (J.S. Bach)',
      description: 'Buen temperamento clásico: divide la coma pitagórica en cuatro quintas estratégicas.',
      centsOffsets: [0.0, -10.0, -8.0, -6.0, -10.0, -2.0, -12.0, -4.0, -8.0, -12.0, -4.0, -8.0],
    ),
    MusicalTemperament(
      id: 'kirnberger_iii',
      name: 'Kirnberger III (1779)',
      historicalEra: 'Clasicismo Temprano',
      description: 'Combina terceras puras sobre la tónica con distribución mesotónica suave.',
      centsOffsets: [0.0, -10.0, -7.0, -6.0, -14.0, -2.0, -10.0, -3.5, -8.0, -10.5, -4.0, -12.0],
    ),
    MusicalTemperament(
      id: 'vallotti',
      name: 'Vallotti (1779)',
      historicalEra: 'Barroco Italiano & Música Antigua',
      description: 'Seis quintas atemperadas en 1/6 de coma y seis quintas puras. El estándar de interpretación histórica.',
      centsOffsets: [0.0, -8.0, -4.0, -2.0, -6.0, 2.0, -10.0, -2.0, -6.0, -6.0, 0.0, -4.0],
    ),
    MusicalTemperament(
      id: 'young_ii',
      name: 'Young II (1800)',
      historicalEra: 'Transición Clásica & Romántica',
      description: 'Progresión gradual de color tonal hacia todas las tonalidades mayores y menores.',
      centsOffsets: [0.0, -8.0, -4.0, -4.0, -8.0, 0.0, -10.0, -2.0, -6.0, -6.0, -2.0, -6.0],
    ),
  ];

  /// Obtiene un temperamento por su ID, o retorna el Temperamento Igual por defecto.
  static MusicalTemperament getById(String id) {
    return allTemperaments.firstWhere(
      (t) => t.id == id,
      orElse: () => allTemperaments.first,
    );
  }

  /// Calcula la desviación en cents de una nota cromática específica según el temperamento
  /// y la nota raíz o tónica seleccionada.
  ///
  /// [noteIndex]: Grado cromático absoluto (0 = Do, 1 = Do#, ..., 9 = La, ..., 11 = Si).
  /// [rootKey]: Tónica fundamental de la escala (0 = Do, 2 = Re, etc.).
  double getCentsOffset({
    required int noteIndex,
    required MusicalTemperament temperament,
    int rootKey = 0,
  }) {
    final normalizedNote = (noteIndex % 12 + 12) % 12;
    final normalizedRoot = (rootKey % 12 + 12) % 12;
    final degreeFromRoot = (normalizedNote - normalizedRoot + 12) % 12;
    return temperament.centsOffsets[degreeFromRoot];
  }

  /// Calcula la frecuencia objetivo exacta en Hz para una nota en un temperamento dado.
  ///
  /// [midiNumber]: Número MIDI de la nota (e.g. 69 = A4 = 440 Hz en afinación estándar).
  /// [a4Ref]: Frecuencia de concierto de calibración para A4 (e.g. 440.0, 442.0, 415.0).
  /// [temperament]: Sistema de temperamento.
  /// [rootKey]: Tónica del temperamento (0 = Do).
  double getTargetFrequency({
    required int midiNumber,
    required MusicalTemperament temperament,
    double a4Ref = 440.0,
    int rootKey = 0,
  }) {
    // 1. Frecuencia base en Temperamento Igual 12-EDO:
    // f_equal = a4Ref * 2^((midiNumber - 69) / 12)
    final equalFrequency = a4Ref * math.pow(2.0, (midiNumber - 69) / 12.0);

    // 2. Desviación en cents en función de la tónica:
    final noteIndex = midiNumber % 12;
    final centsOffset = getCentsOffset(
      noteIndex: noteIndex,
      temperament: temperament,
      rootKey: rootKey,
    );

    // 3. Modulación por factor cents: f_target = f_equal * 2^(centsOffset / 1200)
    return equalFrequency * math.pow(2.0, centsOffset / 1200.0);
  }

  /// Calcula la desviación en cents de una frecuencia acústica detectada contra
  /// la frecuencia objetivo del temperamento:
  ///
  /// cents = 1200 * log2(detectedFrequency / targetFrequency)
  double calculateCentsDeviation({
    required double detectedFrequency,
    required double targetFrequency,
  }) {
    if (detectedFrequency <= 0 || targetFrequency <= 0) return 0.0;
    return 1200.0 * (math.log(detectedFrequency / targetFrequency) / math.ln2);
  }
}
