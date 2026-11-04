import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/navigation/domain/app_tool_item.dart';

void main() {
  group('AppToolCatalog & Universal Search Unit Tests', () {
    test('Catalog contains rich index of modular software tools', () {
      final tools = AppToolCatalog.tools;
      expect(tools.length, greaterThanOrEqualTo(15));
      expect(tools.any((t) => t.id == 'tuner_screen'), isTrue);
      expect(tools.any((t) => t.id == 'guided_lessons'), isTrue);
      expect(tools.any((t) => t.id == 'practice_recorder'), isTrue);
      expect(tools.any((t) => t.id == 'metronome_tool'), isTrue);
      expect(tools.any((t) => t.id == 'song_library_tool'), isTrue);
    });

    test('searchTools returns all tools when query is empty', () {
      final all = AppToolCatalog.searchTools('');
      expect(all.length, equals(AppToolCatalog.tools.length));
    });

    test('searchTools finds tools regardless of accent marks and casing', () {
      // 1. Con acento
      final withAccent = AppToolCatalog.searchTools('metrónomo');
      expect(withAccent.any((t) => t.id == 'metronome_tool'), isTrue);

      // 2. Sin acento
      final withoutAccent = AppToolCatalog.searchTools('metronomo');
      expect(withoutAccent.any((t) => t.id == 'metronome_tool'), isTrue);

      // 3. Mayúsculas
      final uppercase = AppToolCatalog.searchTools('GUITARRA');
      expect(uppercase.isNotEmpty, isTrue);
    });

    test('searchTools filters by keywords and aliases accurately', () {
      // Búsqueda por alias "442"
      final freqResults = AppToolCatalog.searchTools('442');
      expect(freqResults.any((t) => t.id == 'concert_pitch'), isTrue);

      // Búsqueda por "aprender" o "leccion"
      final learningResults = AppToolCatalog.searchTools('aprender');
      expect(learningResults.any((t) => t.id == 'guided_lessons'), isTrue);

      // Búsqueda por "gate" o "ruido"
      final micResults = AppToolCatalog.searchTools('ruido');
      expect(micResults.any((t) => t.id == 'mic_calibration'), isTrue);
    });

    test('searchTools handles multi-word search smoothly', () {
      final results = AppToolCatalog.searchTools('grabacion audio');
      expect(results.any((t) => t.id == 'practice_recorder'), isTrue);
    });
  });
}
