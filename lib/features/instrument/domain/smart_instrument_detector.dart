import 'dart:math' as math;
import 'instrument_profile_entity.dart';

/// Firma acústica extraída de un frame de audio/pitch para identificación de instrumento.
class AcousticSignature {
  /// Frecuencia fundamental detectada en Hz.
  final double fundamentalFrequencyHz;

  /// Nivel de claridad o periodicidad (0.0 a 1.0, típicamente del NSDF de MPM).
  final double clarity;

  /// Amplitudes normalizadas relativas de los primeros 8 armónicos [H1 (f0), H2, ..., H8].
  final List<double> overtoneAmplitudes;

  /// Centroide espectral en Hz (brillo del timbre).
  final double spectralCentroidHz;

  const AcousticSignature({
    required this.fundamentalFrequencyHz,
    required this.clarity,
    required this.overtoneAmplitudes,
    required this.spectralCentroidHz,
  });

  /// Fracción relativa de energía en armónicos impares (H1, H3, H5, H7) respecto al total.
  /// Rango acotado determinista entre 0.0 y 1.0 (MIR Standard).
  double get oddHarmonicEnergyFraction {
    double odd = 0.0;
    double even = 0.0;
    for (int i = 0; i < overtoneAmplitudes.length && i < 8; i++) {
      if ((i + 1) % 2 != 0) {
        odd += overtoneAmplitudes[i];
      } else {
        even += overtoneAmplitudes[i];
      }
    }
    final total = odd + even;
    return total > 0.0 ? odd / total : 0.5;
  }

  /// Brillo espectral relativo: proporción de energía en sobretonos altos (H5..H8) vs bajos (H1..H4).
  double get highFrequencyHarmonicRatio {
    if (overtoneAmplitudes.length < 8) return 0.2;
    double low = 0.0;
    double high = 0.0;
    for (int i = 0; i < 4; i++) {
      low += overtoneAmplitudes[i];
    }
    for (int i = 4; i < 8; i++) {
      high += overtoneAmplitudes[i];
    }
    return high / (low + 0.0001);
  }
}

/// Coincidencia de reconocimiento de instrumento detectado con métrica de confianza.
class SmartInstrumentMatch {
  final InstrumentProfileEntity instrument;
  final double confidence; // 0.0 a 1.0
  final String detectionReason;
  final int soundFontPatch;

  const SmartInstrumentMatch({
    required this.instrument,
    required this.confidence,
    required this.detectionReason,
    required this.soundFontPatch,
  });

  @override
  String toString() =>
      '${instrument.name} (${(confidence * 100).toStringAsFixed(1)}%) - $detectionReason';
}

/// Perfil de referencia acústica interna para la clasificación de timbres.
class _InstrumentTimbralReference {
  final InstrumentProfileEntity instrument;
  final List<double> referenceOvertones;
  final double expectedOddFraction;
  final double expectedCentroidHz;
  final int soundFontPatch;

  const _InstrumentTimbralReference({
    required this.instrument,
    required this.referenceOvertones,
    required this.expectedOddFraction,
    required this.expectedCentroidHz,
    required this.soundFontPatch,
  });
}

/// Servicio de Dominio Puro para reconocimiento y adaptación acústica de instrumentos.
///
/// Evalúa en tiempo real firmas acústicas multivariadas sin dependencias de red o UI.
class SmartInstrumentDetector {
  /// Base de datos canónica de perfiles de referencia tímbrica calibrados.
  static final List<_InstrumentTimbralReference> _referenceProfiles = [
    // 1. Flauta: Fundamental casi pura, sobretonos mínimos, centroide suave
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.flute,
      referenceOvertones: [1.0, 0.15, 0.05, 0.02, 0.01, 0.0, 0.0, 0.0],
      expectedOddFraction: 0.88,
      expectedCentroidHz: 750.0,
      soundFontPatch: 73, // GM Flute
    ),
    // 2. Clarinete Si♭: Armónicos impares marcadamente dominantes (H1, H3, H5)
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.bbClarinet,
      referenceOvertones: [1.0, 0.08, 0.65, 0.05, 0.35, 0.03, 0.18, 0.02],
      expectedOddFraction: 0.92,
      expectedCentroidHz: 920.0,
      soundFontPatch: 71, // GM Clarinet
    ),
    // 3. Trompeta Si♭: Metales brillantes, ricos sobretonos H2..H8, centroide alto
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.bbTrumpet,
      referenceOvertones: [1.0, 0.85, 0.70, 0.55, 0.40, 0.28, 0.18, 0.10],
      expectedOddFraction: 0.56,
      expectedCentroidHz: 1450.0,
      soundFontPatch: 56, // GM Trumpet
    ),
    // 4. Saxofón Alto Mi♭: Caña cónica rica, cuerpo armónico denso
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.ebAltoSax,
      referenceOvertones: [1.0, 0.75, 0.55, 0.45, 0.35, 0.20, 0.15, 0.08],
      expectedOddFraction: 0.59,
      expectedCentroidHz: 1100.0,
      soundFontPatch: 65, // GM Alto Sax
    ),
    // 5. Violín: Cuerda frotada con ricos sobretonos continuos y resonancia de madera
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.violin,
      referenceOvertones: [1.0, 0.70, 0.50, 0.38, 0.25, 0.18, 0.12, 0.06],
      expectedOddFraction: 0.55,
      expectedCentroidHz: 1300.0,
      soundFontPatch: 40, // GM Violin
    ),
    // 6. Guitarra Acústica: Ataque percusivo con decaimiento exponencial y resonancia
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.guitar,
      referenceOvertones: [1.0, 0.60, 0.40, 0.25, 0.15, 0.10, 0.05, 0.02],
      expectedOddFraction: 0.62,
      expectedCentroidHz: 850.0,
      soundFontPatch: 25, // GM Acoustic Guitar Steel
    ),
    // 7. Violonchelo: Cuerda grave-media con fundamental potente
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.cello,
      referenceOvertones: [1.0, 0.65, 0.45, 0.30, 0.18, 0.10, 0.06, 0.02],
      expectedOddFraction: 0.58,
      expectedCentroidHz: 550.0,
      soundFontPatch: 42, // GM Cello
    ),
    // 8. Trombón: Metal cálido medio-grave
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.trombone,
      referenceOvertones: [1.0, 0.80, 0.60, 0.45, 0.30, 0.18, 0.10, 0.05],
      expectedOddFraction: 0.57,
      expectedCentroidHz: 680.0,
      soundFontPatch: 57, // GM Trombone
    ),
    // 9. Voz / Canto Universal: Formantes vocálicos y textura orgánica
    const _InstrumentTimbralReference(
      instrument: InstrumentProfileEntity.voice,
      referenceOvertones: [1.0, 0.50, 0.35, 0.25, 0.20, 0.15, 0.10, 0.05],
      expectedOddFraction: 0.64,
      expectedCentroidHz: 900.0,
      soundFontPatch: 54, // GM Synth Voice
    ),
  ];

  /// Analiza una firma acústica y retorna los mejores candidatos clasificados por confianza.
  List<SmartInstrumentMatch> detectCandidates(
    AcousticSignature signature, {
    int limit = 3,
  }) {
    if (signature.clarity < 0.60 || signature.fundamentalFrequencyHz < 20.0) {
      return const [];
    }

    final results = <SmartInstrumentMatch>[];

    for (final ref in _referenceProfiles) {
      final inst = ref.instrument;

      // 1. Puntuación de Rango de Tesitura
      double rangeScore = 0.0;
      if (signature.fundamentalFrequencyHz >= inst.minFrequencyHz &&
          signature.fundamentalFrequencyHz <= inst.maxFrequencyHz) {
        rangeScore = 1.0;
      } else {
        // Penalización proporcional a la distancia en octavas fuera del rango
        final freqRatio = signature.fundamentalFrequencyHz < inst.minFrequencyHz
            ? inst.minFrequencyHz / signature.fundamentalFrequencyHz
            : signature.fundamentalFrequencyHz / inst.maxFrequencyHz;
        rangeScore = math.max(0.0, 1.0 - (math.log(freqRatio) / math.ln2) * 0.5);
      }

      // Si está totalmente fuera de rango acústico, descartar
      if (rangeScore <= 0.2) continue;

      // 2. Similitud Coseno de Sobretonos Armónicos (H1..H8)
      final overtoneSimilarity = _calculateCosineSimilarity(
        signature.overtoneAmplitudes,
        ref.referenceOvertones,
      );

      // 3. Similitud de Fracción Armónica Impar
      final oddDiff = (signature.oddHarmonicEnergyFraction - ref.expectedOddFraction).abs();
      final oddScore = math.max(0.0, 1.0 - (oddDiff * 1.5));

      // 4. Similitud de Centroide Espectral (Brillo tímbrico)
      final centroidDiff = (signature.spectralCentroidHz - ref.expectedCentroidHz).abs();
      final centroidScore = math.max(0.0, 1.0 - (centroidDiff / 1500.0));

      // 5. Ponderación Multivariada Consolidada
      // 35% Rango + 35% Similitud de Sobretonos + 15% Fracción Impar + 15% Centroide
      final compositeScore = (rangeScore * 0.35) +
          (overtoneSimilarity * 0.35) +
          (oddScore * 0.15) +
          (centroidScore * 0.15);

      final confidence = compositeScore.clamp(0.0, 1.0);

      // Generar razón descriptiva pedagógica
      String reason;
      if (ref.instrument.id == 'bb_clarinet' && signature.oddHarmonicEnergyFraction > 0.80) {
        reason = 'Sobretonos impares prominentes (H3/H5) característicos de caña cilíndrica';
      } else if (ref.instrument.id == 'flute' && signature.highFrequencyHarmonicRatio < 0.15) {
        reason = 'Predominio casi puro de fundamental con mínima distorsión armónica';
      } else if (ref.instrument.id == 'bb_trumpet' && signature.spectralCentroidHz > 1200) {
        reason = 'Timbre brillante y espectro metálico de alta energía en H2..H6';
      } else {
        reason = 'Firma acústica y rango armónico concordante con ${inst.name}';
      }

      results.add(
        SmartInstrumentMatch(
          instrument: inst,
          confidence: confidence,
          detectionReason: reason,
          soundFontPatch: ref.soundFontPatch,
        ),
      );
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results.take(limit).toList();
  }

  /// Retorna la mejor coincidencia única si supera el umbral de certeza establecido.
  SmartInstrumentMatch? bestMatch(
    AcousticSignature signature, {
    double minimumConfidence = 0.75,
  }) {
    final candidates = detectCandidates(signature, limit: 1);
    if (candidates.isEmpty) return null;
    final top = candidates.first;
    return top.confidence >= minimumConfidence ? top : null;
  }

  /// Calcula la similitud coseno entre dos vectores normalizados de armónicos.
  static double _calculateCosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final n = math.min(a.length, b.length);

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < n; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA <= 0.0 || normB <= 0.0) return 0.0;
    return (dotProduct / (math.sqrt(normA) * math.sqrt(normB))).clamp(0.0, 1.0);
  }
}
