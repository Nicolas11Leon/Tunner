import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_event.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_kernel.dart';

void main() {
  group('StudioOsAudioKernel Tests', () {
    late StudioOsAudioKernel kernel;

    setUp(() {
      kernel = StudioOsAudioKernel(maxHistoryLength: 5);
    });

    tearDown(() {
      kernel.dispose();
    });

    test('dispatches tempo change and notifies listeners/callbacks', () async {
      double? receivedBpm;
      kernel.onTempoChanged = (bpm) async {
        receivedBpm = bpm;
      };

      StudioOsAudioEvent? streamEvent;
      final sub = kernel.eventStream.listen((event) {
        streamEvent = event;
      });

      await kernel.dispatchTempo(135.0);

      expect(receivedBpm, 135.0);
      expect(streamEvent, isA<StudioOsTempoEvent>());
      final tempoEvent = streamEvent as StudioOsTempoEvent;
      expect(tempoEvent.bpm, 135.0);
      expect(tempoEvent.eventType, 'TEMPO');
      expect(kernel.eventHistory.length, 1);

      await sub.cancel();
    });

    test('dispatches channel declaration and connection events', () async {
      String? declaredChannel;
      String? connSource;
      String? connDest;

      kernel.onChannelDeclared = (ch) async {
        declaredChannel = ch;
      };
      kernel.onConnectionChanged = (src, dst) async {
        connSource = src;
        connDest = dst;
      };

      await kernel.dispatchDeclareChannel('synth_lead');
      await kernel.dispatchConnect('@synth_lead.out', '@master.in');

      expect(declaredChannel, 'synth_lead');
      expect(connSource, '@synth_lead.out');
      expect(connDest, '@master.in');
      expect(kernel.eventHistory.length, 2);
      expect(kernel.eventHistory[0], isA<StudioOsChannelDeclaredEvent>());
      expect(kernel.eventHistory[1], isA<StudioOsConnectionEvent>());
    });

    test('dispatches parameter modification with unit', () async {
      String? paramTarget;
      String? paramName;
      dynamic paramVal;
      String? paramUnit;

      kernel.onParameterChanged = (t, p, v, u) async {
        paramTarget = t;
        paramName = p;
        paramVal = v;
        paramUnit = u;
      };

      await kernel.dispatchSetParameter('@eq', 'low', 3.5, unit: 'dB');

      expect(paramTarget, '@eq');
      expect(paramName, 'low');
      expect(paramVal, 3.5);
      expect(paramUnit, 'dB');

      final event = kernel.eventHistory.first as StudioOsParameterEvent;
      expect(event.target, '@eq');
      expect(event.parameter, 'low');
      expect(event.value, 3.5);
      expect(event.unit, 'dB');
    });

    test('dispatches note and chord events with accurate acoustic metadata', () async {
      String? notePitch;
      double? noteFreq;
      int? noteMidi;

      kernel.onNoteTriggered = (p, f, m, d, v) async {
        notePitch = p;
        noteFreq = f;
        noteMidi = m;
      };

      await kernel.dispatchNote('A4', 440.0, 69, '1/4', velocity: 0.9);

      expect(notePitch, 'A4');
      expect(noteFreq, 440.0);
      expect(noteMidi, 69);

      List<String>? chordPitches;
      kernel.onChordTriggered = (pitches, freqs, midis, dur, vel) async {
        chordPitches = pitches;
      };

      await kernel.dispatchChord(
        ['C4', 'E4', 'G4'],
        [261.63, 329.63, 392.00],
        [60, 64, 67],
        '1/2',
      );

      expect(chordPitches, ['C4', 'E4', 'G4']);
    });

    test('dispatches transport and rest events', () async {
      String? transportAction;
      kernel.onTransportChanged = (act) async {
        transportAction = act;
      };

      await kernel.dispatchTransport('play');
      await kernel.dispatchRest('1/8');

      expect(transportAction, 'play');
      expect(kernel.eventHistory.last, isA<StudioOsRestEvent>());
      expect((kernel.eventHistory.last as StudioOsRestEvent).durationFraction, '1/8');
    });

    test('truncates history to maxHistoryLength and supports clearHistory', () async {
      for (var i = 1; i <= 8; i++) {
        await kernel.dispatchTempo(100.0 + i);
      }

      // Max history is 5
      expect(kernel.eventHistory.length, 5);
      expect((kernel.eventHistory.last as StudioOsTempoEvent).bpm, 108.0);
      expect((kernel.eventHistory.first as StudioOsTempoEvent).bpm, 104.0);

      kernel.clearHistory();
      expect(kernel.eventHistory, isEmpty);
    });
  });
}
