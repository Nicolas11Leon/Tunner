import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'i_media_io_port.dart';
import 'media_asset_entity.dart';
import 'wav_pcm_codec.dart';

/// In-memory repository for the Multimedia Vault with deterministic seeded
/// offline demo assets materialized lazily on demand so construction never
/// blocks the UI thread with synchronous PCM synthesis.
class InMemoryMediaVaultRepository implements IMediaVaultRepository {
  static const List<String> _seedIds = <String>[
    'seed_house_groove',
    'seed_vocal_stem',
    'seed_flute_score',
    'seed_bassline_midi',
  ];

  static final Map<String, MediaAssetEntity> _cachedSeeds =
      <String, MediaAssetEntity>{};

  final Map<String, MediaAssetEntity> _assets = <String, MediaAssetEntity>{};
  final Set<String> _removedSeedIds = <String>{};
  bool _seeded;

  InMemoryMediaVaultRepository({bool seedDefaultAssets = true})
      : _seeded = !seedDefaultAssets;

  /// Indicates whether default demo seeds have already been materialized.
  bool get isSeeded => _seeded;

  @override
  List<MediaAssetEntity> getAll() {
    _ensureSeeded();
    return _assets.values.toList(growable: false);
  }

  @override
  MediaAssetEntity? findById(String id) {
    final existing = _assets[id];
    if (existing != null) {
      return existing;
    }
    if (!_seeded && !_removedSeedIds.contains(id) && _seedIds.contains(id)) {
      final seed = _materializeSeed(id);
      _assets[id] = seed;
      return seed;
    }
    return null;
  }

  @override
  void upsert(MediaAssetEntity asset) {
    _removedSeedIds.remove(asset.id);
    _assets[asset.id] = asset;
  }

  @override
  void upsertAll(List<MediaAssetEntity> assets) {
    for (final asset in assets) {
      _removedSeedIds.remove(asset.id);
      _assets[asset.id] = asset;
    }
  }

  @override
  void remove(String id) {
    _removedSeedIds.add(id);
    _assets.remove(id);
  }

  @override
  void clear() {
    _seeded = true;
    _removedSeedIds.addAll(_seedIds);
    _assets.clear();
  }

  void _ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    for (final id in _seedIds) {
      if (!_removedSeedIds.contains(id) && !_assets.containsKey(id)) {
        _assets[id] = _materializeSeed(id);
      }
    }
  }

  MediaAssetEntity _materializeSeed(String id) {
    return _cachedSeeds.putIfAbsent(id, () => _buildSeedAsset(id));
  }

  MediaAssetEntity _buildSeedAsset(String id) {
    const codec = WavPcmCodec();
    final now = DateTime.utc(2026, 11, 14);

    switch (id) {
      case 'seed_house_groove':
        final houseSamples = _generateMusicalSequence(
          44100,
          4000,
          const <double>[110.0, 110.0, 130.81, 146.83, 164.81, 146.83, 130.81, 110.0],
          amplitude: 0.42,
        );
        final houseWavBytes = codec.encodeMono16Bit(houseSamples, sampleRate: 44100);
        return MediaAssetEntity(
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
          rawBytes: houseWavBytes,
          waveformPeaks: codec.extractPeaks(houseSamples),
        );
      case 'seed_vocal_stem':
        final vocalStemSamples = _generateMusicalSequence(
          44100,
          4000,
          const <double>[440.0, 523.25, 587.33, 659.25, 587.33, 523.25, 493.88, 440.0],
          amplitude: 0.36,
        );
        final vocalWavBytes = codec.encodeMono16Bit(vocalStemSamples, sampleRate: 44100);
        return MediaAssetEntity(
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
          rawBytes: vocalWavBytes,
          waveformPeaks: codec.extractPeaks(vocalStemSamples),
        );
      case 'seed_flute_score':
        final fluteSamples = _generateMusicalSequence(
          44100,
          4000,
          const <double>[440.0, 493.88, 523.25, 587.33, 659.25, 698.46, 783.99, 880.0],
          amplitude: 0.30,
        );
        final fluteXmlBytes = Uint8List.fromList(utf8.encode(_seedMusicXmlContent()));
        return MediaAssetEntity(
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
          pcmSamples: fluteSamples,
          rawBytes: fluteXmlBytes,
          waveformPeaks: codec.extractPeaks(fluteSamples),
        );
      case 'seed_bassline_midi':
        final bassSamples = _generateMusicalSequence(
          44100,
          4000,
          const <double>[55.0, 65.41, 73.42, 82.41],
          amplitude: 0.45,
        );
        final bassMidiBytes = _seedMidiSmfBytes();
        return MediaAssetEntity(
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
          pcmSamples: bassSamples,
          rawBytes: bassMidiBytes,
          waveformPeaks: codec.extractPeaks(bassSamples),
        );
      default:
        throw ArgumentError.value(id, 'id', 'Unknown seed asset id');
    }
  }

  Float64List _generateMusicalSequence(
    int sampleRate,
    int durationMs,
    List<double> freqsHz, {
    double amplitude = 0.4,
  }) {
    final length = (sampleRate * durationMs) ~/ 1000;
    final out = Float64List(length);
    final stepLen = math.max(1, length ~/ freqsHz.length);
    for (int i = 0; i < length; i++) {
      final stepIdx = math.min(freqsHz.length - 1, i ~/ stepLen);
      final localIdx = i % stepLen;
      final localPos = localIdx / stepLen;
      final freqHz = freqsHz[stepIdx];
      final t = i / sampleRate;
      // Envolvente ADSR suave para evitar clics entre notas consecutivas.
      final attack = math.min(1.0, localPos / 0.08);
      final release = math.min(1.0, (1.0 - localPos) / 0.15);
      final env = math.min(attack, release);
      out[i] = (math.sin(2.0 * math.pi * freqHz * t) +
              0.25 * math.sin(4.0 * math.pi * freqHz * t)) *
          env *
          amplitude *
          0.8;
    }
    return out;
  }

  String _seedMusicXmlContent() {
    return '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<score-partwise version="3.1">\n'
        '  <work><work-title>Estudio Melodico en La Menor</work-title></work>\n'
        '  <part-list><score-part id="P1"><part-name>Flauta</part-name></score-part></part-list>\n'
        '  <part id="P1">\n'
        '    <measure number="1">\n'
        '      <attributes><divisions>1</divisions><key><fifths>0</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>\n'
        '      <note><pitch><step>A</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>\n'
        '      <note><pitch><step>B</step><octave>4</octave></pitch><duration>1</duration><type>quarter</type></note>\n'
        '      <note><pitch><step>C</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>\n'
        '      <note><pitch><step>E</step><octave>5</octave></pitch><duration>1</duration><type>quarter</type></note>\n'
        '    </measure>\n'
        '  </part>\n'
        '</score-partwise>';
  }

  Uint8List _seedMidiSmfBytes() {
    // SMF Type 0 valido (MThd + MTrk con 4 negras A2, C3, E3, G3 a 480 PPQ).
    return Uint8List.fromList(const <int>[
      0x4D, 0x54, 0x68, 0x64, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x01, 0x01, 0xE0,
      0x4D, 0x54, 0x72, 0x6B, 0x00, 0x00, 0x00, 0x24,
      0x00, 0x90, 0x2D, 0x60, 0x83, 0x60, 0x80, 0x2D, 0x00,
      0x00, 0x90, 0x30, 0x60, 0x83, 0x60, 0x80, 0x30, 0x00,
      0x00, 0x90, 0x34, 0x60, 0x83, 0x60, 0x80, 0x34, 0x00,
      0x00, 0x90, 0x37, 0x60, 0x83, 0x60, 0x80, 0x37, 0x00,
      0x00, 0xFF, 0x2F, 0x00,
    ]);
  }
}
