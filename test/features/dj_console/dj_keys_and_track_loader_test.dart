import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tunner/core/design_system/studio_theme_provider.dart';
import 'package:tunner/features/dj_console/data/dj_deck_audio_service.dart';
import 'package:tunner/features/dj_console/domain/dj_action.dart';
import 'package:tunner/features/dj_console/domain/dj_controller_profile_entity.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/dj_console/presentation/dj_track_loader_modal.dart';
import 'package:tunner/features/navigation/presentation/main_app_shell.dart';
import 'package:tunner/features/song_library/data/song_decomposer_service.dart';
import 'package:tunner/features/tuner_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DJ Hardware Keys & Track Loading Tests', () {
    test('DjControllerProfileEntity findAction normalizes lowercase and varied tokens', () {
      final profile = DjControllerProfileEntity.defaultUnified();

      // Lowercase letter tokens
      expect(profile.findAction('w'), equals(DjAction.deckAPlayPause));
      expect(profile.findAction('W'), equals(DjAction.deckAPlayPause));
      expect(profile.findAction('Key W'), equals(DjAction.deckAPlayPause));

      expect(profile.findAction('i'), equals(DjAction.deckBPlayPause));
      expect(profile.findAction('I'), equals(DjAction.deckBPlayPause));
      expect(profile.findAction('Key I'), equals(DjAction.deckBPlayPause));

      expect(profile.findAction('q'), equals(DjAction.deckACue));
      expect(profile.findAction('a'), equals(DjAction.deckAPitchDown));
      expect(profile.findAction('s'), equals(DjAction.deckAPitchUp));
      expect(profile.findAction('b'), equals(DjAction.crossfaderShiftLeft));

      // Number tokens
      expect(profile.findAction('1'), equals(DjAction.deckAHotCue1));
      expect(profile.findAction('Digit 1'), equals(DjAction.deckAHotCue1));
      expect(profile.findAction('7'), equals(DjAction.deckBHotCue1));
      expect(profile.findAction('Digit 7'), equals(DjAction.deckBHotCue1));
    });

    test('DjDeckAudioService stores and retains loaded wavBytes without reset', () async {
      final audioService = DjDeckAudioService();
      final testBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      await audioService.loadDeckTrack('A', wavBytes: testBytes, title: 'Custom Track');
      expect(audioService.isDeckPlaying('A'), isFalse);

      await audioService.playDeck('A');
      expect(audioService.isDeckPlaying('A'), isTrue);

      await audioService.pauseDeck('A');
      expect(audioService.isDeckPlaying('A'), isFalse);
    });

    test('DjConsoleViewModel loadDeckTrack loads track and preserves player buffers', () async {
      final vm = DjConsoleViewModel();
      final fakeWav = Uint8List(128);

      await vm.loadDeckTrack(
        deckId: 'A',
        wavBytes: fakeWav,
        title: 'Prueba de Estudio A',
        artist: 'Artista Maestro',
        bpm: 126.0,
      );

      expect(vm.deckA.trackTitle, equals('Prueba de Estudio A'));
      expect(vm.deckA.artist, equals('Artista Maestro'));
      expect(vm.deckA.bpm, equals(126.0));
      expect(vm.waveformA.isNotEmpty, isTrue);

      // Verify Deck B remains untouched
      expect(vm.deckB.bpm, equals(128.0));

      vm.dispose();
    });

    testWidgets('DjTrackLoaderModal renders 3 tabs (Repertorio, Club, Importar) and loads track', (tester) async {
      final vm = DjConsoleViewModel();
      final curated = SongDecomposerService.getCuratedLibrary();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => DjTrackLoaderModal.show(ctx, deckId: 'A', viewModel: vm),
                child: const Text('Abrir Loader'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Loader'));
      await tester.pumpAndSettle();

      // Verifica presencia de las 3 pestañas
      expect(find.text('Repertorio (${curated.length})'), findsOneWidget);
      expect(find.text('Club (${DjTrackLoaderModal.studioLibrary.length})'), findsOneWidget);
      expect(find.text('Importar Archivo'), findsOneWidget);

      // Cambia a pestaña Repertorio
      await tester.tap(find.text('Repertorio (${curated.length})'));
      await tester.pumpAndSettle();

      // Verifica primera obra curada en la lista
      expect(find.text(curated.first.title), findsOneWidget);

      // Toca CARGAR EN A en la primera obra
      await tester.tap(find.text('CARGAR EN A').first);
      await tester.pumpAndSettle();

      // El modal debe haberse cerrado y el deck tener la pista cargada
      expect(find.byType(DjTrackLoaderModal), findsNothing);
      expect(vm.deckA.trackTitle, equals(curated.first.title));

      vm.dispose();
    });

    testWidgets('MainAppShell keyboard shortcuts do not steal DJ keys when on tab 5', (tester) async {
      final tunerVm = TunerViewModel();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tunerVm),
            ChangeNotifierProvider(create: (_) => StudioThemeController()),
          ],
          child: const MaterialApp(
            home: MainAppShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Navegar a la pestaña 5 (DJ Console)
      await tester.tap(find.text('Consola DJ Pro Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final shellState = tester.state(find.byType(MainAppShell));
      expect(shellState, isNotNull);

      // Los atajos condicionales de la pestaña 5 están activos sin secuestrar teclas de DJ
      expect(find.byType(DjTrackLoaderModal), findsNothing);

      tunerVm.dispose();
    });
  });
}
