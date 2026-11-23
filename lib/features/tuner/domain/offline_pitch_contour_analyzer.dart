import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/audio/domain/offline_wav_decoder.dart';
import '../../practice_recorder/domain/multitrack_session_entity.dart';
import 'mcleod_pitch_method.dart';
import 'note_entity.dart';
import 'signal_conditioning_filter.dart';
import 'temperament_engine.dart';

/// Resultado agregado del analisis de contorno temporal de afinacion (pitch tracking offline).
class OfflinePitchContourResult {
  final int sampleRate;
  final double durationSeconds;
  final List<TimedPitchSample> samples;
  final int voicedFrameCount;
  final double medianPitchHz;
  final double meanPitchHz;
  final double averageAbsoluteCentsDeviation;
  final NoteEntity? dominantNote;

  const OfflinePitchContourResult({
    required this.sampleRate,
    required this.durationSeconds,
    required this.samples,
    required this.voicedFrameCount,
    required this.medianPitchHz,
    required this.meanPitchHz,
    required this.averageAbsoluteCentsDeviation,
    required this.dominantNote,
  });

  bool get hasVoicedFrames => voicedFrameCount > 0;

  Map<String, dynamic> toJson() => {
        'sampleRate': sampleRate,
        'durationSeconds': durationSeconds,
        'voicedFrameCount': voicedFrameCount,
        'totalFrameCount': samples.length,
        'medianPitchHz': medianPitchHz,
        'meanPitchHz': meanPitchHz,
        'averageAbsoluteCentsDeviation': averageAbsoluteCentsDeviation,
        if (dominantNote != null) 'dominantNote': dominantNote!.toJson(),
        'samples': samples.map((s) => s.toMap()).toList(growable: false),
      };
}

/// Analizador de contorno de pitch offline en Pure Dart mediante ventana deslizante.
///
/// Decodifica archivos WAV (16/24/32-bit float, mono/estereo) usando [OfflineWavDecoder]
/// y aplica [McleodPitchMethod] sobre ventanas deslizantes (4096 muestras por defecto,
/// salto configurable) para producir una serie temporal [TimedPitchSample] y metricas agregadas.
class OfflinePitchContourAnalyzer {
  static const int defaultWindowSize = 4096;
  static const int defaultHopSize = 1024;

  final McleodPitchMethod pitchDetector;
  final TemperamentEngine temperamentEngine;

  const OfflinePitchContourAnalyzer({
    this.pitchDetector = const McleodPitchMethod(),
    this.temperamentEngine = const TemperamentEngine(),
  });

  /// Decodifica [wavBytes] mediante [OfflineWavDecoder] y extrae el contorno temporal de pitch.
  OfflinePitchContourResult analyzeWavBytes(
    Uint8List wavBytes, {
    int windowSize = defaultWindowSize,
    int hopSize = defaultHopSize,
    double a4Ref = 440.0,
    MusicalTemperament? temperament,
    int rootKey = 0,
    bool anchorA4 = true,
    bool applyDcBlocker = false,
  }) {
    final decoded = OfflineWavDecoder.decode(wavBytes);
    return analyzeSamples(
      decoded.samples,
      sampleRate: decoded.sampleRate,
      windowSize: windowSize,
      hopSize: hopSize,
      a4Ref: a4Ref,
      temperament: temperament,
      rootKey: rootKey,
      anchorA4: anchorA4,
      applyDcBlocker: applyDcBlocker,
    );
  }

  /// Ejecuta el analisis de pitch por ventana deslizante sobre muestras normalizadas [-1.0, 1.0].
  OfflinePitchContourResult analyzeSamples(
    Float64List samples, {
    required int sampleRate,
    int windowSize = defaultWindowSize,
    int hopSize = defaultHopSize,
    double a4Ref = 440.0,
    MusicalTemperament? temperament,
    int rootKey = 0,
    bool anchorA4 = true,
    bool applyDcBlocker = false,
  }) {
    final safeSampleRate = sampleRate > 0 ? sampleRate : 44100;
    final durationSeconds = samples.length / safeSampleRate;

    if (samples.length < 64) {
      return OfflinePitchContourResult(
        sampleRate: safeSampleRate,
        durationSeconds: durationSeconds,
        samples: const [],
        voicedFrameCount: 0,
        medianPitchHz: 0.0,
        meanPitchHz: 0.0,
        averageAbsoluteCentsDeviation: 0.0,
        dominantNote: null,
      );
    }

    final Float64List workingSamples;
    if (applyDcBlocker) {
      final filter = SignalConditioningFilter();
      workingSamples = filter.conditionSamples(samples, enableDcBlocker: true);
    } else {
      workingSamples = samples;
    }

    final int effectiveWindow = math.min(
      math.max(64, windowSize),
      workingSamples.length,
    );
    final int effectiveHop = math.max(1, hopSize);
    final activeTemperament = temperament ?? TemperamentEngine.equalTemperament;
    final bool useHistoricalTemperament =
        temperament != null && temperament.id != TemperamentEngine.equalTemperament.id;

    final contour = <TimedPitchSample>[];
    final voicedPitches = <double>[];
    double sumPitchHz = 0.0;
    double sumAbsCents = 0.0;

    int offset = 0;
    while (offset + effectiveWindow <= workingSamples.length) {
      final window = Float64List.sublistView(
        workingSamples,
        offset,
        offset + effectiveWindow,
      );
      final detection = pitchDetector.estimatePitch(
        window,
        sampleRate: safeSampleRate,
      );

      final int timeMs = ((offset / safeSampleRate) * 1000.0).round();

      if (detection.pitched && detection.pitchHz > 20.0) {
        final note = NoteEntity.fromFrequency(detection.pitchHz, a4Ref: a4Ref);
        double cents = note.cents;
        if (useHistoricalTemperament) {
          final targetHz = temperamentEngine.getTargetFrequency(
            midiNumber: note.midiNumber,
            temperament: activeTemperament,
            a4Ref: a4Ref,
            rootKey: rootKey,
            anchorA4: anchorA4,
          );
          cents = temperamentEngine.calculateCentsDeviation(
            detectedFrequency: detection.pitchHz,
            targetFrequency: targetHz,
          );
        }

        contour.add(TimedPitchSample(
          timeMs: timeMs,
          frequencyHz: detection.pitchHz,
          centsDeviation: cents,
          targetNoteName: note.name,
          isSilent: false,
        ));
        voicedPitches.add(detection.pitchHz);
        sumPitchHz += detection.pitchHz;
        sumAbsCents += cents.abs();
      } else {
        contour.add(TimedPitchSample(
          timeMs: timeMs,
          frequencyHz: 0.0,
          centsDeviation: 0.0,
          targetNoteName: '--',
          isSilent: true,
        ));
      }

      offset += effectiveHop;
    }

    if (voicedPitches.isEmpty) {
      return OfflinePitchContourResult(
        sampleRate: safeSampleRate,
        durationSeconds: durationSeconds,
        samples: contour,
        voicedFrameCount: 0,
        medianPitchHz: 0.0,
        meanPitchHz: 0.0,
        averageAbsoluteCentsDeviation: 0.0,
        dominantNote: null,
      );
    }

    voicedPitches.sort();
    final int mid = voicedPitches.length ~/ 2;
    final double medianHz = voicedPitches.length.isOdd
        ? voicedPitches[mid]
        : (voicedPitches[mid - 1] + voicedPitches[mid]) * 0.5;
    final double meanHz = sumPitchHz / voicedPitches.length;
    final double avgAbsCents = sumAbsCents / voicedPitches.length;
    final dominant = NoteEntity.fromFrequency(medianHz, a4Ref: a4Ref);

    return OfflinePitchContourResult(
      sampleRate: safeSampleRate,
      durationSeconds: durationSeconds,
      samples: contour,
      voicedFrameCount: voicedPitches.length,
      medianPitchHz: medianHz,
      meanPitchHz: meanHz,
      averageAbsoluteCentsDeviation: avgAbsCents,
      dominantNote: dominant,
    );
  }
}
