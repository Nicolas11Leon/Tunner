import 'dart:math' as math;
import 'chord_entity.dart';
import 'chroma_vector_calculator.dart';

class _ChordTemplate {
  final int rootIndex;
  final ChordQuality quality;
  final List<double> normalizedVector;
  final List<String> notes;

  const _ChordTemplate({
    required this.rootIndex,
    required this.quality,
    required this.normalizedVector,
    required this.notes,
  });
}

/// Clasificador polifónico de máxima verosimilitud por similitud de coseno.
/// Pure Dart: Cero dependencias de plugins o UI.
class PolyphonicChordRecognizer {
  final double confidenceThreshold;
  final ChromaVectorCalculator _calculator;
  final List<_ChordTemplate> _templates = [];

  // Filtro de estabilidad temporal
  ChordEntity _lastStableChord = ChordEntity.none;
  ChordEntity _provisionalChord = ChordEntity.none;
  int _consecutiveDetections = 0;
  static const int _requiredConsecutiveFrames = 2;

  PolyphonicChordRecognizer({
    this.confidenceThreshold = 0.58,
    ChromaVectorCalculator? calculator,
  }) : _calculator = calculator ?? const ChromaVectorCalculator() {
    _initTemplates();
  }

  void _initTemplates() {
    for (int root = 0; root < 12; root++) {
      for (final quality in ChordQuality.values) {
        final intervals = quality.intervalsInSemitones;
        final rawVector = List<double>.filled(12, 0.0);
        final notes = <String>[];

        for (final interval in intervals) {
          final pitchClass = (root + interval) % 12;
          // Ponderación armónica: Fundamental y tercera tienen peso preponderante
          double weight = 1.0;
          if (interval == 7) weight = 0.85; // Quinta justa
          if (interval >= 10) weight = 0.90; // Séptimas

          rawVector[pitchClass] = weight;
          notes.add(ChordEntity.chromaticNoteNames[pitchClass]);
        }

        final normalized = ChromaVectorCalculator.normalizeChroma(rawVector);

        _templates.add(_ChordTemplate(
          rootIndex: root,
          quality: quality,
          normalizedVector: normalized,
          notes: notes,
        ));
      }
    }
  }

  /// Identifica el acorde a partir de muestras de audio PCM directas.
  ChordEntity identifyFromSamples({
    required List<double> samples,
    double sampleRate = 44100.0,
    double a4Ref = 440.0,
    double noiseGateRms = 0.008,
  }) {
    final chroma = _calculator.calculateFromSamples(
      samples: samples,
      sampleRate: sampleRate,
      a4Ref: a4Ref,
      noiseGateRms: noiseGateRms,
    );

    return identifyFromChroma(chroma);
  }

  /// Identifica el acorde a partir de un vector de cromagrama normalizado de 12 clases.
  ChordEntity identifyFromChroma(List<double> chromaVector) {
    if (chromaVector.length != 12) {
      return ChordEntity.none;
    }

    // Comprobación de energía en el vector
    double maxEnergy = 0.0;
    for (int i = 0; i < 12; i++) {
      if (chromaVector[i] > maxEnergy) {
        maxEnergy = chromaVector[i];
      }
    }

    if (maxEnergy < 0.15) {
      _consecutiveDetections = 0;
      _provisionalChord = ChordEntity.none;
      _lastStableChord = ChordEntity.none;
      return ChordEntity.none;
    }

    _ChordTemplate? bestTemplate;
    double highestSimilarity = -1.0;

    for (final template in _templates) {
      // Producto escalar entre vectores L2 normalizados (Similitud de Coseno)
      double dotProduct = 0.0;
      for (int i = 0; i < 12; i++) {
        dotProduct += chromaVector[i] * template.normalizedVector[i];
      }

      if (dotProduct > highestSimilarity) {
        highestSimilarity = dotProduct;
        bestTemplate = template;
      }
    }

    if (bestTemplate == null || highestSimilarity < confidenceThreshold) {
      _consecutiveDetections = 0;
      return ChordEntity.none;
    }

    final candidate = ChordEntity(
      rootNoteIndex: bestTemplate.rootIndex,
      quality: bestTemplate.quality,
      confidence: math.min(1.0, math.max(0.0, highestSimilarity)),
      chromaVector: List<double>.from(chromaVector),
      notes: bestTemplate.notes,
    );

    // Aplicar histéresis temporal para evitar fluctuaciones
    if (candidate == _provisionalChord) {
      _consecutiveDetections++;
      if (_consecutiveDetections >= _requiredConsecutiveFrames) {
        _lastStableChord = candidate;
      }
    } else {
      _provisionalChord = candidate;
      _consecutiveDetections = 1;
      // Si la confianza es muy alta (>0.82), adoptar inmediatamente
      if (candidate.confidence >= 0.82) {
        _lastStableChord = candidate;
      }
    }

    return _lastStableChord.isRecognized ? _lastStableChord : candidate;
  }

  /// Reinicia el historial temporal del reconocedor.
  void reset() {
    _consecutiveDetections = 0;
    _provisionalChord = ChordEntity.none;
    _lastStableChord = ChordEntity.none;
  }
}
