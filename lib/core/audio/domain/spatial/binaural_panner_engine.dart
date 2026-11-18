import 'dart:math' as math;
import 'dart:typed_data';

import 'binaural_panner_entity.dart';
export 'binaural_panner_entity.dart';

/// Motor de espacialización binaural 3D en Dart puro.
/// Implementa el modelo de retardo esférico de Woodworth para diferencias interaurales
/// de tiempo (ITD) y filtros IIR de sombra craneal para diferencias interaurales de nivel (ILD).
class BinauralPannerEngine {
  static const int _delayBufferSize = 128;
  static const int _delayBufferMask = _delayBufferSize - 1;

  final double sampleRate;

  BinauralPannerEntity _coordinates;

  // Búferes circulares para retardo fraccionario ITD
  final Float32List _leftDelayBuffer = Float32List(_delayBufferSize);
  final Float32List _rightDelayBuffer = Float32List(_delayBufferSize);
  int _writeIndex = 0;

  // Estados de filtros IIR de 1 polo para sombra craneal ILD
  double _leftFilterState = 0.0;
  double _rightFilterState = 0.0;

  // Parámetros calculados en caché
  double _leftDelaySamples = 0.0;
  double _rightDelaySamples = 0.0;
  double _leftFilterAlpha = 0.0;
  double _rightFilterAlpha = 0.0;
  double _leftGain = 1.0;
  double _rightGain = 1.0;
  double _distanceGain = 1.0;

  /// Constructor con frecuencia de muestreo y coordenadas iniciales opcionales.
  BinauralPannerEngine({
    this.sampleRate = 44100.0,
    BinauralPannerEntity? initialCoordinates,
  }) : _coordinates = initialCoordinates ?? const BinauralPannerEntity() {
    _updateInternalParameters();
  }

  /// Coordenadas espaciales actuales.
  BinauralPannerEntity get coordinates => _coordinates;

  /// Actualiza las coordenadas espaciales y recalcula los coeficientes acústicos.
  set coordinates(BinauralPannerEntity value) {
    if (_coordinates != value) {
      _coordinates = value;
      _updateInternalParameters();
    }
  }

  /// Retardo ITD calculado para el oído izquierdo (en milisegundos).
  double get leftDelayMs => (_leftDelaySamples / sampleRate) * 1000.0;

  /// Retardo ITD calculado para el oído derecho (en milisegundos).
  double get rightDelayMs => (_rightDelaySamples / sampleRate) * 1000.0;

  /// Diferencia interaural temporal ITD neta (en milisegundos).
  double get itdMs => ((_leftDelaySamples - _rightDelaySamples) / sampleRate) * 1000.0;

  /// Ganancia de distancia aplicada actualmente.
  double get distanceGain => _distanceGain;

  /// Configura el ángulo azimutal en grados [-180.0, 180.0].
  void setAzimuth(double azimuthDegrees) {
    coordinates = coordinates.copyWith(
      azimuthDegrees: azimuthDegrees.clamp(-180.0, 180.0),
    );
  }

  /// Configura el ángulo de elevación en grados [-90.0, 90.0].
  void setElevation(double elevationDegrees) {
    coordinates = coordinates.copyWith(
      elevationDegrees: elevationDegrees.clamp(-90.0, 90.0),
    );
  }

  /// Configura la distancia en metros (> 0.0).
  void setDistance(double distanceMeters) {
    if (distanceMeters <= 0.0) return;
    coordinates = coordinates.copyWith(distanceMeters: distanceMeters);
  }

  /// Recalcula coeficientes de ITD de Woodworth, filtros ILD y ley de distancia.
  void _updateInternalParameters() {
    final theta = _coordinates.azimuthRadians; // -pi a pi
    final absTheta = theta.abs();
    final r = _coordinates.headRadiusMeters;
    final c = _coordinates.speedOfSoundMps;

    // 1. Modelo de Woodworth para retardo ITD sobre cabeza esférica:
    // deltaT = (r / c) * (sin(theta') + theta')
    double effectiveAngle;
    if (absTheta <= (math.pi / 2.0)) {
      effectiveAngle = absTheta;
    } else {
      effectiveAngle = math.pi - absTheta;
    }

    final double maxDelaySeconds = (r / c) * (math.sin(effectiveAngle) + effectiveAngle);
    final double maxDelaySamples = maxDelaySeconds * sampleRate;

    // Si theta > 0 (fuente a la derecha): oído izquierdo se retrasa
    // Si theta < 0 (fuente a la izquierda): oído derecho se retrasa
    if (theta > 0.0) {
      _leftDelaySamples = maxDelaySamples;
      _rightDelaySamples = 0.0;
    } else if (theta < 0.0) {
      _leftDelaySamples = 0.0;
      _rightDelaySamples = maxDelaySamples;
    } else {
      _leftDelaySamples = 0.0;
      _rightDelaySamples = 0.0;
    }

    // 2. Modelo de sombra craneal (Head Shadow ILD):
    // El oído contralateral sufre atenuación paso-bajo y pérdida de amplitud
    const double fMin = 1500.0;
    const double fMax = 18000.0;
    final double cutoffFrequency = fMin + (fMax - fMin) * ((1.0 + math.cos(absTheta)) / 2.0);

    // alpha = exp(-2 * pi * fc / fs)
    final double shadowAlpha = math.exp(-2.0 * math.pi * cutoffFrequency / sampleRate);

    // Elevación: elevación positiva mantiene brillo, elevación negativa incrementa sombra
    final double elevationFactor = 1.0 + 0.15 * math.sin(_coordinates.elevationRadians);

    if (theta > 0.0) {
      // Oído derecho es ipsilateral (abierto), izquierdo contralateral (sombra)
      _rightFilterAlpha = 0.0; // Pasa directo sin filtro
      _leftFilterAlpha = shadowAlpha;
      _rightGain = 1.0 * elevationFactor;
      _leftGain = (1.0 - 0.4 * math.sin(absTheta)) * elevationFactor;
    } else if (theta < 0.0) {
      // Oído izquierdo es ipsilateral (abierto), derecho contralateral (sombra)
      _leftFilterAlpha = 0.0;
      _rightFilterAlpha = shadowAlpha;
      _leftGain = 1.0 * elevationFactor;
      _rightGain = (1.0 - 0.4 * math.sin(absTheta)) * elevationFactor;
    } else {
      // Centro exacto
      _leftFilterAlpha = 0.0;
      _rightFilterAlpha = 0.0;
      _leftGain = 1.0 * elevationFactor;
      _rightGain = 1.0 * elevationFactor;
    }

    // 3. Atenuación por distancia (ley inversa clamped)
    const double refDistance = 1.0;
    if (_coordinates.distanceMeters <= refDistance) {
      _distanceGain = 1.0;
    } else {
      _distanceGain = refDistance / _coordinates.distanceMeters;
    }
  }

  /// Lee una muestra con retardo fraccionario e interpolación lineal de un búfer circular.
  double _readFractionalDelay(Float32List buffer, double delaySamples) {
    final int delayInt = delaySamples.floor();
    final double frac = delaySamples - delayInt;

    final int idxA = (_writeIndex - 1 - delayInt) & _delayBufferMask;
    final int idxB = (_writeIndex - 2 - delayInt) & _delayBufferMask;

    final double sampleA = buffer[idxA];
    final double sampleB = buffer[idxB];

    return sampleA + frac * (sampleB - sampleA);
  }

  /// Procesa una única muestra de entrada monofónica produciendo un par estéreo [left, right].
  void processSample(double input, Float32List stereoOut) {
    // Escribir en búferes de retardo
    _leftDelayBuffer[_writeIndex] = input;
    _rightDelayBuffer[_writeIndex] = input;
    _writeIndex = (_writeIndex + 1) & _delayBufferMask;

    // Leer con ITD fraccionario
    double leftDelayed = _readFractionalDelay(_leftDelayBuffer, _leftDelaySamples);
    double rightDelayed = _readFractionalDelay(_rightDelayBuffer, _rightDelaySamples);

    // Aplicar filtro de sombra craneal ILD (1-pole IIR low-pass)
    if (_leftFilterAlpha > 0.0) {
      _leftFilterState = (1.0 - _leftFilterAlpha) * leftDelayed + _leftFilterAlpha * _leftFilterState;
      leftDelayed = _leftFilterState;
    }
    if (_rightFilterAlpha > 0.0) {
      _rightFilterState = (1.0 - _rightFilterAlpha) * rightDelayed + _rightFilterAlpha * _rightFilterState;
      rightDelayed = _rightFilterState;
    }

    // Aplicar ganancias de canal y de distancia
    stereoOut[0] = leftDelayed * _leftGain * _distanceGain;
    stereoOut[1] = rightDelayed * _rightGain * _distanceGain;
  }

  /// Procesa un búfer monofónico de entrada generando salida estéreo en [leftOut] y [rightOut].
  void processMonoToStereo(
    Float32List monoIn,
    Float32List leftOut,
    Float32List rightOut,
    int numSamples,
  ) {
    final pair = Float32List(2);
    for (int i = 0; i < numSamples; i++) {
      processSample(monoIn[i], pair);
      leftOut[i] = pair[0];
      rightOut[i] = pair[1];
    }
  }

  /// Procesa un búfer estéreo de entrada combinándolo espacialmente en los canales de salida.
  void processStereo(
    Float32List leftIn,
    Float32List rightIn,
    Float32List leftOut,
    Float32List rightOut,
    int numSamples,
  ) {
    final pair = Float32List(2);
    for (int i = 0; i < numSamples; i++) {
      // Suma monoaural como fuente espacial coherente
      final double mono = 0.5 * (leftIn[i] + rightIn[i]);
      processSample(mono, pair);
      leftOut[i] = pair[0];
      rightOut[i] = pair[1];
    }
  }

  /// Reinicia el historial de retardos y los estados de los filtros a silencio.
  void reset() {
    _leftDelayBuffer.fillRange(0, _delayBufferSize, 0.0);
    _rightDelayBuffer.fillRange(0, _delayBufferSize, 0.0);
    _writeIndex = 0;
    _leftFilterState = 0.0;
    _rightFilterState = 0.0;
  }
}
