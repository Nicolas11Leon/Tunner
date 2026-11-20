import 'dart:math' as math;
import 'dart:typed_data';

import 'i_media_io_port.dart';
import 'media_asset_entity.dart';
import 'wav_pcm_codec.dart';

/// In-memory repository for the Multimedia Vault with deterministic seeded
/// offline demo assets so the workspace is immediately interactive.
class InMemoryMediaVaultRepository implements IMediaVaultRepository {
  final Map<String, MediaAssetEntity> _assets = <String, MediaAssetEntity>{};

  InMemoryMediaVaultRepository({bool seedDefaultAssets = true}) {
    if (seedDefaultAssets) {
      _seedDefaults();
    }
  }

  @override
  List<MediaAssetEntity> getAll() =>
      _assets.values.toList(growable: false);

  @override
  MediaAssetEntity? findById(String id) => _assets[id];

  @override
  void upsert(MediaAssetEntity asset) {
    _assets[asset.id] = asset;
  }

  @override
  void upsertAll(List<MediaAssetEntity> assets) {
    for (final asset in assets) {
      _assets[asset.id] = asset;
    }
  }

  @override
  void remove(String id) {
    _assets.remove(id);
  }

  @override
  void clear() {
    _assets.clear();
  }

  void _seedDefaults() {
    const codec = WavPcmCodec();
    final houseSamples = _generateDemoPulse(44100, 4000, 110.0);
    final vocalStemSamples = _generateDemoPulse(44100, 4000, 440.0);
    final now = DateTime.utc(2026, 11, 14);

    upsertAll(<MediaAssetEntity>[
      MediaAssetEntity(
        id: 'seed_house_groove',
        title: 'Midnight Groove 124',
        fileName: 'midnight_groove_124.wav',
        extensionName: 'wav',
        kind: MediaAssetKind.audioTrack,
        durationMs: 4000,
        bpm: 124.0,
        camelotKey: '8A',
        tags: const <String>['house', 'club', 'master'],
        createdAt: now,
        pcmSamples: houseSamples,
        waveformPeaks: codec.extractPeaks(houseSamples),
      ),
      MediaAssetEntity(
        id: 'seed_vocal_stem',
        title: 'Skyline Acapella Stem',
        fileName: 'skyline_vocals_stem.wav',
        extensionName: 'wav',
        kind: MediaAssetKind.stem,
        durationMs: 4000,
        bpm: 124.0,
        camelotKey: '9A',
        tags: const <String>['vocals', 'stem'],
        createdAt: now,
        pcmSamples: vocalStemSamples,
        waveformPeaks: codec.extractPeaks(vocalStemSamples),
      ),
      MediaAssetEntity(
        id: 'seed_flute_score',
        title: 'Estudio Melodico en La Menor',
        fileName: 'estudio_la_menor.musicxml',
        extensionName: 'musicxml',
        kind: MediaAssetKind.sheetMusic,
        durationMs: 8000,
        bpm: 124.0,
        camelotKey: '8A',
        tags: const <String>['partitura', 'flauta', 'musicxml'],
        createdAt: now,
      ),
      MediaAssetEntity(
        id: 'seed_bassline_midi',
        title: 'Sub Bassline Pattern 01',
        fileName: 'sub_bassline_01.mid',
        extensionName: 'mid',
        kind: MediaAssetKind.midiSequence,
        durationMs: 4000,
        bpm: 124.0,
        camelotKey: '8A',
        tags: const <String>['midi', 'bass'],
        createdAt: now,
      ),
    ]);
  }

  Float64List _generateDemoPulse(int sampleRate, int durationMs, double freqHz) {
    final length = (sampleRate * durationMs) ~/ 1000;
    final out = Float64List(length);
    for (int i = 0; i < length; i++) {
      final t = i / sampleRate;
      final beatEnv = 0.5 + 0.5 * math.cos(2.0 * math.pi * 2.0 * t);
      out[i] = math.sin(2.0 * math.pi * freqHz * t) * beatEnv * 0.4;
    }
    return out;
  }
}
