import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_export_entity.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';

void main() {
  group('StemExportConfig & ExportedStemFile Domain Tests', () {
    test('StemExportConfig default values and copyWith', () {
      const config = StemExportConfig();
      expect(config.sampleRate, 44100);
      expect(config.includeMasterMixdown, isTrue);
      expect(config.includeIndividualStems, isTrue);
      expect(config.includeMidiFile, isTrue);

      final modified = config.copyWith(
        sampleRate: 48000,
        includeMasterMixdown: false,
        includeIndividualStems: false,
      );
      expect(modified.sampleRate, 48000);
      expect(modified.includeMasterMixdown, isFalse);
      expect(modified.includeIndividualStems, isFalse);
      expect(modified.includeMidiFile, isTrue);
    });

    test('ExportedStemFile formatted size produces human readable text', () {
      final small = ExportedStemFile(
        fileName: 'test.mid',
        bytes: Uint8List(512),
        mimeType: 'audio/midi',
        duration: const Duration(seconds: 2),
        description: 'MIDI',
      );
      expect(small.formattedSize, '512 B');

      final medium = ExportedStemFile(
        fileName: 'stem.wav',
        bytes: Uint8List(250 * 1024),
        mimeType: 'audio/wav',
        duration: const Duration(seconds: 3),
        description: 'Stem',
      );
      expect(medium.formattedSize, '250.0 KB');

      final large = ExportedStemFile(
        fileName: 'master.wav',
        bytes: Uint8List(2 * 1024 * 1024),
        mimeType: 'audio/wav',
        duration: const Duration(seconds: 20),
        description: 'Master',
      );
      expect(large.formattedSize, '2.00 MB');
    });

    test('ExportBundleResult calculates total bytes and formatted sizes', () {
      final fileA = ExportedStemFile(
        fileName: 'a.wav',
        bytes: Uint8List(1024 * 500),
        mimeType: 'audio/wav',
        duration: const Duration(seconds: 5),
        description: 'Track A',
      );
      final fileB = ExportedStemFile(
        fileName: 'b.mid',
        bytes: Uint8List(1024 * 10),
        mimeType: 'audio/midi',
        duration: const Duration(seconds: 5),
        description: 'Track B',
      );

      final bundle = ExportBundleResult(
        files: [fileA, fileB],
        createdAt: DateTime(2026, 10, 28),
      );

      expect(bundle.isEmpty, isFalse);
      expect(bundle.isNotEmpty, isTrue);
      expect(bundle.totalBytes, 1024 * 510);
      expect(bundle.formattedTotalSize, '510.0 KB');
    });
  });

  group('StemAudioSynthesizer DSP & Synthesis Tests', () {
    const synthesizer = StemAudioSynthesizer();

    late HierarchicalScore score;
    late MixerConsoleEntity mixer;

    setUp(() {
      score = const HierarchicalScore(
        title: 'Estudio de Prueba',
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote(noteName: 'A4', startTick: 0, durationTicks: 4),
              HierarchicalNote(noteName: 'C5', startTick: 4, durationTicks: 4),
              HierarchicalNote(noteName: 'E5', startTick: 8, durationTicks: 4),
              HierarchicalNote(noteName: '--', startTick: 12, durationTicks: 4, isRest: true), // Silencio
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote(noteName: 'G4', startTick: 0, durationTicks: 8),
              HierarchicalNote(noteName: 'F4', startTick: 8, durationTicks: 8),
            ],
          ),
        ],
      );

      mixer = MixerConsoleEntity.defaultSetup();
    });

    test('calculateScoreDurationSeconds computes accurate duration based on ticks and bpm', () {
      // 2 compases 4/4 = 32 ticks totales. A 120 BPM: 1 beat = 0.5s = 4 ticks.
      // 32 ticks / 4 ticks/beat = 8 beats -> 8 beats * 0.5s = 4.0 segundos.
      final duration = synthesizer.calculateScoreDurationSeconds(score: score, bpm: 120);
      expect(duration, closeTo(4.0, 0.001));
    });

    test('midiPitchToFrequency calculates Concert Pitch A4 and C4 correctly', () {
      final fA4 = StemAudioSynthesizer.midiPitchToFrequency(69); // A4
      expect(fA4, closeTo(440.0, 0.01));

      final fC4 = StemAudioSynthesizer.midiPitchToFrequency(60); // C4
      expect(fC4, closeTo(261.63, 0.1));
    });

    test('synthesizeMelodySamples generates non-zero signal for active notes', () {
      const sampleRate = 44100;
      final totalSamples = (4.0 * sampleRate).round();

      final melodyBuffer = synthesizer.synthesizeMelodySamples(
        score: score,
        bpm: 120,
        sampleRate: sampleRate,
        totalSamples: totalSamples,
      );

      expect(melodyBuffer.length, totalSamples);
      final hasSignal = melodyBuffer.any((s) => s.abs() > 100.0);
      expect(hasSignal, isTrue);
    });

    test('synthesizeMetronomeSamples creates percussive woodblock peaks', () {
      const sampleRate = 44100;
      final totalSamples = (4.0 * sampleRate).round();

      final metroBuffer = synthesizer.synthesizeMetronomeSamples(
        score: score,
        bpm: 120,
        sampleRate: sampleRate,
        totalSamples: totalSamples,
      );

      expect(metroBuffer.length, totalSamples);
      final maxSample = metroBuffer.fold(0.0, (acc, s) => s.abs() > acc ? s.abs() : acc);
      expect(maxSample, greaterThan(1000.0));
    });

    test('floatBufferToWav generates valid RIFF WAVE header and PCM samples', () {
      const sampleRate = 44100;
      final buffer = Float64List(4410); // 100 ms

      // Onda senoidal de prueba
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = 16000.0;
      }

      final wavBytes = synthesizer.floatBufferToWav(buffer: buffer, sampleRate: sampleRate);

      expect(wavBytes.length, 44 + buffer.length * 2);

      // Comprobar "RIFF"
      expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');
      // Comprobar "WAVE"
      expect(String.fromCharCodes(wavBytes.sublist(8, 12)), 'WAVE');
      // Comprobar "fmt "
      expect(String.fromCharCodes(wavBytes.sublist(12, 16)), 'fmt ');
      // Comprobar "data"
      expect(String.fromCharCodes(wavBytes.sublist(36, 40)), 'data');
    });

    test('exportStemsAndMidi produces master mixdown, stem files and MIDI file', () {
      final bundle = synthesizer.exportStemsAndMidi(
        score: score,
        mixerConsole: mixer,
        bpm: 120,
        trackTitle: 'Oda a la Alegria',
        config: const StemExportConfig(
          includeMasterMixdown: true,
          includeIndividualStems: true,
          includeMidiFile: true,
          includeRecordedTake: true,
        ),
        recordedPcmBytes: Uint8List(1000), // Simulación de toma grabada
      );

      expect(bundle.files.length, 6); // Master + Melody + Accompaniment + Metronome + RecordedTake + MIDI
      // Revisar nombres
      final fileNames = bundle.files.map((f) => f.fileName).toList();
      expect(fileNames.any((name) => name.contains('master_mixdown.wav')), isTrue);
      expect(fileNames.any((name) => name == 'stem_01_melody.wav'), isTrue);
      expect(fileNames.any((name) => name == 'stem_02_accompaniment.wav'), isTrue);
      expect(fileNames.any((name) => name == 'stem_03_metronome_click.wav'), isTrue);
      expect(fileNames.any((name) => name == 'stem_04_user_recorded_take.wav'), isTrue);
      expect(fileNames.any((name) => name.endsWith('.mid')), isTrue);
    });

    test('exportStemsAndMidi respects selective config options', () {
      final bundle = synthesizer.exportStemsAndMidi(
        score: score,
        mixerConsole: mixer,
        bpm: 120,
        trackTitle: 'Ejercicio 1',
        config: const StemExportConfig(
          includeMasterMixdown: false,
          includeIndividualStems: false,
          includeMidiFile: true,
        ),
      );

      expect(bundle.files.length, 1);
      expect(bundle.files.first.mimeType, 'audio/midi');
      expect(bundle.files.first.fileName, 'ejercicio_1.mid');
    });
  });
}
