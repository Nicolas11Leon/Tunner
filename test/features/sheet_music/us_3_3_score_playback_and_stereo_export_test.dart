import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_export_entity.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_playback_coordinator.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';

void main() {
  group('US-3.3 ScorePlaybackCoordinator, Polyphonic Stems and Stereo Export Tests', () {
    test('ScorePlaybackCoordinator manages active preview timers without leaks', () async {
      final voicePool = PolyphonicVoicePool();
      final coordinator = ScorePlaybackCoordinator(voicePool: voicePool);

      const noteC4 = HierarchicalNote(noteName: 'C4', durationTicks: 4, startTick: 0);

      // Disparar preview de la nota C4
      coordinator.previewNote(noteC4, durationSeconds: 0.1);

      // Re-disparar inmediatamente para verificar que no colisiona ni fuga temporizadores
      coordinator.previewNote(noteC4, durationSeconds: 0.1);

      // Detener y limpiar
      coordinator.stopPlayback();
      coordinator.dispose();
      voicePool.panic();
    });

    test('StemAudioSynthesizer floatStereoBufferToWav produces canonical 2-channel stereo WAV header', () {
      const synthesizer = StemAudioSynthesizer();
      const sampleRate = 44100;
      const numSamples = 1000;

      final leftBuffer = Float64List(numSamples);
      final rightBuffer = Float64List(numSamples);
      for (int i = 0; i < numSamples; i++) {
        leftBuffer[i] = 16000.0;
        rightBuffer[i] = -16000.0;
      }

      final stereoWav = synthesizer.floatStereoBufferToWav(
        leftBuffer: leftBuffer,
        rightBuffer: rightBuffer,
        sampleRate: sampleRate,
      );

      expect(stereoWav, isNotNull);
      // Longitud total = 44 bytes de encabezado + (numSamples * 2 canales * 2 bytes = 4000)
      expect(stereoWav.length, equals(44 + 4000));

      // Verificar cabecera RIFF y WAVE
      final byteData = ByteData.sublistView(stereoWav);
      expect(String.fromCharCodes(stereoWav.sublist(0, 4)), equals('RIFF'));
      expect(String.fromCharCodes(stereoWav.sublist(8, 12)), equals('WAVE'));

      // Canales en offset 22 (uint16 little endian): 2 canales (Stereo)
      final channels = byteData.getUint16(22, Endian.little);
      expect(channels, equals(2), reason: 'El archivo WAV debe ser estéreo real de 2 canales');

      // SampleRate en offset 24 (uint32 little endian)
      final readSampleRate = byteData.getUint32(24, Endian.little);
      expect(readSampleRate, equals(sampleRate));

      // Bits por muestra en offset 34 (uint16 little endian): 16 bits
      final bitsPerSample = byteData.getUint16(34, Endian.little);
      expect(bitsPerSample, equals(16));
    });

    test('StemAudioSynthesizer exportStemsAndMidi processes all stems and outputs stereo master mixdown', () {
      const synthesizer = StemAudioSynthesizer();
      final score = HierarchicalScore(
        title: 'Estudio Estéreo Multi-Stem',
        baseBpm: 120,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'C4'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'E4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'G4'),
              HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: 'C5'),
            ],
          ),
        ],
      );

      final mixerConsole = MixerConsoleEntity(
        metronomeTrack: const AudioTrack(
          id: 'metronome',
          title: 'Metrónomo',
          instrumentIcon: 'metronome',
          volume: 0.5,
        ),
        stems: const [
          AudioTrack(id: 'lead_voice', title: 'Voz Principal', instrumentIcon: 'voice', volume: 0.9),
          AudioTrack(id: 'piano_harmony', title: 'Piano Base', instrumentIcon: 'piano', volume: 0.8),
          AudioTrack(id: 'acoustic_guitar', title: 'Guitarra Rítmica', instrumentIcon: 'guitar', volume: 0.7),
          AudioTrack(id: 'bass_line', title: 'Bajo Acústico', instrumentIcon: 'bass', volume: 0.85),
        ],
      );

      final result = synthesizer.exportStemsAndMidi(
        score: score,
        mixerConsole: mixerConsole,
        bpm: 120,
        trackTitle: 'Suite Estéreo',
        config: const StemExportConfig(
          includeMasterMixdown: true,
          includeIndividualStems: true,
          includeMetronomeTrack: true,
          includeMidiFile: true,
        ),
      );

      expect(result.files, isNotEmpty);

      // Verificar que el master mixdown existe y es estéreo de 2 canales
      final masterFile = result.files.firstWhere(
        (f) => f.fileName.contains('master_mixdown.wav'),
      );
      expect(masterFile.description, contains('Estéreo 2 Canales'));
      final masterHeader = ByteData.sublistView(masterFile.bytes);
      expect(masterHeader.getUint16(22, Endian.little), equals(2), reason: 'Master Mixdown debe ser de 2 canales');

      // Verificar que se exportaron todos los stems individuales definidos en mixerConsole.stems
      final exportedStems = result.files.where((f) => f.fileName.startsWith('stem_')).toList();
      // 4 stems de consola + 1 metrónomo = 5 stems individuales
      expect(exportedStems.length, greaterThanOrEqualTo(5));

      expect(result.files.any((f) => f.fileName.contains('lead_voice')), isTrue);
      expect(result.files.any((f) => f.fileName.contains('piano_harmony')), isTrue);
      expect(result.files.any((f) => f.fileName.contains('acoustic_guitar')), isTrue);
      expect(result.files.any((f) => f.fileName.contains('bass_line')), isTrue);
      expect(result.files.any((f) => f.fileName.contains('metronome_click')), isTrue);
    });
  });
}
