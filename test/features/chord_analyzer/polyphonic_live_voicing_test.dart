import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/chord_analyzer/domain/chord_entity.dart';
import 'package:tunner/features/chord_analyzer/domain/polyphonic_pitch_entity.dart';
import 'package:tunner/features/chord_analyzer/presentation/polyphonic_live_voicing_widget.dart';

void main() {
  group('PolyphonicLiveVoicingWidget Widget Tests', () {
    testWidgets('Renders empty state cleanly when no voices detected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolyphonicLiveVoicingWidget(
              recognizedChord: null,
              analysisResult: PolyphonicMultiToneAnalysisResult.empty,
              palette: TunnerThemePalette.obsidianStudio,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('polyphonic_live_voicing_container')), findsOneWidget);
      expect(find.text('VISUALIZADOR POLIFÓNICO'), findsOneWidget);
      expect(find.text('Esperando señal polifónica...'), findsOneWidget);
    });

    testWidgets('Renders detected chord and toggles between harmonics breakdown and voices', (tester) async {
      final chord = ChordEntity(
        rootNoteIndex: 0, // C
        quality: ChordQuality.major7,
        confidence: 0.94,
        chromaVector: List.filled(12, 0.5),
        notes: const ['Do', 'Mi', 'Sol', 'Si'],
      );

      final analysis = PolyphonicMultiToneAnalysisResult(
        voices: const [
          DetectedPolyphonicVoice(
            noteName: 'Do',
            noteNameInternational: 'C',
            octave: 4,
            pitchClassIndex: 0,
            frequencyHz: 261.63,
            midiNumber: 60,
            centsDeviation: 0.2,
            salience: 0.9,
            harmonicRole: 'Fundamental / Root',
          ),
          DetectedPolyphonicVoice(
            noteName: 'Mi',
            noteNameInternational: 'E',
            octave: 4,
            pitchClassIndex: 4,
            frequencyHz: 329.63,
            midiNumber: 64,
            centsDeviation: -1.5,
            salience: 0.8,
            harmonicRole: 'Tercera Mayor (3M)',
          ),
          DetectedPolyphonicVoice(
            noteName: 'Sol',
            noteNameInternational: 'G',
            octave: 4,
            pitchClassIndex: 7,
            frequencyHz: 392.00,
            midiNumber: 67,
            centsDeviation: 0.8,
            salience: 0.85,
            harmonicRole: 'Quinta Justa (5J)',
          ),
          DetectedPolyphonicVoice(
            noteName: 'Si',
            noteNameInternational: 'B',
            octave: 4,
            pitchClassIndex: 11,
            frequencyHz: 493.88,
            midiNumber: 71,
            centsDeviation: -0.4,
            salience: 0.7,
            harmonicRole: 'Séptima Mayor (7M)',
          ),
        ],
        chord: chord,
        voicingName: 'Cmaj7 Posición Fundamental',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PolyphonicLiveVoicingWidget(
              recognizedChord: chord,
              analysisResult: analysis,
              palette: TunnerThemePalette.obsidianStudio,
            ),
          ),
        ),
      );

      // Verifica símbolo de acorde reconocido y confianza
      expect(find.text('Cmaj7'), findsOneWidget);
      expect(find.text('94% Confianza'), findsOneWidget);
      expect(find.text('4 voces'), findsOneWidget);

      // Por defecto muestra armónicos H1 a H8
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H8'), findsOneWidget);

      // Alternar a la vista de filas de voces
      final toggleBtn = find.byKey(const Key('btn_toggle_harmonics_view'));
      expect(toggleBtn, findsOneWidget);
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      // Verifica que las notas individuales se muestran
      expect(find.byKey(const Key('voice_badge_C4')), findsOneWidget);
      expect(find.byKey(const Key('voice_badge_E4')), findsOneWidget);
      expect(find.byKey(const Key('voice_badge_G4')), findsOneWidget);
      expect(find.byKey(const Key('voice_badge_B4')), findsOneWidget);
    });
  });
}
