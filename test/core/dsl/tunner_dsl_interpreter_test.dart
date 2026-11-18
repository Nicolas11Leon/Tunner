import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_event.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_kernel.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_interpreter.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_parser.dart';

void main() {
  group('TunnerDslInterpreter Tests', () {
    late StudioOsAudioKernel kernel;
    late TunnerDslInterpreter interpreter;
    late TunnerDslParser parser;

    setUp(() {
      kernel = StudioOsAudioKernel(maxHistoryLength: 100);
      interpreter = TunnerDslInterpreter(defaultKernel: kernel);
      parser = TunnerDslParser();
    });

    tearDown(() {
      kernel.dispose();
    });

    test('static note and frequency calculations are acoustically precise', () {
      expect(TunnerDslInterpreter.pitchToMidi('C4'), 60);
      expect(TunnerDslInterpreter.pitchToMidi('A4'), 69);
      expect(TunnerDslInterpreter.pitchToMidi('A#4'), 70);
      expect(TunnerDslInterpreter.pitchToMidi('Bb4'), 70);
      expect(TunnerDslInterpreter.pitchToMidi('C5'), 72);

      // Frecuencias canónicas
      expect(TunnerDslInterpreter.midiToFrequency(69), 440.0);
      expect(TunnerDslInterpreter.midiToFrequency(57), 220.0); // A3
      expect(TunnerDslInterpreter.midiToFrequency(81), 880.0); // A5
      expect(TunnerDslInterpreter.midiToFrequency(60), closeTo(261.63, 0.01)); // C4

      // Fracciones y duraciones
      expect(TunnerDslInterpreter.parseFraction('1/4'), 0.25);
      expect(TunnerDslInterpreter.parseFraction('1/8'), 0.125);
      expect(TunnerDslInterpreter.parseFraction('1/2'), 0.5);

      // A 120 BPM: 1 beat = 500 ms (1/4 de nota)
      expect(TunnerDslInterpreter.calculateDurationMs('1/4', 120.0), 500.0);
      expect(TunnerDslInterpreter.calculateDurationMs('1/8', 120.0), 250.0);
      expect(TunnerDslInterpreter.calculateDurationMs('1/2', 120.0), 1000.0);
    });

    test('interprets and dispatches complete studio script', () async {
      const source = '''
        tempo 130;
        channel synth;
        connect @synth.out -> @master.in;
        set @master.gain = -3.0 dB;
        note C4 1/4;
        chord [C4, E4, G4] 1/2;
        rest 1/8;
        play;
      ''';

      final parseResult = parser.parse(source);
      expect(parseResult.isSuccess, isTrue);

      final report = await interpreter.interpret(parseResult.program!, kernel: kernel);

      expect(report.isSuccess, isTrue);
      expect(report.totalStatementsExecuted, 8);
      expect(report.warnings, isEmpty);
      expect(report.generatedEvents.length, 8);

      expect(report.generatedEvents[0], isA<StudioOsTempoEvent>());
      expect((report.generatedEvents[0] as StudioOsTempoEvent).bpm, 130.0);

      expect(report.generatedEvents[1], isA<StudioOsChannelDeclaredEvent>());
      expect((report.generatedEvents[1] as StudioOsChannelDeclaredEvent).channelName, 'synth');

      expect(report.generatedEvents[2], isA<StudioOsConnectionEvent>());
      expect(report.generatedEvents[3], isA<StudioOsParameterEvent>());

      expect(report.generatedEvents[4], isA<StudioOsNoteEvent>());
      final noteEvent = report.generatedEvents[4] as StudioOsNoteEvent;
      expect(noteEvent.pitch, 'C4');
      expect(noteEvent.midiNote, 60);

      expect(report.generatedEvents[5], isA<StudioOsChordEvent>());
      final chordEvent = report.generatedEvents[5] as StudioOsChordEvent;
      expect(chordEvent.pitches, ['C4', 'E4', 'G4']);
      expect(chordEvent.midiNotes, [60, 64, 67]);

      expect(report.generatedEvents[6], isA<StudioOsRestEvent>());
      expect(report.generatedEvents[7], isA<StudioOsTransportEvent>());
      expect((report.generatedEvents[7] as StudioOsTransportEvent).action, 'play');
    });

    test('evaluates nested loops deterministically', () async {
      const source = '''
        loop 3 {
          note A4 1/4;
          rest 1/4;
        }
      ''';

      final parseResult = parser.parse(source);
      final report = await interpreter.interpret(parseResult.program!, kernel: kernel);

      expect(report.isSuccess, isTrue);
      // 3 repeticiones x 2 sentencias = 6 ejecuciones
      expect(report.totalStatementsExecuted, 6);
      expect(report.generatedEvents.length, 6);

      for (var i = 0; i < 6; i += 2) {
        expect(report.generatedEvents[i], isA<StudioOsNoteEvent>());
        expect(report.generatedEvents[i + 1], isA<StudioOsRestEvent>());
      }
    });

    test('handles exceptions during evaluation and captures warnings', () async {
      kernel.onTempoChanged = (bpm) async {
        throw StateError('Fallo simulado en hardware clock');
      };

      const source = 'tempo 140;';
      final parseResult = parser.parse(source);
      final report = await interpreter.interpret(parseResult.program!, kernel: kernel);

      expect(report.isSuccess, isFalse);
      expect(report.warnings.length, 1);
      expect(report.warnings.first, contains('Fallo simulado en hardware clock'));
    });
  });
}
