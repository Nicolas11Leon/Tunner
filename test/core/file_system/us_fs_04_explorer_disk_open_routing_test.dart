import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/audio/domain/i_audio_transcoder_port.dart';
import 'package:tunner/core/file_system/data/memory_studio_file_system_repository.dart';
import 'package:tunner/core/file_system/data/studio_workspace_file_system_service.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/domain/studio_file_type.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/persistence/domain/i_local_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner/presentation/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

class _SpyMemoryStudioFileSystemRepository extends MemoryStudioFileSystemRepository {
  final List<String> readPaths = <String>[];

  @override
  Future<Uint8List> readFile(String relativePath) async {
    readPaths.add(relativePath);
    return super.readFile(relativePath);
  }
}

class _FakePitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}

  @override
  Future<void> stopRecording() async {}
}

class _FakeMetronomeService implements IMetronomeService {
  @override
  Function(int)? onSubTick;

  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}

  @override
  Future<void> stop() async {}
}

class _FakeRecorderService implements IPracticeRecorderService {
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

class _FakePlaybackService implements IAudioPlaybackService {
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

class _FakePersistenceService implements ILocalPersistenceService {
  AppUserSettingsEntity? savedSettings;

  @override
  Future<AppUserSettingsEntity> loadSettings() async =>
      savedSettings ?? AppUserSettingsEntity.defaultSettings;

  @override
  Future<void> saveSettings(AppUserSettingsEntity settings) async {
    savedSettings = settings;
  }

  @override
  Future<void> clearSettings() async {
    savedSettings = null;
  }
}

class _FakeAudioTranscoder implements IAudioTranscoderPort {
  final Uint8List transcodedWavBytes;
  final List<String> transcodedExtensions = <String>[];

  _FakeAudioTranscoder(this.transcodedWavBytes);

  @override
  bool isSupportedCompressedExtension(String extension) {
    final clean = extension.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    return IAudioTranscoderPort.compressedAudioExtensions.contains(clean);
  }

  @override
  Future<Uint8List?> transcodeToWav16BitPcm(
    Uint8List inputBytes, {
    required String fileExtension,
    int targetSampleRate = 44100,
    int channels = 1,
  }) async {
    transcodedExtensions.add(fileExtension);
    return transcodedWavBytes;
  }
}

Uint8List _buildMinimalMusicXmlBytes({required String title}) {
  final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work>
    <work-title>$title</work-title>
  </work>
  <part-list>
    <score-part id="P1">
      <part-name>Flauta</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
      </attributes>
      <note>
        <pitch>
          <step>C</step>
          <octave>5</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch>
          <step>E</step>
          <octave>5</octave>
        </pitch>
        <duration>4</duration>
        <type>quarter</type>
      </note>
    </measure>
  </part>
</score-partwise>''';
  return Uint8List.fromList(utf8.encode(xml));
}

Uint8List _buildSineWavBytes({
  double freqHz = 440.0,
  int sampleRate = 22050,
  double durationSeconds = 0.5,
}) {
  final numSamples = (sampleRate * durationSeconds).round();
  final dataSize = numSamples * 2;
  final buffer = ByteData(44 + dataSize);

  // RIFF header
  buffer.setUint8(0, 0x52); // R
  buffer.setUint8(1, 0x49); // I
  buffer.setUint8(2, 0x46); // F
  buffer.setUint8(3, 0x46); // F
  buffer.setUint32(4, 36 + dataSize, Endian.little);
  buffer.setUint8(8, 0x57); // W
  buffer.setUint8(9, 0x41); // A
  buffer.setUint8(10, 0x56); // V
  buffer.setUint8(11, 0x45); // E

  // fmt chunk
  buffer.setUint8(12, 0x66); // f
  buffer.setUint8(13, 0x6D); // m
  buffer.setUint8(14, 0x74); // t
  buffer.setUint8(15, 0x20); // ' '
  buffer.setUint32(16, 16, Endian.little); // PCM chunk size
  buffer.setUint16(20, 1, Endian.little); // PCM format
  buffer.setUint16(22, 1, Endian.little); // Mono
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little);
  buffer.setUint16(32, 2, Endian.little);
  buffer.setUint16(34, 16, Endian.little);

  // data chunk
  buffer.setUint8(36, 0x64); // d
  buffer.setUint8(37, 0x61); // a
  buffer.setUint8(38, 0x74); // t
  buffer.setUint8(39, 0x61); // a
  buffer.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    final sample = (math.sin(2.0 * math.pi * freqHz * i / sampleRate) * 16000).round();
    buffer.setInt16(44 + i * 2, sample.clamp(-32768, 32767), Endian.little);
  }

  return buffer.buffer.asUint8List();
}

StudioFileEntity? _findFileByName(StudioFolderEntity folder, String fileName) {
  for (final node in folder.children) {
    if (node is StudioFileEntity && node.name == fileName) {
      return node;
    }
    if (node is StudioFolderEntity) {
      final found = _findFileByName(node, fileName);
      if (found != null) return found;
    }
  }
  return null;
}

Future<void> _openExplorerAndTapFile(WidgetTester tester, String fileName) async {
  final explorerBtn = find.byKey(const Key('sidebar_mode_explorer_btn'));
  expect(explorerBtn, findsOneWidget);
  await tester.tap(explorerBtn);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  final target = find.text(fileName);
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  late _SpyMemoryStudioFileSystemRepository spyRepo;
  late StudioWorkspaceFileSystemService fsService;
  late TunerViewModel tunerViewModel;
  late _FakeAudioTranscoder fakeTranscoder;

  setUp(() {
    spyRepo = _SpyMemoryStudioFileSystemRepository();
    fakeTranscoder = _FakeAudioTranscoder(_buildSineWavBytes(freqHz: 523.25));
    fsService = StudioWorkspaceFileSystemService.isolated(fileSystemRepository: spyRepo);
    tunerViewModel = TunerViewModel(
      pitchService: _FakePitchService(),
      metronomeService: _FakeMetronomeService(),
      recorderService: _FakeRecorderService(),
      playbackService: _FakePlaybackService(),
      persistenceService: _FakePersistenceService(),
      scoreImporterService: const UniversalScoreImporterService(),
      audioTranscoder: fakeTranscoder,
    );
  });

  tearDown(() {
    fsService.dispose();
    tunerViewModel.dispose();
  });

  Widget createHarness({int initialIndex = 0}) {
    return ChangeNotifierProvider<TunerViewModel>.value(
      value: tunerViewModel,
      child: MaterialApp(
        home: MainAppShell(
          initialIndex: initialIndex,
          fileSystemService: fsService,
          audioTranscoder: fakeTranscoder,
        ),
      ),
    );
  }

  group('US-FS-04: Lectura Real desde Disco y Enrutamiento Dual', () {
    testWidgets(
      'Al abrir un .musicxml con payload == null desde el Explorador, lee bytes via readFile y actualiza activePackage',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1680, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const scorePath = '/Partituras & Notación/Oda_A_La_Alegria.musicxml';
        await spyRepo.saveFile(
          relativePath: scorePath,
          bytes: _buildMinimalMusicXmlBytes(title: 'Oda a la Alegria Real'),
        );

        await tester.pumpWidget(createHarness());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final scoreNode = _findFileByName(fsService.rootFolder, 'Oda_A_La_Alegria.musicxml');
        expect(scoreNode, isNotNull);
        expect(scoreNode!.payload, isNull);

        await _openExplorerAndTapFile(tester, 'Oda_A_La_Alegria.musicxml');

        expect(spyRepo.readPaths, contains(scorePath));
        expect(tunerViewModel.activePackage.title, 'Oda a la Alegria Real');
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 4);
      },
    );

    testWidgets(
      'Al abrir un .wav con payload == null, lee bytes via readFile, actualiza activePackage con 4 stems y enruta a Consola DJ desde Home',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1680, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const wavPath = '/Tomas de Audio & WAV/Flauta_Estudio.wav';
        await spyRepo.saveFile(
          relativePath: wavPath,
          bytes: _buildSineWavBytes(freqHz: 440.0),
        );

        await tester.pumpWidget(createHarness(initialIndex: 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final wavNode = _findFileByName(fsService.rootFolder, 'Flauta_Estudio.wav');
        expect(wavNode, isNotNull);
        expect(wavNode!.payload, isNull);

        await _openExplorerAndTapFile(tester, 'Flauta_Estudio.wav');

        expect(spyRepo.readPaths, contains(wavPath));
        expect(tunerViewModel.activePackage.title, 'Flauta_Estudio');
        expect(tunerViewModel.activePackage.tracks.length, 4);
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 5);
      },
    );

    testWidgets(
      'Al abrir un .mp3 sin cabecera RIFF con payload == null desde Partituras, transcodifica, actualiza activePackage y permanece en Partituras',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1680, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const mp3Path = '/Tomas de Audio & WAV/Solfeggio_Loop.mp3';
        // Bytes simulados sin cabecera RIFF ('ID3'...)
        await spyRepo.saveFile(
          relativePath: mp3Path,
          bytes: Uint8List.fromList(<int>[0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06]),
        );

        await tester.pumpWidget(createHarness(initialIndex: 4));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final mp3Node = _findFileByName(fsService.rootFolder, 'Solfeggio_Loop.mp3');
        expect(mp3Node, isNotNull);
        expect(mp3Node!.fileType, StudioFileType.audioWav);
        expect(mp3Node.payload, isNull);

        await _openExplorerAndTapFile(tester, 'Solfeggio_Loop.mp3');

        expect(spyRepo.readPaths, contains(mp3Path));
        expect(fakeTranscoder.transcodedExtensions, contains('mp3'));
        expect(tunerViewModel.activePackage.title, 'Solfeggio_Loop');
        expect(tunerViewModel.activePackage.tracks.length, 4);
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 4);
      },
    );

    testWidgets(
      'Al abrir un preset .tpreset con payload == null, lee JSON UTF-8 desde disco y calibra TunerViewModel',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const presetPath = '/Presets de Afinación/Barroco_415.tpreset';
        await spyRepo.saveFile(
          relativePath: presetPath,
          bytes: Uint8List.fromList(utf8.encode('{"referencePitch": 415.0}')),
        );

        await tester.pumpWidget(createHarness(initialIndex: 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final presetNode = _findFileByName(fsService.rootFolder, 'Barroco_415.tpreset');
        expect(presetNode, isNotNull);
        expect(presetNode!.payload, isNull);

        fsService.selectNode(presetNode.id);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(spyRepo.readPaths, contains(presetPath));
        expect(tunerViewModel.referencePitch, 415.0);
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 1);
      },
    );

    testWidgets(
      'Al abrir un .djblueprint con payload == null, lee JSON desde disco y navega a la Consola DJ',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1680, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const bpPath = '/Modelos Consola DJ/Club_Setup.djblueprint';
        await spyRepo.saveFile(
          relativePath: bpPath,
          bytes: Uint8List.fromList(utf8.encode('{"skinId": "cdj_3000"}')),
        );

        await tester.pumpWidget(createHarness(initialIndex: 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final bpNode = _findFileByName(fsService.rootFolder, 'Club_Setup.djblueprint');
        expect(bpNode, isNotNull);
        expect(bpNode!.payload, isNull);

        await _openExplorerAndTapFile(tester, 'Club_Setup.djblueprint');

        expect(spyRepo.readPaths, contains(bpPath));
        final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
        expect(stack.index, 5);
      },
    );
  });
}
