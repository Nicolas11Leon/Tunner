import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/terminal/domain/tunner_os_kernel.dart';

void main() {
  group('TunnerOsKernel Unit Tests', () {
    late TunnerOsKernel kernel;
    int? navigatedTab;
    String? loadedTrackDeck;
    String? loadedTrackTitle;
    String? playedDeck;
    double? xfaderVal;
    String? chosenTheme;

    setUp(() {
      navigatedTab = null;
      loadedTrackDeck = null;
      loadedTrackTitle = null;
      playedDeck = null;
      xfaderVal = null;
      chosenTheme = null;

      kernel = TunnerOsKernel(
        onNavigateTab: (tab) => navigatedTab = tab,
        onDjLoadTrack: (deck, track) {
          loadedTrackDeck = deck;
          loadedTrackTitle = track;
        },
        onDjTogglePlay: (deck) => playedDeck = deck,
        onDjSetCrossfader: (val) => xfaderVal = val,
        onSetTheme: (theme) => chosenTheme = theme,
      );
    });

    test('help command returns comprehensive syntax guide', () async {
      final res = await kernel.execute('help');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('COMANDOS DISPONIBLES'));
      expect(res.message, contains('tuner run'));
      expect(res.message, contains('dj load'));
    });

    test('tuner run navigates to specified tab index', () async {
      final resDj = await kernel.execute('tuner run dj');
      expect(resDj.isSuccess, isTrue);
      expect(navigatedTab, 5);

      final resTuner = await kernel.execute('tuner run tuner');
      expect(resTuner.isSuccess, isTrue);
      expect(navigatedTab, 1);

      final resScores = await kernel.execute('tuner run library');
      expect(resScores.isSuccess, isTrue);
      expect(navigatedTab, 4);
    });

    test('dj load parses quoted track title and targets deck', () async {
      final res = await kernel.execute('dj load A "Para Elisa"');
      expect(res.isSuccess, isTrue);
      expect(loadedTrackDeck, 'A');
      expect(loadedTrackTitle, 'Para Elisa');
    });

    test('dj play and pause dispatch deck toggling', () async {
      final resPlay = await kernel.execute('dj play B');
      expect(resPlay.isSuccess, isTrue);
      expect(playedDeck, 'B');

      final resPause = await kernel.execute('dj pause A');
      expect(resPause.isSuccess, isTrue);
      expect(playedDeck, 'A');
    });

    test('dj xfader modulates crossfader position', () async {
      final res = await kernel.execute('dj xfader -0.45');
      expect(res.isSuccess, isTrue);
      expect(xfaderVal, closeTo(-0.45, 1e-4));
    });

    test('dsp status reports full-duplex audio health', () async {
      final res = await kernel.execute('dsp status');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('FULL-DUPLEX'));
      expect(res.message, contains('44.1 kHz / 48.0 kHz'));
    });

    test('fs ls reports current project files', () async {
      final res = await kernel.execute('fs ls');
      expect(res.isSuccess, isTrue);
      expect(res.message, contains('Suite_No1_Bach.tunner'));
      expect(res.message, contains('Fur_Elise_Club_Mix.tndj'));
    });

    test('theme set dispatches theme change', () async {
      final res = await kernel.execute('theme set "Tokyo Cyberpunk"');
      expect(res.isSuccess, isTrue);
      expect(chosenTheme, 'Tokyo Cyberpunk');
    });

    test('unknown command returns helpful error', () async {
      final res = await kernel.execute('nonexistent_command foo bar');
      expect(res.isSuccess, isFalse);
      expect(res.message, contains('Comando no reconocido'));
    });
  });
}
