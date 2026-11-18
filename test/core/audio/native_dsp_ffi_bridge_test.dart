import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:tunner/core/audio/domain/ffi/native_dsp_bridge_fallback.dart';
import 'package:tunner/core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';
import 'package:tunner/core/terminal/domain/tunner_os_kernel.dart';

void main() {
  group('NativeDspBridgeFallback Unit Tests', () {
    const fallback = NativeDspBridgeFallback();

    test('Propiedades de estado y metadatos', () {
      expect(fallback.isNativeAvailable, isFalse);
      expect(fallback.engineName, equals('Pure Dart SIMD Fallback'));
    });

    test('applyGain modula correctamente el buffer de audio', () {
      final buffer = Float32List.fromList([1.0, -0.5, 0.25, 0.0, 2.0, -1.0]);
      fallback.applyGain(buffer, 0.5);

      expect(buffer[0], closeTo(0.5, 1e-6));
      expect(buffer[1], closeTo(-0.25, 1e-6));
      expect(buffer[2], closeTo(0.125, 1e-6));
      expect(buffer[3], closeTo(0.0, 1e-6));
      expect(buffer[4], closeTo(1.0, 1e-6));
      expect(buffer[5], closeTo(-0.5, 1e-6));
    });

    test('vectorSum suma dos senales punto a punto', () {
      final a = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]);
      final b = Float32List.fromList([0.9, 0.8, 0.7, 0.6, 0.5]);
      final out = Float32List(5);

      fallback.vectorSum(a, b, out);

      for (int i = 0; i < 5; i++) {
        expect(out[i], closeTo(1.0, 1e-6));
      }
    });

    test('autoCorrelate calcula los lags temporales de la senal', () {
      // Senal unitaria constante
      final input = Float32List.fromList([1.0, 1.0, 1.0, 1.0]);
      final output = Float32List(3);

      fallback.autoCorrelate(input, output);

      // Lag 0: 1*1 + 1*1 + 1*1 + 1*1 = 4.0
      expect(output[0], closeTo(4.0, 1e-6));
      // Lag 1: 1*1 + 1*1 + 1*1 = 3.0
      expect(output[1], closeTo(3.0, 1e-6));
      // Lag 2: 1*1 + 1*1 = 2.0
      expect(output[2], closeTo(2.0, 1e-6));
    });
  });

  group('NativeDspFfiBridge Resilient Lifecycle Tests', () {
    test('Inicializacion segura sin biblioteca binaria conmuta a fallback sin excepciones', () {
      final bridge = NativeDspFfiBridge(customLibraryPath: 'non_existent_library.so');

      expect(bridge.isNativeAvailable, isFalse);
      expect(bridge.engineName, contains('Pure Dart SIMD Fallback'));

      final buffer = Float32List.fromList([1.0, 2.0, 3.0]);
      bridge.applyGain(buffer, 2.0);
      expect(buffer[0], equals(2.0));
      expect(buffer[1], equals(4.0));
      expect(buffer[2], equals(6.0));
    });
  });

  group('TunnerOsKernel DSP CLI Integration Tests', () {
    test('dsp status incluye informacion del acelerador nativo FFI', () async {
      final kernel = TunnerOsKernel();
      final res = await kernel.execute('dsp status');

      expect(res.isSuccess, isTrue);
      expect(res.message, contains('ESTADO DEL MOTOR DSP CORE (TUNNER STUDIO):'));
      expect(res.message, contains('Acelerador Nativo FFI'));
      expect(res.message, contains('Pure Dart SIMD Fallback'));
    });
  });
}
