import 'dart:math' as math;
import 'studio_master_audio_mixer.dart';

/// Procesador dinámico de grado estudio que implementa un Compresor/Limitador de Pico
/// con detección de envolvente simétrica y medición de Reducción de Ganancia (GR).
class StudioMasterDynamicsProcessor {
  final double thresholdDb;
  final double ratio;
  final double attackMs;
  final double releaseMs;
  final double makeupGainDb;
  final int sampleRate;

  // Coeficientes de envolvente
  late double _alphaAttack;
  late double _alphaRelease;
  late double _makeupLinear;

  // Estado del detector de envolvente
  double _envelope = 0.0;
  double _currentGainReductionDb = 0.0;

  StudioMasterDynamicsProcessor({
    this.thresholdDb = 0.0,
    this.ratio = 2.0,
    this.attackMs = 10.0,
    this.releaseMs = 100.0,
    this.makeupGainDb = 0.0,
    this.sampleRate = 44100,
  }) {
    _calculateCoefficients();
  }

  void _calculateCoefficients() {
    final attackSamples = (attackMs * 0.001 * sampleRate).clamp(1.0, 100000.0);
    final releaseSamples = (releaseMs * 0.001 * sampleRate).clamp(1.0, 100000.0);

    _alphaAttack = math.exp(-1.0 / attackSamples);
    _alphaRelease = math.exp(-1.0 / releaseSamples);
    _makeupLinear = StudioMasterAudioMixer.linearGainFromDb(makeupGainDb);
  }

  /// Nivel instantáneo de reducción de ganancia expresado en decibelios negativos ($GR \le 0$).
  double get currentGainReductionDb => _currentGainReductionDb;

  /// Procesa una muestra estéreo [xL, xR] y retorna la muestra atenuada dinámicamente [yL, yR].
  (double, double) processStereoSample(double xL, double xR) {
    // 1. Detección de pico lateral máximo L/R
    final peak = math.max(xL.abs(), xR.abs());

    // 2. Filtro seguidor de envolvente de ataque y liberación
    if (peak > _envelope) {
      _envelope = _alphaAttack * _envelope + (1.0 - _alphaAttack) * peak;
    } else {
      _envelope = _alphaRelease * _envelope + (1.0 - _alphaRelease) * peak;
    }

    // 3. Conversión de envolvente a escala logarítmica (dB)
    final envDb = StudioMasterAudioMixer.dbFromLinearGain(_envelope);

    // 4. Curva de compresión por encima del umbral
    if (envDb > thresholdDb && ratio > 1.0) {
      // Diferencia excedente comprimida por el factor de ratio
      final overShootDb = envDb - thresholdDb;
      final compressedOverShootDb = overShootDb / ratio;
      _currentGainReductionDb = compressedOverShootDb - overShootDb; // Valor <= 0 dB
    } else {
      _currentGainReductionDb = 0.0;
    }

    // 5. Aplicación de ganancia dinámica y compensación (Make-up Gain)
    final compLinearGain = StudioMasterAudioMixer.linearGainFromDb(_currentGainReductionDb) * _makeupLinear;

    return (xL * compLinearGain, xR * compLinearGain);
  }

  /// Limpia los estados de memoria interna del detector de envolvente.
  void reset() {
    _envelope = 0.0;
    _currentGainReductionDb = 0.0;
  }
}
