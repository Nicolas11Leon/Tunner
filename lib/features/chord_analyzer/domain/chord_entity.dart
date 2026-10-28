/// Calidades o especies armónicas reconocidas por el analizador polifónico.
enum ChordQuality {
  major,
  minor,
  diminished,
  augmented,
  dominant7,
  major7,
  minor7,
  sus4,
  sus2,
}

extension ChordQualityExtension on ChordQuality {
  String get nameSpanish {
    switch (this) {
      case ChordQuality.major:
        return 'Mayor';
      case ChordQuality.minor:
        return 'Menor';
      case ChordQuality.diminished:
        return 'Disminuido';
      case ChordQuality.augmented:
        return 'Aumentado';
      case ChordQuality.dominant7:
        return 'Séptima de Dominante';
      case ChordQuality.major7:
        return 'Séptima Mayor';
      case ChordQuality.minor7:
        return 'Séptima Menor';
      case ChordQuality.sus4:
        return 'Suspendido de Cuarta';
      case ChordQuality.sus2:
        return 'Suspendido de Segunda';
    }
  }

  String get symbolSuffix {
    switch (this) {
      case ChordQuality.major:
        return '';
      case ChordQuality.minor:
        return 'm';
      case ChordQuality.diminished:
        return 'dim';
      case ChordQuality.augmented:
        return 'aug';
      case ChordQuality.dominant7:
        return '7';
      case ChordQuality.major7:
        return 'maj7';
      case ChordQuality.minor7:
        return 'm7';
      case ChordQuality.sus4:
        return 'sus4';
      case ChordQuality.sus2:
        return 'sus2';
    }
  }

  /// Intervalos en semitonos relativos a la nota fundamental.
  List<int> get intervalsInSemitones {
    switch (this) {
      case ChordQuality.major:
        return const [0, 4, 7];
      case ChordQuality.minor:
        return const [0, 3, 7];
      case ChordQuality.diminished:
        return const [0, 3, 6];
      case ChordQuality.augmented:
        return const [0, 4, 8];
      case ChordQuality.dominant7:
        return const [0, 4, 7, 10];
      case ChordQuality.major7:
        return const [0, 4, 7, 11];
      case ChordQuality.minor7:
        return const [0, 3, 7, 10];
      case ChordQuality.sus4:
        return const [0, 5, 7];
      case ChordQuality.sus2:
        return const [0, 2, 7];
    }
  }

  String get formulaLabel {
    switch (this) {
      case ChordQuality.major:
        return '1 - 3 - 5';
      case ChordQuality.minor:
        return '1 - b3 - 5';
      case ChordQuality.diminished:
        return '1 - b3 - b5';
      case ChordQuality.augmented:
        return '1 - 3 - #5';
      case ChordQuality.dominant7:
        return '1 - 3 - 5 - b7';
      case ChordQuality.major7:
        return '1 - 3 - 5 - 7';
      case ChordQuality.minor7:
        return '1 - b3 - 5 - b7';
      case ChordQuality.sus4:
        return '1 - 4 - 5';
      case ChordQuality.sus2:
        return '1 - 2 - 5';
    }
  }
}

/// Entidad inmutable que encapsula el resultado del análisis polifónico de un acorde.
class ChordEntity {
  static const List<String> chromaticNoteNames = [
    'Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si',
  ];

  static const List<String> internationalNoteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// Índice cromático de la nota fundamental (0 = C / Do, ..., 11 = B / Si).
  final int rootNoteIndex;

  /// Especie o cualidad armónica del acorde.
  final ChordQuality quality;

  /// Nivel de confianza o certidumbre estadística de la clasificación (0.0 a 1.0).
  final double confidence;

  /// Vector de energía cromagrama normalizado de 12 clases (Pitch Class Profile).
  final List<double> chromaVector;

  /// Lista de notas constitutivas del acorde en notación silábica (ej. ['Do', 'Mi', 'Sol']).
  final List<String> notes;

  const ChordEntity({
    required this.rootNoteIndex,
    required this.quality,
    required this.confidence,
    required this.chromaVector,
    required this.notes,
  });

  /// Instancia nula representativa de ausencia de acorde o silencio acústico.
  static final ChordEntity none = ChordEntity(
    rootNoteIndex: -1,
    quality: ChordQuality.major,
    confidence: 0.0,
    chromaVector: List.filled(12, 0.0),
    notes: const [],
  );

  bool get isRecognized => rootNoteIndex >= 0 && confidence > 0.0;

  /// Nombre de la nota raíz en notación silábica en español (ej. 'Do', 'Fa#').
  String get rootNameSpanish =>
      rootNoteIndex >= 0 && rootNoteIndex < 12 ? chromaticNoteNames[rootNoteIndex] : '--';

  /// Nombre de la nota raíz en cifrado internacional (ej. 'C', 'F#').
  String get rootNameInternational =>
      rootNoteIndex >= 0 && rootNoteIndex < 12 ? internationalNoteNames[rootNoteIndex] : '--';

  /// Símbolo internacional abreviado del acorde (ej. 'C', 'Am', 'G7', 'F#maj7').
  String get symbol =>
      rootNoteIndex >= 0 ? '$rootNameInternational${quality.symbolSuffix}' : '--';

  /// Nombre descriptivo completo en español (ej. 'Do Mayor', 'La Menor 7').
  String get displayName =>
      rootNoteIndex >= 0 ? '$rootNameSpanish ${quality.nameSpanish}' : 'Sin acorde detectado';

  /// Fórmula interválica teórica (ej. '1 - 3 - 5').
  String get formula => rootNoteIndex >= 0 ? quality.formulaLabel : '--';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChordEntity &&
          runtimeType == other.runtimeType &&
          rootNoteIndex == other.rootNoteIndex &&
          quality == other.quality;

  @override
  int get hashCode => rootNoteIndex.hashCode ^ quality.hashCode;

  @override
  String toString() => 'ChordEntity($symbol, ${(confidence * 100).toStringAsFixed(1)}%)';
}
