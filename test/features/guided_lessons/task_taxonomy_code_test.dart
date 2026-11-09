import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/guided_lessons/domain/task_taxonomy_code.dart';

void main() {
  group('TaskTaxonomyCode Domain Value Object Tests', () {
    test('Parses valid TTC string canonical representation correctly', () {
      final code = TaskTaxonomyCode.parse('EAR.01.INTV.001');

      expect(code.domain, equals(TaskDomain.ear));
      expect(code.level, equals(TaskLevel.level1));
      expect(code.subtype, equals(TaskSubtype.intervals));
      expect(code.sequence, equals(1));
      expect(code.formatted, equals('EAR.01.INTV.001'));
      expect(code.shortCode, equals('E1-001'));
    });

    test('Throws FormatException on invalid TTC format or values', () {
      // Formato incompleto
      expect(() => TaskTaxonomyCode.parse('EAR.01.INTV'), throwsFormatException);

      // Dominio inexistente
      expect(() => TaskTaxonomyCode.parse('XYZ.01.INTV.001'), throwsFormatException);

      // Nivel fuera de rango
      expect(() => TaskTaxonomyCode.parse('EAR.99.INTV.001'), throwsFormatException);

      // Subtipo desconocido
      expect(() => TaskTaxonomyCode.parse('EAR.01.ABCD.001'), throwsFormatException);
    });

    test('tryParse returns null on invalid input without throwing', () {
      expect(TaskTaxonomyCode.tryParse(null), isNull);
      expect(TaskTaxonomyCode.tryParse(''), isNull);
      expect(TaskTaxonomyCode.tryParse('invalid'), isNull);
      expect(TaskTaxonomyCode.tryParse('RHY.02.SYNC.012'), isNotNull);
    });

    test('Comparable implements deterministic canonical sorting', () {
      final c1 = TaskTaxonomyCode.parse('EAR.01.INTV.001');
      final c2 = TaskTaxonomyCode.parse('EAR.01.INTV.002');
      final c3 = TaskTaxonomyCode.parse('EAR.02.INTV.001');
      final c4 = TaskTaxonomyCode.parse('RHY.01.SYNC.001');

      final list = [c4, c2, c3, c1]..sort();

      expect(list, equals([c1, c2, c3, c4]));
    });

    test('Equality and hashCode work as expected for Value Objects', () {
      final codeA = TaskTaxonomyCode.parse('PCH.03.STRB.005');
      final codeB = const TaskTaxonomyCode(
        domain: TaskDomain.pitch,
        level: TaskLevel.level3,
        subtype: TaskSubtype.strobe,
        sequence: 5,
      );

      expect(codeA, equals(codeB));
      expect(codeA.hashCode, equals(codeB.hashCode));
    });
  });
}
