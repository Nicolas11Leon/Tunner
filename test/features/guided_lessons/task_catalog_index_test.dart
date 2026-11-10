import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/guided_lessons/domain/task_catalog_index.dart';
import 'package:tunner/features/guided_lessons/domain/task_taxonomy_code.dart';

void main() {
  group('TaskCatalogIndex High-Speed Search Tests', () {
    late TaskCatalogIndex index;

    setUp(() {
      index = TaskCatalogIndex();
    });

    test('Loads seed catalog with multiple domains and levels', () {
      expect(index.count, greaterThanOrEqualTo(10));
      expect(index.allTasks.isNotEmpty, isTrue);
    });

    test('Retrieves task by exact code in O(1)', () {
      final task = index.getByCodeString('EAR.01.INTV.001');

      expect(task, isNotNull);
      expect(task!.title, contains('Unísono vs. Quinta Justa'));
      expect(task.code.domain, equals(TaskDomain.ear));
      expect(task.isCompleted, isTrue);
      expect(task.bestGrade.letter, equals('S'));
    });

    test('Filters tasks by query prefix (EAR, RHY, PCH)', () {
      final earTasks = index.searchByQuery('EAR');
      expect(earTasks.isNotEmpty, isTrue);
      expect(earTasks.every((t) => t.code.domain == TaskDomain.ear), isTrue);

      final rhyLevel1 = index.searchByQuery('RHY.01');
      expect(rhyLevel1.isNotEmpty, isTrue);
      expect(rhyLevel1.first.code.formatted, startsWith('RHY.01'));
    });

    test('Searches by sequential number or keywords', () {
      final numResults = index.searchByQuery('001');
      expect(numResults.isNotEmpty, isTrue);

      final keywordResults = index.searchByQuery('estroboscópico');
      expect(keywordResults.isNotEmpty, isTrue);
      expect(keywordResults.any((t) => t.code.domain == TaskDomain.pitch), isTrue);
    });

    test('Filters tasks by domain and level cleanly', () {
      final level1Ear = index.filter(domain: TaskDomain.ear, level: TaskLevel.level1);
      expect(level1Ear.length, greaterThanOrEqualTo(2));
      for (final t in level1Ear) {
        expect(t.code.domain, equals(TaskDomain.ear));
        expect(t.code.level, equals(TaskLevel.level1));
      }
    });

    test('Retrieves multi-tool joint tasks correctly with isMultiTool and requiredToolIds >= 3', () {
      final multiTasks = index.getMultiToolJointTasks();

      expect(multiTasks.length, greaterThanOrEqualTo(5));
      for (final t in multiTasks) {
        expect(t.isMultiTool, isTrue);
        expect(t.requiredToolIds.length, greaterThanOrEqualTo(3));
        expect(t.interconnectionLinks.isNotEmpty, isTrue);
      }

      // Probar búsqueda por palabra clave "sinergia"
      final synergyTasks = index.searchByQuery('sinergia');
      expect(synergyTasks.length, greaterThanOrEqualTo(5));
      expect(synergyTasks.every((t) => t.isMultiTool), isTrue);

      // Verificar la tarea canónica de Lectura en Vuelo
      final flightReading = index.getByCodeString('SGT.02.MULT.005');
      expect(flightReading, isNotNull);
      expect(flightReading!.requiredToolIds, containsAll(['metronome', 'score_notation', 'strobe_tuner', 'guided_lessons']));
      expect(flightReading.interconnectionLinks.length, equals(4));
    });
  });
}
