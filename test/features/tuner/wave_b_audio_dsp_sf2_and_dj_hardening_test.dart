import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tunner/core/audio/domain/studio_master_audio_mixer.dart';
import 'package:tunner/core/channels/domain/studio_modular_plug.dart';
import 'package:tunner/core/channels/domain/studio_patchbay_routing_service.dart';
import 'package:tunner/core/channels/domain/studio_plug_type.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/sf2_models.dart';
import 'package:tunner/features/audio_synthesizer/domain/sf2/sf2_wavetable_oscillator.dart';
import 'package:tunner/features/dj_console/domain/i_dj_deck_audio_player.dart';
import 'package:tunner/features/dj_console/presentation/dj_console_view_model.dart';
import 'package:tunner/features/metronome/domain/tap_tempo_engine.dart';
import 'package:tunner/features/modular_rack/domain/module_connection.dart';
import 'package:tunner/features/modular_rack/domain/port_id.dart';
import 'package:tunner/features/modular_rack/domain/signal_bus.dart';
import 'package:tunner/features/modular_rack/domain/signal_type.dart';
import 'package:tunner/features/practice_recorder/domain/multitrack_session_entity.dart';
import 'package:tunner/features/tuner/domain/note_entity.dart';
import 'package:tunner/features/tuner/domain/temperament_engine.dart';
import 'package:tunner/features/vocal_autotune/domain/autotune_config_entity.dart';
import 'package:tunner/features/vocal_autotune/domain/vocal_autotune_processor.dart';

class _SpyDjDeckAudioPlayer implements IDjDeckAudioPlayer {
  final Map<String, double> lastRates = {};

  @override
  Future<void> loadDeckTrack(
    String deckId, {
    String? filePath,
    Uint8List? wavBytes,
    String? title,
    double? bpm,
  }) async {}

  @override
  bool isDeckPlaying(String deckId) => false;

  @override
  Future<void> pauseDeck(String deckId) async {}

  @override
  Future<void> playDeck(String deckId) async {}

  @override
  Future<void> seekDeck(String deckId, Duration position) async {}

  @override
  Future<void> setDeckPlaybackRate(String deckId, double rate) async {
    lastRates[deckId] = rate;
  }

  @override
  Future<void> setDeckVolume(String deckId, double volume) async {}

  @override
  void dispose() {}
}

void main() {
  group('Wave B Audio, DSP, Temperaments, SF2 & DJ Hardening Tests', () {
    test('TemperamentEngine Vallotti/Young II/Werckmeister IV accuracy and A4=440Hz anchoring', () {
      const engine = TemperamentEngine();
      final vallotti = TemperamentEngine.getById('vallotti');
      expect(vallotti.centsOffsets[11], closeTo(-9.78, 0.05));
      expect(vallotti.centsOffsets[4], closeTo(-7.82, 0.05));

      final youngII = TemperamentEngine.getById('young_ii');
      expect(youngII.centsOffsets[11], closeTo(-9.78, 0.05));
      expect(youngII.centsOffsets[5], closeTo(-1.96, 0.05));

      final werck = TemperamentEngine.getById('werckmeister_iii');
      final a4Target = engine.getTargetFrequency(
        midiNumber: 69,
        temperament: werck,
        a4Ref: 440.0,
        rootKey: 0,
        anchorA4: true,
      );
      expect(a4Target, closeTo(440.0, 0.01));
    });

    test('NoteEntity.frequencyForNote fixes Cb/B# octave carry and accepts Unicode accidentals', () {
      expect(NoteEntity.frequencyForNote('Cb4'), closeTo(NoteEntity.frequencyForNote('B3'), 0.01));
      expect(NoteEntity.frequencyForNote('B#3'), closeTo(NoteEntity.frequencyForNote('C4'), 0.01));
      expect(NoteEntity.frequencyForNote('Fa♯4'), closeTo(NoteEntity.frequencyForNote('Fa#4'), 0.01));
      expect(NoteEntity.frequencyForNote('Si♭4'), closeTo(NoteEntity.frequencyForNote('Sib4'), 0.01));
    });

    test('TapTempoEngine measures slow tempos (20-29 BPM) accurately', () {
      final tap = TapTempoEngine();
      tap.recordTap(1000);
      final res = tap.recordTap(3500);
      expect(res.bpm, equals(24));
    });

    test('Sf2WavetableOscillator renders Release phase beyond note duration without truncation', () {
      const osc = Sf2WavetableOscillator();
      final sampleData = Int16List.fromList(List.generate(4410, (i) => ((i % 100) * 200) - 10000));
      const header = Sf2SampleHeader(
        name: 'test',
        start: 0,
        end: 4410,
        startLoop: 100,
        endLoop: 4000,
        sampleRate: 44100,
        originalPitch: 60,
        pitchCorrection: 0,
        sampleLink: 0,
        sampleType: 1,
      );
      const env = Sf2EnvelopeParams(attackSeconds: 0.005, releaseSeconds: 0.25);
      final out = osc.renderNoteSamples(
        sampleData: sampleData,
        header: header,
        targetMidiPitch: 60,
        durationSeconds: 0.2,
        outputSampleRate: 44100,
        envelope: env,
      );
      expect(out.length, greaterThan((0.2 * 44100).round()));
    });

    test('VocalAutoTuneProcessor.processWavBytes tunes 16-bit PCM WAV via TD-PSOLA', () {
      const sampleRate = 44100;
      const totalSamples = 4410;
      final wav = Uint8List(44 + totalSamples * 2);
      final view = ByteData.sublistView(wav);
      wav.setRange(0, 4, 'RIFF'.codeUnits);
      view.setUint32(4, 36 + totalSamples * 2, Endian.little);
      wav.setRange(8, 12, 'WAVE'.codeUnits);
      wav.setRange(12, 16, 'fmt '.codeUnits);
      view.setUint32(16, 16, Endian.little);
      view.setUint16(20, 1, Endian.little);
      view.setUint16(22, 1, Endian.little);
      view.setUint32(24, sampleRate, Endian.little);
      view.setUint32(28, sampleRate * 2, Endian.little);
      view.setUint16(32, 2, Endian.little);
      view.setUint16(34, 16, Endian.little);
      wav.setRange(36, 40, 'data'.codeUnits);
      view.setUint32(40, totalSamples * 2, Endian.little);
      for (int i = 0; i < totalSamples; i++) {
        view.setInt16(44 + i * 2, ((i % 100) * 150) - 7500, Endian.little);
      }

      final processor = VocalAutoTuneProcessor(
        config: const AutoTuneConfigEntity(isEnabled: true, correctionAmount: 1.0, retuneSpeedMs: 0.0),
      );
      final outWav = processor.processWavBytes(
        wavBytes: wav,
        pitchTrack: const [
          TimedPitchSample(
            timeMs: 0,
            frequencyHz: 430.0,
            centsDeviation: -39.0,
            targetNoteName: 'La4',
          ),
          TimedPitchSample(
            timeMs: 100,
            frequencyHz: 430.0,
            centsDeviation: -39.0,
            targetNoteName: 'La4',
          ),
        ],
      );
      expect(outWav.length, equals(wav.length));
      expect(String.fromCharCodes(outWav.sublist(0, 4)), equals('RIFF'));
    });

    test('DjConsoleViewModel.syncBpm updates deck playback rate', () {
      final spy = _SpyDjDeckAudioPlayer();
      final vm = DjConsoleViewModel(deckAudioPlayer: spy);
      addTearDown(vm.dispose);
      vm.syncBpm('B');
      expect(spy.lastRates.containsKey('B'), isTrue);
    });

    test('StudioPatchbayRoutingService dispatches once per sink and enforces channel Mute', () {
      final service = StudioPatchbayRoutingService.isolated();
      addTearDown(service.dispose);
      final channel = service.matrix.channels.values.first;
      const sourcePlug = StudioModularPlug(
        id: 'plug_src_1',
        label: 'Deck A Out',
        toolId: 'dj',
        type: StudioPlugType.audioOutput,
      );
      const sinkPlug = StudioModularPlug(
        id: 'plug_sink_1',
        label: 'Master In',
        toolId: 'master',
        type: StudioPlugType.audioInput,
      );
      service.registerPlug(sourcePlug);
      service.registerPlug(sinkPlug);

      service.connectPlugToChannel(sourcePlug.id, channel.id);
      service.connectPlugToChannel(sinkPlug.id, channel.id);

      int callCount = 0;
      Map<String, dynamic>? lastPayload;
      service.registerSinkListener(sinkPlug.id, (_, _, payload) {
        callCount++;
        lastPayload = payload;
      });

      service.dispatchSignalFromPlug(
        sourcePlugId: sourcePlug.id,
        payload: {'title': 'Track 1', 'isPlaying': true, 'pcmBuffer': Float32List.fromList([0.5, -0.5])},
      );
      expect(callCount, equals(1));
      expect(lastPayload?['isPlaying'], isTrue);

      service.toggleChannelMute(channel.id);
      service.dispatchSignalFromPlug(
        sourcePlugId: sourcePlug.id,
        payload: {'isPlaying': true, 'pcmBuffer': Float32List.fromList([0.5, -0.5])},
      );
      expect(callCount, equals(2));
      expect(lastPayload?['isPlaying'], isFalse);
      expect((lastPayload?['pcmBuffer'] as Float32List)[0], equals(0.0));
    });

    test('SignalBus broadcast only targets input ports and never leaks to output ports', () async {
      final bus = SignalBus();
      addTearDown(bus.dispose);

      const srcOut = PortId(ownerModuleId: 'm1', id: 'out', displayName: 'Out', direction: PortDirection.output, signalType: SignalType.audioPcm);
      const otherOut = PortId(ownerModuleId: 'm2', id: 'out', displayName: 'Out2', direction: PortDirection.output, signalType: SignalType.audioPcm);
      const otherIn = PortId(ownerModuleId: 'm2', id: 'in', displayName: 'In2', direction: PortDirection.input, signalType: SignalType.audioPcm);

      bus.registerPort(srcOut);
      bus.registerPort(otherOut);
      bus.registerPort(otherIn);

      int outEvents = 0;
      int inEvents = 0;
      final subOut = bus.subscribe<String>(otherOut).listen((_) => outEvents++);
      final subIn = bus.subscribe<String>(otherIn).listen((_) => inEvents++);
      addTearDown(() async {
        await subOut.cancel();
        await subIn.cancel();
      });

      bus.addConnection(
        const ModuleConnection(
          connectionId: 'c1',
          sourcePort: srcOut,
          scope: ConnectionScope.broadcast,
        ),
      );
      bus.emit(srcOut, 'ping');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(inEvents, equals(1));
      expect(outEvents, equals(0));
    });

    test('StudioMasterAudioMixer.processStereoFrame is continuous across 0.85..0.95..1.05', () {
      final (l94, _) = StudioMasterAudioMixer.processStereoFrame(
        leftSample: 0.94,
        rightSample: 0.94,
        effectiveGain: 1.0,
        isMono: false,
      );
      final (l96, _) = StudioMasterAudioMixer.processStereoFrame(
        leftSample: 0.96,
        rightSample: 0.96,
        effectiveGain: 1.0,
        isMono: false,
      );
      expect(l96, greaterThan(l94));
    });
  });
}
