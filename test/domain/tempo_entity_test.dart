import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/domain/tempo_entity.dart';

void main() {
  group('TempoMark Domain Tests', () {
    test('Correctly maps boundary and typical BPMs to standard Italian tempo marks', () {
      expect(TempoMark.fromBpm(20).italianName, equals('Larghissimo'));
      expect(TempoMark.fromBpm(35).italianName, equals('Larghissimo'));
      expect(TempoMark.fromBpm(40).italianName, equals('Largo'));
      expect(TempoMark.fromBpm(60).italianName, equals('Adagio'));
      expect(TempoMark.fromBpm(72).italianName, equals('Adagio'));
      expect(TempoMark.fromBpm(76).italianName, equals('Andante'));
      expect(TempoMark.fromBpm(100).italianName, equals('Andante'));
      expect(TempoMark.fromBpm(108).italianName, equals('Moderato'));
      expect(TempoMark.fromBpm(115).italianName, equals('Moderato'));
      expect(TempoMark.fromBpm(120).italianName, equals('Allegro'));
      expect(TempoMark.fromBpm(144).italianName, equals('Allegro'));
      expect(TempoMark.fromBpm(156).italianName, equals('Presto'));
      expect(TempoMark.fromBpm(180).italianName, equals('Presto'));
      expect(TempoMark.fromBpm(200).italianName, equals('Prestissimo'));
      expect(TempoMark.fromBpm(300).italianName, equals('Prestissimo'));
    });

    test('Clamps out-of-range values safely to extreme Italian marks', () {
      expect(TempoMark.fromBpm(10).italianName, equals('Larghissimo'));
      expect(TempoMark.fromBpm(450).italianName, equals('Prestissimo'));
    });

    test('All standard tempo marks have contiguous BPM intervals', () {
      final marks = TempoMark.standardMarks;
      for (int i = 0; i < marks.length - 1; i++) {
        expect(marks[i].maxBpm + 1, equals(marks[i + 1].minBpm));
      }
      expect(marks.first.minBpm, equals(20));
      expect(marks.last.maxBpm, equals(300));
    });
  });
}
