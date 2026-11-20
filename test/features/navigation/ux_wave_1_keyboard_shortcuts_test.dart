import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/design_system/molecules/studio_command_prompt_bar.dart';
import 'package:tunner/core/theme/tunner_theme.dart';
import 'package:tunner/features/navigation/presentation/pro_command_palette_modal.dart';
import 'package:tunner/features/metronome/presentation/tap_tempo_modal.dart';
import 'package:tunner/features/instrument/domain/instrument_customization_profile.dart';
import 'package:tunner/features/instrument/domain/universal_instrument_definition.dart';
import 'package:tunner/features/instrument/presentation/universal_master_keyboard_widget.dart';
import 'package:tunner/features/audio_synthesizer/domain/i_audio_synthesizer_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

class _SpySynthesizerService extends NoOpAudioSynthesizerService {
  bool wasDisposed = false;
  int playCount = 0;

  @override
  Future<void> playPcmWav(Uint8List wavBytes, {double volume = 0.8}) async {
    playCount++;
  }

  @override
  void dispose() {
    wasDisposed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UX Wave 1 - ProCommandPaletteModal Tests', () {
    testWidgets('Navegacion con flechas y seleccion con Enter en ProCommandPaletteModal', (tester) async {
      bool commandExecuted = false;
      const palette = TunnerThemePalette.obsidianStudio;
      final commands = [
        CommandItem(
          id: 'cmd1',
          title: 'Comando Uno',
          subtitle: 'Subtitulo Uno',
          icon: Icons.ac_unit,
          category: 'Prueba',
          onSelect: () {},
        ),
        CommandItem(
          id: 'cmd2',
          title: 'Comando Dos',
          subtitle: 'Subtitulo Dos',
          icon: Icons.access_alarm,
          category: 'Prueba',
          onSelect: () {
            commandExecuted = true;
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => ProCommandPaletteModal.show(
                  context: ctx,
                  palette: palette,
                  commands: commands,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      // Abrir modal
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Comando Uno'), findsOneWidget);
      expect(find.text('Comando Dos'), findsOneWidget);

      // Presionar Flecha Abajo para resaltar el segundo comando
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Presionar Enter para ejecutar
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(commandExecuted, isTrue);
      expect(find.text('Comando Uno'), findsNothing); // Modal cerrado
    });
  });

  group('UX Wave 1 - StudioCommandPromptBar Arguments Tests', () {
    testWidgets('Comando con argumento /bpm 140 filtra correctamente y ejecuta sin terminal', (tester) async {
      String executedRawText = '';
      bool terminalExecuted = false;

      final suggestions = [
        PromptSuggestion(
          id: 'bpm',
          trigger: '/',
          command: '/bpm',
          title: 'Fijar Tempo (BPM)',
          description: 'Ajustar la velocidad del metrónomo',
          icon: Icons.access_time,
          category: 'Transporte',
          onExecute: (raw) {
            executedRawText = raw;
          },
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioCommandPromptBar(
              suggestions: suggestions,
              onOpenHelp: () {},
              onCommandExecuted: (cmd) {
                terminalExecuted = true;
              },
            ),
          ),
        ),
      );

      // Escribir '/bpm 140' en el input
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, '/bpm 140');
      await tester.pumpAndSettle();

      // Verificar que la sugerencia /bpm sigue activa en la lista
      expect(find.text('/bpm'), findsOneWidget);

      // Enviar comando con Enter
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(executedRawText, equals('/bpm 140'));
      expect(terminalExecuted, isFalse); // No debe saltar a terminal accidental
    });
  });

  group('UX Wave 1 - TapTempoModal Keyboard Tests', () {
    testWidgets('Pulsar tecla T registra tap tempo en TapTempoModal', (tester) async {
      final vm = TunerViewModel();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TapTempoModal.show(ctx, vm),
                child: const Text('Abrir Tap'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Tap'));
      await tester.pumpAndSettle();

      // Presionar tecla T
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();

      // Debe haberse registrado el tap en el viewmodel
      expect(vm.lastTapTempoResult, isNotNull);
    });
  });

  group('UX Wave 1 - UniversalMasterKeyboardWidget Tests', () {
    testWidgets('Teclas PC ejecutan notas y dispose no destruye sintetizador compartido', (tester) async {
      final fakeSynth = _SpySynthesizerService();
      final profile = InstrumentCustomizationProfile(
        instrument: UniversalInstrumentDefinition.grandPiano,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UniversalMasterKeyboardWidget(
              customization: profile,
              audioSynthesizer: fakeSynth,
            ),
          ),
        ),
      );

      // Presionar tecla A (nota Do / C)
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();

      expect(fakeSynth.playCount, greaterThan(0));

      // Desmontar widget
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      await tester.pumpAndSettle();

      // El sintetizador externo NO debe haber sido destruido
      expect(fakeSynth.wasDisposed, isFalse);
    });
  });
}
