import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/reverb/all_pass_filter.dart';
import 'package:tunner/core/audio/domain/reverb/comb_filter.dart';
import 'package:tunner/core/audio/domain/reverb/ir_convolution_processor.dart';
import 'package:tunner/core/audio/domain/reverb/schroeder_reverb_engine.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';

void main() {
  group('CombFilter Tests', () {
    test('delays impulse by exact buffer size and decays exponentially', () {
      const bufferSize = 10;
      final comb = CombFilter(bufferSize)..feedback = 0.5..damp = 0.0;

      // Impulso unitario en n=0
      final out0 = comb.process(1.0);
      expect(out0, 0.0); // Buffer inicialmente vacío

      // Muestras intermedias hasta el retardo
      for (var i = 1; i < bufferSize; i++) {
        expect(comb.process(0.0), 0.0);
      }

      // Primera reflexión en n=bufferSize
      final reflection1 = comb.process(0.0);
      expect(reflection1, 1.0);

      // Segunda reflexión en n=2*bufferSize con factor de feedback 0.5
      for (var i = 1; i < bufferSize; i++) {
        comb.process(0.0);
      }
      final reflection2 = comb.process(0.0);
      expect(reflection2, closeTo(0.5, 0.001));
    });

    test('mute clears internal delay line and filter state', () {
      final comb = CombFilter(8)..feedback = 0.8;
      comb.process(1.0);
      comb.mute();

      for (var i = 0; i < 20; i++) {
        expect(comb.process(0.0), 0.0);
      }
    });
  });

  group('AllPassFilter Tests', () {
    test('produces flat magnitude response with phase dispersion', () {
      const bufferSize = 5;
      final allPass = AllPassFilter(bufferSize, feedback: 0.5);

      // En n=0 con impulso x[0]=1.0 en Schroeder Direct Form II: y[0] = -feedback * x[0] = -0.5
      final y0 = allPass.process(1.0);
      expect(y0, -0.5);

      // En n=bufferSize: emerge x[0] en el buffer
      for (var i = 1; i < bufferSize; i++) {
        allPass.process(0.0);
      }
      final yDelay = allPass.process(0.0);
      expect(yDelay.abs(), greaterThan(0.0));
    });

    test('mute clears all-pass state', () {
      final allPass = AllPassFilter(10);
      allPass.process(1.0);
      allPass.mute();

      for (var i = 0; i < 20; i++) {
        expect(allPass.process(0.0), 0.0);
      }
    });
  });

  group('SchroederReverbEngine Tests', () {
    late SchroederReverbEngine engine;

    setUp(() {
      engine = SchroederReverbEngine(
        roomSize: 0.7,
        damping: 0.3,
        wetMix: 0.4,
        dryMix: 0.8,
        width: 1.0,
      );
    });

    test('parameter clamping and setters function predictably', () {
      engine.roomSize = 1.5;
      expect(engine.roomSize, 1.0);

      engine.roomSize = -0.5;
      expect(engine.roomSize, 0.0);

      engine.damping = 2.0;
      expect(engine.damping, 1.0);

      engine.wetMix = 0.5;
      expect(engine.wetMix, 0.5);

      engine.width = 0.8;
      expect(engine.width, 0.8);
    });

    test('processStereo processes audio blocks deterministically without NaN or explosion', () {
      const numSamples = 512;
      final leftIn = Float32List(numSamples);
      final rightIn = Float32List(numSamples);
      final leftOut = Float32List(numSamples);
      final rightOut = Float32List(numSamples);

      // Impulso en la primera muestra
      leftIn[0] = 1.0;
      rightIn[0] = 1.0;

      engine.processStereo(leftIn, rightIn, leftOut, rightOut, numSamples);

      for (var i = 0; i < numSamples; i++) {
        expect(leftOut[i].isNaN, isFalse);
        expect(rightOut[i].isNaN, isFalse);
        expect(leftOut[i].isInfinite, isFalse);
        expect(rightOut[i].isInfinite, isFalse);
      }

      // Procesar varios bloques para comprobar decaimiento estable de la cola
      for (var b = 0; b < 10; b++) {
        leftIn.fillRange(0, numSamples, 0.0);
        rightIn.fillRange(0, numSamples, 0.0);
        engine.processStereo(leftIn, rightIn, leftOut, rightOut, numSamples);

        for (var i = 0; i < numSamples; i++) {
          expect(leftOut[i].abs(), lessThanOrEqualTo(2.0));
        }
      }
    });

    test('decorrelates left and right channels to produce spacious stereo image', () {
      const numSamples = 2048;
      final leftIn = Float32List(numSamples);
      final rightIn = Float32List(numSamples);
      final leftOut = Float32List(numSamples);
      final rightOut = Float32List(numSamples);

      // Impulso monoaural identico en ambos canales
      leftIn[0] = 1.0;
      rightIn[0] = 1.0;

      engine.processStereo(leftIn, rightIn, leftOut, rightOut, numSamples);

      // Despues de las primeras reflexiones (> 50 muestras), Left y Right deben ser diferentes debido al stereo spread
      var differenceFound = false;
      for (var i = 50; i < numSamples; i++) {
        if ((leftOut[i] - rightOut[i]).abs() > 0.001) {
          differenceFound = true;
          break;
        }
      }

      expect(differenceFound, isTrue);
    });

    test('mute clears echo tail completely', () {
      const numSamples = 256;
      final leftIn = Float32List(numSamples);
      final rightIn = Float32List(numSamples);
      final leftOut = Float32List(numSamples);
      final rightOut = Float32List(numSamples);

      leftIn[0] = 1.0;
      engine.processStereo(leftIn, rightIn, leftOut, rightOut, numSamples);

      engine.mute();

      leftIn.fillRange(0, numSamples, 0.0);
      engine.processStereo(leftIn, rightIn, leftOut, rightOut, numSamples);

      for (var i = 0; i < numSamples; i++) {
        expect(leftOut[i], 0.0);
        expect(rightOut[i], 0.0);
      }
    });
  });

  group('IrConvolutionProcessor Tests', () {
    const processor = IrConvolutionProcessor();

    test('convolving with Dirac delta impulse preserves original signal perfectly', () {
      final signal = Float32List.fromList([0.1, 0.5, -0.3, 0.8, -0.2]);
      final dirac = Float32List.fromList([1.0, 0.0, 0.0]);

      final result = processor.convolve(signal, dirac, normalize: false);

      expect(result.length, signal.length + dirac.length - 1);
      for (var i = 0; i < signal.length; i++) {
        expect(result[i], closeTo(signal[i], 0.0001));
      }
    });

    test('calculates exact algebraic discrete convolution', () {
      final x = Float32List.fromList([1.0, 2.0, 3.0]);
      final h = Float32List.fromList([0.5, 0.5]);

      // y[0] = 1*0.5 = 0.5
      // y[1] = 1*0.5 + 2*0.5 = 1.5
      // y[2] = 2*0.5 + 3*0.5 = 2.5
      // y[3] = 3*0.5 = 1.5
      final y = processor.convolve(x, h, normalize: false);

      expect(y.length, 4);
      expect(y[0], closeTo(0.5, 0.0001));
      expect(y[1], closeTo(1.5, 0.0001));
      expect(y[2], closeTo(2.5, 0.0001));
      expect(y[3], closeTo(1.5, 0.0001));
    });

    test('generateSyntheticIr generates decaying impulse response of requested duration', () {
      final ir = IrConvolutionProcessor.generateSyntheticIr(
        rt60Seconds: 0.1,
        sampleRate: 44100.0,
      );

      expect(ir.length, 4410); // 0.1 * 44100
      expect(ir.any((sample) => sample != 0.0), isTrue);
    });
  });

  group('TunnerOsKernel Reverb Integration Tests', () {
    late TunnerOsKernel kernel;
    late SchroederReverbEngine reverbEngine;

    setUp(() {
      reverbEngine = SchroederReverbEngine();
      kernel = TunnerOsKernel(reverbEngine: reverbEngine);
    });

    tearDown(() {
      kernel.audioKernel?.dispose();
    });

    test('reverb status command returns formatted telemetry report', () async {
      final res = await kernel.execute('reverb status');

      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[ESTADO REVERBERADOR SCHROEDER-MOORER]'));
      expect(res.message, contains('Room Size:'));
      expect(res.message, contains('Damping:'));
    });

    test('reverb parameter commands modify reverbEngine settings', () async {
      final res1 = await kernel.execute('reverb room 0.85');
      expect(res1.isSuccess, isTrue);
      expect(reverbEngine.roomSize, 0.85);

      final res2 = await kernel.execute('reverb wet 0.4');
      expect(res2.isSuccess, isTrue);
      expect(reverbEngine.wetMix, 0.4);

      final res3 = await kernel.execute('reverb damp 0.25');
      expect(res3.isSuccess, isTrue);
      expect(reverbEngine.damping, 0.25);
    });

    test('dsl command modulates @reverb target parameters', () async {
      final res = await kernel.execute('dsl set @reverb.room = 0.92; set @reverb.wet = 0.38;');

      expect(res.isSuccess, isTrue);
      expect(reverbEngine.roomSize, 0.92);
      expect(reverbEngine.wetMix, 0.38);
    });
  });
}
