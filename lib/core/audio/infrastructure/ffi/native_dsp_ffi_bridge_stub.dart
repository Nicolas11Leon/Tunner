import 'dart:typed_data';

import '../../../logging/domain/i_studio_logger.dart';
import '../../domain/ffi/i_native_dsp_bridge.dart';
import '../../domain/ffi/native_dsp_bridge_fallback.dart';

/// Implementacion Pure Dart para entornos sin `dart:ffi` (Web / Wasm).
class NativeDspFfiBridge implements INativeDspBridge {
  final INativeDspBridge _fallback;
  bool _isDisposed = false;

  Object? get dynamicLibrary => null;

  NativeDspFfiBridge({
    INativeDspBridge? fallback,
    String? customLibraryPath,
    IStudioLogger? logger,
  }) : _fallback = fallback ?? const NativeDspBridgeFallback();

  @override
  bool get isNativeAvailable => false;

  @override
  String get engineName => 'Pure Dart SIMD Fallback (Web Environment)';

  @override
  void applyGain(Float32List buffer, double gain) {
    if (_isDisposed || buffer.isEmpty) return;
    _fallback.applyGain(buffer, gain);
  }

  @override
  void vectorSum(Float32List a, Float32List b, Float32List out) {
    if (_isDisposed) return;
    _fallback.vectorSum(a, b, out);
  }

  @override
  void autoCorrelate(Float32List input, Float32List output) {
    if (_isDisposed || input.isEmpty || output.isEmpty) return;
    _fallback.autoCorrelate(input, output);
  }

  void dispose() {
    _isDisposed = true;
  }
}
