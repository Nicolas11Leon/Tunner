import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/exercise_generator/domain/algorithmic_exercise_generator.dart';
import 'package:tunner/features/practice_evaluator/domain/practice_report_entity.dart';
import 'package:tunner/features/practice_evaluator/presentation/practice_report_modal.dart';
import 'package:tunner/features/song_library/domain/song_package_entity.dart';

void main() {
  group('US-HC-06: Bucle Pedagógico Cerrado (Estudio Correctivo y Dron)', () {
    test(
      'Prueba 1: generateRemedialDrillFromCriticalNotes genera un SongPackage válido con Fa#4 y Do#5 a 92 BPM',
      () {
        final pkg =
            AlgorithmicExerciseGenerator.generateRemedialDrillFromCriticalNotes(
          criticalNotes: const ['Fa#4', 'Do#5'],
          bpm: 92,
        );

        expect(pkg.title, equals('Estudio Correctivo: Fa#4, Do#5'));
        expect(pkg.defaultBpm, equals(92));
        expect(pkg.score.baseBpm, equals(92));
        expect(pkg.score.measures.length, equals(4));
        expect(pkg.score.isValidScore, isTrue);

        final generatedNoteNames = pkg.score.measures
            .expand((m) => m.notes)
            .where((n) => !n.isRest)
            .map((n) => n.noteName)
            .toSet();

        expect(generatedNoteNames, containsAll(<String>['Fa#4', 'Do#5']));
      },
    );

    test(
      'generateRemedialDrillFromCriticalNotes normaliza notas sin octava y usa respaldo si criticalNotes está vacía',
      () {
        final normalizedPkg =
            AlgorithmicExerciseGenerator.generateRemedialDrillFromCriticalNotes(
          criticalNotes: const ['Fa#'],
        );
        final normalizedNames = normalizedPkg.score.measures
            .expand((m) => m.notes)
            .map((n) => n.noteName)
            .toSet();
        expect(normalizedNames, contains('Fa#4'));
        expect(normalizedPkg.score.isValidScore, isTrue);

        final fallbackPkg =
            AlgorithmicExerciseGenerator.generateRemedialDrillFromCriticalNotes(
          criticalNotes: const [],
        );
        final fallbackNames = fallbackPkg.score.measures
            .expand((m) => m.notes)
            .map((n) => n.noteName)
            .toSet();
        expect(
          fallbackNames,
          containsAll(<String>['La4', 'Si4', 'Do5', 'Re5']),
        );
        expect(fallbackPkg.score.isValidScore, isTrue);
      },
    );

    testWidgets(
      'Prueba 2: PracticeReportModal con criticalNotes muestra botones y dispara callbacks onLoadRemedialDrill y onLockDroneToCriticalNote',
      (tester) async {
        final report = PracticeReportEntity(
          songTitle: 'Estudio de Intervalos',
          instrumentName: 'Violín',
          timestamp: DateTime(2026, 1, 15),
          totalNotes: 12,
          hitNotes: 8,
          pitchAccuracyPercentage: 72.0,
          averageCentsDeviation: 14.0,
          rhythmAccuracyPercentage: 85.0,
          overallScore: 76.0,
          grade: PerformanceGrade.b,
          evaluations: const [],
          noteAccuracyMap: const {'Fa#4': 58.0, 'Si4': 64.0, 'La4': 95.0},
          criticalNotes: const ['Fa#4', 'Si4'],
          masteredNotes: const ['La4'],
        );

        SongPackage? loadedDrill;
        String? lockedDroneNote;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      PracticeReportModal.show(
                        context: context,
                        report: report,
                        palette: TunnerThemePalette.obsidianStudio,
                        onRetry: () {},
                        onLoadRemedialDrill: (pkg) {
                          loadedDrill = pkg;
                        },
                        onLockDroneToCriticalNote: (note) {
                          lockedDroneNote = note;
                        },
                      );
                    },
                    child: const Text('Abrir Reporte'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Reporte'));
        await tester.pumpAndSettle();

        final drillBtnFinder =
            find.byKey(const Key('btn_generate_remedial_drill_from_report'));
        final droneBtnFinder =
            find.byKey(const Key('btn_lock_drone_on_first_critical_note'));

        expect(drillBtnFinder, findsOneWidget);
        expect(droneBtnFinder, findsOneWidget);
        expect(find.text('Generar Estudio sobre Notas Críticas'), findsOneWidget);
        expect(find.text('Fijar Dron en Fa#4'), findsOneWidget);

        await tester.ensureVisible(droneBtnFinder);
        await tester.tap(droneBtnFinder);
        await tester.pump();
        expect(lockedDroneNote, equals('Fa#4'));

        await tester.ensureVisible(drillBtnFinder);
        await tester.tap(drillBtnFinder);
        await tester.pumpAndSettle();

        expect(loadedDrill, isNotNull);
        expect(loadedDrill!.title, contains('Fa#4'));
        expect(loadedDrill!.title, contains('Si4'));
        final drillNotes = loadedDrill!.score.measures
            .expand((m) => m.notes)
            .map((n) => n.noteName)
            .toSet();
        expect(drillNotes, containsAll(<String>['Fa#4', 'Si4']));
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}
