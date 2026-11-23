import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/offline_wav_decoder.dart';
import 'package:tunner/features/acoustic_lab/domain/harmonic_series_analyzer.dart';
import 'package:tunner/features/audio_synthesizer/data/soundfont_synthesizer_service.dart';
import 'package:tunner/features/audio_synthesizer/domain/offline_score_wav_renderer.dart';
import 'package:tunner/features/audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_export_entity.dart';
import 'package:tunner/features/drone/domain/drone_timbre.dart';
import 'package:tunner/features/drone/domain/harmonic_drone_config.dart';
import 'package:tunner/features/drone/domain/harmonic_drone_synthesizer.dart';
import 'package:tunner/features/metronome/domain/offline_metronome_track_generator.dart';
import 'package:tunner/features/metronome/domain/tap_tempo_engine.dart';
import 'package:tunner/features/metronome/domain/tap_tempo_result.dart';
import 'package:tunner/features/metronome/domain/tempo_entity.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/tuner/domain/mcleod_pitch_method.dart';
import 'package:tunner/features/tuner/domain/note_entity.dart';
import 'package:tunner/features/tuner/domain/offline_pitch_contour_analyzer.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/scale_quantizer.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_autotune_processor.dart';

double _peakAmplitude(Float64List samples, [int start = 0, int? end]) {
  final int s = start.clamp(0, samples.length);
  final int e = (end ?? samples.length).clamp(s, samples.length);
  double peak = 0.0;
  for (int i = s; i < e; i++) {
    final v = samples[i].abs();
    if (v > peak) peak = v;
  }
  return peak;
}

Uint8List _buildFloat32MonoWav({
  required double frequencyHz,
  required int sampleRate,
  required double durationSeconds,
  double amplitude = 0.65,
}) {
  final int frames = (sampleRate * durationSeconds).round();
  final int dataSize = frames * 4;
  final Uint8List wav = Uint8List(44 + dataSize);
  final ByteData view = ByteData.sublistView(wav);

  wav.setRange(0, 4, 'RIFF'.codeUnits);
  view.setUint32(4, 36 + dataSize, Endian.little);
  wav.setRange(8, 12, 'WAVE'.codeUnits);
  wav.setRange(12, 16, 'fmt '.codeUnits);
  view.setUint32(16, 16, Endian.little);
  view.setUint16(20, 3, Endian.little); // IEEE Float
  view.setUint16(22, 1, Endian.little);
  view.setUint32(24, sampleRate, Endian.little);
  view.setUint32(28, sampleRate * 4, Endian.little);
  view.setUint16(32, 4, Endian.little);
  view.setUint16(34, 32, Endian.little);
  wav.setRange(36, 40, 'data'.codeUnits);
  view.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < frames; i++) {
    final double s = amplitude * math.sin(2.0 * math.pi * frequencyHz * i / sampleRate);
    view.setFloat32(44 + i * 4, s, Endian.little);
  }
  return wav;
}

void main() {
  group('Ola 1B - HarmonicDroneSynthesizer volumen y configuracion JSON', () {
    test('generateDroneWavBuffer aplica config.volume proporcionalmente', () {
      const synth = HarmonicDroneSynthesizer();
      const baseConfig = HarmonicDroneConfig(
        rootNoteIndex: 9, // La
        octave: 3,
        includeFifth: false,
        includeOctave: false,
        timbre: DroneTimbre.pureSine,
      );

      final wavLoud = synth.generateDroneWavBuffer(
        config: baseConfig.copyWith(volume: 1.0),
        durationSeconds: 0.25,
      );
      final wavHalf = synth.generateDroneWavBuffer(
        config: baseConfig.copyWith(volume: 0.5),
        durationSeconds: 0.25,
      );
      final wavSilent = synth.generateDroneWavBuffer(
        config: baseConfig.copyWith(volume: 0.0),
        durationSeconds: 0.25,
      );

      final peakLoud = _peakAmplitude(OfflineWavDecoder.decode(wavLoud).samples);
      final peakHalf = _peakAmplitude(OfflineWavDecoder.decode(wavHalf).samples);
      final peakSilent = _peakAmplitude(OfflineWavDecoder.decode(wavSilent).samples);

      expect(peakSilent, equals(0.0));
      expect(peakLoud, greaterThan(0.7));
      expect(peakHalf / peakLoud, closeTo(0.5, 0.02));
    });
  });

  group('Ola 1B - Renderizado Offline Multipista SF2 / VoicePool / Fallback', () {
    const score = HierarchicalScore(
      title: 'Arpegio La Mayor',
      measures: [
        MeasureEntity(
          index: 0,
          timeSignature: TimeSignature.commonTime44,
          notes: [
            HierarchicalNote(noteName: 'A4', startTick: 0, durationTicks: 8),
            HierarchicalNote(noteName: 'C#5', startTick: 0, durationTicks: 8),
            HierarchicalNote(noteName: 'E5', startTick: 8, durationTicks: 8),
          ],
        ),
      ],
    );

    test('OfflineScoreWavRenderer renderiza con SF2, PolyphonicVoicePool y fallback aditivo', () {
      const renderer = OfflineScoreWavRenderer();
      final sf2Service = SoundFontSynthesizerService();
      final voicePool = PolyphonicVoicePool(sampleRate: 44100.0);

      final wavSf2 = renderer.renderScoreToWav(
        score: score,
        bpm: 120,
        a4Ref: 442.0,
        soundFontService: sf2Service,
        sf2Patch: 0,
      );
      final wavPool = renderer.renderScoreToWav(
        score: score,
        bpm: 120,
        a4Ref: 442.0,
        polyphonicPool: voicePool,
      );
      final wavAdditive = renderer.renderScoreToWav(
        score: score,
        bpm: 120,
        a4Ref: 442.0,
      );

      for (final wav in [wavSf2, wavPool, wavAdditive]) {
        final decoded = OfflineWavDecoder.decode(wav);
        expect(decoded.sampleRate, equals(44100));
        expect(decoded.durationSeconds, closeTo(2.0, 0.05));
        expect(_peakAmplitude(decoded.samples), greaterThan(0.05));
      }
    });

    test('StemAudioSynthesizer respeta includeMelodyTrack, includeAccompanimentTrack y a4Ref', () {
      const synth = StemAudioSynthesizer();
      final mixer = MixerConsoleEntity.defaultSetup();

      final bundleWithoutMelody = synth.exportStemsAndMidi(
        score: score,
        mixerConsole: mixer,
        bpm: 120,
        trackTitle: 'Sin Melodia',
        config: const StemExportConfig(
          includeMasterMixdown: false,
          includeIndividualStems: true,
          includeMidiFile: false,
          includeMelodyTrack: false,
          includeAccompanimentTrack: false,
          includeMetronomeTrack: false,
        ),
        a4Ref: 415.0,
      );

      // En defaultSetup hay 3 stems: [0]=melody, [1]=accompaniment, [2]=extra track.
      // Al deshabilitar melody y accompaniment solo debe exportarse el 3er stem.
      expect(bundleWithoutMelody.files.length, equals(1));
      expect(bundleWithoutMelody.files.first.fileName, startsWith('stem_03_'));
    });
  });

  group('Ola 1B - OfflinePitchContourAnalyzer y HarmonicSeriesAnalyzer.analyzeWavBytes', () {
    test('OfflinePitchContourAnalyzer detecta 440 Hz en onda senoidal WAV', () {
      final wav440 = PcmWavSynthesizer.generateSineToneWav(
        frequency: 440.0,
        durationSeconds: 0.6,
        sampleRate: 44100,
        seamlessLoop: true,
      );

      const analyzer = OfflinePitchContourAnalyzer();
      final result = analyzer.analyzeWavBytes(
        wav440,
        windowSize: 4096,
        hopSize: 1024,
      );

      expect(result.sampleRate, equals(44100));
      expect(result.hasVoicedFrames, isTrue);
      expect(result.voicedFrameCount, greaterThan(5));
      expect(result.medianPitchHz, closeTo(440.0, 1.0));
      expect(result.meanPitchHz, closeTo(440.0, 1.0));
      expect(result.dominantNote, isNotNull);
      expect(result.dominantNote!.toEnglishName(), equals('A4'));
      expect(result.averageAbsoluteCentsDeviation, lessThan(5.0));
    });

    test('HarmonicSeriesAnalyzer.analyzeWavBytes auto-detecta fundamentalHz desde WAV', () {
      final wav440 = PcmWavSynthesizer.generateSineToneWav(
        frequency: 440.0,
        durationSeconds: 0.4,
        sampleRate: 44100,
        seamlessLoop: true,
      );

      const harmonicAnalyzer = HarmonicSeriesAnalyzer(maxHarmonics: 6);
      final timbre = harmonicAnalyzer.analyzeWavBytes(wav440);

      expect(timbre.fundamentalHz, closeTo(440.0, 1.5));
      expect(timbre.harmonics.length, equals(6));
      expect(timbre.totalHarmonicDistortionPercent, lessThan(8.0));
    });
  });

  group('Ola 1B - VocalAutoTuneProcessor autonomo (sin pitchTrack)', () {
    test('processWavBytes corrige afinacion en WAV 32-bit float sin pitchTrack previo', () {
      final rawFloatWav = _buildFloat32MonoWav(
        frequencyHz: 430.0, // ~ -39.8 cents respecto a A4 (440 Hz)
        sampleRate: 44100,
        durationSeconds: 0.45,
      );

      final processor = VocalAutoTuneProcessor(
        config: const AutoTuneConfigEntity(
          isEnabled: true,
          scaleRoot: 0,
          scaleType: VocalScaleType.chromatic,
          retuneSpeedMs: 0.0,
          correctionAmount: 1.0,
          formantPreservation: true,
        ),
      );

      final tunedWav = processor.processWavBytes(
        wavBytes: rawFloatWav,
      );

      const contourAnalyzer = OfflinePitchContourAnalyzer();
      final origContour = contourAnalyzer.analyzeWavBytes(rawFloatWav);
      final tunedContour = contourAnalyzer.analyzeWavBytes(tunedWav);

      expect(origContour.medianPitchHz, closeTo(430.0, 2.0));
      expect(tunedContour.medianPitchHz, closeTo(440.0, 5.0));
    });
  });

  group('Ola 1B - OfflineMetronomeTrackGenerator en 3/4 y 6/8', () {
    const generator = OfflineMetronomeTrackGenerator();

    test('Genera pista WAV en 3/4 con countInBars y duracion exacta', () {
      // 3/4 a 120 BPM: 1 beat = 0.5s, 1 compas = 1.5s.
      // 2 compases + 1 compas count-in = 3 compases = 9 beats = 4.5s.
      final result = generator.generateTrack(
        bpm: 120,
        numerator: 3,
        denominator: 4,
        bars: 2,
        countInBars: 1,
        sampleRate: 44100,
      );

      expect(result.meter, equals('3/4'));
      expect(result.isCompoundMeter, isFalse);
      expect(result.totalBeats, equals(9));
      expect(result.durationSeconds, closeTo(4.5, 0.001));

      final decoded = OfflineWavDecoder.decode(result.wavBytes);
      expect(decoded.sampleRate, equals(44100));
      expect(decoded.channels, equals(1));
      expect(decoded.bitsPerSample, equals(16));
      expect(decoded.durationSeconds, closeTo(4.5, 0.002));
      expect(_peakAmplitude(decoded.samples), greaterThan(0.5));
    });

    test('Genera pista WAV en 6/8 con acento primario en pulso 1 y secundario en pulso 4', () {
      // 6/8 a 120 BPM: cada corchea = 0.25s, 1 compas = 1.5s, 2 compases = 3.0s.
      final result = generator.generateTrack(
        bpm: 120,
        numerator: 6,
        denominator: 8,
        bars: 2,
        countInBars: 0,
        sampleRate: 44100,
      );

      expect(result.meter, equals('6/8'));
      expect(result.isCompoundMeter, isTrue);
      expect(result.totalBeats, equals(12));
      expect(result.durationSeconds, closeTo(3.0, 0.001));

      final decoded = OfflineWavDecoder.decode(result.wavBytes);
      final int beatSamples = (0.25 * 44100).round();
      final int clickWindow = (0.03 * 44100).round();

      final double beat1Peak = _peakAmplitude(decoded.samples, 0, clickWindow);
      final double beat2Peak = _peakAmplitude(
        decoded.samples,
        beatSamples,
        beatSamples + clickWindow,
      );
      final double beat4Peak = _peakAmplitude(
        decoded.samples,
        beatSamples * 3,
        beatSamples * 3 + clickWindow,
      );

      expect(beat1Peak, greaterThan(beat4Peak));
      expect(beat4Peak, greaterThan(beat2Peak));
    });
  });

  group('Ola 1B - Serializacion JSON canonica toJson/fromJson', () {
    test('Round-trip JSON de todas las entidades clave de Ola 1B', () {
      const drone = HarmonicDroneConfig(
        rootNoteIndex: 7,
        octave: 2,
        includeFifth: true,
        includeOctave: true,
        timbre: DroneTimbre.richCello,
        volume: 0.42,
        harmonicBalance: 0.6,
      );
      expect(HarmonicDroneConfig.fromJson(drone.toJson()), equals(drone));

      const pitch = PitchDetectionResult(
        pitched: true,
        pitchHz: 440.25,
        clarity: 0.96,
        rms: 0.31,
      );
      final pitchRt = PitchDetectionResult.fromJson(pitch.toJson());
      expect(pitchRt.pitched, isTrue);
      expect(pitchRt.pitchHz, closeTo(440.25, 1e-6));
      expect(pitchRt.clarity, closeTo(0.96, 1e-6));

      final note = NoteEntity.fromFrequency(440.0);
      final noteRt = NoteEntity.fromJson(note.toJson());
      expect(noteRt.name, equals(note.name));
      expect(noteRt.midiNumber, equals(69));
      expect(noteRt.frequency, closeTo(440.0, 1e-6));

      const timbre = TimbreAnalysisResult(
        fundamentalHz: 440.0,
        harmonics: [
          HarmonicBarEntity(
            harmonicNumber: 1,
            frequencyHz: 440.0,
            relativeAmplitude: 1.0,
            dbLevel: 0.0,
            intervalLabel: '1 (Fundamental)',
          ),
        ],
        spectralCentroidHz: 440.0,
        totalHarmonicDistortionPercent: 1.2,
        timbreClassification: 'Puro y Suave',
      );
      final timbreRt = TimbreAnalysisResult.fromJson(timbre.toJson());
      expect(timbreRt.fundamentalHz, equals(440.0));
      expect(timbreRt.harmonics.length, equals(1));
      expect(timbreRt.timbreClassification, equals('Puro y Suave'));

      const quant = ScaleQuantizationResult(
        detectedFrequencyHz: 432.0,
        targetFrequencyHz: 440.0,
        targetNoteName: 'La4',
        pitchShiftRatio: 1.0185,
        centsDeviation: -31.76,
        isVoiced: true,
        isNoteInScale: true,
      );
      final quantRt = ScaleQuantizationResult.fromJson(quant.toJson());
      expect(quantRt.targetNoteName, equals('La4'));
      expect(quantRt.pitchShiftRatio, closeTo(1.0185, 1e-4));

      final tempo = TempoMark.fromBpm(128);
      final tempoRt = TempoMark.fromJson(tempo.toJson());
      expect(tempoRt.italianName, equals(tempo.italianName));
      expect(tempoRt.minBpm, equals(tempo.minBpm));

      final tapEngine = TapTempoEngine();
      final tapResult = tapEngine.analyzeTimestamps([0, 500, 1000, 1500]);
      final tapRt = TapTempoResult.fromJson(tapResult.toJson());
      expect(tapRt.bpm, equals(120));
      expect(tapRt.isCalibrated, isTrue);

      const exportCfg = StemExportConfig(
        sampleRate: 48000,
        includeMelodyTrack: false,
        includeAccompanimentTrack: true,
      );
      final exportRt = StemExportConfig.fromJson(exportCfg.toJson());
      expect(exportRt.sampleRate, equals(48000));
      expect(exportRt.includeMelodyTrack, isFalse);
      expect(exportRt.includeAccompanimentTrack, isTrue);
    });
  });
}
