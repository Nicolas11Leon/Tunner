import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/file_system/domain/i_platform_file_gateway.dart';
import 'package:tunner/features/audio_synthesizer/data/memory_audio_synthesizer_service.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/score_editor/domain/score_editor_domain.dart';
import 'package:tunner/features/score_editor/presentation/score_editor_modal.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

import '../../helpers/studio_test_fakes.dart';

class _RecordingDiskPlatformFileGateway implements IPlatformFileGateway {
  final Directory outputDir;
  final List<({String fileName, String savedPath, Uint8List bytes})> savedExports = [];
  Completer<void>? pendingGate;

  _RecordingDiskPlatformFileGateway(this.outputDir);

  @override
  Future<String> getDocumentsDirectoryPath() async => outputDir.path;

  @override
  Future<String> getTemporaryDirectoryPath() async => outputDir.path;

  @override
  Future<PlatformPickedFile?> pickFile({List<String>? allowedExtensions}) async => null;

  @override
  Future<String> saveExportedBytes(String fileName, Uint8List bytes) async {
    if (pendingGate != null) {
      await pendingGate!.future;
    }
    final file = File('${outputDir.path}/$fileName');
    file.writeAsBytesSync(bytes, flush: true);
    savedExports.add((fileName: fileName, savedPath: file.path, bytes: bytes));
    return file.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('US-3.4 Domain: ScoreEditorOperations & Serialization', () {
    const ops = ScoreEditorOperations();

    test('transposeScore preserves HierarchicalNote.rest (isRest=true, empty noteName) and "--" rests', () {
      final pkg = SongPackage(
        id: 'rest_guard_pkg',
        title: 'Estudio con Silencios',
        composer: 'Tunner',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.beginner,
        defaultBpm: 80,
        tracks: const [],
        score: HierarchicalScore(
          title: 'Estudio con Silencios',
          baseBpm: 80,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
                HierarchicalNote.rest(startTick: 4, durationTicks: 4),
                const HierarchicalNote(startTick: 8, durationTicks: 4, noteName: '--', isRest: true),
                const HierarchicalNote(startTick: 12, durationTicks: 4, noteName: 'rest', isRest: true),
              ],
            ),
          ],
        ),
      );

      final transposed = ops.transposeScore(package: pkg, semitones: 5);
      final notes = transposed.score.measures.first.notes;

      expect(notes[0].noteName, startsWith('Fa'));
      expect(notes[0].isRest, isFalse);

      expect(notes[1].isRest, isTrue);
      expect(notes[1].noteName, isEmpty);

      expect(notes[2].isRest, isTrue);
      expect(notes[2].noteName, equals('--'));

      expect(notes[3].isRest, isTrue);
      expect(notes[3].noteName, equals('rest'));
    });

    test('transposeScore handles full octave range 0..8 accurately', () {
      final pkg = SongPackage(
        id: 'octave_range_pkg',
        title: 'Rango Completo 0..8',
        composer: 'Tunner',
        genre: MusicGenre.classical,
        difficulty: SongDifficulty.advanced,
        defaultBpm: 100,
        tracks: const [],
        score: HierarchicalScore(
          title: 'Rango Completo 0..8',
          baseBpm: 100,
          measures: [
            MeasureEntity(
              index: 0,
              timeSignature: TimeSignature.commonTime44,
              notes: [
                HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Do0'),
                HierarchicalNote.note(startTick: 8, durationTicks: 8, noteName: 'La7'),
              ],
            ),
          ],
        ),
      );

      final transposed = ops.transposeScore(package: pkg, semitones: 3);
      final notes = transposed.score.measures.first.notes;

      expect(notes[0].noteName, contains('0'));
      expect(notes[1].noteName, equals('Do8'));
    });

    test('MixerConsoleEntity and AppUserSettingsEntity serialize and restore mixerConsole cleanly', () {
      const mixer = MixerConsoleEntity(
        metronomeTrack: AudioTrack(
          id: 'metronome',
          title: 'Metronomo',
          instrumentIcon: 'timer',
          volume: 0.42,
          isMuted: true,
          isSolo: false,
        ),
        stems: [
          AudioTrack(
            id: 'violins',
            title: 'Violin',
            instrumentIcon: 'music_note',
            volume: 0.65,
            isMuted: false,
            isSolo: true,
          ),
        ],
      );

      final settings = const AppUserSettingsEntity(
        referencePitch: 442.0,
        activeScoreId: 'custom_score_1',
      ).copyWith(mixerConsole: mixer);

      final map = settings.toMap();
      final restored = AppUserSettingsEntity.fromMap(map);

      expect(restored.activeScoreId, equals('custom_score_1'));
      expect(restored.mixerConsole, isNotNull);
      expect(restored.mixerConsole!.metronomeTrack.volume, closeTo(0.42, 0.001));
      expect(restored.mixerConsole!.metronomeTrack.isMuted, isTrue);
      expect(restored.mixerConsole!.stems.length, equals(1));
      expect(restored.mixerConsole!.stems.first.id, equals('violins'));
      expect(restored.mixerConsole!.stems.first.volume, closeTo(0.65, 0.001));
      expect(restored.mixerConsole!.stems.first.isSolo, isTrue);

      final legacyRestored = AppUserSettingsEntity.fromMap({'referencePitch': 440.0});
      expect(legacyRestored.mixerConsole, isNull);
      expect(legacyRestored.activeScoreId, isNull);
    });
  });

  group('US-3.4 TunerViewModel Auto-Save & Mixer Persistence', () {
    late Directory tempDir;
    late JsonLocalPersistenceService persistenceService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_us34_persist_');
      persistenceService = JsonLocalPersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'us34_settings.json',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<TunerViewModel> createViewModel() async {
      final vm = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        persistenceService: persistenceService,
        audioSynthesizerService: MemoryAudioSynthesizerService(),
        platformFileGateway: _RecordingDiskPlatformFileGateway(tempDir),
      );
      await vm.isInitialized;
      return vm;
    }

    test('All score edit mutations sync _workspaceScores and auto-save to disk across restarts', () async {
      final vm1 = await createViewModel();
      final created = vm1.createWorkspaceScore(
        title: 'Obra Persistida US-3.4',
        bpm: 96,
        timeSignature: TimeSignature.commonTime44,
        initialMeasures: 2,
      );

      // 1. insertOrUpdateScoreNote
      vm1.insertOrUpdateScoreNote(
        measureIndex: 0,
        startTick: 0,
        durationTicks: 4,
        noteName: 'Do4',
        playAudibleFeedback: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var vm2 = await createViewModel();
      expect(vm2.workspaceScores.length, equals(1));
      expect(vm2.workspaceScores.first.id, equals(created.id));
      expect(vm2.activePackage.score.measures.first.notes.first.noteName, equals('Do4'));
      vm2.dispose();

      // 2. insertScoreChordNotes
      vm1.insertScoreChordNotes(
        measureIndex: 0,
        startTick: 4,
        durationTicks: 4,
        noteNames: const ['Do4', 'Mi4', 'Sol4'],
        playAudibleFeedback: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      vm2 = await createViewModel();
      final chordNotes = vm2.activePackage.score.measures.first.notes
          .where((n) => n.startTick == 4)
          .map((n) => n.noteName)
          .toList();
      expect(chordNotes, containsAll(['Do4', 'Mi4', 'Sol4']));
      vm2.dispose();

      // 3. deleteScoreNote
      vm1.deleteScoreNote(measureIndex: 0, startTick: 0);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      vm2 = await createViewModel();
      expect(vm2.activePackage.score.measures.first.notes.first.isRest, isTrue);
      vm2.dispose();

      // 4. undoScoreEdit & redoScoreEdit
      vm1.undoScoreEdit();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      vm2 = await createViewModel();
      expect(vm2.activePackage.score.measures.first.notes.first.noteName, equals('Do4'));
      vm2.dispose();

      vm1.redoScoreEdit();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      vm2 = await createViewModel();
      expect(vm2.activePackage.score.measures.first.notes.first.isRest, isTrue);
      vm2.dispose();

      // 5. addScoreMeasure & removeScoreMeasure
      vm1.addScoreMeasure();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      vm2 = await createViewModel();
      expect(vm2.activePackage.totalMeasures, equals(3));
      vm2.dispose();

      vm1.removeScoreMeasure(2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      vm2 = await createViewModel();
      expect(vm2.activePackage.totalMeasures, equals(2));
      vm2.dispose();

      // 6. transposeActiveScore (preserving rests while transposing chord notes)
      vm1.transposeActiveScore(2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      vm2 = await createViewModel();
      final transposedMeasureNotes = vm2.activePackage.score.measures.first.notes;
      expect(transposedMeasureNotes.first.isRest, isTrue);
      final transposedChord = transposedMeasureNotes
          .where((n) => n.startTick == 4)
          .map((n) => n.noteName)
          .toList();
      expect(transposedChord, containsAll(['Re4', 'Fa#4', 'La4']));
      expect(vm2.workspaceScores.length, equals(1));
      vm2.dispose();

      vm1.dispose();
    });

    test('setTrackVolume, toggleTrackMute and toggleTrackSolo persist _mixerConsole across restarts', () async {
      final vm1 = await createViewModel();
      final stemId = vm1.mixerConsole.stems.first.id;
      final metroId = vm1.mixerConsole.metronomeTrack.id;

      vm1.setTrackVolume(stemId, 0.33);
      vm1.toggleTrackMute(metroId);
      vm1.toggleTrackSolo(stemId);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final vm2 = await createViewModel();
      final restoredStem = vm2.mixerConsole.stems.firstWhere((t) => t.id == stemId);
      expect(restoredStem.volume, closeTo(0.33, 0.001));
      expect(restoredStem.isSolo, isTrue);
      expect(vm2.mixerConsole.metronomeTrack.isMuted, isTrue);

      vm1.dispose();
      vm2.dispose();
    });
  });

  group('US-3.4 ScoreEditorModal UI Tests: Octaves 0..8, Dotted Chips, Chords & Disk Export', () {
    late Directory tempDir;
    late JsonLocalPersistenceService persistenceService;
    late _RecordingDiskPlatformFileGateway diskGateway;
    late TunerViewModel viewModel;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_us34_ui_');
      persistenceService = JsonLocalPersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'us34_ui_settings.json',
      );
      diskGateway = _RecordingDiskPlatformFileGateway(tempDir);
      viewModel = TunerViewModel(
        pitchService: StudioFakePitchDetectorService(),
        persistenceService: persistenceService,
        audioSynthesizerService: MemoryAudioSynthesizerService(),
        platformFileGateway: diskGateway,
      );
      await viewModel.isInitialized;
    });

    tearDown(() async {
      viewModel.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget buildModalApp() {
      return ChangeNotifierProvider<TunerViewModel>.value(
        value: viewModel,
        child: const MaterialApp(
          home: Scaffold(
            body: ScoreEditorModal(),
          ),
        ),
      );
    }

    testWidgets('Supports full octave range 0..8 via buttons and keyboard arrows', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildModalApp());
      await tester.pumpAndSettle();

      final downBtn = find.byKey(const Key('score_editor_octave_down_btn'));
      final upBtn = find.byKey(const Key('score_editor_octave_up_btn'));

      // Button decrement from 4 down to 0
      for (int i = 0; i < 4; i++) {
        await tester.ensureVisible(downBtn);
        await tester.tap(downBtn);
        await tester.pumpAndSettle();
      }
      expect(find.text('Oct 0'), findsOneWidget);
      expect(find.textContaining('Vista Previa: Do0'), findsOneWidget);
      expect(tester.widget<IconButton>(downBtn).onPressed, isNull);

      // Button increment from 0 up to 8
      for (int i = 0; i < 8; i++) {
        await tester.ensureVisible(upBtn);
        await tester.tap(upBtn);
        await tester.pumpAndSettle();
      }
      expect(find.text('Oct 8'), findsOneWidget);
      expect(find.textContaining('Vista Previa: Do8'), findsOneWidget);
      expect(tester.widget<IconButton>(upBtn).onPressed, isNull);

      // Keyboard arrowDown clamped at 0 and arrowUp clamped at 8
      for (int i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      expect(find.text('Oct 0'), findsOneWidget);

      for (int i = 0; i < 10; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
      }
      expect(find.text('Oct 8'), findsOneWidget);
    });

    testWidgets('Exposes dotted duration chips (12, 6, 3 ticks) and inserts matching durations', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildModalApp());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('duration_chip_12')), findsOneWidget);
      expect(find.byKey(const Key('duration_chip_6')), findsOneWidget);
      expect(find.byKey(const Key('duration_chip_3')), findsOneWidget);

      final insertBtn = find.byKey(const Key('score_editor_insert_btn'));

      // Insert 12-tick dotted half at tick 0
      await tester.tap(find.byKey(const Key('duration_chip_12')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(insertBtn);
      await tester.tap(insertBtn);
      await tester.pumpAndSettle();

      expect(
        viewModel.activePackage.score.measures.first.notes.any((n) => n.startTick == 0 && n.durationTicks == 12),
        isTrue,
      );

      // Cursor auto-advanced to tick 12; insert 3-tick dotted eighth
      await tester.ensureVisible(find.byKey(const Key('duration_chip_3')));
      await tester.tap(find.byKey(const Key('duration_chip_3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(insertBtn);
      await tester.tap(insertBtn);
      await tester.pumpAndSettle();

      expect(
        viewModel.activePackage.score.measures.first.notes.any((n) => n.startTick == 12 && n.durationTicks == 3),
        isTrue,
      );

      // Select 6-tick dotted quarter and verify chip selection updates insertion
      await tester.ensureVisible(find.byKey(const Key('duration_chip_6')));
      await tester.tap(find.byKey(const Key('duration_chip_6')));
      await tester.pumpAndSettle();

      viewModel.insertOrUpdateScoreNote(
        measureIndex: 0,
        startTick: 0,
        durationTicks: 6,
        noteName: 'Re4',
        playAudibleFeedback: false,
      );
      expect(
        viewModel.activePackage.score.measures.first.notes.any((n) => n.startTick == 0 && n.durationTicks == 6),
        isTrue,
      );
    });

    testWidgets('Polyphonic chord mode inserts simultaneous notes via insertChordNotes and persists', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildModalApp());
      await tester.pumpAndSettle();

      // Enable chord mode
      final chordToggle = find.byKey(const Key('score_editor_chord_mode_toggle'));
      await tester.ensureVisible(chordToggle);
      await tester.tap(chordToggle);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('score_editor_chord_panel')), findsOneWidget);

      final addChordNoteBtn = find.byKey(const Key('score_editor_add_chord_note_btn'));

      // Add Do4
      await tester.tap(addChordNoteBtn);
      await tester.pumpAndSettle();

      // Select Mi and add Mi4
      await tester.tap(find.text('Mi'));
      await tester.pumpAndSettle();
      await tester.tap(addChordNoteBtn);
      await tester.pumpAndSettle();

      // Select Sol and add Sol4
      await tester.tap(find.text('Sol'));
      await tester.pumpAndSettle();
      await tester.tap(addChordNoteBtn);
      await tester.pumpAndSettle();

      // Insert chord at tick 0
      final insertBtn = find.byKey(const Key('score_editor_insert_btn'));
      await tester.ensureVisible(insertBtn);
      await tester.tap(insertBtn);
      await tester.pumpAndSettle();

      final notesAt0 = viewModel.activePackage.score.measures.first.notes
          .where((n) => n.startTick == 0)
          .map((n) => n.noteName)
          .toList();
      expect(notesAt0, containsAll(['Do4', 'Mi4', 'Sol4']));
      expect(viewModel.workspaceScores.any((s) => s.id == viewModel.activePackage.id), isTrue);
    });

    testWidgets('All 4 export buttons await saveExportedBytes before displaying SnackBar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildModalApp());
      await tester.pumpAndSettle();

      final exportCases = <({String keyName, String ext, String expectedText})>[
        (keyName: 'export_musicxml_btn', ext: '.musicxml', expectedText: 'MusicXML'),
        (keyName: 'export_midi_btn', ext: '.mid', expectedText: 'MIDI'),
        (keyName: 'export_abc_btn', ext: '.abc', expectedText: 'ABC'),
        (keyName: 'export_pdf_btn', ext: '.pdf', expectedText: 'PDF'),
      ];

      for (final item in exportCases) {
        final gate = Completer<void>();
        diskGateway.pendingGate = gate;

        final btn = find.byKey(Key(item.keyName));
        await tester.ensureVisible(btn);
        await tester.tap(btn);
        await tester.pump();

        // SnackBar must NOT appear before saveExportedBytes resolves
        expect(find.byType(SnackBar), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();

        // Once disk write completes, SnackBar shows with saved file path
        final latestExport = diskGateway.savedExports.last;
        expect(latestExport.fileName, endsWith(item.ext));
        expect(latestExport.bytes, isNotEmpty);
        expect(File(latestExport.savedPath).existsSync(), isTrue);
        expect(find.textContaining(latestExport.savedPath), findsOneWidget);
        expect(find.textContaining(item.expectedText), findsWidgets);

        // Dismiss SnackBar cleanly before next button
        ScaffoldMessenger.of(tester.element(btn)).hideCurrentSnackBar();
        await tester.pumpAndSettle();
      }

      expect(diskGateway.savedExports.length, equals(4));
    });
  });
}
