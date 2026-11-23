import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/i_studio_audio_channel.dart';
import 'package:tunner/core/audio/domain/i_studio_audio_engine.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_node.dart';
import 'package:tunner/core/file_system/domain/studio_file_system_repository.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/media_vault/data/universal_media_io_service.dart';
import 'package:tunner/features/media_vault/domain/in_memory_media_vault_repository.dart';
import 'package:tunner/features/media_vault/domain/media_asset_entity.dart';
import 'package:tunner/features/media_vault/domain/wav_pcm_codec.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';

class _SpyAudioEngine implements IStudioAudioEngine {
  int stopAllCalls = 0;
  int pauseAllCalls = 0;

  @override
  IStudioAudioChannel getChannel(String channelId) =>
      throw UnimplementedError();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> pauseAll() async {
    pauseAllCalls++;
  }

  @override
  Future<void> stopAll() async {
    stopAllCalls++;
  }
}

class _SpyAudioSynthesizer extends NoOpAudioSynthesizerService {
  final List<Uint8List> playedWavs = <Uint8List>[];

  @override
  Future<void> playPcmWav(Uint8List wavBytes, {double volume = 0.8}) async {
    playedWavs.add(wavBytes);
  }
}

class _InMemoryDiskFileSystemRepo implements StudioFileSystemRepository {
  final Map<String, Uint8List> files = <String, Uint8List>{};

  @override
  Future<void> createFolder(String relativePath) async {}

  @override
  Future<void> deletePath(String relativePath) async {
    files.remove(relativePath);
  }

  @override
  Future<StudioFolderEntity> loadRootWorkspace() async => const StudioFolderEntity(
        id: 'root',
        name: 'Root',
        relativePath: '/',
        modifiedAtMicros: 0,
      );

  @override
  Future<void> movePath({
    required String oldRelativePath,
    required String newRelativePath,
  }) async {
    final data = files.remove(oldRelativePath);
    if (data != null) {
      files[newRelativePath] = data;
    }
  }

  @override
  Future<Uint8List> readFile(String relativePath) async =>
      files[relativePath] ?? Uint8List(0);

  @override
  Future<void> saveFile({
    required String relativePath,
    required Uint8List bytes,
  }) async {
    files[relativePath] = bytes;
  }

  @override
  Future<bool> openInSystemExplorer(String relativePath) async => false;
}

void main() {
  test('US-5.3: InMemoryMediaVaultRepository puebla rawBytes y pcmSamples reales en las 4 semillas', () {
    final repo = InMemoryMediaVaultRepository();
    final assets = repo.getAll();
    expect(assets.length, 4);
    for (final asset in assets) {
      expect(asset.rawBytes, isNotNull, reason: '${asset.id} debe tener rawBytes');
      expect(asset.rawBytes!.isNotEmpty, isTrue, reason: '${asset.id} rawBytes no vacio');
      expect(asset.pcmSamples, isNotNull, reason: '${asset.id} debe tener pcmSamples');
      expect(asset.pcmSamples!.isNotEmpty, isTrue, reason: '${asset.id} pcmSamples no vacio');
      expect(asset.waveformPeaks.isNotEmpty, isTrue, reason: '${asset.id} waveformPeaks no vacio');
    }
  });

  test('US-5.3: togglePlayback reproduce mixdown real y Mute/Solo actualizan en vivo', () async {
    final engine = _SpyAudioEngine();
    final synth = _SpyAudioSynthesizer();
    final vm = MediaVaultViewModel(
      ioService: const UniversalMediaIoService(),
      audioEngine: engine,
      audioSynthesizer: synth,
    );

    final house = vm.allAssets.firstWhere((a) => a.id == 'seed_house_groove');
    final trackId = vm.timeline.tracks.first.trackId;
    vm.dropAssetOnTrack(asset: house, trackId: trackId, dropMs: 0);

    vm.togglePlayback();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(vm.isPlaying, isTrue);
    expect(synth.playedWavs.length, 1);
    expect(synth.playedWavs.first.length, greaterThan(44));

    // Mute en vivo detiene el motor y evita relanzar si no hay pistas audibles
    vm.toggleTrackMute(trackId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(engine.stopAllCalls, greaterThanOrEqualTo(1));
    expect(synth.playedWavs.length, 1);

    // Desmutear en vivo relanza inmediatamente el audio
    vm.toggleTrackMute(trackId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(synth.playedWavs.length, 2);

    // Solo en vivo también relanza audio
    vm.toggleTrackSolo(trackId);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(synth.playedWavs.length, 3);

    vm.stopPlayback();
    expect(vm.isPlaying, isFalse);
    expect(vm.playheadMs, 0);
    expect(engine.stopAllCalls, greaterThanOrEqualTo(3));

    vm.dispose();
  });

  test('US-5.3: catalogo de MediaVault se persiste y restaura desde StudioFileSystemRepository', () async {
    final fs = _InMemoryDiskFileSystemRepo();
    const codec = WavPcmCodec();
    final samples = Float64List.fromList(List<double>.generate(441, (i) => (i % 20) / 20.0));
    final wavBytes = codec.encodeMono16Bit(samples, sampleRate: 44100);

    final vm1 = MediaVaultViewModel(
      repository: InMemoryMediaVaultRepository(seedDefaultAssets: false),
      fileSystemRepository: fs,
    );
    vm1.registerAsset(
      MediaAssetEntity(
        id: 'custom_take_1',
        title: 'Toma Persistida',
        fileName: 'toma_persistida.wav',
        extensionName: 'wav',
        kind: MediaAssetKind.practiceRecording,
        durationMs: 10,
        createdAt: DateTime.utc(2026, 11, 22),
        pcmSamples: samples,
        rawBytes: wavBytes,
        waveformPeaks: codec.extractPeaks(samples),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fs.files.containsKey(MediaVaultViewModel.catalogStorageRelativePath), isTrue);
    vm1.dispose();

    final vm2 = MediaVaultViewModel(
      repository: InMemoryMediaVaultRepository(seedDefaultAssets: false),
      fileSystemRepository: fs,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(vm2.allAssets.length, 1);
    expect(vm2.allAssets.first.id, 'custom_take_1');
    expect(vm2.allAssets.first.rawBytes, isNotNull);
    expect(vm2.allAssets.first.pcmSamples, isNotNull);
    vm2.dispose();
  });
}
