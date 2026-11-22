import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/studio_composition_root.dart';
import 'package:tunner/core/logging/domain/i_studio_logger.dart';
import 'package:tunner/features/guided_lessons/domain/guided_lesson_evaluator.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';
import 'package:tunner/features/vocal_autotune/data/local_vocal_take_file_gateway.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/td_psola_pitch_shifter.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_autotune_processor.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_score_converter.dart';
import 'package:tunner/features/vocal_autotune/presentation/vocal_pedagogy_controller.dart';

Uint8List _buildPcm16MonoWav({
  required double frequencyHz,
  required int sampleRate,
  required double durationSeconds,
  double amplitude = 0.65,
}) {
  final int totalSamples = (sampleRate * durationSeconds).round();
  final int dataSize = totalSamples * 2;
  final Uint8List wav = Uint8List(44 + dataSize);
  final ByteData view = ByteData.sublistView(wav);

  wav.setRange(0, 4, 'RIFF'.codeUnits);
  view.setUint32(4, 36 + dataSize, Endian.little);
  wav.setRange(8, 12, 'WAVE'.codeUnits);
  wav.setRange(12, 16, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 1, Endian.little);
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * 2, Endian.little);
  view.setUint16(32, 2, Endian.little);
  view.setUint16(34, 16, Endian.little);
  wav.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < totalSamples; i++) {
    final double s =
        amplitude * math.sin(2.0 * math.pi * frequencyHz * (i / sampleRate));
    final int pcm16 = (s * 32767.0).round().clamp(-32768, 32767);
    view.setInt16(44 + i * 2, pcm16, Endian.little);
  }
  return wav;
}

Float64List _decodeMonoWavSamples(Uint8List wavBytes) {
  final int totalFrames = (wavBytes.length - 44) ~/ 2;
  final ByteData view = ByteData.sublistView(wavBytes, 44);
  final Float64List out = Float64List(totalFrames);
  for (int i = 0; i < totalFrames; i++) {
    out[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

double _estimateDominantFreqByZeroCrossings(
  Float64List samples,
  int sampleRate, {
  int startOffset = 200,
  int? endOffset,
}) {
  final int start = startOffset.clamp(0, samples.length);
  final int end = (endOffset ?? samples.length - 200).clamp(start, samples.length);
  int crossings = 0;
  for (int i = start + 1; i < end; i++) {
    if (samples[i - 1] <= 0.0 && samples[i] > 0.0) {
      crossings++;
    }
  }
  final double durationSec = (end - start) / sampleRate;
  return durationSec > 0 ? crossings / durationSec : 0.0;
}

double _computeSpectralCentroid(Float64List samples, int sampleRate) {
  const int n = 1024;
  final int len = math.min(n, samples.length);
  double weightedSum = 0.0;
  double magSum = 0.0;
  final int maxBin = len ~/ 2;

  for (int k = 1; k < maxBin; k++) {
    double re = 0.0;
    double im = 0.0;
    final double angleStep = -2.0 * math.pi * k / len;
    for (int t = 0; t < len; t++) {
      final double w = 0.5 * (1.0 - math.cos(2.0 * math.pi * t / len));
      final double x = samples[t] * w;
      final double a = angleStep * t;
      re += x * math.cos(a);
      im += x * math.sin(a);
    }
    final double mag = math.sqrt(re * re + im * im);
    final double freq = (k * sampleRate) / len;
    weightedSum += freq * mag;
    magSum += mag;
  }
  return magSum > 1e-9 ? weightedSum / magSum : 0.0;
}

Float64List _synthesizeFormantSignal({
  required double f0Hz,
  required int sampleRate,
  required int length,
  double formant1Hz = 600.0,
  double formant2Hz = 1800.0,
}) {
  final Float64List out = Float64List(length);
  for (int i = 0; i < length; i++) {
    final double t = i / sampleRate;
    double val = 0.0;
    for (int h = 1; h <= 16; h++) {
      final double harmonicFreq = f0Hz * h;
      if (harmonicFreq >= sampleRate * 0.45) break;
      final double d1 = (harmonicFreq - formant1Hz) / 140.0;
      final double d2 = (harmonicFreq - formant2Hz) / 220.0;
      final double env =
          0.15 / h + 1.0 * math.exp(-d1 * d1) + 0.75 * math.exp(-d2 * d2);
      val += env * math.sin(2.0 * math.pi * harmonicFreq * t);
    }
    out[i] = val;
  }
  // Normalizar pico a 0.7
  double maxAbs = 0.0;
  for (final s in out) {
    if (s.abs() > maxAbs) maxAbs = s.abs();
  }
  if (maxAbs > 1e-9) {
    final double scale = 0.7 / maxAbs;
    for (int i = 0; i < length; i++) {
      out[i] *= scale;
    }
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-4.5 Vocal AutoTune Post-Produccion WAV Real', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('us_4_5_autotune_wav_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'applyAutoTuneToRecordingTake lee WAV real, ejecuta processWavBytesAsync, guarda *_autotuned.wav y actualiza filePath',
      () async {
        const int sampleRate = 44100;
        const double inputHz = 430.0; // -39.8 cents respecto a La4 (440 Hz)
        final Uint8List rawWav = _buildPcm16MonoWav(
          frequencyHz: inputHz,
          sampleRate: sampleRate,
          durationSeconds: 0.40,
        );
        final File originalFile = File('${tempDir.path}/vocal_take_raw.wav');
        originalFile.writeAsBytesSync(rawWav, flush: true);

        final List<TimedPitchSample> pitchTrack = List.generate(
          8,
          (i) => TimedPitchSample(
            timeMs: i * 50,
            frequencyHz: inputHz,
            centsDeviation: -39.8,
            targetNoteName: 'La4',
          ),
        );

        final PracticeTakeEntity originalTake = PracticeTakeEntity(
          id: 'take_raw_wav',
          name: 'Voz Cruda',
          timestamp: DateTime(2026, 11, 22),
          duration: const Duration(milliseconds: 400),
          filePath: originalFile.path,
          pitchTrack: pitchTrack,
        );

        final MultiTrackSessionEntity session = MultiTrackSessionEntity(
          id: 'sess_1',
          title: 'Ensayo Vocal',
          createdAt: DateTime(2026, 11, 22),
          bpm: 120,
          takes: [originalTake],
        );

        final VocalAutoTuneProcessor processor = VocalAutoTuneProcessor(
          config: const AutoTuneConfigEntity(
            isEnabled: true,
            scaleRoot: 0,
            scaleType: VocalScaleType.chromatic,
            retuneSpeedMs: 0.0,
            correctionAmount: 1.0,
            formantPreservation: true,
          ),
        );

        final VocalPedagogyController controller = VocalPedagogyController(
          guidedLessonEvaluator: GuidedLessonEvaluator(),
          autoTuneProcessor: processor,
          vocalTakeFileGateway: const LocalVocalTakeFileGateway(),
          logger: const NoOpStudioLogger(),
          onNotify: () {},
          onAutoSave: () {},
        );

        final result = await controller.applyAutoTuneToRecordingTake(
          session: session,
          takeId: originalTake.id,
        );

        expect(result, isNotNull);
        final PracticeTakeEntity tunedTake = result!.tunedTake;
        expect(tunedTake.filePath, isNot(equals(originalTake.filePath)));
        expect(tunedTake.filePath, endsWith('_autotuned.wav'));

        final File tunedFile = File(tunedTake.filePath);
        expect(tunedFile.existsSync(), isTrue);

        final Uint8List tunedWavBytes = tunedFile.readAsBytesSync();
        expect(tunedWavBytes.length, equals(rawWav.length));
        expect(String.fromCharCodes(tunedWavBytes.sublist(0, 4)), equals('RIFF'));
        expect(String.fromCharCodes(tunedWavBytes.sublist(8, 12)), equals('WAVE'));
        expect(tunedWavBytes, isNot(equals(rawWav)));

        final Float64List decodedOrig = _decodeMonoWavSamples(rawWav);
        final Float64List decodedTuned = _decodeMonoWavSamples(tunedWavBytes);
        final double origFreq =
            _estimateDominantFreqByZeroCrossings(decodedOrig, sampleRate);
        final double tunedFreq =
            _estimateDominantFreqByZeroCrossings(decodedTuned, sampleRate);

        expect(origFreq, closeTo(430.0, 5.0));
        expect(tunedFreq, closeTo(440.0, 6.0));
      },
    );

    test(
      'TunerViewModel con LocalVocalTakeFileGateway y StudioCompositionRoot cablean el gateway WAV sin violar DIP',
      () async {
        final File originalFile = File('${tempDir.path}/vm_take.wav');
        originalFile.writeAsBytesSync(
          _buildPcm16MonoWav(
            frequencyHz: 430.0,
            sampleRate: 44100,
            durationSeconds: 0.25,
          ),
          flush: true,
        );

        final TunerViewModel vm = TunerViewModel(
          vocalTakeFileGateway: const LocalVocalTakeFileGateway(),
        );
        vm.updateAutoTuneConfig(
          const AutoTuneConfigEntity(
            isEnabled: true,
            retuneSpeedMs: 0.0,
            correctionAmount: 1.0,
          ),
        );

        final PracticeTakeEntity take = PracticeTakeEntity(
          id: 'vm_take_1',
          name: 'Toma VM',
          timestamp: DateTime(2026, 11, 22),
          duration: const Duration(milliseconds: 250),
          filePath: originalFile.path,
          pitchTrack: List.generate(
            5,
            (i) => TimedPitchSample(
              timeMs: i * 50,
              frequencyHz: 430.0,
              centsDeviation: -39.0,
              targetNoteName: 'La4',
            ),
          ),
        );
        vm.addPracticeTake(take);

        final tuned = await vm.applyAutoTuneToRecordingTake(take.id);
        expect(tuned, isNotNull);
        expect(tuned!.filePath, endsWith('_autotuned.wav'));
        expect(File(tuned.filePath).existsSync(), isTrue);

        vm.dispose();

        final root = StudioCompositionRoot.create(isolatedServices: true);
        final rootVm = root.createTunerViewModel(seedDefaults: false);
        expect(rootVm.applyAutoTuneToRecordingTake('non_existent'), completion(isNull));
        rootVm.dispose();
        root.dispose();
      },
    );
  });

  group('US-4.5 TdPsolaPitchShifter Formantes y Rango 27.5..4186.0 Hz', () {
    const TdPsolaPitchShifter shifter = TdPsolaPitchShifter();
    const int sampleRate = 44100;

    test(
      'preserveFormants == true mantiene envolvente espectral mientras preserveFormants == false desplaza formantes al re-muestrear',
      () {
        const int len = 4096;
        final Float64List vowel = _synthesizeFormantSignal(
          f0Hz: 180.0,
          sampleRate: sampleRate,
          length: len,
          formant1Hz: 600.0,
          formant2Hz: 1800.0,
        );

        final Float64List withFormants = shifter.shiftPitch(
          inputSamples: vowel,
          pitchShiftRatio: 1.45,
          detectedPitchHz: 180.0,
          sampleRate: sampleRate,
          preserveFormants: true,
        );

        final Float64List withoutFormants = shifter.shiftPitch(
          inputSamples: vowel,
          pitchShiftRatio: 1.45,
          detectedPitchHz: 180.0,
          sampleRate: sampleRate,
          preserveFormants: false,
        );

        expect(withFormants.length, equals(len));
        expect(withoutFormants.length, equals(len));

        double absDiffSum = 0.0;
        for (int i = 0; i < len; i++) {
          expect(withFormants[i], inInclusiveRange(-1.0, 1.0));
          expect(withoutFormants[i], inInclusiveRange(-1.0, 1.0));
          absDiffSum += (withFormants[i] - withoutFormants[i]).abs();
        }
        final double meanAbsDiff = absDiffSum / len;
        expect(meanAbsDiff, greaterThan(0.01));

        final double centroidOrig = _computeSpectralCentroid(vowel, sampleRate);
        final double centroidPreserved =
            _computeSpectralCentroid(withFormants, sampleRate);
        final double centroidResampled =
            _computeSpectralCentroid(withoutFormants, sampleRate);

        // El re-muestreo directo desplaza los formantes hacia arriba aumentando el centroide
        expect(centroidResampled, greaterThan(centroidOrig + 150.0));
        // La preservacion cepstral mantiene el centroide mucho mas cerca del original
        expect(
          (centroidPreserved - centroidOrig).abs(),
          lessThan((centroidResampled - centroidOrig).abs()),
        );
      },
    );

    test('Soporta extremo grave A0 (27.5 Hz) sin clamping artificial a 50 Hz', () {
      const int len = 8192;
      final Float64List lowTone = Float64List(len);
      for (int i = 0; i < len; i++) {
        lowTone[i] = 0.65 * math.sin(2.0 * math.pi * 27.5 * (i / sampleRate));
      }

      final Float64List shiftedA0 = shifter.shiftPitch(
        inputSamples: lowTone,
        pitchShiftRatio: 1.12,
        detectedPitchHz: 27.5,
        sampleRate: sampleRate,
        preserveFormants: true,
      );

      final Float64List shiftedClamped50 = shifter.shiftPitch(
        inputSamples: lowTone,
        pitchShiftRatio: 1.12,
        detectedPitchHz: 50.0,
        sampleRate: sampleRate,
        preserveFormants: true,
      );

      expect(shiftedA0.length, equals(len));
      double diffFromInput = 0.0;
      double diffFrom50Hz = 0.0;
      for (int i = 0; i < len; i++) {
        expect(shiftedA0[i].isNaN, isFalse);
        expect(shiftedA0[i], inInclusiveRange(-1.0, 1.0));
        diffFromInput += (shiftedA0[i] - lowTone[i]).abs();
        diffFrom50Hz += (shiftedA0[i] - shiftedClamped50[i]).abs();
      }
      expect(diffFromInput / len, greaterThan(0.005));
      expect(diffFrom50Hz / len, greaterThan(0.005));
    });

    test('Soporta extremo agudo C8 (4186.0 Hz) sin clamping artificial a 1500 Hz', () {
      const int len = 2048;
      final Float64List highTone = Float64List(len);
      for (int i = 0; i < len; i++) {
        highTone[i] = 0.65 * math.sin(2.0 * math.pi * 4186.0 * (i / sampleRate));
      }

      final Float64List shiftedC8 = shifter.shiftPitch(
        inputSamples: highTone,
        pitchShiftRatio: 0.90,
        detectedPitchHz: 4186.0,
        sampleRate: sampleRate,
        preserveFormants: false,
      );

      final Float64List shifted1500 = shifter.shiftPitch(
        inputSamples: highTone,
        pitchShiftRatio: 0.90,
        detectedPitchHz: 1500.0,
        sampleRate: sampleRate,
        preserveFormants: false,
      );

      expect(shiftedC8.length, equals(len));
      double diffFromInput = 0.0;
      double diffFrom1500Hz = 0.0;
      for (int i = 0; i < len; i++) {
        expect(shiftedC8[i].isNaN, isFalse);
        expect(shiftedC8[i], inInclusiveRange(-1.0, 1.0));
        diffFromInput += (shiftedC8[i] - highTone[i]).abs();
        diffFrom1500Hz += (shiftedC8[i] - shifted1500[i]).abs();
      }
      expect(diffFromInput / len, greaterThan(0.05));
      expect(diffFrom1500Hz / len, greaterThan(0.01));
    });
  });

  group('US-4.5 VocalScoreConverter Insercion de Silencios Cuantizados', () {
    const VocalScoreConverter converter = VocalScoreConverter();

    test('Inserta silencios cuantizados HierarchicalNote.rest para brechas iniciales e intermedias', () {
      // A 120 BPM: 1 beat = 500 ms, 1 tick (semicorchea) = 125 ms
      final List<TimedPitchSample> samples = [
        // Silencio inicial de 500 ms (4 ticks)
        const TimedPitchSample(
          timeMs: 0,
          frequencyHz: 0.0,
          centsDeviation: 0.0,
          targetNoteName: '--',
          isSilent: true,
        ),
        // Nota 1: Do4 de 500 ms a 740 ms (~240 ms -> 2 ticks)
        ...List.generate(
          13,
          (i) => TimedPitchSample(
            timeMs: 500 + (i * 20),
            frequencyHz: 261.63,
            centsDeviation: 0.0,
            targetNoteName: 'Do4',
          ),
        ),
        // Brecha intermedia de 500 ms (740 ms a 1240 ms -> 4 ticks)
        const TimedPitchSample(
          timeMs: 900,
          frequencyHz: 0.0,
          centsDeviation: 0.0,
          targetNoteName: '--',
          isSilent: true,
        ),
        // Nota 2: Sol4 de 1240 ms a 1480 ms (~240 ms -> 2 ticks)
        ...List.generate(
          13,
          (i) => TimedPitchSample(
            timeMs: 1240 + (i * 20),
            frequencyHz: 392.00,
            centsDeviation: 0.0,
            targetNoteName: 'Sol4',
          ),
        ),
      ];

      final result = converter.convertTrackToScore(
        pitchTrack: samples,
        bpm: 120,
        timeSignature: TimeSignature.commonTime44,
      );

      expect(result.totalNotes, equals(2));
      expect(result.package.score.isValidScore, isTrue);

      final notes = result.package.score.measures.first.notes;
      expect(notes.length, equals(5));
      expect(notes[0].isRest, isTrue);
      expect(notes[0].startTick, equals(0));
      expect(notes[0].durationTicks, equals(4));

      expect(notes[1].isRest, isFalse);
      expect(notes[1].noteName, equals('Do4'));
      expect(notes[1].startTick, equals(4));
      expect(notes[1].durationTicks, equals(2));

      expect(notes[2].isRest, isTrue);
      expect(notes[2].startTick, equals(6));
      expect(notes[2].durationTicks, equals(4));

      expect(notes[3].isRest, isFalse);
      expect(notes[3].noteName, equals('Sol4'));
      expect(notes[3].startTick, equals(10));
      expect(notes[3].durationTicks, equals(2));

      expect(notes[4].isRest, isTrue);
      expect(notes[4].startTick, equals(12));
      expect(notes[4].durationTicks, equals(4));
    });

    test('Divide silencios extensos a traves de limites de compas manteniendo validez metrica', () {
      // A 120 BPM: msPerTick = 125 ms.
      // Nota 1: 0..240 ms (2 ticks).
      // Brecha: 240..2740 ms = 2500 ms = 20 ticks (cruza del compas 0 al compas 1).
      // Nota 2: 2740..2980 ms (2 ticks).
      final List<TimedPitchSample> samples = [
        ...List.generate(
          13,
          (i) => TimedPitchSample(
            timeMs: i * 20,
            frequencyHz: 440.0,
            centsDeviation: 0.0,
            targetNoteName: 'La4',
          ),
        ),
        ...List.generate(
          13,
          (i) => TimedPitchSample(
            timeMs: 2740 + (i * 20),
            frequencyHz: 493.88,
            centsDeviation: 0.0,
            targetNoteName: 'Si4',
          ),
        ),
      ];

      final result = converter.convertTrackToScore(
        pitchTrack: samples,
        bpm: 120,
        timeSignature: TimeSignature.commonTime44,
      );

      expect(result.totalNotes, equals(2));
      expect(result.package.score.measures.length, equals(2));
      expect(result.package.score.isValidScore, isTrue);

      final m0Notes = result.package.score.measures[0].notes;
      expect(m0Notes[0].noteName, equals('La4'));
      expect(m0Notes[0].startTick, equals(0));
      expect(m0Notes[0].durationTicks, equals(2));
      expect(m0Notes[1].isRest, isTrue);
      expect(m0Notes[1].startTick, equals(2));
      expect(m0Notes[1].durationTicks, equals(14));

      final m1Notes = result.package.score.measures[1].notes;
      expect(m1Notes[0].isRest, isTrue);
      expect(m1Notes[0].startTick, equals(0));
      expect(m1Notes[0].durationTicks, equals(6));
      expect(m1Notes[1].noteName, equals('Si4'));
      expect(m1Notes[1].startTick, equals(6));
      expect(m1Notes[1].durationTicks, equals(2));
    });
  });
}
