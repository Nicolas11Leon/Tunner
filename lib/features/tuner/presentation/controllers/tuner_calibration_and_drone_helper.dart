import '../../../audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import '../../../drone/domain/harmonic_drone_config.dart';
import '../../../drone/domain/harmonic_drone_synthesizer.dart';
import '../../../ear_training/domain/musical_interval.dart';
import '../../domain/i_pitch_detector_service.dart';
import '../../domain/microphone_calibration_models.dart';
import '../../domain/temperament_engine.dart';

/// Resultado inmutable de una sesión de calibración de piso de ruido ambiental.
class NoiseCalibrationOutcome {
  final NoiseProfileReport report;
  final double recommendedNoiseGate;
  final double measuredNoiseFloorRms;

  const NoiseCalibrationOutcome({
    required this.report,
    required this.recommendedNoiseGate,
    required this.measuredNoiseFloorRms,
  });
}

/// Controlador auxiliar cohesivo extraído de [TunerViewModel] que encapsula:
/// 1. Calibración real del piso de ruido ambiental y medición aritmética de DC offset.
/// 2. Mapeo canónico de intervalos musicales hacia claves de repetición espaciada Ebbinghaus.
/// 3. Refresco de síntesis y reproducción del dron armónico pedal.
class TunerCalibrationAndDroneHelper {
  const TunerCalibrationAndDroneHelper();

  /// Factor multiplicativo recomendado para situar el Noise Gate por encima del piso de ruido medio.
  static const double recommendedGateMultiplier = 1.8;

  /// Piso de ruido RMS por defecto cuando no se reciben cuadros durante la calibración.
  static const double fallbackMeanRms = 0.002;

  /// Límites de seguridad del umbral de Noise Gate (RMS normalizado).
  static const double minNoiseGateThreshold = 0.003;
  static const double maxNoiseGateThreshold = 0.080;

  /// Calcula el DC offset real (media aritmética) de una ventana de muestras PCM normalizadas.
  ///
  /// Fórmula: `mu_DC = (1 / N) * sum(x_i)`.
  static double computeDcOffset(List<double>? samples) {
    if (samples == null || samples.isEmpty) {
      return 0.0;
    }
    double sum = 0.0;
    for (final sample in samples) {
      sum += sample;
    }
    return sum / samples.length;
  }

  /// Construye un [NoiseProfileReport] real a partir de muestras RMS y offsets DC capturados.
  static NoiseCalibrationOutcome buildNoiseCalibrationOutcome({
    required List<double> capturedRmsSamples,
    required List<double> capturedDcOffsets,
    List<double>? fallbackAudioSamples,
  }) {
    double sumRms = 0.0;
    double maxRms = 0.0;
    for (final rms in capturedRmsSamples) {
      sumRms += rms;
      if (rms > maxRms) {
        maxRms = rms;
      }
    }

    final double meanRms = capturedRmsSamples.isNotEmpty
        ? (sumRms / capturedRmsSamples.length)
        : fallbackMeanRms;

    final double recommendedGate = (meanRms * recommendedGateMultiplier).clamp(
      minNoiseGateThreshold,
      maxNoiseGateThreshold,
    );

    final double detectedDcOffset;
    if (capturedDcOffsets.isNotEmpty) {
      double sumDc = 0.0;
      for (final dc in capturedDcOffsets) {
        sumDc += dc;
      }
      detectedDcOffset = sumDc / capturedDcOffsets.length;
    } else {
      detectedDcOffset = computeDcOffset(fallbackAudioSamples);
    }

    final report = NoiseProfileReport(
      meanRms: meanRms,
      peakRms: maxRms,
      recommendedNoiseGate: recommendedGate,
      detectedDcOffset: detectedDcOffset,
      totalFramesAnalyzed: capturedRmsSamples.length,
    );

    return NoiseCalibrationOutcome(
      report: report,
      recommendedNoiseGate: recommendedGate,
      measuredNoiseFloorRms: meanRms,
    );
  }

  /// Ejecuta la calibración del piso de ruido ambiental y mide el DC offset real de señal.
  ///
  /// Garantiza restauración de callbacks en `finally` y aborta sin mutaciones si [isDisposed]
  /// se vuelve verdadero durante la espera asíncrona.
  Future<NoiseCalibrationOutcome?> calibrateAmbientNoiseFloor({
    required IPitchDetectorService pitchService,
    required bool wasRecording,
    required bool Function() isDisposed,
    required List<double>? Function() latestSamplesProvider,
    Duration calibrationDuration = const Duration(milliseconds: 1600),
  }) async {
    final capturedRmsSamples = <double>[];
    final capturedDcOffsets = <double>[];

    final prevRmsCallback = pitchService.onRmsLevelChanged;
    final prevWindowCallback = pitchService.onAudioWindowCaptured;

    pitchService.onRmsLevelChanged = (rms) {
      capturedRmsSamples.add(rms);
      prevRmsCallback?.call(rms);
    };

    pitchService.onAudioWindowCaptured = (window) {
      if (window.isNotEmpty) {
        capturedDcOffsets.add(computeDcOffset(window));
      }
      prevWindowCallback?.call(window);
    };

    try {
      if (!wasRecording) {
        await pitchService.startRecording();
      }

      await Future<void>.delayed(calibrationDuration);

      if (isDisposed()) {
        return null;
      }

      return buildNoiseCalibrationOutcome(
        capturedRmsSamples: capturedRmsSamples,
        capturedDcOffsets: capturedDcOffsets,
        fallbackAudioSamples: latestSamplesProvider(),
      );
    } finally {
      if (!wasRecording) {
        await pitchService.stopRecording();
      }
      pitchService.onRmsLevelChanged = prevRmsCallback;
      pitchService.onAudioWindowCaptured = prevWindowCallback;
    }
  }

  /// Sintetiza el búfer WAV del dron armónico según la configuración, referencia A4
  /// y temperamento activo, e inicia su bucle continuo en [audioSynthesizer].
  Future<void> refreshDronePlayback({
    required HarmonicDroneSynthesizer droneSynthesizer,
    required IAudioSynthesizerService audioSynthesizer,
    required HarmonicDroneConfig config,
    required double a4Ref,
    required MusicalTemperament temperament,
    required int temperamentRootKey,
  }) async {
    final buffer = droneSynthesizer.generateDroneWavBuffer(
      config: config,
      a4Ref: a4Ref,
      temperament: temperament,
      temperamentRootKey: temperamentRootKey,
    );
    await audioSynthesizer.startDroneLoop(buffer, volume: config.volume);
  }

  /// Construye la configuración de dron para un paso de calentamiento en círculo de quintas.
  static HarmonicDroneConfig buildWarmupStepConfig(
    HarmonicDroneConfig current,
    int rootNoteIndex,
  ) {
    return current.copyWith(
      rootNoteIndex: rootNoteIndex,
      includeFifth: true,
    );
  }

  /// Mapea un [MusicalInterval] al identificador canónico de ítem de repetición espaciada Ebbinghaus.
  static String mapIntervalToEbbinghausId(MusicalInterval interval) {
    switch (interval) {
      case MusicalInterval.minorSecond:
        return 'interval_m2';
      case MusicalInterval.majorSecond:
        return 'interval_M2';
      case MusicalInterval.minorThird:
        return 'interval_m3';
      case MusicalInterval.majorThird:
        return 'interval_M3';
      case MusicalInterval.perfectFourth:
        return 'interval_P4';
      case MusicalInterval.tritone:
        return 'interval_TT';
      case MusicalInterval.perfectFifth:
        return 'interval_P5';
      case MusicalInterval.minorSixth:
        return 'interval_m6';
      case MusicalInterval.majorSixth:
        return 'interval_M6';
      case MusicalInterval.minorSeventh:
        return 'interval_m7';
      case MusicalInterval.majorSeventh:
        return 'interval_M7';
      case MusicalInterval.perfectOctave:
        return 'interval_P8';
      case MusicalInterval.unison:
        return 'interval_P1';
    }
  }
}
