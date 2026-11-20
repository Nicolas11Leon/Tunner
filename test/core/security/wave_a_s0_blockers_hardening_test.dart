import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/app/studio_composition_root.dart';
import 'package:tunner/core/design_system/atoms/studio_theme_switcher.dart';
import 'package:tunner/core/design_system/molecules/studio_command_prompt_bar.dart';
import 'package:tunner/core/design_system/molecules/studio_tree_view.dart';
import 'package:tunner/core/design_system/organisms/studio_desktop_app_shell.dart';
import 'package:tunner/core/design_system/studio_design_tokens.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/core/file_system/data/local_disk_studio_file_system_repository.dart';
import 'package:tunner/core/packaging/domain/tunner_package_exceptions.dart';
import 'package:tunner/core/packaging/domain/tunner_project_manifest_entity.dart';
import 'package:tunner/core/packaging/domain/tunner_project_package_entity.dart';
import 'package:tunner/core/packaging/infrastructure/tunner_package_codec_service.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/core/terminal/presentation/tunner_os_terminal_drawer.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_export_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_audio_processor.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_reference_synth.dart';
import 'package:tunner/features/harmonic_tutor/domain/harmonic_role_entity.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/practice_recorder/domain/practice_recording_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/universal_importer/data/compressed_musicxml_parser.dart';
import 'package:tunner/features/vocal_autotune/domain/td_psola_pitch_shifter.dart';

void main() {
  group('Wave A S0 Blockers Regression Suite', () {
    test('LocalDiskStudioFileSystemRepository blocks OS absolute paths, ./ root wipe, and drive prefixes', () async {
      final rootDir = await Directory.systemTemp.createTemp('tunner_s0_fs_');
      try {
        final repo = LocalDiskStudioFileSystemRepository(customRootPath: rootDir.path);
        await repo.saveFile(relativePath: 'safe/keep.txt', bytes: Uint8List.fromList([1, 2, 3]));

        // Reading /etc/passwd must resolve inside sandbox (FileSystemException), NEVER OS /etc/passwd
        await expectLater(
          () => repo.readFile('/etc/passwd'),
          throwsA(isA<FileSystemException>()),
        );
        // Writing /tmp/outside_escape.txt must NOT create /tmp/outside_escape.txt on OS
        await repo.saveFile(relativePath: '/tmp/outside_escape.txt', bytes: Uint8List.fromList([9]));
        expect(File('/tmp/outside_escape.txt').existsSync(), isFalse);
        // Writing ${rootDir.path}Evil/pwn.txt must NOT escape outside rootDir
        await repo.saveFile(relativePath: '${rootDir.path}Evil/pwn.txt', bytes: Uint8List.fromList([9]));
        expect(File('${rootDir.path}Evil/pwn.txt').existsSync(), isFalse);
        await expectLater(
          () => repo.saveFile(relativePath: '../outside.txt', bytes: Uint8List.fromList([9])),
          throwsArgumentError,
        );
        await expectLater(
          () => repo.saveFile(relativePath: 'C:/Windows/evil.txt', bytes: Uint8List.fromList([9])),
          throwsArgumentError,
        );

        await expectLater(() => repo.deletePath('./'), throwsArgumentError);
        await expectLater(() => repo.deletePath('/./'), throwsArgumentError);
        await expectLater(() => repo.deletePath('.'), throwsArgumentError);

        final kept = await repo.readFile('safe/keep.txt');
        expect(kept, equals(Uint8List.fromList([1, 2, 3])));
      } finally {
        if (await rootDir.exists()) {
          await rootDir.delete(recursive: true);
        }
      }
    });

    test('TunnerPackageCodecService enforces 1:1 bidirectional SHA-256 and allows valid empty project', () {
      const codec = TunnerPackageCodecService();
      final now = DateTime.utc(2026, 11, 19);

      final emptyPkg = TunnerProjectPackageEntity(
        manifest: TunnerProjectManifestEntity(
          id: 'empty-1',
          title: 'Empty Project',
          bpm: 120.0,
          timeSignature: '4/4',
          createdAt: now,
          modifiedAt: now,
        ),
      );
      final emptyZip = codec.encodePackage(emptyPkg);
      final decodedEmpty = codec.decodePackage(emptyZip, verifyHashes: true);
      expect(decodedEmpty.manifest.title, equals('Empty Project'));

      // Partial tamper: unsigned extra file injected alongside valid fileHashes entry
      final archive = Archive();
      final validBytes = utf8.encode('{"ok":true}');
      final validHash = sha256.convert(validBytes).toString();
      archive.addFile(ArchiveFile('notation/score.json', validBytes.length, validBytes));
      final injectedBytes = utf8.encode('{"evil":true}');
      archive.addFile(ArchiveFile('audio_vault/unverified.wav', injectedBytes.length, injectedBytes));

      final manifestJson = jsonEncode(
        TunnerProjectManifestEntity(
          id: 'tamper-1',
          title: 'Tamper Test',
          bpm: 120.0,
          timeSignature: '4/4',
          createdAt: now,
          modifiedAt: now,
          fileHashes: {'notation/score.json': validHash},
        ).toJson(),
      );
      final manifestBytes = utf8.encode(manifestJson);
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      final tamperedZip = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        () => codec.decodePackage(tamperedZip, verifyHashes: true),
        throwsA(isA<TunnerPackageCorruptedException>()),
      );
    });

    test('CompressedMusicXmlParser blocks Zip-Slip entries inside .mxl archives', () async {
      const parser = CompressedMusicXmlParser();
      final archive = Archive();
      final evilBytes = utf8.encode('<score-partwise/>');
      archive.addFile(ArchiveFile('../../evil.xml', evilBytes.length, evilBytes));
      final mxlBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      await expectLater(
        () => parser.parseScoreData(bytes: mxlBytes, fileName: 'evil.mxl'),
        throwsFormatException,
      );
    });

    test('AppUserSettingsEntity.toMap preserves the 50 NEWEST recordings (index 0..49)', () {
      final recordings = <PracticeRecordingEntity>[];
      for (int i = 1; i <= 60; i++) {
        recordings.insert(
          0,
          PracticeRecordingEntity(
            id: 'rec_$i',
            filePath: '/tmp/take_$i.wav',
            recordedAt: DateTime(2026, 11, 19, 0, i),
            duration: const Duration(seconds: 5),
            songTitle: 'Take $i',
            bpm: 120,
          ),
        );
      }
      final settings = AppUserSettingsEntity(recordingHistory: recordings);
      final map = settings.toMap();
      final savedList = map['recordingHistory'] as List<dynamic>;
      expect(savedList.length, equals(50));
      expect((savedList.first as Map<String, dynamic>)['id'], equals('rec_60'));
      expect((savedList.last as Map<String, dynamic>)['id'], equals('rec_11'));
    });

    test('DjAudioProcessor and HarmonicReferenceSynth soft limiters are monotonic without foldback', () {
      final processor = DjAudioProcessor();
      final a = Float32List.fromList([1.2, 2.5, -1.2, -2.5]);
      final b = Float32List.fromList([0.0, 0.0, 0.0, 0.0]);
      final mixed = processor.mixBuffers(bufferA: a, bufferB: b, gainA: 1.0, gainB: 0.0);
      expect(mixed[0], greaterThan(0.85));
      expect(mixed[1], greaterThanOrEqualTo(mixed[0]));
      expect(mixed[1], lessThanOrEqualTo(1.0));
      expect(mixed[2], lessThan(-0.85));
      expect(mixed[3], lessThanOrEqualTo(mixed[2]));
      expect(mixed[3], greaterThanOrEqualTo(-1.0));

      final chord = HarmonicReferenceSynth(sampleRate: 44100).generateChordBuffer(
        rootFrequency: 220.0,
        roles: [HarmonicRole.root, HarmonicRole.majorThird, HarmonicRole.perfectFifth],
        durationMs: 50,
        volume: 1.0,
      );
      expect(chord.every((s) => s.abs() <= 1.0 && !s.isNaN), isTrue);
    });

    test('TdPsolaPitchShifter handles short buffers (< 48 samples) without ArgumentError', () {
      final shortBuf = Float64List.fromList([0.1, 0.2, -0.1, -0.2, 0.05]);
      final out = const TdPsolaPitchShifter().shiftPitch(
        inputSamples: shortBuf,
        detectedPitchHz: 440.0,
        pitchShiftRatio: 1.05,
        sampleRate: 44100,
      );
      expect(out.length, equals(shortBuf.length));
    });

    test('StemAudioSynthesizer resolves non-voice/piano curated track gains for Master Mixdown', () {
      const synth = StemAudioSynthesizer();
      final score = HierarchicalScore(
        title: 'Canon',
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: const TimeSignature(4, 4),
            notes: [HierarchicalNote.note(startTick: 0, durationTicks: 16, noteName: 'Do4')],
          ),
        ],
      );
      const mixer = MixerConsoleEntity(
        metronomeTrack: AudioTrack(id: 'metronome', title: 'Metronome', instrumentIcon: 'timer'),
        stems: [
          AudioTrack(id: 'violins', title: 'Violins', instrumentIcon: 'music_note', volume: 0.9),
          AudioTrack(id: 'continuo', title: 'Continuo', instrumentIcon: 'piano', volume: 0.8),
        ],
      );
      final bundle = synth.exportStemsAndMidi(
        score: score,
        bpm: 120,
        trackTitle: 'Canon',
        mixerConsole: mixer,
        config: const StemExportConfig(
          includeMasterMixdown: true,
          includeMelodyTrack: true,
          includeAccompanimentTrack: false,
          includeMetronomeTrack: false,
          includeMidiFile: false,
        ),
      );
      expect(bundle.files.isNotEmpty, isTrue);
      final masterFile = bundle.files.firstWhere((f) => f.fileName.contains('master_mixdown'));
      final wav = masterFile.bytes;
      final hasNonZero = wav.sublist(44).any((b) => b != 0);
      expect(hasNonZero, isTrue);
    });

    test('StudioCompositionRoot disposes cleanly without destroying shared audio channels prematurely', () {
      final root = StudioCompositionRoot.create();
      final tunerVm = root.createTunerViewModel(seedDefaults: false);
      final djVm = root.createDjConsoleViewModel();
      final rackVm = root.createModularRackViewModel();

      djVm.dispose();
      rackVm.dispose();
      tunerVm.dispose();
      root.dispose();
    });

    testWidgets('StudioThemeSwitcher handles custom imported theme IDs without DropdownButton crash', (tester) async {
      final controller = StudioThemeController();
      addTearDown(controller.dispose);
      final base = StudioDesignTokens.studioDark;
      controller.setTokens(
        StudioDesignTokens(
          id: 'custom_imported_skin_99',
          displayName: 'Custom Imported',
          brightness: base.brightness,
          canvasBackground: base.canvasBackground,
          panelBackground: base.panelBackground,
          panelHeaderBackground: base.panelHeaderBackground,
          elevatedSurface: base.elevatedSurface,
          inputSurface: base.inputSurface,
          hoverSurface: base.hoverSurface,
          borderHairline: base.borderHairline,
          borderSubtle: base.borderSubtle,
          borderFocus: base.borderFocus,
          accentPrimary: base.accentPrimary,
          accentSecondary: base.accentSecondary,
          accentSuccess: base.accentSuccess,
          accentWarning: base.accentWarning,
          accentDanger: base.accentDanger,
          textPrimary: base.textPrimary,
          textSecondary: base.textSecondary,
          textMuted: base.textMuted,
          textOnAccent: base.textOnAccent,
        ),
      );

      await tester.pumpWidget(
        StudioThemeScope(
          controller: controller,
          child: const MaterialApp(
            home: Scaffold(body: StudioThemeSwitcher()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('studio_theme_switcher_dropdown')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StudioCommandPromptBar survives rapid suggestion list reallocation while focused', (tester) async {
      final controller = StudioThemeController();
      addTearDown(controller.dispose);
      int tick = 0;

      await tester.pumpWidget(
        StudioThemeScope(
          controller: controller,
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: Column(
                    children: [
                      StudioCommandPromptBar(
                        onOpenHelp: () {},
                        suggestions: [
                          PromptSuggestion(
                            id: 'cmd_$tick',
                            trigger: '/',
                            command: '/afinar_$tick',
                            title: 'Afinar',
                            description: 'Abrir afinador',
                            category: 'Audio',
                            icon: Icons.tune,
                            onExecute: (_) {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 260),
                      TextButton(
                        onPressed: () => setState(() => tick++),
                        child: const Text('Rebuild'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.text('Rebuild'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('StudioDesktopAppShell Dual Split does not crash at 1280px or 900px width', (tester) async {
      final controller = StudioThemeController();
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        StudioThemeScope(
          controller: controller,
          child: MaterialApp(
            home: StudioDesktopAppShell(
              currentBreadcrumb: 'Inicio',
              navigationSections: [
                StudioTreeSection(
                  title: 'Principal',
                  items: [
                    StudioTreeItem(id: 'home', title: 'Inicio', icon: Icons.home, onSelect: () {}),
                  ],
                ),
              ],
              activeItemId: 'home',
              currentTabIndex: 0,
              activeView: const SizedBox.expand(),
              secondaryView: const SizedBox.expand(),
              onOpenSearch: () {},
              onOpenShortcuts: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('desktop_dual_split_btn')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('TunnerOsTerminalDrawer mounts, executes command, and disposes cleanly', (tester) async {
      final kernel = TunnerOsKernel();
      addTearDown(kernel.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TunnerOsTerminalDrawer(
              kernel: kernel,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'help');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
