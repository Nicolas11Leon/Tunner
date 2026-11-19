import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:tunner/core/audio/domain/ffi/native_dsp_bridge_fallback.dart';
import 'package:tunner/core/audio/infrastructure/ffi/native_dsp_ffi_bridge.dart';

void main() {
  group('Native C/C++ SIMD vs Fallback Numerical Parity Tests', () {
    late NativeDspFfiBridge nativeBridge;
    const fallbackBridge = NativeDspBridgeFallback();

    setUpAll(() {
      nativeBridge = NativeDspFfiBridge();
    });

    test('Verificacion de disponibilidad del motor nativo compilado', () {
      expect(nativeBridge.isNativeAvailable, isTrue);
      expect(nativeBridge.engineName, contains('Native C/Rust SIMD'));
      expect(nativeBridge.dynamicLibrary, isNotNull);
    });

    test('Paridad numerica estricta en applyGain (Tolerancia < 1e-5)', () {
      // Probar diferentes longitudes: desalineadas (7, 13) y alineadas a 4 (16, 1024)
      for (final length in [1, 4, 7, 16, 255, 1024]) {
        final rawSamples = List<double>.generate(
          length,
          (i) => math.sin(2 * math.pi * i / 44.1) * (i % 2 == 0 ? 1.0 : -0.75),
        );

        final bufferNative = Float32List.fromList(rawSamples);
        final bufferFallback = Float32List.fromList(rawSamples);

        const gain = 0.825;
        nativeBridge.applyGain(bufferNative, gain);
        fallbackBridge.applyGain(bufferFallback, gain);

        for (int i = 0; i < length; i++) {
          expect(
            bufferNative[i],
            closeTo(bufferFallback[i], 1e-5),
            reason: 'Divergencia en applyGain en indice $i con longitud $length',
          );
        }
      }
    });

    test('Paridad numerica estricta en vectorSum (Tolerancia < 1e-5)', () {
      for (final length in [2, 5, 8, 33, 512]) {
        final aRaw = List<double>.generate(length, (i) => math.cos(i * 0.1));
        final bRaw = List<double>.generate(length, (i) => math.sin(i * 0.15));

        final aNative = Float32List.fromList(aRaw);
        final bNative = Float32List.fromList(bRaw);
        final outNative = Float32List(length);

        final aFallback = Float32List.fromList(aRaw);
        final bFallback = Float32List.fromList(bRaw);
        final outFallback = Float32List(length);

        nativeBridge.vectorSum(aNative, bNative, outNative);
        fallbackBridge.vectorSum(aFallback, bFallback, outFallback);

        for (int i = 0; i < length; i++) {
          expect(
            outNative[i],
            closeTo(outFallback[i], 1e-5),
            reason: 'Divergencia en vectorSum en indice $i con longitud $length',
          );
        }
      }
    });

    test('Paridad numerica estricta en autoCorrelate (Tolerancia < 1e-5)', () {
      final inputSamples = List<double>.generate(
        128,
        (i) => math.sin(2 * math.pi * 440.0 * i / 44100.0) + 0.3 * math.cos(2 * math.pi * 880.0 * i / 44100.0),
      );

      final inNative = Float32List.fromList(inputSamples);
      final outNative = Float32List(64);

      final inFallback = Float32List.fromList(inputSamples);
      final outFallback = Float32List(64);

      nativeBridge.autoCorrelate(inNative, outNative);
      fallbackBridge.autoCorrelate(inFallback, outFallback);

      for (int lag = 0; lag < 64; lag++) {
        expect(
          outNative[lag],
          closeTo(outFallback[lag], 1e-5),
          reason: 'Divergencia en autoCorrelate en lag $lag',
        );
      }
    });

    test('autoCorrelate con salida mas larga que entrada no genera desbordamientos', () {
      final inNative = Float32List.fromList([1.0, 2.0, 3.0]);
      final outNative = Float32List(6);

      final inFallback = Float32List.fromList([1.0, 2.0, 3.0]);
      final outFallback = Float32List(6);

      nativeBridge.autoCorrelate(inNative, outNative);
      fallbackBridge.autoCorrelate(inFallback, outFallback);

      for (int lag = 0; lag < 6; lag++) {
        expect(
          outNative[lag],
          closeTo(outFallback[lag], 1e-5),
        );
      }
    });

    test('Resiliencia ante buferes vacios sin excepciones ni caidas de memoria', () {
      final empty = Float32List(0);
      expect(() => nativeBridge.applyGain(empty, 1.5), returnsNormally);
      expect(() => nativeBridge.vectorSum(empty, empty, empty), returnsNormally);
      expect(() => nativeBridge.autoCorrelate(empty, empty), returnsNormally);
    });

    test('Resiliencia ante desalineacion de tamano en vectorSum', () {
      final a = Float32List(4);
      final b = Float32List(8);
      final out = Float32List(4);

      // No debe lanzar segfault ni romper ejecucion
      expect(() => nativeBridge.vectorSum(a, b, out), returnsNormally);
    });
  });
}
