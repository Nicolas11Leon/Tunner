import 'dart:typed_data';

/// Contrato formal de dominio para la pasarela de procesamiento digital de señales (DSP)
/// acelerado por hardware mediante bibliotecas nativas C/C++/Rust o fallback en Dart puro.
abstract class INativeDspBridge {
  /// Indica si la biblioteca nativa C/Rust está cargada y activa en el sistema.
  bool get isNativeAvailable;

  /// Nombre descriptivo del motor de ejecución activo ('Native C/Rust SIMD' o 'Pure Dart SIMD Fallback').
  String get engineName;

  /// Aplica una ganancia escalar continua sobre un búfer de audio en bloque.
  void applyGain(Float32List buffer, double gain);

  /// Realiza la suma vectorial en bloque de dos señales de entrada (mezcla digital):
  /// [out] = [a] + [b]
  void vectorSum(Float32List a, Float32List b, Float32List out);

  /// Calcula la autocorrelación normalizada de una señal de entrada para estimación
  /// de periodo fundamental o análisis de fase:
  /// r[k] = sum_{n} x[n] * x[n + k]
  void autoCorrelate(Float32List input, Float32List output);
}
