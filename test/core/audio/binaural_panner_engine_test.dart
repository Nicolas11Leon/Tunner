import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:tunner/core/audio/domain/spatial/binaural_panner_engine.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';

void main() {
  group('BinauralPannerEntity Tests', () {
    test('Valores por defecto son conformes con el modelo acustico estandar', () {
      const entity = BinauralPannerEntity();
      expect(entity.azimuthDegrees, equals(0.0));
      expect(entity.elevationDegrees, equals(0.0));
      expect(entity.distanceMeters, equals(1.0));
      expect(entity.headRadiusMeters, equals(0.0875));
      expect(entity.speedOfSoundMps, equals(343.0));
      expect(entity.azimuthRadians, equals(0.0));
      expect(entity.elevationRadians, equals(0.0));
    });

    test('Validacion de rangos dispara aserciones en valores fuera de limites', () {
      expect(
        () => BinauralPannerEntity(azimuthDegrees: 181.0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BinauralPannerEntity(azimuthDegrees: -181.0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BinauralPannerEntity(elevationDegrees: 91.0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => BinauralPannerEntity(distanceMeters: 0.0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Inmutabilidad y copyWith operan correctamente', () {
      const entity = BinauralPannerEntity();
      final modified = entity.copyWith(azimuthDegrees: 45.0, distanceMeters: 2.5);

      expect(modified.azimuthDegrees, equals(45.0));
      expect(modified.elevationDegrees, equals(0.0));
      expect(modified.distanceMeters, equals(2.5));
      expect(entity.azimuthDegrees, equals(0.0));
      expect(entity == modified, isFalse);
    });
  });

  group('BinauralPannerEngine Acoustic Tests', () {
    late BinauralPannerEngine engine;

    setUp(() {
      engine = BinauralPannerEngine(sampleRate: 44100.0);
    });

    test('Centro exacto (azimut 0) produce retardo cero y simetria bilateral', () {
      engine.setAzimuth(0.0);

      expect(engine.leftDelayMs, equals(0.0));
      expect(engine.rightDelayMs, equals(0.0));
      expect(engine.itdMs, equals(0.0));

      final out = Float32List(2);
      engine.processSample(1.0, out);
      expect(out[0], closeTo(out[1], 1e-5));
    });

    test('Azimut a +90 grados produce retardo Woodworth acustico maximo en oido contralateral (izquierdo)', () {
      engine.setAzimuth(90.0);

      // En +90 grados, oido derecho no tiene retardo
      expect(engine.rightDelayMs, equals(0.0));

      // Oido izquierdo se retrasa segun modelo de Woodworth:
      // deltaT = (r / c) * (sin(pi/2) + pi/2) = (0.0875 / 343) * (1 + 1.5708) ~= 0.6558 ms
      expect(engine.leftDelayMs, greaterThan(0.6));
      expect(engine.leftDelayMs, lessThan(0.7)); // Conforme con limite fisiologico < 0.7 ms
      expect(engine.itdMs, closeTo(engine.leftDelayMs, 1e-4));
    });

    test('Azimut a -90 grados produce retardo Woodworth maximo en oido derecho', () {
      engine.setAzimuth(-90.0);

      expect(engine.leftDelayMs, equals(0.0));
      expect(engine.rightDelayMs, greaterThan(0.6));
      expect(engine.rightDelayMs, lessThan(0.7));
      expect(engine.itdMs, closeTo(-engine.rightDelayMs, 1e-4));
    });

    test('Atenuacion por distancia obedece la ley inversa', () {
      engine.setDistance(1.0);
      expect(engine.distanceGain, equals(1.0));

      engine.setDistance(2.0);
      expect(engine.distanceGain, closeTo(0.5, 1e-5));

      engine.setDistance(4.0);
      expect(engine.distanceGain, closeTo(0.25, 1e-5));

      // Distancia menor a 1 metro se limita a 1.0 para evitar distorsion
      engine.setDistance(0.5);
      expect(engine.distanceGain, equals(1.0));
    });

    test('Procesamiento de impulso verifica retardo temporal relativo', () {
      engine.setAzimuth(90.0); // Fuente a la derecha

      const int sampleCount = 64;
      final monoIn = Float32List(sampleCount);
      monoIn[0] = 1.0; // Impulso unitario

      final leftOut = Float32List(sampleCount);
      final rightOut = Float32List(sampleCount);

      engine.processMonoToStereo(monoIn, leftOut, rightOut, sampleCount);

      // En el canal derecho (ipsilateral), el impulso llega de inmediato en muestra 0
      expect(rightOut[0], greaterThan(0.5));

      // En el canal izquierdo (contralateral retrasado ~29 muestras), muestra 0 es silencio o cercana a cero
      expect(leftOut[0], closeTo(0.0, 1e-5));

      // El pico en el canal izquierdo debe aparecer alrededor de la muestra 28 o 29
      int leftPeakIndex = 0;
      double maxLeftVal = 0.0;
      for (int i = 0; i < sampleCount; i++) {
        if (leftOut[i].abs() > maxLeftVal) {
          maxLeftVal = leftOut[i].abs();
          leftPeakIndex = i;
        }
      }
      expect(leftPeakIndex, inInclusiveRange(27, 30));
    });

    test('Procesamiento estereo y reset de lineas de retardo', () {
      final leftIn = Float32List.fromList([0.5, 0.4, 0.3]);
      final rightIn = Float32List.fromList([0.5, 0.4, 0.3]);
      final leftOut = Float32List(3);
      final rightOut = Float32List(3);

      engine.processStereo(leftIn, rightIn, leftOut, rightOut, 3);
      expect(leftOut[0], isNot(isNaN));
      expect(rightOut[0], isNot(isNaN));

      engine.reset();
      final stereoOut = Float32List(2);
      engine.processSample(0.0, stereoOut);
      expect(stereoOut[0], equals(0.0));
      expect(stereoOut[1], equals(0.0));
    });
  });

  group('TunnerOsKernel CLI Spatial Commands Tests', () {
    late TunnerOsKernel kernel;

    setUp(() {
      kernel = TunnerOsKernel();
    });

    test('Comando spatial status reporta telemetria valida', () async {
      final res = await kernel.execute('spatial status');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[MATRIZ DE ESPACIALIZACION BINAURAL 3D'));
      expect(res.message, contains('Azimut: 0.0°'));
      expect(res.message, contains('Distancia: 1.00 m'));
    });

    test('Comando spatial pan modula el azimut y el ITD', () async {
      final res = await kernel.execute('spatial pan 45');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[OK] Azimut fijado en: 45.0°'));
      expect(kernel.spatialEngine!.coordinates.azimuthDegrees, equals(45.0));
    });

    test('Comando spatial elev modula la elevacion', () async {
      final res = await kernel.execute('spatial elev 30');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[OK] Elevacion fijada en: 30.0°'));
      expect(kernel.spatialEngine!.coordinates.elevationDegrees, equals(30.0));
    });

    test('Comando spatial dist modula la distancia', () async {
      final res = await kernel.execute('spatial dist 2.5');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('[OK] Distancia fijada en: 2.5 m'));
      expect(kernel.spatialEngine!.coordinates.distanceMeters, equals(2.5));
    });

    test('Comando spatial reset restaura el estado acustico inicial', () async {
      await kernel.execute('spatial pan 60');
      final res = await kernel.execute('spatial reset');
      expect(res.isSuccess, isTrue);
      expect(kernel.spatialEngine!.coordinates.azimuthDegrees, equals(0.0));
    });

    test('Integracion Tunner DSL con target @spatial', () async {
      final res = await kernel.execute('dsl set @spatial.azimuth = -45; set @spatial.distance = 3.0;');
      expect(res.isSuccess, isTrue);
      expect(kernel.spatialEngine!.coordinates.azimuthDegrees, equals(-45.0));
      expect(kernel.spatialEngine!.coordinates.distanceMeters, equals(3.0));
    });
  });
}
