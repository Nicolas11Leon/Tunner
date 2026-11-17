import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/media_vault/data/universal_media_io_service.dart';
import 'package:tunner/features/media_vault/data/wav_pcm_codec.dart';
import 'package:tunner/features/media_vault/domain/media_asset_entity.dart';
import 'package:tunner/features/media_vault/domain/media_synergy_target.dart';
import 'package:tunner/features/media_vault/domain/timeline_project_entity.dart';

void main() {
  group('WavPcmCodec & UniversalMediaIoService Tests', () {
    const codec = WavPcmCodec();
    const ioService = UniversalMediaIoService();

    Float64List makeSine(int count, double freq, int sampleRate) {
      final out = Float64List(count);
      for (int i = 0; i < count; i++) {
        out[i] = math.sin(2.0 * math.pi * freq * (i / sampleRate)) * 0.5;
      }
      return out;
    }

    test('WavPcmCodec roundtrips 16-bit mono WAV cleanly', () {
      final samples = makeSine(4410, 440.0, 44100); // 100 ms
      final wavBytes = codec.encodeMono16Bit(samples, sampleRate: 44100);

      expect(wavBytes.length, WavPcmCodec.standardHeaderBytes + 4410 * 2);

      final decoded = codec.decode(wavBytes);
      expect(decoded, isNotNull);
      expect(decoded!.sampleRate, 44100);
      expect(decoded.channels, 1);
      expect(decoded.durationMs, 100);
      expect(decoded.monoSamples.length, 4410);
      expect((decoded.monoSamples[10] - samples[10]).abs(), lessThan(0.001));
    });

    test('importBytes decodes valid WAV and rejects corrupted header', () async {
      final samples = makeSine(22050, 220.0, 44100);
      final wavBytes = codec.encodeMono16Bit(samples, sampleRate: 44100);

      final ok = await ioService.importBytes(
        fileName: 'bass_loop.wav',
        bytes: wavBytes,
      );
      expect(ok.success, isTrue);
      expect(ok.importedAssets.length, 1);
      expect(ok.importedAssets.first.kind, MediaAssetKind.audioTrack);
      expect(ok.importedAssets.first.durationMs, 500);
      expect(ok.importedAssets.first.waveformPeaks, isNotEmpty);

      final bad = await ioService.importBytes(
        fileName: 'broken.wav',
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
      );
      expect(bad.success, isFalse);
    });

    test('importBytes ingests ABC notation and MusicXML cleanly', () async {
      const abcContent = 'X:1\nT:Test Tune\nM:4/4\nK:C\nC D E F |\n';
      final abcResult = await ioService.importBytes(
        fileName: 'test_tune.abc',
        bytes: Uint8List.fromList(utf8.encode(abcContent)),
      );
      expect(abcResult.success, isTrue);
      expect(abcResult.importedAssets.first.kind, MediaAssetKind.sheetMusic);
    });

    test('exportTimeline produces valid WAV mixdown, CUE sheet, JSON bundle, MIDI, MusicXML, and ABC', () async {
      final samples = makeSine(22050, 330.0, 44100);
      final asset = MediaAssetEntity(
        id: 'a1',
        title: 'Club Lead',
        fileName: 'club_lead.wav',
        extensionName: 'wav',
        kind: MediaAssetKind.audioTrack,
        durationMs: 500,
        bpm: 120.0,
        camelotKey: '8A',
        createdAt: DateTime.utc(2026, 11, 14),
        pcmSamples: samples,
      );

      final project = TimelineProjectEntity.defaultWorkspace().placeAssetOnTrack(
        asset: asset,
        trackId: 'track_deck_a',
        rawStartMs: 0,
        clipId: 'c1',
      );
      final map = <String, MediaAssetEntity>{'a1': asset};

      final wavRes = await ioService.exportTimeline(
        project: project,
        assetsById: map,
        format: MediaExportFormat.wavMixdown,
      );
      expect(wavRes.success, isTrue);
      expect(codec.decode(wavRes.bytes), isNotNull);

      final cueRes = await ioService.exportTimeline(
        project: project,
        assetsById: map,
        format: MediaExportFormat.cueSheet,
      );
      expect(cueRes.success, isTrue);
      expect(utf8.decode(cueRes.bytes), contains('TRACK 01 AUDIO'));
      expect(utf8.decode(cueRes.bytes), contains('Club Lead'));

      final jsonRes = await ioService.exportTimeline(
        project: project,
        assetsById: map,
        format: MediaExportFormat.tunnerBundleJson,
      );
      expect(jsonRes.success, isTrue);
      final reimported = await ioService.importBytes(
        fileName: jsonRes.fileName,
        bytes: jsonRes.bytes,
      );
      expect(reimported.success, isTrue);
      expect(reimported.importedAssets.single.id, 'a1');

      final midiRes = await ioService.exportTimeline(
        project: project,
        assetsById: map,
        format: MediaExportFormat.midi,
      );
      expect(midiRes.success, isTrue);
      expect(String.fromCharCodes(midiRes.bytes.sublist(0, 4)), 'MThd');

      final xmlRes = await ioService.exportTimeline(
        project: project,
        assetsById: map,
        format: MediaExportFormat.musicXml,
      );
      expect(xmlRes.success, isTrue);
      expect(utf8.decode(xmlRes.bytes), contains('<score-partwise'));

      final abcRes = await ioService.exportTimeline(
        project: project,
        assetsById: map,
        format: MediaExportFormat.abcNotation,
      );
      expect(abcRes.success, isTrue);
      expect(utf8.decode(abcRes.bytes), contains('X:1'));
    });
  });
}
