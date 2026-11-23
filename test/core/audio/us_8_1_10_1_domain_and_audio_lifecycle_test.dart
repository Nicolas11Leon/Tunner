import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_channel.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_capture_service.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/features/harmonic_tutor/domain/just_intonation_calculator.dart';
import 'package:tunner/features/harmonic_tutor/presentation/harmonic_beat_gauge.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/pedagogy/infrastructure/pedagogical_certificate_pdf_generator.dart';
import 'package:tunner/features/pedagogy/domain/vocal_evaluation_result.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/practice_recorder/data/audio_playback_service.dart';
import 'package:tunner/features/tuner/data/pitch_detector_service.dart';

class _FakeAudioPlayer extends Fake implements AudioPlayer {
  final StreamController<Duration> positionCtrl = StreamController<Duration>.broadcast();
  final StreamController<Duration> durationCtrl = StreamController<Duration>.broadcast();
  final StreamController<void> completeCtrl = StreamController<void>.broadcast();

  bool stopCalled = false;
  bool disposeCalled = false;

  @override
  Stream<Duration> get onPositionChanged => positionCtrl.stream;

  @override
  Stream<Duration> get onDurationChanged => durationCtrl.stream;

  @override
  Stream<void> get onPlayerComplete => completeCtrl.stream;

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
    await positionCtrl.close();
    await durationCtrl.close();
    await completeCtrl.close();
  }
}

void main() {
  group('US-8.1: Dominio Puro, Persistencia de Skin, Mixer y PDF', () {
    test('AppUserSettingsEntity persiste y restaura activeStudioThemeId con default studio_oled_monochrome', () {
      const defaults = AppUserSettingsEntity();
      expect(defaults.activeStudioThemeId, 'studio_oled_monochrome');

      final updated = defaults.copyWith(activeStudioThemeId: 'vintage_analog_warm');
      expect(updated.activeStudioThemeId, 'vintage_analog_warm');

      final serialized = updated.toMap();
      expect(serialized['activeStudioThemeId'], 'vintage_analog_warm');

      final restored = AppUserSettingsEntity.fromMap(serialized);
      expect(restored.activeStudioThemeId, 'vintage_analog_warm');

      final fallbackRestored = AppUserSettingsEntity.fromMap(<String, dynamic>{});
      expect(fallbackRestored.activeStudioThemeId, 'studio_oled_monochrome');
    });

    test('AudioTrack.fromMap valida NaN/Infinity/>1.0, soporta pan y sobreescribe == y hashCode', () {
      final nanTrack = AudioTrack.fromMap({
        'id': 't1',
        'title': 'Track NaN',
        'instrumentIcon': 'mic',
        'volume': double.nan,
        'pan': double.negativeInfinity,
      });
      expect(nanTrack.volume, 0.8);
      expect(nanTrack.pan, 0.0);

      final infTrack = AudioTrack.fromMap({
        'id': 't2',
        'title': 'Track Inf',
        'instrumentIcon': 'piano',
        'volume': double.infinity,
        'pan': 2.5,
      });
      expect(infTrack.volume, 0.8);
      expect(infTrack.pan, 1.0);

      final clampedTrack = AudioTrack.fromMap({
        'id': 't3',
        'title': 'Track Clamped',
        'instrumentIcon': 'guitar',
        'volume': 1.75,
        'pan': -1.9,
      });
      expect(clampedTrack.volume, 1.0);
      expect(clampedTrack.pan, -1.0);

      const trackA = AudioTrack(
        id: 'stem_1',
        title: 'Flauta',
        instrumentIcon: 'flute',
        volume: 0.75,
        pan: -0.25,
        isMuted: false,
        isSolo: true,
      );
      final trackB = AudioTrack.fromMap(trackA.toMap());
      expect(trackA, equals(trackB));
      expect(trackA.hashCode, equals(trackB.hashCode));

      final consoleA = MixerConsoleEntity.defaultSetup();
      final consoleB = MixerConsoleEntity.fromMap(consoleA.toMap());
      expect(consoleA, equals(consoleB));
      expect(consoleA.hashCode, equals(consoleB.hashCode));
    });

    test('StudioPatchbayRoutingService mantiene timers de pulso independientes por plugId y notifica con _safeNotify', () {
      final service = StudioPatchbayRoutingService.isolated();
      const sourcePlug = StudioModularPlug(
        id: 'plug_source_test',
        toolId: 'tool_src',
        label: 'Source',
        type: StudioPlugType.audioOutput,
      );
      const sinkPlugA = StudioModularPlug(
        id: 'plug_sink_a',
        toolId: 'tool_a',
        label: 'Sink A',
        type: StudioPlugType.audioInput,
      );
      const sinkPlugB = StudioModularPlug(
        id: 'plug_sink_b',
        toolId: 'tool_b',
        label: 'Sink B',
        type: StudioPlugType.audioInput,
      );

      service.registerPlug(sourcePlug);
      service.registerPlug(sinkPlugA);
      service.registerPlug(sinkPlugB);

      final bus = service.createCustomChannel(name: 'Test Bus');
      service.connectPlugToChannel(sourcePlug.id, bus.id);
      service.connectPlugToChannel(sinkPlugA.id, bus.id);
      service.connectPlugToChannel(sinkPlugB.id, bus.id);

      service.dispatchSignalFromPlug(
        sourcePlugId: sourcePlug.id,
        payload: {'title': 'Take 1', 'bpm': 120.0},
      );

      expect(service.isPlugPulsing(sourcePlug.id), isTrue);
      expect(service.isPlugPulsing(sinkPlugA.id), isTrue);
      expect(service.isPlugPulsing(sinkPlugB.id), isTrue);
      expect(
        service.activePulsePlugIds,
        containsAll(<String>[sourcePlug.id, sinkPlugA.id, sinkPlugB.id]),
      );

      service.dispose();
      // Llamadas posteriores a dispose no deben lanzar excepcion gracias a _safeNotify
      expect(() => service.disconnectPlug(sinkPlugA.id), returnsNormally);
    });

    test('PedagogicalCertificatePdfGenerator sanitiza caracteres acentuados y eñes para WinAnsi Type1 Helvetica', () {
      final evaluation = VocalEvaluationResult(
        evaluationId: 'EVAL-2026-01',
        timestamp: DateTime.utc(2026, 11, 23, 15, 0),
        targetFrequencyHz: 440.0,
        measuredMeanFrequencyHz: 440.2,
        centsDeviation: 0.8,
        jitterPercent: 0.45,
        shimmerPercent: 1.80,
        vibratoRateHz: 5.5,
        vibratoDepthCents: 35.0,
        overallScore: 96.5,
        classificationLabel: 'Excelencia Acústica de Conservatorio - Ñandú',
      );

      final pdfBytes = PedagogicalCertificatePdfGenerator.generateCertificatePdf(
        studentName: 'Inés Núñez Peña',
        evaluation: evaluation,
      );

      final asciiText = latin1.decode(pdfBytes);
      expect(asciiText, contains('/Encoding /WinAnsiEncoding'));
      expect(asciiText, contains('(Ines Nunez Pena)'));
      expect(asciiText, contains('Excelencia Acustica de Conservatorio - Nandu'));
    });
  });

  group('US-10.1: Ciclo de Vida de Audio, Escritura Asincrona WAV y HarmonicBeatGauge', () {
    test('StudioAudioChannel.dispose() cancela explicitamente las 3 suscripciones del AudioPlayer', () async {
      final fakePlayer = _FakeAudioPlayer();
      final channel = StudioAudioChannel(
        channelId: 'ch_test',
        injectedPlayer: fakePlayer,
      );

      expect(fakePlayer.positionCtrl.hasListener, isTrue);
      expect(fakePlayer.durationCtrl.hasListener, isTrue);
      expect(fakePlayer.completeCtrl.hasListener, isTrue);

      await channel.dispose();

      expect(fakePlayer.positionCtrl.hasListener, isFalse);
      expect(fakePlayer.durationCtrl.hasListener, isFalse);
      expect(fakePlayer.completeCtrl.hasListener, isFalse);
      expect(fakePlayer.stopCalled, isTrue);
      expect(fakePlayer.disposeCalled, isTrue);
    });

    test('StudioAudioInputEngine respeta bufferSize y AudioPlaybackService / PitchDetectorService liberan motores propios', () async {
      final inputEngine = StudioAudioInputEngine();
      await inputEngine.startCapture(sampleRate: 48000, bufferSize: 2048);
      expect(inputEngine.activeSampleRate, 48000);
      expect(inputEngine.activeBufferSize, 2048);
      inputEngine.dispose();
      expect(inputEngine.isDisposed, isTrue);
      // Doble dispose seguro
      expect(() => inputEngine.dispose(), returnsNormally);

      final playbackService = AudioPlaybackService();
      expect(() => playbackService.dispose(), returnsNormally);

      final pitchService = PitchDetectorService();
      await expectLater(pitchService.dispose(), completes);

      final kernel = TunnerOsKernel();
      final kernelEventDone = kernel.audioKernel!.eventStream.drain<void>();
      kernel.dispose();
      await expectLater(kernelEventDone, completes);
    });

    test('StudioMasterCaptureService escribe bloques PCM mediante cola asincrona y genera WAV valido al finalizar', () async {
      final tempDir = await Directory.systemTemp.createTemp('tunner_wav_async_');
      final wavPath = '${tempDir.path}/master_capture.wav';
      final service = StudioMasterCaptureService();

      await service.startCapture(
        destinationPath: wavPath,
        sampleRate: 44100,
        channels: 2,
      );

      final left = List<double>.filled(256, 0.5);
      final right = List<double>.filled(256, -0.5);

      service.appendStereoSamples(left, right);
      service.appendStereoSamples(left, right);

      final finalizedPath = await service.stopAndFinalizeCapture();
      expect(finalizedPath, wavPath);

      final file = File(wavPath);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      // 44 bytes header + 2 bloques * 256 muestras * 4 bytes = 44 + 2048 = 2092 bytes
      expect(bytes.length, 2092);

      final headerData = ByteData.sublistView(bytes, 0, 44);
      // Subchunk2Size en offset 40 debe ser 2048
      expect(headerData.getUint32(40, Endian.little), 2048);

      service.dispose();
      await tempDir.delete(recursive: true);
    });

    testWidgets('HarmonicBeatGauge detiene el AnimationController en pureConsonance y anima cuando hay batimiento', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HarmonicBeatGauge(
              centsOffset: 0.5,
              beatFrequencyHz: 0.0,
              status: HarmonicLockStatus.pureConsonance,
              accentColor: Colors.green,
            ),
          ),
        ),
      );

      // En pureConsonance no debe haber animaciones activas pendientes
      expect(tester.hasRunningAnimations, isFalse);

      // Cambiar a estado con batimiento activo
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HarmonicBeatGauge(
              centsOffset: 12.0,
              beatFrequencyHz: 4.2,
              status: HarmonicLockStatus.adjusting,
              accentColor: Colors.amber,
            ),
          ),
        ),
      );

      expect(tester.hasRunningAnimations, isTrue);

      // Regresar a pureConsonance debe detener nuevamente el controlador
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HarmonicBeatGauge(
              centsOffset: 0.0,
              beatFrequencyHz: 0.0,
              status: HarmonicLockStatus.pureConsonance,
              accentColor: Colors.green,
            ),
          ),
        ),
      );

      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
