import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/dsl/domain/i_synth_voice_pool_port.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_event.dart';
import 'package:tunner/core/dsl/domain/studio_os_audio_kernel.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_interpreter.dart';
import 'package:tunner/core/dsl/domain/tunner_dsl_parser.dart';
import 'package:tunner/core/dsl/infrastructure/studio_os_audio_kernel_bridge.dart';
import 'package:tunner/features/acoustic_lab/domain/harmonic_series_analyzer.dart';
import 'package:tunner/features/audio_synthesizer/domain/polyphonic/polyphonic_voice_pool.dart';
import 'package:tunner/features/audio_synthesizer/domain/stem_audio_synthesizer.dart';
import 'package:tunner/features/drone/domain/drone_timbre.dart';
import 'package:tunner/features/drone/domain/harmonic_drone_synthesizer.dart';
import 'package:tunner/features/metronome/data/metronome_service.dart';
import 'package:tunner/features/project_format/data/tunner_binary_project_codec.dart';
import 'package:tunner/features/project_format/domain/tunner_project_package.dart';
import 'package:tunner/features/project_format/domain/tunner_tool_preset.dart';

class _RecordingSynthVoicePool implements ISynthVoicePoolPort {
  final List<({int midi, double velocity, double? frequency, int timestampMs})> noteOnLog = [];
  final List<({int midi, int timestampMs})> noteOffLog = [];
  int panicCalls = 0;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  int get maxPolyphony => 16;

  @override
  int get activeVoiceCount => noteOnLog.length - noteOffLog.length;

  @override
  String get dslWaveformName => 'sine';

  @override
  double attackSeconds = 0.01;

  @override
  double decaySeconds = 0.1;

  @override
  double sustainLevel = 0.8;

  @override
  double releaseSeconds = 0.2;

  @override
  double get masterGain => 1.0;

  @override
  void setDslWaveform(DslSynthWaveform value) {}

  @override
  void noteOn(int midiNote, double velocity, {double? frequency}) {
    noteOnLog.add((
      midi: midiNote,
      velocity: velocity,
      frequency: frequency,
      timestampMs: _clock.elapsedMilliseconds,
    ));
  }

  @override
  void noteOff(int midiNote) {
    noteOffLog.add((
      midi: midiNote,
      timestampMs: _clock.elapsedMilliseconds,
    ));
  }

  @override
  void panic() {
    panicCalls++;
  }
}

void main() {
  group('US-10.2: Anti Zip-Bomb ZLib, DSP Isolates, Compound Meters & Acoustic Precision', () {
    test('TunnerBinaryProjectCodec aborts chunked decompression early on zip-bomb payload', () {
      final codec = TunnerBinaryProjectCodec(maxAllowedDecompressedBytes: 1024);

      // Payload altamente comprimible (256 KiB de ceros) empaquetado con cabecera valida .tunner
      final hugePayload = Uint8List(256 * 1024);
      final compressed = zlib.encode(hugePayload);
      final framed = BytesBuilder(copy: false)
        ..add(TunnerBinaryProjectCodec.projectMagicBytes)
        ..addByte(TunnerBinaryProjectCodec.currentVersion)
        ..add(compressed);

      expect(
        () => codec.decodeProject(framed.toBytes()),
        throwsA(isA<FormatException>()),
      );
    });

    test('TunnerBinaryProjectCodec round-trip encodes and decodes valid project and tool preset', () {
      final codec = TunnerBinaryProjectCodec();
      const nowMicros = 1795440000000000;
      const project = TunnerProjectPackage(
        projectId: 'proj_us_10_2',
        projectName: 'Suite Hardening',
        masterBpm: 118.0,
        referenceA4Hz: 432.0,
        tools: [],
        createdAtMicros: nowMicros,
        updatedAtMicros: nowMicros,
      );

      final encoded = codec.encodeProject(project);
      final decoded = codec.decodeProject(encoded);
      expect(decoded.projectId, equals('proj_us_10_2'));
      expect(decoded.masterBpm, equals(118.0));
      expect(decoded.referenceA4Hz, equals(432.0));

      const tool = TunnerToolPreset(
        moduleTypeCode: 'harmonic_drone',
        customTitle: 'A432 Drone',
        toolParameters: {'referencePitchHz': 432.0},
        savedAtMicros: nowMicros,
      );
      final encodedTool = codec.encodeToolPreset(tool);
      final decodedTool = codec.decodeToolPreset(encodedTool);
      expect(decodedTool.moduleTypeCode, equals('harmonic_drone'));
      expect(decodedTool.toolParameters['referencePitchHz'], equals(432.0));
    });

    test('MetronomeService.computeSubTicksPerBeat supports compound and simple meters', () {
      expect(MetronomeService.computeSubTicksPerBeat(8), equals(2.0)); // 6/8, 9/8, 12/8
      expect(MetronomeService.computeSubTicksPerBeat(4), equals(4.0)); // 4/4, 3/4
      expect(MetronomeService.computeSubTicksPerBeat(2), equals(8.0)); // 2/2
      expect(MetronomeService.computeSubTicksPerBeat(16), equals(1.0)); // 7/16
    });

    test('HarmonicSeriesAnalyzer caches Hann window and runs analyzeAsync off-thread', () async {
      final w1 = HarmonicSeriesAnalyzer.getHannWindow(1024);
      final w2 = HarmonicSeriesAnalyzer.getHannWindow(1024);
      expect(identical(w1, w2), isTrue);
      expect(HarmonicSeriesAnalyzer.hasCachedHannWindow(1024), isTrue);

      const sampleRate = 44100.0;
      const f0 = 440.0;
      final samples = List<double>.generate(
        2048,
        (i) => math.sin(2.0 * math.pi * f0 * i / sampleRate),
      );

      const analyzer = HarmonicSeriesAnalyzer(maxHarmonics: 6);
      final asyncResult = await analyzer.analyzeAsync(
        fundamentalHz: f0,
        samples: samples,
        sampleRate: sampleRate,
      );
      expect(asyncResult.harmonics, isNotEmpty);
      expect(asyncResult.fundamentalHz, equals(f0));
    });

    test('HarmonicDroneSynthesizer enforces Nyquist anti-aliasing guard and A4 reference pitch is configurable', () {
      const sampleRate = 44100;
      // Frecuencia por encima de 0.48 * sampleRate debe retornar 0.0
      final aliasedSample = HarmonicDroneSynthesizer.synthesizeVoiceSample(
        sampleRate * 0.49,
        0.001,
        DroneTimbre.organ,
        sampleRate: sampleRate,
      );
      expect(aliasedSample, equals(0.0));

      // Calibracion parametrica A4 = 432 Hz en todos los motores
      expect(
        TunnerDslInterpreter.midiToFrequency(69, referencePitchHz: 432.0),
        closeTo(432.0, 1e-6),
      );
      expect(
        StemAudioSynthesizer.midiPitchToFrequency(69, referencePitchHz: 432.0),
        closeTo(432.0, 1e-6),
      );
      expect(
        PolyphonicVoicePool.midiToFrequency(69, referencePitchHz: 432.0),
        closeTo(432.0, 1e-6),
      );
    });
  });

  group('US-10.3: Temporal DSL Scheduler in TunnerDslInterpreter & StudioOsAudioKernelBridge', () {
    test('Accumulates scheduledOffsetMs across note, rest, chord and loop without firing all at t=0', () async {
      const script = '''
        tempo 120;
        note C4 1/4;
        rest 1/4;
        chord [C4, E4, G4] 1/2;
        loop 2 {
          note A4 1/8;
          rest 1/8;
        }
      ''';

      final parseResult = TunnerDslParser().parse(script);
      expect(parseResult.isSuccess, isTrue);
      final kernel = StudioOsAudioKernel();
      final interpreter = TunnerDslInterpreter(defaultKernel: kernel);

      final report = await interpreter.interpret(parseResult.program!);
      expect(report.isSuccess, isTrue);

      final notes = report.generatedEvents.whereType<StudioOsNoteEvent>().toList();
      final rests = report.generatedEvents.whereType<StudioOsRestEvent>().toList();
      final chords = report.generatedEvents.whereType<StudioOsChordEvent>().toList();

      expect(notes.length, equals(3));
      expect(rests.length, equals(3));
      expect(chords.length, equals(1));

      // At 120 BPM: 1/4 = 500ms, 1/2 = 1000ms, 1/8 = 250ms
      expect(notes[0].scheduledOffsetMs, equals(0));
      expect(notes[0].durationMs, equals(500));

      expect(rests[0].scheduledOffsetMs, equals(500));
      expect(rests[0].durationMs, equals(500));

      expect(chords[0].scheduledOffsetMs, equals(1000));
      expect(chords[0].durationMs, equals(1000));

      // Loop iteration 1
      expect(notes[1].scheduledOffsetMs, equals(2000));
      expect(notes[1].durationMs, equals(250));
      expect(rests[1].scheduledOffsetMs, equals(2250));
      expect(rests[1].durationMs, equals(250));

      // Loop iteration 2
      expect(notes[2].scheduledOffsetMs, equals(2500));
      expect(notes[2].durationMs, equals(250));
      expect(rests[2].scheduledOffsetMs, equals(2750));
      expect(rests[2].durationMs, equals(250));

      expect(report.totalScheduledDurationMs, equals(3000));
      kernel.dispose();
    });

    test('Mid-script tempo change preserves elapsed ms for previous events', () async {
      const script = '''
        tempo 120;
        note C4 1/4;
        tempo 60;
        note D4 1/4;
      ''';

      final parseResult = TunnerDslParser().parse(script);
      expect(parseResult.isSuccess, isTrue);
      final kernel = StudioOsAudioKernel();
      final interpreter = TunnerDslInterpreter(defaultKernel: kernel);

      final report = await interpreter.interpret(parseResult.program!);
      expect(report.isSuccess, isTrue);

      final notes = report.generatedEvents.whereType<StudioOsNoteEvent>().toList();
      expect(notes.length, equals(2));
      expect(notes[0].scheduledOffsetMs, equals(0));
      expect(notes[0].durationMs, equals(500)); // 1/4 at 120 BPM
      expect(notes[1].scheduledOffsetMs, equals(500));
      expect(notes[1].durationMs, equals(1000)); // 1/4 at 60 BPM
      expect(report.totalScheduledDurationMs, equals(1500));
      kernel.dispose();
    });

    test('StudioOsAudioKernelBridge schedules future notes asynchronously and cancels on dispose', () async {
      const script = '''
        tempo 240;
        note C4 1/8;
        rest 1/8;
        note E4 1/8;
      ''';
      // At 240 BPM: 1/4 = 250ms, 1/8 = 125ms
      // C4 at 0ms (dur 125ms), rest at 125ms (dur 125ms), E4 at 250ms (dur 125ms)

      final kernel = StudioOsAudioKernel();
      final synth = _RecordingSynthVoicePool();
      final bridge = StudioOsAudioKernelBridge(
        kernel: kernel,
        synthVoicePool: synth,
      );

      final parseResult = TunnerDslParser().parse(script);
      expect(parseResult.isSuccess, isTrue);
      final interpreter = TunnerDslInterpreter(defaultKernel: kernel);

      final report = await interpreter.interpret(parseResult.program!);
      expect(report.isSuccess, isTrue);

      // Immediately after interpret(): only C4 (t=0) should have fired; E4 (t=250ms) must be scheduled via Timer
      expect(synth.noteOnLog.length, equals(1));
      expect(synth.noteOnLog.first.midi, equals(60)); // C4
      expect(bridge.activeScheduledTimerCount, greaterThanOrEqualTo(2));

      // Wait for E4 to fire after the rest
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(synth.noteOnLog.length, equals(2));
      expect(synth.noteOnLog[1].midi, equals(64)); // E4
      expect(
        synth.noteOnLog[1].timestampMs - synth.noteOnLog[0].timestampMs,
        greaterThanOrEqualTo(180),
      );

      bridge.dispose();
      expect(bridge.activeScheduledTimerCount, equals(0));
      kernel.dispose();
    });
  });
}
