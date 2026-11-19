import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/dj_console/data/dj_console_blueprint_storage_service.dart';
import 'package:tunner/features/dj_console/data/dj_keymap_persistence_service.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_console_blueprint_entity.dart';
import 'package:tunner/features/dj_console/domain/dj_keymap_profile_entity.dart';
import 'package:tunner/features/mixer/domain/mixer_track_entity.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/practice_evaluator/domain/practice_report_entity.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';

void main() {
  group('UserSettings & Model Persistence Resilience Tests (Ola 1)', () {
    test('AppUserSettingsEntity.toMap() retains the 50 MOST RECENT sessions', () {
      final reports = List<PracticeReportEntity>.generate(
        70,
        (i) => PracticeReportEntity(
          songTitle: 'Song $i',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000 + i * 100),
          totalNotes: 10,
          hitNotes: 9,
          pitchAccuracyPercentage: 90.0,
          averageCentsDeviation: i.toDouble(),
          rhythmAccuracyPercentage: 90.0,
          overallScore: 90.0,
          grade: PerformanceGrade.a,
          evaluations: const [],
          noteAccuracyMap: const {},
          criticalNotes: const [],
          masteredNotes: const [],
        ),
      );

      final settings = AppUserSettingsEntity(sessionHistory: reports);
      final map = settings.toMap();
      final exportedSessions = map['sessionHistory'] as List<dynamic>;

      expect(exportedSessions.length, 50);
      // The first exported item must be Song 20 (not Song 0)
      expect(exportedSessions.first['songTitle'], 'Song 20');
      // The last exported item must be Song 69
      expect(exportedSessions.last['songTitle'], 'Song 69');
    });

    test('AppUserSettingsEntity.fromMap() tolerates corrupted items without data loss', () {
      final validReport = PracticeReportEntity(
        songTitle: 'Valid Song',
        timestamp: DateTime.now(),
        totalNotes: 10,
        hitNotes: 9,
        pitchAccuracyPercentage: 90.0,
        averageCentsDeviation: 1.2,
        rhythmAccuracyPercentage: 90.0,
        overallScore: 90.0,
        grade: PerformanceGrade.a,
        evaluations: [],
        noteAccuracyMap: {},
        criticalNotes: [],
        masteredNotes: [],
      );

      final map = {
        'referencePitch': 442.0,
        'bpm': 128,
        'sessionHistory': [
          validReport.toMap(),
          {'noteAccuracyMap': {'A4': 'not_a_number_triggers_cast_error'}},
          'string_instead_of_map',
        ],
      };

      final restored = AppUserSettingsEntity.fromMap(map);
      expect(restored.referencePitch, 442.0);
      expect(restored.bpm, 128);
      // Only the valid report is kept, corrupted items safely ignored
      expect(restored.sessionHistory.length, 1);
      expect(restored.sessionHistory.first.songTitle, 'Valid Song');
    });

    test('SongPackage serializes and restores tracks (stems) completely', () {
      final tracks = [
        const AudioTrack(
          id: 'stem_lead_vocal',
          title: 'Lead Vocal',
          instrumentIcon: 'mic',
          volume: 0.85,
          isMuted: false,
          isSolo: true,
        ),
        const AudioTrack(
          id: 'stem_grand_piano',
          title: 'Grand Piano',
          instrumentIcon: 'piano',
          volume: 0.70,
          isMuted: true,
          isSolo: false,
        ),
      ];

      final song = SongPackage(
        id: 'song_test_1',
        title: 'Nocturne in Eb Major',
        composer: 'Chopin',
        genre: MusicGenre.romantic,
        difficulty: SongDifficulty.advanced,
        defaultBpm: 72,
        score: const HierarchicalScore(title: 'Nocturne', measures: []),
        tracks: tracks,
      );

      final map = song.toMap();
      expect(map['tracks'], isNotEmpty);

      final restored = SongPackage.fromMap(map);
      expect(restored.tracks.length, 2);
      expect(restored.tracks[0].id, 'stem_lead_vocal');
      expect(restored.tracks[0].isSolo, isTrue);
      expect(restored.tracks[1].id, 'stem_grand_piano');
      expect(restored.tracks[1].isMuted, isTrue);
    });

    test('DjKeymapPersistenceService saves and loads from local disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('keymap_test_');
      try {
        final service = DjKeymapPersistenceService(
          documentsPathProvider: () async => tempDir.path,
        );

        final initial = await service.loadActiveProfile();
        expect(initial.name, 'Default Ergonomico (QWERTY)');

        const custom = DjKeymapProfileEntity(
          id: 'custom_pro',
          name: 'Club Pro 2026',
          keyBindings: {'KeyA': DjAction.deckACue, 'KeyS': DjAction.deckAPlayPause},
        );

        await service.saveProfile(custom);

        // New service instance reading from disk
        final newService = DjKeymapPersistenceService(
          documentsPathProvider: () async => tempDir.path,
        );
        final loaded = await newService.loadActiveProfile();
        expect(loaded.id, 'custom_pro');
        expect(loaded.name, 'Club Pro 2026');
        expect(loaded.keyBindings['KeyA'], DjAction.deckACue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('DjConsoleBlueprintStorageService persists custom blueprints to disk', () async {
      final tempDir = await Directory.systemTemp.createTemp('blueprint_test_');
      try {
        final service = DjConsoleBlueprintStorageService(
          documentsPathProvider: () async => tempDir.path,
        );

        const blueprint = DjConsoleBlueprintEntity(
          id: 'bp_traktor_s4',
          name: 'Traktor Kontrol S4 MK3',
          manufacturer: 'Native Instruments',
          zones: [],
        );

        await service.saveBlueprint(blueprint);

        // New instance loading from disk
        final newService = DjConsoleBlueprintStorageService(
          documentsPathProvider: () async => tempDir.path,
        );
        final loaded = await newService.loadCustomBlueprints();
        expect(loaded.length, 1);
        expect(loaded.first.id, 'bp_traktor_s4');
        expect(loaded.first.name, 'Traktor Kontrol S4 MK3');

        await newService.deleteBlueprint('bp_traktor_s4');
        expect(newService.currentBlueprints.isEmpty, isTrue);
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
