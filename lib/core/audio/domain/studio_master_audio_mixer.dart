import 'dart:math' as math;

/// Estructura inmutable con mediciones balísticas estéreo en decibelios y amplitud RMS.
class StudioStereoLevelMeterData {
  final double leftRms;
  final double rightRms;
  final double leftPeakDb;
  final double rightPeakDb;
  final bool isClipping;

  const StudioStereoLevelMeterData({
    this.leftRms = 0.0,
    this.rightRms = 0.0,
    this.leftPeakDb = -96.0,
    this.rightPeakDb = -96.0,
    this.isClipping = false,
  });

  /// Instancia en silencio absoluto.
  static const zero = StudioStereoLevelMeterData();
}

/// Procesador matemático del bus maestro y mezclador de audio de Tunner Studio.
/// Realiza conversión de decibelios, cálculo de valor eficaz (RMS), limitación suave
/// anti-distorsión armónica digital y colapso de fase monoaural.
class StudioMasterAudioMixer {
  /// Umbral en decibelios a partir del cual se enciende la alarma de saturación (*clipping*).
  static const double clippingThresholdDb = -0.1;

  /// Conversión de ganancia lineal $x$ a decibelios (dBFS):
  ///
  /// $$\text{dB} = 20 \log_{10}(\max(x, 10^{-5}))$$
  static double dbFromLinearGain(double linearGain) {
    if (linearGain <= 0.00001) return -96.0;
    return 20.0 * (math.log(linearGain) / math.ln10);
  }

  /// Conversión de decibelios (dBFS) a factor de escala de ganancia lineal:
  ///
  /// $$\text{Ganancia Lineal} = 10^{\frac{\text{dB}}{20}}$$
  static double linearGainFromDb(double db) {
    if (db <= -96.0) return 0.0;
    return math.pow(10.0, db / 20.0).toDouble();
  }

  /// Calcula el valor cuadrático medio (RMS) de un bloque de muestras de audio:
  ///
  /// $$\text{RMS} = \sqrt{\frac{1}{N} \sum_{i=1}^N x_i^2}$$
  static double calculateRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      sumSquares += s * s;
    }
    return math.sqrt(sumSquares / samples.length);
  }

  /// Detecta el pico de amplitud absoluto de un bloque de muestras de audio.
  static double calculatePeak(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double peak = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final abs = samples[i].abs();
      if (abs > peak) peak = abs;
    }
    return peak;
  }

  /// Limitador suave (*soft-clipper limiter*) de función tangencial para prevenir
  /// distorsión digital abrasiva por recorte de onda (*hard clipping*) en sobrecargas:
  ///
  /// $$f(x) = \tanh(x)$$
  static double applySoftClipper(double sample) {
    if (sample > 3.0) return 1.0;
    if (sample < -3.0) return -1.0;
    // Aproximación numérica rápida de tanh(x) = (e^2x - 1) / (e^2x + 1)
    final exp2x = math.exp(2.0 * sample);
    return (exp2x - 1.0) / (exp2x + 1.0);
  }

  /// Procesa y mezcla un par de muestras estéreo $(L, R)$ aplicando ganancia maestra,
  /// modificadores DIM, MUTE, suma MONO y limitador suave.
  static (double, double) processStereoFrame({
    required double leftSample,
    required double rightSample,
    required double effectiveGain,
    required bool isMono,
  }) {
    // Si la ganancia es prácticamente nula, retorno instantáneo
    if (effectiveGain <= 0.0001) return (0.0, 0.0);

    // Suma mono para comprobación de fase si está activado
    double l = isMono ? (leftSample + rightSample) * 0.5 : leftSample;
    double r = isMono ? (leftSample + rightSample) * 0.5 : rightSample;

    // Aplicar ganancia maestra
    l *= effectiveGain;
    r *= effectiveGain;

    // Limitador suave si excede rango dinámico unitario
    if (l.abs() > 0.95) l = applySoftClipper(l);
    if (r.abs() > 0.95) r = applySoftClipper(r);

    return (l.clamp(-1.0, 1.0), r.clamp(-1.0, 1.0));
  }

  /// Calcula las métricas balísticas estéreo completas (RMS, Peak dB, Clipping)
  /// a partir de búferes de audio PCM izquierdo y derecho.
  static StudioStereoLevelMeterData analyzeStereoBuffers({
    required List<double> leftSamples,
    required List<double> rightSamples,
  }) {
    if (leftSamples.isEmpty && rightSamples.isEmpty) {
      return StudioStereoLevelMeterData.zero;
    }

    final lRms = calculateRms(leftSamples);
    final rRms = calculateRms(rightSamples);
    final lPeak = calculatePeak(leftSamples);
    final rPeak = calculatePeak(rightSamples);

    final lPeakDb = dbFromLinearGain(lPeak);
    final rPeakDb = dbFromLinearGain(rPeak);

    final isClipping = lPeakDb >= clippingThresholdDb || rPeakDb >= clippingThresholdDb;

    return StudioStereoLevelMeterData(
      leftRms: lRms,
      rightRms: rRms,
      leftPeakDb: lPeakDb,
      rightPeakDb: rPeakDb,
      isClipping: isClipping,
    );
  }
}
