import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/features/sheet_music/domain/score_tree.dart';
import 'package:tunner/features/universal_importer/domain/canonical_musicxml_exporter.dart';

void main() {
  group('CanonicalMusicXmlExporter Domain Tests', () {
    const exporter = CanonicalMusicXmlExporter();

    test('Generates valid MusicXML 3.1 header and work title', () {
      final score = HierarchicalScore(
        title: 'Estudio de Flauta',
        baseBpm: 80,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Do4'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Re4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Mi4'),
              HierarchicalNote.note(startTick: 12, durationTicks: 4, noteName: 'Fa4'),
            ],
          ),
        ],
      );

      final xml = exporter.exportScore(score: score, title: 'Estudio de Flauta');

      expect(xml, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(xml, contains('<!DOCTYPE score-partwise'));
      expect(xml, contains('<score-partwise version="3.1">'));
      expect(xml, contains('<work-title>Estudio de Flauta</work-title>'));
      expect(xml, contains('<creator type="composer">Tunner Music Studio</creator>'));
      expect(xml, contains('<measure number="1">'));
      expect(xml, contains('<divisions>4</divisions>'));
      expect(xml, contains('<beats>4</beats>'));
      expect(xml, contains('<beat-type>4</beat-type>'));
      expect(xml, contains('</score-partwise>'));
    });

    test('Correctly serializes pitch step, alter and octave for sharps and flats', () {
      final score = HierarchicalScore(
        title: 'Armaduras y Alteraciones',
        baseBpm: 90,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 4, noteName: 'Fa#5'),
              HierarchicalNote.note(startTick: 4, durationTicks: 4, noteName: 'Sib4'),
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: '--'), // Rest
            ],
          ),
        ],
      );

      final xml = exporter.exportScore(score: score);

      // Fa#5 -> Step F, Alter 1, Octave 5, Accidental sharp
      expect(xml, contains('<step>F</step>'));
      expect(xml, contains('<alter>1</alter>'));
      expect(xml, contains('<octave>5</octave>'));
      expect(xml, contains('<accidental>sharp</accidental>'));

      // Sib4 -> Step B, Alter -1, Octave 4, Accidental flat
      expect(xml, contains('<step>B</step>'));
      expect(xml, contains('<alter>-1</alter>'));
      expect(xml, contains('<octave>4</octave>'));
      expect(xml, contains('<accidental>flat</accidental>'));

      // Rest
      expect(xml, contains('<rest/>'));
    });

    test('Maps tick durations to correct MusicXML note types', () {
      final score = HierarchicalScore(
        title: 'Rítmica Diversa',
        baseBpm: 100,
        measures: [
          MeasureEntity(
            index: 0,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 16, noteName: 'Do4'), // Whole
            ],
          ),
          MeasureEntity(
            index: 1,
            timeSignature: TimeSignature.commonTime44,
            notes: [
              HierarchicalNote.note(startTick: 0, durationTicks: 8, noteName: 'Re4'),  // Half
              HierarchicalNote.note(startTick: 8, durationTicks: 4, noteName: 'Mi4'),  // Quarter
              HierarchicalNote.note(startTick: 12, durationTicks: 2, noteName: 'Fa4'), // Eighth
              HierarchicalNote.note(startTick: 14, durationTicks: 1, noteName: 'Sol4'),// 16th
              HierarchicalNote.note(startTick: 15, durationTicks: 1, noteName: 'La4'), // 16th
            ],
          ),
        ],
      );

      final xml = exporter.exportScore(score: score);

      expect(xml, contains('<type>whole</type>'));
      expect(xml, contains('<type>half</type>'));
      expect(xml, contains('<type>quarter</type>'));
      expect(xml, contains('<type>eighth</type>'));
      expect(xml, contains('<type>16th</type>'));
    });
  });
}
