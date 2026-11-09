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
      expect(keywordResults.first.code.domain, equals(TaskDomain.pitch));
    });

    test('Filters tasks by domain and level cleanly', () {
      final level1Ear = index.filter(domain: TaskDomain.ear, level: TaskLevel.level1);
      expect(level1Ear.length, greaterThanOrEqualTo(2));
      for (final t in level1Ear) {
        expect(t.code.domain, equals(TaskDomain.ear));
        expect(t.code.level, equals(TaskLevel.level1));
      }
    });
  });
}
