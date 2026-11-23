import 'dart:typed_data';
import 'i_native_dsp_bridge.dart';

/// Implementación de respaldo (fallback) en Dart puro para el motor DSP.
/// Garantiza ejecución determinista y completa en cualquier plataforma sin requerir
/// la precompilación o enlace dinámico de bibliotecas binarias C/Rust.
class NativeDspBridgeFallback implements INativeDspBridge {
  const NativeDspBridgeFallback();

  @override
  bool get isNativeAvailable => false;

  @override
  String get engineName => 'Pure Dart SIMD Fallback';

  @override
  void applyGain(Float32List buffer, double gain) {
    final len = buffer.length;
    // Bucle desenrollado para optimización de caché del procesador
    int i = 0;
    for (; i + 3 < len; i += 4) {
      buffer[i] *= gain;
      buffer[i + 1] *= gain;
      buffer[i + 2] *= gain;
      buffer[i + 3] *= gain;
    }
    for (; i < len; i++) {
      buffer[i] *= gain;
    }
  }

  @override
  void vectorSum(Float32List a, Float32List b, Float32List out) {
    final lenAB = a.length < b.length ? a.length : b.length;
    final len = lenAB < out.length ? lenAB : out.length;
    if (len <= 0) return;

    int i = 0;
    for (; i + 3 < len; i += 4) {
      out[i] = a[i] + b[i];
      out[i + 1] = a[i + 1] + b[i + 1];
      out[i + 2] = a[i + 2] + b[i + 2];
      out[i + 3] = a[i + 3] + b[i + 3];
    }
    for (; i < len; i++) {
      out[i] = a[i] + b[i];
    }
  }

  @override
  void autoCorrelate(Float32List input, Float32List output) {
    final n = input.length;
    final maxLags = output.length;

    for (int lag = 0; lag < maxLags; lag++) {
      double sum = 0.0;
      final limit = n - lag;
      for (int i = 0; i < limit; i++) {
        sum += input[i] * input[i + lag];
      }
      output[lag] = sum;
    }
  }
}
