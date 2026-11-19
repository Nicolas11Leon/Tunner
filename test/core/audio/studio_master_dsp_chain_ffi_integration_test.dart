import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:tunner/core/audio/domain/ffi/native_dsp_bridge_fallback.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_dsp_chain.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';

void main() {
  group('StudioMasterDspChain Core Processing Tests', () {
    late StudioMasterDspChain dspChain;

    setUp(() {
      dspChain = StudioMasterDspChain();
    });

    test('Inicializacion exitosa con puente DSP activo', () {
      expect(dspChain.bridge, isNotNull);
      expect(dspChain.bridge.engineName, isNotEmpty);
    });

    test('processMasterBlock modula ganancia estereo en ambos canales', () {
      final left = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final right = Float32List.fromList([0.5, 1.0, 1.5, 2.0]);

      dspChain.processMasterBlock(left, right, masterGain: 0.5);

      expect(left[0], closeTo(0.5, 1e-5));
      expect(left[1], closeTo(1.0, 1e-5));
      expect(left[2], closeTo(1.5, 1e-5));
      expect(left[3], closeTo(2.0, 1e-5));

      expect(right[0], closeTo(0.25, 1e-5));
      expect(right[1], closeTo(0.50, 1e-5));
      expect(right[2], closeTo(0.75, 1e-5));
      expect(right[3], closeTo(1.00, 1e-5));
    });

    test('processMasterBlock con isMuted silencia ambos canales a cero', () {
      final left = Float32List.fromList([0.8, -0.4, 0.2]);
      final right = Float32List.fromList([0.9, -0.5, 0.1]);

      dspChain.processMasterBlock(left, right, isMuted: true);

      for (int i = 0; i < 3; i++) {
        expect(left[i], equals(0.0));
        expect(right[i], equals(0.0));
      }
    });

    test('processMasterBlock con isDimmed aplica factor de atenuacion 0.35', () {
      final left = Float32List.fromList([1.0, 2.0]);
      final right = Float32List.fromList([1.0, 2.0]);

      dspChain.processMasterBlock(left, right, masterGain: 1.0, isDimmed: true);

      expect(left[0], closeTo(0.35, 1e-5));
      expect(left[1], closeTo(0.70, 1e-5));
      expect(right[0], closeTo(0.35, 1e-5));
      expect(right[1], closeTo(0.70, 1e-5));
    });

    test('processMasterBlock con isMono calcula promedio ponderado en ambos canales', () {
      final left = Float32List.fromList([1.0, 0.0, -1.0]);
      final right = Float32List.fromList([0.0, 1.0, -1.0]);

      dspChain.processMasterBlock(left, right, masterGain: 1.0, isMono: true);

      // (1 + 0) * 0.5 = 0.5
      expect(left[0], closeTo(0.5, 1e-5));
      expect(right[0], closeTo(0.5, 1e-5));

      // (0 + 1) * 0.5 = 0.5
      expect(left[1], closeTo(0.5, 1e-5));
      expect(right[1], closeTo(0.5, 1e-5));

      // (-1 + -1) * 0.5 = -1.0
      expect(left[2], closeTo(-1.0, 1e-5));
      expect(right[2], closeTo(-1.0, 1e-5));
    });

    test('mixChannels suma ponderadamente multiples canales de audio (stems)', () {
      final ch1 = Float32List.fromList([0.2, 0.4, 0.6, 0.8]);
      final ch2 = Float32List.fromList([0.1, 0.2, 0.3, 0.4]);
      final ch3 = Float32List.fromList([1.0, 1.0, 1.0, 1.0]);

      final out = Float32List(4);

      // ch1 al 100%, ch2 al 50% (0.05, 0.1, 0.15, 0.2), ch3 al 0% (mute)
      dspChain.mixChannels([ch1, ch2, ch3], [1.0, 0.5, 0.0], out);

      expect(out[0], closeTo(0.2 + 0.05, 1e-5));
      expect(out[1], closeTo(0.4 + 0.10, 1e-5));
      expect(out[2], closeTo(0.6 + 0.15, 1e-5));
      expect(out[3], closeTo(0.8 + 0.20, 1e-5));
    });

    test('computeCorrelations calcula coeficientes de retardo temporal', () {
      final input = Float32List.fromList([1.0, 1.0, 1.0, 1.0]);
      final output = Float32List(3);

      dspChain.computeCorrelations(input, output);

      expect(output[0], closeTo(4.0, 1e-5));
      expect(output[1], closeTo(3.0, 1e-5));
      expect(output[2], closeTo(2.0, 1e-5));
    });

    test('runBenchmark produce metricas cuantitativas validas', () {
      final res = dspChain.runBenchmark(iterations: 50, blockSize: 1024);

      expect(res.engineName, isNotEmpty);
      expect(res.iterations, equals(50));
      expect(res.blockSize, equals(1024));
      expect(res.elapsedMicroseconds, greaterThan(0));
      expect(res.throughputMegaSamplesPerSec, greaterThan(0.0));
      expect(res.toString(), contains('DspBenchmarkResult'));
    });

    test('Resiliencia ante buferes vacios o asimetricos', () {
      final empty = Float32List(0);
      final valid = Float32List(4);

      expect(() => dspChain.processMasterBlock(empty, valid), returnsNormally);
      expect(() => dspChain.mixChannels([], [], empty), returnsNormally);
      expect(() => dspChain.computeCorrelations(empty, empty), returnsNormally);
    });
  });

  group('StudioMasterDspChain Fallback Injection Tests', () {
    test('Cadena funciona de forma transparente con NativeDspBridgeFallback', () {
      const fallback = NativeDspBridgeFallback();
      final chain = StudioMasterDspChain(bridge: fallback);

      expect(chain.bridge.isNativeAvailable, isFalse);
      expect(chain.bridge.engineName, equals('Pure Dart SIMD Fallback'));

      final left = Float32List.fromList([2.0, 4.0]);
      final right = Float32List.fromList([1.0, 2.0]);
      chain.processMasterBlock(left, right, masterGain: 0.5);

      expect(left[0], closeTo(1.0, 1e-5));
      expect(right[0], closeTo(0.5, 1e-5));
    });
  });

  group('TunnerOsKernel dsp bench CLI Tests', () {
    test('dsp bench ejecuta el benchmark y muestra telemetria en consola', () async {
      final kernel = TunnerOsKernel();
      final res = await kernel.execute('dsp bench');

      expect(res.isSuccess, isTrue);
      expect(res.message, contains('BENCHMARK DEL MOTOR DSP (TUNNER STUDIO):'));
      expect(res.message, contains('Motor Activo'));
      expect(res.message, contains('Aceleración Nativa'));
      expect(res.message, contains('Muestras Procesadas'));
      expect(res.message, contains('Tiempo Transcurrido'));
      expect(res.message, contains('Tasa de Rendimiento'));
      expect(res.message, contains('Latencia por Bloque'));
    });

    test('dsp bench acepta argumentos de iteraciones y tamano de bloque', () async {
      final kernel = TunnerOsKernel();
      final res = await kernel.execute('dsp bench 25 512');

      expect(res.isSuccess, isTrue);
      expect(res.message, contains('25 iteraciones x 512 muestras'));
      expect(res.message, contains('25600 muestras')); // 25 * 512 * 2
    });
  });
}
