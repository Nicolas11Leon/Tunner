import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/i_audio_transcoder_port.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/features/media_vault/data/universal_media_io_service.dart';
import 'package:tunner/features/media_vault/domain/media_asset_entity.dart';
import 'package:tunner/features/metronome/domain/i_metronome_service.dart';
import 'package:tunner/features/persistence/data/memory_persistence_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_audio_playback_service.dart';
import 'package:tunner/features/practice_recorder/domain/i_practice_recorder_service.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/song_library/presentation/studio_assets_modals.dart';
import 'package:tunner/features/tuner/domain/i_pitch_detector_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';
import 'package:tunner/features/universal_importer/data/universal_score_importer_service.dart';

Uint8List _buildSineWavBytes({
  double frequencyHz = 440.0,
  int sampleRate = 44100,
  double durationSeconds = 0.5,
}) {
  final numSamples = (sampleRate * durationSeconds).round();
  final dataByteCount = numSamples * 2;
  final totalBytes = 44 + dataByteCount;
  final data = ByteData(totalBytes);

  // RIFF header
  data.setUint8(0, 0x52); // R
  data.setUint8(1, 0x49); // I
  data.setUint8(2, 0x46); // F
  data.setUint8(3, 0x46); // F
  data.setUint32(4, totalBytes - 8, Endian.little);
  data.setUint8(8, 0x57); // W
  data.setUint8(9, 0x41); // A
  data.setUint8(10, 0x56); // V
  data.setUint8(11, 0x45); // E

  // fmt chunk
  data.setUint8(12, 0x66); // f
  data.setUint8(13, 0x6D); // m
  data.setUint8(14, 0x74); // t
  data.setUint8(15, 0x20); // space
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // Mono
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);

  // data chunk
  data.setUint8(36, 0x64); // d
  data.setUint8(37, 0x61); // a
  data.setUint8(38, 0x74); // t
  data.setUint8(39, 0x61); // a
  data.setUint32(40, dataByteCount, Endian.little);

  for (var i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final sample = (math.sin(2 * math.pi * frequencyHz * t) * 16000).round();
    data.setInt16(44 + i * 2, sample, Endian.little);
  }
  return data.buffer.asUint8List();
}

class _FakeAudioTranscoder implements IAudioTranscoderPort {
  final List<String> transcodedExtensions = <String>[];

  @override
  bool isSupportedCompressedExtension(String extension) {
    final normalized = extension.trim().toLowerCase().replaceAll('.', '');
    return const <String>{'mp3', 'flac', 'ogg', 'm4a', 'aac', 'opus'}
        .contains(normalized);
  }

  @override
  Future<Uint8List?> transcodeToWav16BitPcm(
    Uint8List inputBytes, {
    required String fileExtension,
    int targetSampleRate = 44100,
    int channels = 1,
  }) async {
    transcodedExtensions.add(fileExtension.toLowerCase());
    if (!isSupportedCompressedExtension(fileExtension) || inputBytes.isEmpty) {
      return null;
    }
    return _buildSineWavBytes(sampleRate: targetSampleRate);
  }
}

class _FakeDiskBrowserFileGateway
    implements IPlatformFileGateway, IStudioDiskBrowserGateway {
  final Map<String, Uint8List> filesByPath;

  _FakeDiskBrowserFileGateway(this.filesByPath);

  @override
  Future<List<StudioQuickDirectory>> getQuickDirectories() async => const [
        StudioQuickDirectory(
          label: 'Música',
          path: '/home/user/Music',
          iconKey: 'music',
        ),
        StudioQuickDirectory(
          label: 'Descargas',
          path: '/home/user/Downloads',
          iconKey: 'downloads',
        ),
      ];

  @override
  Future<List<StudioDiskEntry>> listDirectoryEntries(
    String directoryPath, {
    Set<String>? allowedExtensions,
  }) async {
    if (directoryPath == '/home/user/Music') {
      final all = <StudioDiskEntry>[
        const StudioDiskEntry(
          name: 'SubcarpetaJazz',
          path: '/home/user/Music/SubcarpetaJazz',
          isDirectory: true,
        ),
        const StudioDiskEntry(
          name: 'backing_track_440.mp3',
          path: '/home/user/Music/backing_track_440.mp3',
          isDirectory: false,
          extensionName: 'mp3',
          sizeBytes: 2048,
        ),
        const StudioDiskEntry(
          name: 'estudio_clasico.musicxml',
          path: '/home/user/Music/estudio_clasico.musicxml',
          isDirectory: false,
          extensionName: 'musicxml',
          sizeBytes: 1024,
        ),
      ];
      if (allowedExtensions == null || allowedExtensions.isEmpty) return all;
      return all
          .where(
            (e) =>
                e.isDirectory ||
                allowedExtensions.contains(e.extensionName.toLowerCase()),
          )
          .toList(growable: false);
    }
    return const <StudioDiskEntry>[];
  }

  @override
  Future<Uint8List?> readFileBytes(String filePath) async =>
      filesByPath[filePath];

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async =>
      null;

  @override
  Future<String> getDocumentsDirectoryPath() async => '/home/user/Documents';

  @override
  Future<String> getTemporaryDirectoryPath() async => '/tmp';

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async =>
      '/tmp/$fileName';
}

class _StubPitchService extends IPitchDetectorService {
  @override
  Future<void> startRecording() async {}
  @override
  Future<void> stopRecording() async {}
}

class _StubMetronomeService implements IMetronomeService {
  @override
  Function(int)? onSubTick;
  @override
  Future<void> start(int bpm, {int ticksPerMeasure = 16}) async {}
  @override
  Future<void> stop() async {}
}

class _StubRecorderService implements IPracticeRecorderService {
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

class _StubPlaybackService implements IAudioPlaybackService {
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

TunerViewModel _createTestViewModel({
  required IAudioTranscoderPort transcoder,
  IPlatformFileGateway? fileGateway,
}) {
  return TunerViewModel(
    pitchService: _StubPitchService(),
    metronomeService: _StubMetronomeService(),
    recorderService: _StubRecorderService(),
    playbackService: _StubPlaybackService(),
    persistenceService: MemoryPersistenceService(),
    scoreImporterService: const UniversalScoreImporterService(),
    audioTranscoder: transcoder,
    platformFileGateway: fileGateway,
  );
}

void main() {
  group('MP3 Transcoding & Import', () {
    test('TunerViewModel.importScoreFromBytes transcodes .mp3 via port',
        () async {
      final fakeTranscoder = _FakeAudioTranscoder();
      final vm = _createTestViewModel(transcoder: fakeTranscoder);

      final fakeMp3Bytes = Uint8List.fromList([0x49, 0x44, 0x33, 0x03, 0x00]);
      final result = await vm.importScoreFromBytes(
        fakeMp3Bytes,
        'mi_pista_vocal.mp3',
      );

      expect(fakeTranscoder.transcodedExtensions, equals(['mp3']));
      expect(result, isNotNull);
      expect(result!.package.title, isNotEmpty);
      expect(result.package.score.measures, isNotEmpty);
      vm.dispose();
    });

    test('UniversalMediaIoService.importBytes decodes .mp3 into PCM asset',
        () async {
      final fakeTranscoder = _FakeAudioTranscoder();
      final ioService = UniversalMediaIoService(
        audioTranscoder: fakeTranscoder,
      );

      final fakeMp3Bytes = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x64]);
      final result = await ioService.importBytes(
        bytes: fakeMp3Bytes,
        fileName: 'groove_club.mp3',
      );

      expect(fakeTranscoder.transcodedExtensions, equals(['mp3']));
      expect(result.success, isTrue);
      expect(result.importedAssets, hasLength(1));
      final asset = result.importedAssets.first;
      expect(asset.kind, equals(MediaAssetKind.audioTrack));
      expect(asset.pcmSamples, isNotEmpty);
      expect(asset.waveformPeaks, isNotEmpty);
      expect(asset.durationMs, greaterThan(0));
    });
  });

  group('Didactic Studio File Browser Dialog', () {
    testWidgets(
      'Renders didactic disk browser, filters Audio vs Partituras, and imports MP3',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 950);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeTranscoder = _FakeAudioTranscoder();
        final fakeGateway = _FakeDiskBrowserFileGateway({
          '/home/user/Music/backing_track_440.mp3':
              Uint8List.fromList([0x49, 0x44, 0x33, 0x04]),
        });
        final vm = _createTestViewModel(
          transcoder: fakeTranscoder,
          fileGateway: fakeGateway,
        );
        addTearDown(vm.dispose);

        SongPackage? importedPackage;
        int? navigatedTab;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    StudioAssetsModals.showImportScoreDialog(
                      context: context,
                      viewModel: vm,
                      onNavigateToTab: (tab) => navigatedTab = tab,
                      onScoreImported: (pkg) => importedPackage = pkg,
                    );
                  },
                  child: const Text('Abrir Importador'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Importador'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('import_tab_disk_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('import_tab_library_btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('import_dialog_os_picker_btn')),
          findsOneWidget,
        );
        expect(find.text('Música'), findsOneWidget);
        expect(find.text('Descargas'), findsOneWidget);
        expect(find.text('backing_track_440.mp3'), findsOneWidget);
        expect(find.text('estudio_clasico.musicxml'), findsOneWidget);

        // Filter to Audio only
        await tester.tap(find.text('Audio (MP3 / WAV / FLAC / OGG)'));
        await tester.pumpAndSettle();
        expect(find.text('backing_track_440.mp3'), findsOneWidget);
        expect(find.text('estudio_clasico.musicxml'), findsNothing);

        // Tap Transcribir button on MP3 entry to import
        await tester.tap(find.text('Transcribir'));
        await tester.pumpAndSettle();

        expect(fakeTranscoder.transcodedExtensions, equals(['mp3']));
        expect(importedPackage, isNotNull);
        expect(navigatedTab, equals(4));
      },
    );
  });
}
