import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/domain/score_tree.dart';

void main() {
  group('TimeSignature Domain Math', () {
    test('4/4 common time has 16 sub-ticks (semicorcheas)', () {
      const sig = TimeSignature.commonTime44;
      expect(sig.numerator, equals(4));
      expect(sig.denominator, equals(4));
      expect(sig.totalTicks, equals(16));
      expect(sig.toString(), equals('4/4'));
    });

    test('3/4 waltz time has 12 sub-ticks (semicorcheas)', () {
      const sig = TimeSignature.waltzTime34;
      expect(sig.numerator, equals(3));
      expect(sig.denominator, equals(4));
      expect(sig.totalTicks, equals(12));
      expect(sig.toString(), equals('3/4'));
    });

    test('2/4 march time has 8 sub-ticks (semicorcheas)', () {
      const sig = TimeSignature.marchTime24;
      expect(sig.numerator, equals(2));
      expect(sig.denominator, equals(4));
      expect(sig.totalTicks, equals(8));
      expect(sig.toString(), equals('2/4'));
    });

    test('6/8 compound time has 12 sub-ticks (semicorcheas)', () {
      const sig = TimeSignature.compoundTime68;
      expect(sig.numerator, equals(6));
      expect(sig.denominator, equals(8));
      expect(sig.totalTicks, equals(12));
      expect(sig.toString(), equals('6/8'));
    });
  });

  group('HierarchicalScore and Measure Validation', () {
    test('Mock studies have valid measures adhering to their time signatures', () {
      final studies = HierarchicalScore.getMockStudies();
      expect(studies.length, greaterThanOrEqualTo(3));

      for (final study in studies) {
        expect(study.title.isNotEmpty, isTrue);
        expect(study.measures.isNotEmpty, isTrue);

        for (final measure in study.measures) {
          expect(measure.isValidMeasure, isTrue,
              reason: 'El compás ${measure.index} del estudio "${study.title}" no suma la métrica esperada.');
        }
      }
    });

    test('Measure with incomplete duration reports isValidMeasure as false', () {
      final invalidMeasure = MeasureEntity(
        index: 0,
        timeSignature: TimeSignature.commonTime44, // Espera 16 ticks
        notes: [
          HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'), // Solo 4 ticks
        ],
      );
      expect(invalidMeasure.isValidMeasure, isFalse);
    });

    test('Multi-measure studies have sequential indices and at least two measures', () {
      final studies = HierarchicalScore.getMockStudies();
      final multiMeasureStudy = studies.firstWhere((s) => s.measures.length > 1);
      
      expect(multiMeasureStudy.measures.length, equals(2));
      expect(multiMeasureStudy.measures[0].index, equals(0));
      expect(multiMeasureStudy.measures[1].index, equals(1));
      expect(multiMeasureStudy.measures[0].isValidMeasure, isTrue);
      expect(multiMeasureStudy.measures[1].isValidMeasure, isTrue);
    });
  });
}
