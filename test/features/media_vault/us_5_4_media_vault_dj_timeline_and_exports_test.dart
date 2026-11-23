import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/features/media_vault/data/universal_media_io_service.dart';
import 'package:tunner/features/media_vault/domain/media_synergy_target.dart';
import 'package:tunner/features/media_vault/domain/wav_pcm_codec.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_viewmodel.dart';
import 'package:tunner/features/media_vault/presentation/media_vault_workspace_modal.dart';

void main() {
  test('US-5.4: UniversalMediaIoService exporta notas reales en MIDI/MusicXML/ABC y restaura timeline/rawBytes en JSON', () async {
    const io = UniversalMediaIoService();
    final vm = MediaVaultViewModel(ioService: io);
    final scoreAsset = vm.allAssets.firstWhere((a) => a.id == 'seed_house_groove');
    vm.dropAssetOnTrack(asset: scoreAsset, trackId: 'track_deck_a', dropMs: 1000);

    final midiRes = await vm.exportTimeline(MediaExportFormat.midi);
    expect(midiRes.success, isTrue);
    expect(midiRes.bytes.length, greaterThan(30));

    final xmlRes = await vm.exportTimeline(MediaExportFormat.musicXml);
    expect(xmlRes.success, isTrue);
    final xmlText = String.fromCharCodes(xmlRes.bytes);
    expect(xmlText.contains('<pitch>'), isTrue);
    expect(xmlText.contains('<rest/><duration>4</duration>'), isFalse);

    final abcRes = await vm.exportTimeline(MediaExportFormat.abcNotation);
    expect(abcRes.success, isTrue);
    final abcText = String.fromCharCodes(abcRes.bytes);
    expect(abcText.contains('z4 |]'), isFalse);

    final jsonRes = await vm.exportTimeline(MediaExportFormat.tunnerBundleJson);
    expect(jsonRes.success, isTrue);

    final vm2 = MediaVaultViewModel(ioService: io);
    final importRes = await vm2.importExternalBytes(
      fileName: jsonRes.fileName,
      bytes: jsonRes.bytes,
    );
    expect(importRes.success, isTrue);
    expect(importRes.restoredTimeline, isNotNull);
    expect(vm2.timeline.tracks.first.clips.length, 1);
    expect(
      vm2.timeline.tracks.first.clips.first.startMs,
      vm.timeline.tracks.first.clips.first.startMs,
    );

    vm.dispose();
    vm2.dispose();
  });

  test('US-5.4: importBytes estima BPM y Camelot reales al importar WAV', () async {
    const io = UniversalMediaIoService();
    const codec = WavPcmCodec();
    const sr = 22050;
    const totalSec = 3;
    final samples = Float64List(sr * totalSec);
    // Pulsos a 140 BPM (~0.428s por beat) con tono C5 (523.25 Hz)
    final beatSamples = (sr * 60.0 / 140.0).round();
    for (int i = 0; i < samples.length; i++) {
      final posInBeat = i % beatSamples;
      final env = posInBeat < 1200 ? (1.0 - posInBeat / 1200.0) : 0.05;
      samples[i] = math.sin(2.0 * math.pi * 523.25 * (i / sr)) * env * 0.8;
    }
    final wavBytes = codec.encodeMono16Bit(samples, sampleRate: sr);

    final res = await io.importBytes(fileName: 'beat_140_c5.wav', bytes: wavBytes);
    expect(res.success, isTrue);
    expect(res.importedAssets.length, 1);
    final imported = res.importedAssets.first;
    expect(imported.bpm, greaterThan(60.0));
    expect(imported.camelotKey.isNotEmpty, isTrue);
  });

  testWidgets('US-5.4: MediaVaultWorkspaceModal soporta menu track_sampler_sfx, waveformPeaks y moveClip por arrastre', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final vm = MediaVaultViewModel(ioService: const UniversalMediaIoService());
    final house = vm.allAssets.firstWhere((a) => a.id == 'seed_house_groove');
    vm.dropAssetOnTrack(asset: house, trackId: 'track_deck_a', dropMs: 0);
    final clip = vm.timeline.tracks.first.clips.first;

    await tester.pumpWidget(
      StudioThemeScope(
        controller: StudioThemeController(),
        child: MaterialApp(
          home: Scaffold(
            body: MediaVaultWorkspaceModal(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Waveform painter montado dentro del clip
    final clipFinder = find.byKey(Key('timeline_clip_${clip.clipId}'));
    expect(clipFinder, findsOneWidget);
    expect(
      find.descendant(of: clipFinder, matching: find.byType(CustomPaint)),
      findsWidgets,
    );

    // Arrastrar clip horizontalmente debe invocar moveClip
    await tester.drag(clipFinder, const Offset(160, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(vm.timeline.tracks.first.clips.first.startMs, greaterThan(0));

    // Menu contextual incluye track_sampler_sfx
    final menuBtn = find.byTooltip('Sincronizar o agregar a pista').first;
    await tester.tap(menuBtn);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Agregar a Pista Sampler / SFX'), findsOneWidget);

    vm.dispose();
  });
}
