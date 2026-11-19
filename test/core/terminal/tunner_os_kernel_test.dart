import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/infrastructure/studio_master_clock_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_audio_hardware_persistence_service.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_audio_input_engine.dart';
import 'package:tunner/core/audio/infrastructure/memory_studio_master_capture_service.dart';
import 'package:tunner/core/audio/infrastructure/studio_audio_device_matrix_service.dart';
import 'package:tunner/core/terminal/application/tunner_os_kernel.dart';
import 'package:tunner/core/terminal/domain/i_terminal_command_handler.dart';
import 'package:tunner/core/terminal/domain/tunner_os_command_entity.dart';

void main() {
  group('TunnerOsKernel Unit Tests', () {
    late TunnerOsKernel kernel;
    late StudioAudioDeviceMatrixService matrixService;
    late StudioMasterClockService clockService;
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

      matrixService = StudioAudioDeviceMatrixService(
        outputEngine: MemoryStudioAudioEngine(),
        inputEngine: MemoryStudioAudioInputEngine(),
        persistenceService: MemoryAudioHardwarePersistenceService(),
        captureService: MemoryStudioMasterCaptureService(),
      );
      clockService = StudioMasterClockService(initialBpm: 120.0);

      kernel = TunnerOsKernel(
        onNavigateTab: (tab) => navigatedTab = tab,
        matrixService: matrixService,
        clockService: clockService,
        onDjLoadTrack: (deck, track) {
          loadedTrackDeck = deck;
          loadedTrackTitle = track;
        },
        onDjTogglePlay: (deck) => playedDeck = deck,
        onDjSetCrossfader: (val) => xfaderVal = val,
        onSetTheme: (theme) => chosenTheme = theme,
      );
    });

    tearDown(() {
      matrixService.dispose();
      clockService.dispose();
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

    test('master command sets gain, mute, dim, mono, and rec', () async {
      final resGain = await kernel.execute('master gain -4.5');
      expect(resGain.isSuccess, isTrue);
      expect(matrixService.matrix.masterGainDb, closeTo(-4.5, 0.1));

      final resMute = await kernel.execute('master mute');
      expect(resMute.isSuccess, isTrue);
      expect(matrixService.matrix.isMuted, isTrue);

      final resDim = await kernel.execute('master dim');
      expect(resDim.isSuccess, isTrue);
      expect(matrixService.matrix.isDimmed, isTrue);

      final resMono = await kernel.execute('master mono');
      expect(resMono.isSuccess, isTrue);
      expect(matrixService.matrix.isMono, isTrue);

      final resRec = await kernel.execute('master rec');
      expect(resRec.isSuccess, isTrue);
      expect(matrixService.matrix.isMasterRecording, isTrue);

      final resStopRec = await kernel.execute('master stop-rec');
      expect(resStopRec.isSuccess, isTrue);
      expect(matrixService.matrix.isMasterRecording, isFalse);
    });

    test('eq command configures low, mid, high bands and bypass', () async {
      final resLow = await kernel.execute('eq low 3.5');
      expect(resLow.isSuccess, isTrue);
      expect(matrixService.matrix.eqLowDb, 3.5);

      final resMid = await kernel.execute('eq mid -2.0');
      expect(resMid.isSuccess, isTrue);
      expect(matrixService.matrix.eqMidDb, -2.0);

      final resHigh = await kernel.execute('eq high 4.0');
      expect(resHigh.isSuccess, isTrue);
      expect(matrixService.matrix.eqHighDb, 4.0);

      final resBypass = await kernel.execute('eq bypass');
      expect(resBypass.isSuccess, isTrue);
      expect(matrixService.matrix.isEqBypassed, isTrue);
    });

    test('comp command configures threshold, ratio and bypass', () async {
      final resThresh = await kernel.execute('comp thresh -14.0');
      expect(resThresh.isSuccess, isTrue);
      expect(matrixService.matrix.compThresholdDb, -14.0);

      final resRatio = await kernel.execute('comp ratio 4.0');
      expect(resRatio.isSuccess, isTrue);
      expect(matrixService.matrix.compRatio, 4.0);

      final resBypass = await kernel.execute('comp bypass');
      expect(resBypass.isSuccess, isTrue);
      expect(matrixService.matrix.isCompBypassed, isTrue);
    });

    test('route command redirects virtual channels', () async {
      final res = await kernel.execute('route dj_deck_a cue');
      expect(res.isSuccess, isTrue);
      expect(matrixService.matrix.channelRoutings['dj_deck_a'], 'cue');
    });

    test('clock command controls play, pause, stop, bpm and tap', () async {
      final resBpm = await kernel.execute('clock bpm 126.0');
      expect(resBpm.isSuccess, isTrue);
      expect(clockService.bpm, 126.0);

      final resPlay = await kernel.execute('clock play');
      expect(resPlay.isSuccess, isTrue);
      expect(clockService.isPlaying, isTrue);

      final resPause = await kernel.execute('clock pause');
      expect(resPause.isSuccess, isTrue);
      expect(clockService.isPaused, isTrue);

      final resStop = await kernel.execute('clock stop');
      expect(resStop.isSuccess, isTrue);
      expect(clockService.isStopped, isTrue);

      final resTap = await kernel.execute('clock tap');
      expect(resTap.isSuccess, isTrue);
    });

    test('registerHandler dispatches custom ITerminalCommandHandler in O(1)', () async {
      kernel.registerHandler(_EchoTestHandler());
      final res = await kernel.execute('echo_custom hello world');
      expect(res.isSuccess, isTrue);
      expect(res.message, 'echo_custom:hello,world');
    });
  });
}

class _EchoTestHandler implements ITerminalCommandHandler {
  @override
  Set<String> get supportedDomains => const {'echo_custom'};

  @override
  TunnerOsCommandResult execute(
    String domain,
    List<String> args,
    String rawCommandLine,
  ) {
    return TunnerOsCommandResult.success('$domain:${args.join(',')}');
  }
}
