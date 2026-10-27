import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

class _MockPitchService implements IPitchDetectorService {
  @override
  Function(double)? onPitchDetected;
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _MockMetronomeService implements IMetronomeService {
  @override
  Function(int)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

class _MockRecorderService implements IPracticeRecorderService {
  @override
  Stream<double> get amplitudeStream => const Stream.empty();
  @override
  bool get isRecording => false;
  @override
  Future<void> startRecording({required String destinationPath}) async {}
  @override
  Future<void> pauseRecording() async {}
  @override
  Future<void> resumeRecording() async {}
  @override
  Future<String?> stopRecording() async => null;
  @override
  void dispose() {}
}

class _MockPlaybackService implements IAudioPlaybackService {
  @override
  Stream<Duration> get onPositionChanged => const Stream.empty();
  @override
  Stream<Duration> get onDurationChanged => const Stream.empty();
  @override
  Stream<void> get onPlayerComplete => const Stream.empty();
  @override
  bool get isPlaying => false;
  @override
  Future<void> play(String filePath) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setPlaybackRate(double rate) async {}
  @override
  void dispose() {}
}

void main() {
  late TunerViewModel viewModel;
  late MemoryPersistenceService memoryPersistence;

  setUp(() async {
    memoryPersistence = MemoryPersistenceService();
    viewModel = TunerViewModel(
      pitchService: _MockPitchService(),
      metronomeService: _MockMetronomeService(),
      recorderService: _MockRecorderService(),
      playbackService: _MockPlaybackService(),
      persistenceService: memoryPersistence,
      scoreImporterService: UniversalScoreImporterService(),
    );
    await viewModel.isInitialized;
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('Universal Importer ViewModel Tests', () {
    test('Successfully imports MusicXML and updates activePackage and bpm', () async {
      const musicXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 3.1 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="3.1">
  <work><work-title>Concierto en Re</work-title></work>
  <identification><creator type="composer">J. S. Bach</creator></identification>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <sound tempo="128"/>
      <note>
        <pitch><step>D</step><octave>4</octave></pitch>
        <duration>4</duration>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final bytes = Uint8List.fromList(utf8.encode(musicXml));
      final result = await viewModel.importScoreFromBytes(bytes, 'bach.musicxml');

      expect(result, isNotNull);
      expect(result!.package.title, 'Concierto en Re');
      expect(result.package.composer, 'J. S. Bach');
      expect(result.package.defaultBpm, 128);
      expect(viewModel.activePackage.title, 'Concierto en Re');
      expect(viewModel.activePackage.tracks.length, 1);
      expect(viewModel.bpm, 128);
    });

    test('Successfully imports MIDI bytes and configures score', () async {
      // Build a minimal single-track MIDI in memory
      final b = BytesBuilder();
      b.add([0x4D, 0x54, 0x68, 0x64]); // MThd
      b.add([0x00, 0x00, 0x00, 0x06]); // length 6
      b.add([0x00, 0x00]); // format 0
      b.add([0x00, 0x01]); // 1 track
      b.add([0x01, 0xE0]); // 480 PPQ

      // Track chunk
      final tb = BytesBuilder();
      // Delta 0, Tempo Meta (500000 microsec = 120 bpm)
      tb.add([0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20]);
      // Delta 0, Note On C4 (60), vel 64
      tb.add([0x00, 0x90, 0x3C, 0x40]);
      // Delta 480, Note Off C4 (60), vel 0
      tb.add([0x83, 0x60, 0x80, 0x3C, 0x00]);
      // Delta 0, End of Track
      tb.add([0x00, 0xFF, 0x2F, 0x00]);

      final trackBytes = tb.toBytes();
      b.add([0x4D, 0x54, 0x72, 0x6B]); // MTrk
      final lenData = ByteData(4)..setUint32(0, trackBytes.length, Endian.big);
      b.add(lenData.buffer.asUint8List());
      b.add(trackBytes);

      final midiBytes = b.toBytes();
      final result = await viewModel.importScoreFromBytes(midiBytes, 'estudio.mid');

      expect(result, isNotNull);
      expect(result!.package.defaultBpm, 120);
      expect(viewModel.activePackage.title, 'estudio');
      expect(viewModel.bpm, 120);
    });

    test('Gracefully returns null on invalid corrupted bytes and preserves existing score', () async {
      final oldScoreTitle = viewModel.activePackage.title;
      final invalidBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);

      final result = await viewModel.importScoreFromBytes(invalidBytes, 'corrupted.bin');

      expect(result, isNull);
      // Existing score must remain intact
      expect(viewModel.activePackage.title, oldScoreTitle);
    });
  });
}
