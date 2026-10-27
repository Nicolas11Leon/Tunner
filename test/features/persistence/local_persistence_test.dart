import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/persistence/data/json_local_persistence_service.dart';
import 'package:tunner/features/persistence/domain/app_user_settings_entity.dart';
import 'package:tunner/features/practice_evaluator/domain/practice_report_entity.dart';
import 'package:tunner/features/practice_recorder/domain/practice_recording_entity.dart';

void main() {
  group('JsonLocalPersistenceService & AppUserSettingsEntity', () {
    late Directory tempDir;
    late JsonLocalPersistenceService persistenceService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tunner_test_persistence_');
      persistenceService = JsonLocalPersistenceService(
        documentsPathProvider: () async => tempDir.path,
        fileName: 'test_tunner_settings.json',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Loads default settings when no persistence file exists', () async {
      final settings = await persistenceService.loadSettings();
      expect(settings.referencePitch, equals(440.0));
      expect(settings.selectedThemeId, equals('obsidian_studio'));
      expect(settings.selectedInstrumentId, equals('flute'));
      expect(settings.customPalettes, isEmpty);
      expect(settings.sessionHistory, isEmpty);
    });

    test('Saves and loads settings round-trip with full fidelity', () async {
      final customPalette = TunnerThemePalette.createCustom(
        name: 'Neon Wave Test',
        baseStyle: 'dark',
        primaryAccent: const Color(0xFFFF0055),
        secondaryAccent: const Color(0xFF00FFAA),
      );

      final recording = PracticeRecordingEntity(
        id: 'rec_101',
        filePath: '/tmp/test.wav',
        recordedAt: DateTime(2026, 10, 26, 12, 0),
        duration: const Duration(seconds: 45),
        songTitle: 'Canon en Re',
        bpm: 72,
        waveformPeaks: [0.1, 0.4, 0.8, 0.2],
      );

      final report = PracticeReportEntity(
        songTitle: 'Canon en Re',
        instrumentName: 'Trompeta en Si♭',
        timestamp: DateTime(2026, 10, 26, 12, 5),
        totalNotes: 20,
        hitNotes: 19,
        pitchAccuracyPercentage: 95.0,
        averageCentsDeviation: 2.1,
        rhythmAccuracyPercentage: 90.0,
        overallScore: 92.5,
        grade: PerformanceGrade.s,
        evaluations: const [],
        noteAccuracyMap: {'Fa#5': 98.0, 'Mi5': 92.0},
        criticalNotes: const ['Re5'],
        masteredNotes: const ['Fa#5'],
        recording: recording,
      );

      final originalSettings = AppUserSettingsEntity(
        referencePitch: 442.0,
        selectedThemeId: customPalette.id,
        selectedInstrumentId: 'bb_trumpet',
        bpm: 72,
        isSmartWaitEnabled: true,
        customPalettes: [customPalette],
        sessionHistory: [report],
        recordingHistory: [recording],
      );

      await persistenceService.saveSettings(originalSettings);

      final loadedSettings = await persistenceService.loadSettings();

      expect(loadedSettings.referencePitch, equals(442.0));
      expect(loadedSettings.selectedThemeId, equals(customPalette.id));
      expect(loadedSettings.selectedInstrumentId, equals('bb_trumpet'));
      expect(loadedSettings.bpm, equals(72));
      expect(loadedSettings.isSmartWaitEnabled, isTrue);
      expect(loadedSettings.customPalettes.length, equals(1));
      expect(loadedSettings.customPalettes.first.displayName, equals('Neon Wave Test'));
      expect(loadedSettings.sessionHistory.length, equals(1));
      expect(loadedSettings.sessionHistory.first.overallScore, equals(92.5));
      expect(loadedSettings.sessionHistory.first.recording?.id, equals('rec_101'));
      expect(loadedSettings.recordingHistory.length, equals(1));
      expect(loadedSettings.recordingHistory.first.id, equals('rec_101'));
    });

    test('Gracefully returns default settings when JSON is corrupted', () async {
      final file = File('${tempDir.path}/test_tunner_settings.json');
      await file.writeAsString('{ corrupted json syntax [[[ }}}');

      final settings = await persistenceService.loadSettings();
      expect(settings.referencePitch, equals(440.0));
      expect(settings.selectedThemeId, equals('obsidian_studio'));
    });

    test('clearSettings deletes the storage file cleanly', () async {
      final settings = const AppUserSettingsEntity(referencePitch: 432.0);
      await persistenceService.saveSettings(settings);

      final file = File('${tempDir.path}/test_tunner_settings.json');
      expect(await file.exists(), isTrue);

      await persistenceService.clearSettings();
      expect(await file.exists(), isFalse);

      final reloaded = await persistenceService.loadSettings();
      expect(reloaded.referencePitch, equals(440.0));
    });
  });
}
