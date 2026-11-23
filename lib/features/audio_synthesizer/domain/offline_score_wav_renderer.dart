import 'dart:math' as math;
import 'dart:typed_data';

import '../../sheet_music/domain/score_tree.dart';
import '../../universal_importer/domain/canonical_midi_exporter.dart';
import 'pcm_wav_synthesizer.dart';
import 'polyphonic/polyphonic_voice_pool.dart';
import 'sf2/i_soundfont_synthesizer_service.dart';
import 'sf2/sf2_models.dart';
import 'sf2/sf2_wavetable_oscillator.dart';

/// Evento de nota determinista para renderizado offline multi-nota / polifonico.
class OfflineNoteEvent {
  final double startSeconds;
  final double durationSeconds;
  final int midiPitch;
  final int velocity;
  final int? patch;

  const OfflineNoteEvent({
    required this.startSeconds,
    required this.durationSeconds,
    required this.midiPitch,
    this.velocity = 100,
    this.patch,
  });
}

/// Renderizador offline multipista y multi-nota en Pure Dart para partituras y secuencias MIDI.
///
/// Soporta tres motores intercambiables con fallback limpio:
/// 1. Banco SoundFont SF2 (`ISoundFontSynthesizerService`) mediante interpolacion Hermite-4.
/// 2. Motor polifonico sustractivo (`PolyphonicVoicePool`) con disparo muestra a muestra.
/// 3. Fallback aditivo armonico puro cuando no hay banco SF2 ni pool configurado.
class OfflineScoreWavRenderer {
  static const int defaultSampleRate = 44100;
  static const int ticksPerBeat = 4;

  final Sf2WavetableOscillator _sf2Oscillator;

  const OfflineScoreWavRenderer({
    Sf2WavetableOscillator sf2Oscillator = const Sf2WavetableOscillator(),
  }) : _sf2Oscillator = sf2Oscillator;

  /// Extrae todos los eventos sonoros de una partitura [HierarchicalScore] a [bpm].
  static List<OfflineNoteEvent> extractScoreEvents({
    required HierarchicalScore score,
    required int bpm,
    int velocity = 100,
    int? patch,
  }) {
    if (score.measures.isEmpty) return const [];
    final safeBpm = bpm.clamp(20, 300);
    final double secondsPerTick = (60.0 / safeBpm) / ticksPerBeat;
    final events = <OfflineNoteEvent>[];
    int currentMeasureStartTick = 0;

    for (final measure in score.measures) {
      for (final note in measure.notes) {
        final isRest = note.isRest ||
            note.noteName == '--' ||
            note.noteName.toLowerCase() == 'rest' ||
            note.noteName.isEmpty;
        if (isRest) continue;

        final midiPitch = CanonicalMidiExporter.noteNameToMidiPitch(note.noteName);
        final startSec = (currentMeasureStartTick + note.startTick) * secondsPerTick;
        final durationSec = math.max(0.02, note.durationTicks * secondsPerTick);
        events.add(OfflineNoteEvent(
          startSeconds: startSec,
          durationSeconds: durationSec,
          midiPitch: midiPitch,
          velocity: velocity,
          patch: patch,
        ));
      }
      currentMeasureStartTick += measure.timeSignature.totalTicks;
    }

    return events;
  }

  /// Calcula la duracion total en segundos de una partitura [HierarchicalScore].
  static double calculateScoreDurationSeconds({
    required HierarchicalScore score,
    required int bpm,
  }) {
    if (score.measures.isEmpty) return 2.0;
    final safeBpm = bpm.clamp(20, 300);
    final double secondsPerTick = (60.0 / safeBpm) / ticksPerBeat;
    int totalTicks = 0;
    for (final measure in score.measures) {
      totalTicks += measure.timeSignature.totalTicks;
    }
    return math.max(1.0, totalTicks * secondsPerTick);
  }

  /// Renderiza una partitura [HierarchicalScore] en muestras Float64 (escala PCM 16-bit).
  Float64List renderScoreSamples({
    required HierarchicalScore score,
    required int bpm,
    int sampleRate = defaultSampleRate,
    int? totalSamples,
    double a4Ref = 440.0,
    ISoundFontSynthesizerService? soundFontService,
    int? sf2Patch,
    PolyphonicVoicePool? polyphonicPool,
  }) {
    final durationSeconds = calculateScoreDurationSeconds(score: score, bpm: bpm);
    final targetSamples = totalSamples ?? (durationSeconds * sampleRate).round();
    if (score.measures.isEmpty || targetSamples <= 0) {
      return Float64List(math.max(0, targetSamples));
    }

    final events = extractScoreEvents(
      score: score,
      bpm: bpm,
      patch: sf2Patch,
    );

    return renderEventsSamples(
      events: events,
      totalSamples: targetSamples,
      sampleRate: sampleRate,
      a4Ref: a4Ref,
      soundFontService: soundFontService,
      sf2Patch: sf2Patch,
      polyphonicPool: polyphonicPool,
    );
  }

  /// Renderiza una lista arbitraria de [OfflineNoteEvent] a muestras Float64 (escala PCM 16-bit).
  Float64List renderEventsSamples({
    required List<OfflineNoteEvent> events,
    required int totalSamples,
    int sampleRate = defaultSampleRate,
    double a4Ref = 440.0,
    ISoundFontSynthesizerService? soundFontService,
    int? sf2Patch,
    PolyphonicVoicePool? polyphonicPool,
  }) {
    final buffer = Float64List(math.max(0, totalSamples));
    if (events.isEmpty || totalSamples <= 0) return buffer;

    final safeA4 = (a4Ref > 20.0 && a4Ref.isFinite) ? a4Ref : 440.0;

    final bool canUseSf2 = soundFontService != null &&
        soundFontService.activeSoundFont.sampleHeaders.isNotEmpty &&
        soundFontService.activeSoundFont.presets.isNotEmpty;

    if (canUseSf2) {
      _renderEventsWithSoundFont(
        buffer: buffer,
        events: events,
        sampleRate: sampleRate,
        a4Ref: safeA4,
        soundFont: soundFontService.activeSoundFont,
        defaultPatch: sf2Patch ?? soundFontService.activePatch,
      );
      return buffer;
    }

    if (polyphonicPool != null) {
      _renderEventsWithVoicePool(
        buffer: buffer,
        events: events,
        sampleRate: sampleRate,
        a4Ref: safeA4,
        pool: polyphonicPool,
      );
      return buffer;
    }

    _renderEventsAdditiveFallback(
      buffer: buffer,
      events: events,
      sampleRate: sampleRate,
      a4Ref: safeA4,
    );
    return buffer;
  }

  /// Renderiza una partitura completa a un buffer canonico WAV PCM 16-bit mono.
  Uint8List renderScoreToWav({
    required HierarchicalScore score,
    required int bpm,
    int sampleRate = defaultSampleRate,
    double a4Ref = 440.0,
    ISoundFontSynthesizerService? soundFontService,
    int? sf2Patch,
    PolyphonicVoicePool? polyphonicPool,
  }) {
    final samples = renderScoreSamples(
      score: score,
      bpm: bpm,
      sampleRate: sampleRate,
      a4Ref: a4Ref,
      soundFontService: soundFontService,
      sf2Patch: sf2Patch,
      polyphonicPool: polyphonicPool,
    );
    return encodeFloatSamplesToWav(samples, sampleRate: sampleRate);
  }

  /// Renderiza eventos discretos a un buffer canonico WAV PCM 16-bit mono.
  Uint8List renderEventsToWav({
    required List<OfflineNoteEvent> events,
    required double totalDurationSeconds,
    int sampleRate = defaultSampleRate,
    double a4Ref = 440.0,
    ISoundFontSynthesizerService? soundFontService,
    int? sf2Patch,
    PolyphonicVoicePool? polyphonicPool,
  }) {
    final totalSamples = math.max(1, (totalDurationSeconds * sampleRate).round());
    final samples = renderEventsSamples(
      events: events,
      totalSamples: totalSamples,
      sampleRate: sampleRate,
      a4Ref: a4Ref,
      soundFontService: soundFontService,
      sf2Patch: sf2Patch,
      polyphonicPool: polyphonicPool,
    );
    return encodeFloatSamplesToWav(samples, sampleRate: sampleRate);
  }

  /// Codifica muestras Float64 (escala PCM 16-bit) a WAV PCM 16-bit mono con limitador suave tanh.
  static Uint8List encodeFloatSamplesToWav(
    Float64List buffer, {
    int sampleRate = defaultSampleRate,
  }) {
    final pcmBytes = ByteData(buffer.length * 2);
    for (int i = 0; i < buffer.length; i++) {
      final double normalized = buffer[i] / 32768.0;
      final double saturated = _tanh(normalized);
      final int sampleInt16 = (saturated * 32767.0).round().clamp(-32768, 32767);
      pcmBytes.setInt16(i * 2, sampleInt16, Endian.little);
    }

    final header = PcmWavSynthesizer.buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: sampleRate,
      channels: 1,
      bitsPerSample: 16,
    );

    final builder = BytesBuilder(copy: false);
    builder.add(header);
    builder.add(pcmBytes.buffer.asUint8List());
    return builder.toBytes();
  }

  void _renderEventsWithSoundFont({
    required Float64List buffer,
    required List<OfflineNoteEvent> events,
    required int sampleRate,
    required double a4Ref,
    required Sf2SoundFont soundFont,
    required int defaultPatch,
  }) {
    for (final event in events) {
      final int startSample = (event.startSeconds * sampleRate).round();
      if (startSample >= buffer.length || startSample < 0) continue;

      final patch = event.patch ?? defaultPatch;
      final preset = soundFont.findPreset(patch);
      if (preset == null) {
        _mixAdditiveEvent(buffer, event, sampleRate, a4Ref);
        continue;
      }

      Sf2Zone? matchingPresetZone;
      for (final zone in preset.zones) {
        if (zone.keyRange.contains(event.midiPitch) &&
            zone.velRange.contains(event.velocity)) {
          matchingPresetZone = zone;
          break;
        }
      }

      final instrumentId = matchingPresetZone?.instrumentId ??
          (preset.zones.isNotEmpty ? preset.zones.first.instrumentId : 0);

      Sf2Instrument? inst;
      if (instrumentId != null && instrumentId < soundFont.instruments.length) {
        inst = soundFont.instruments[instrumentId];
      } else if (soundFont.instruments.isNotEmpty) {
        inst = soundFont.instruments.first;
      }

      Sf2Zone? matchingInstZone;
      if (inst != null) {
        for (final zone in inst.zones) {
          if (zone.keyRange.contains(event.midiPitch) &&
              zone.velRange.contains(event.velocity)) {
            matchingInstZone = zone;
            break;
          }
        }
        matchingInstZone ??= inst.zones.isNotEmpty ? inst.zones.first : null;
      }

      final sampleId = matchingInstZone?.sampleId ?? 0;
      if (sampleId >= soundFont.sampleHeaders.length) {
        _mixAdditiveEvent(buffer, event, sampleRate, a4Ref);
        continue;
      }

      final header = soundFont.sampleHeaders[sampleId];
      final combinedGens = <int, int>{};
      if (matchingPresetZone != null) combinedGens.addAll(matchingPresetZone.generators);
      if (matchingInstZone != null) combinedGens.addAll(matchingInstZone.generators);

      final envelope = Sf2EnvelopeParams(
        delaySeconds: combinedGens.containsKey(Sf2GeneratorType.delayVolEnv)
            ? Sf2EnvelopeParams.timecentsToSeconds(combinedGens[Sf2GeneratorType.delayVolEnv]!)
            : 0.001,
        attackSeconds: combinedGens.containsKey(Sf2GeneratorType.attackVolEnv)
            ? Sf2EnvelopeParams.timecentsToSeconds(combinedGens[Sf2GeneratorType.attackVolEnv]!)
            : 0.015,
        holdSeconds: combinedGens.containsKey(Sf2GeneratorType.holdVolEnv)
            ? Sf2EnvelopeParams.timecentsToSeconds(combinedGens[Sf2GeneratorType.holdVolEnv]!)
            : 0.010,
        decaySeconds: combinedGens.containsKey(Sf2GeneratorType.decayVolEnv)
            ? Sf2EnvelopeParams.timecentsToSeconds(combinedGens[Sf2GeneratorType.decayVolEnv]!)
            : 0.400,
        sustainLevel: combinedGens.containsKey(Sf2GeneratorType.sustainVolEnv)
            ? Sf2EnvelopeParams.centibelsToGain(combinedGens[Sf2GeneratorType.sustainVolEnv]!)
            : 0.40,
        releaseSeconds: combinedGens.containsKey(Sf2GeneratorType.releaseVolEnv)
            ? Sf2EnvelopeParams.timecentsToSeconds(combinedGens[Sf2GeneratorType.releaseVolEnv]!)
            : 0.080,
      );

      final rendered = _sf2Oscillator.renderNoteSamples(
        sampleData: soundFont.sampleData,
        header: header,
        targetMidiPitch: event.midiPitch,
        durationSeconds: event.durationSeconds,
        outputSampleRate: sampleRate,
        velocity: event.velocity,
        envelope: envelope,
        a4Ref: a4Ref,
      );

      final int count = math.min(rendered.length, buffer.length - startSample);
      for (int i = 0; i < count; i++) {
        buffer[startSample + i] += rendered[i];
      }
    }
  }

  void _renderEventsWithVoicePool({
    required Float64List buffer,
    required List<OfflineNoteEvent> events,
    required int sampleRate,
    required double a4Ref,
    required PolyphonicVoicePool pool,
  }) {
    pool.panic();
    pool.sampleRate = sampleRate.toDouble();

    final timeline = <_ScheduledVoiceAction>[];
    for (final e in events) {
      final startSample = (e.startSeconds * sampleRate).round().clamp(0, buffer.length);
      final endSample = ((e.startSeconds + e.durationSeconds) * sampleRate)
          .round()
          .clamp(startSample, buffer.length);
      timeline.add(_ScheduledVoiceAction(
        sampleIndex: startSample,
        isNoteOn: true,
        midiPitch: e.midiPitch,
        velocity: (e.velocity / 127.0).clamp(0.05, 1.0),
      ));
      timeline.add(_ScheduledVoiceAction(
        sampleIndex: endSample,
        isNoteOn: false,
        midiPitch: e.midiPitch,
        velocity: 0.0,
      ));
    }

    timeline.sort((a, b) {
      final cmp = a.sampleIndex.compareTo(b.sampleIndex);
      if (cmp != 0) return cmp;
      // Procesar noteOff antes de noteOn en la misma muestra
      if (a.isNoteOn == b.isNoteOn) return 0;
      return a.isNoteOn ? 1 : -1;
    });

    int cursor = 0;
    int actionIdx = 0;
    final tempBlock = Float64List(buffer.length);

    while (cursor < buffer.length) {
      while (actionIdx < timeline.length && timeline[actionIdx].sampleIndex <= cursor) {
        final action = timeline[actionIdx++];
        if (action.isNoteOn) {
          final freq = PolyphonicVoicePool.midiToFrequency(
            action.midiPitch,
            referencePitchHz: a4Ref,
          );
          pool.noteOn(action.midiPitch, action.velocity, frequency: freq);
        } else {
          pool.noteOff(action.midiPitch);
        }
      }

      final nextEventSample =
          actionIdx < timeline.length ? timeline[actionIdx].sampleIndex : buffer.length;
      final chunkLen = math.min(nextEventSample, buffer.length) - cursor;
      if (chunkLen <= 0) break;

      final slice = Float64List.sublistView(tempBlock, cursor, cursor + chunkLen);
      pool.renderMonoBlock(out: slice, numSamples: chunkLen);
      for (int i = 0; i < chunkLen; i++) {
        buffer[cursor + i] += slice[i] * 24000.0;
      }
      cursor += chunkLen;
    }

    pool.panic();
  }

  void _renderEventsAdditiveFallback({
    required Float64List buffer,
    required List<OfflineNoteEvent> events,
    required int sampleRate,
    required double a4Ref,
  }) {
    for (final event in events) {
      _mixAdditiveEvent(buffer, event, sampleRate, a4Ref);
    }
  }

  static void _mixAdditiveEvent(
    Float64List buffer,
    OfflineNoteEvent event,
    int sampleRate,
    double a4Ref,
  ) {
    final frequency = a4Ref * math.pow(2.0, (event.midiPitch - 69.0) / 12.0);
    final startSample = (event.startSeconds * sampleRate).round();
    final noteTotalSamples = (event.durationSeconds * sampleRate).round();
    final endSample = math.min(buffer.length, startSample + noteTotalSamples);

    if (startSample < 0 || startSample >= buffer.length || endSample <= startSample) {
      return;
    }

    final activeLength = endSample - startSample;
    final attackSamples =
        math.min((sampleRate * 0.015).round(), (activeLength * 0.15).round());
    final releaseSamples =
        math.min((sampleRate * 0.025).round(), (activeLength * 0.20).round());
    final releaseStartIndex = math.max(0, activeLength - releaseSamples);
    final velScale = (event.velocity / 127.0).clamp(0.1, 1.0);

    for (int s = 0; s < activeLength; s++) {
      final int sampleIndex = startSample + s;
      final double t = s / sampleRate;

      double envelope = 0.85;
      if (s < attackSamples && attackSamples > 0) {
        envelope = (s / attackSamples) * 0.85;
      } else if (s >= releaseStartIndex && releaseSamples > 0) {
        envelope = 0.85 * (1.0 - (s - releaseStartIndex) / releaseSamples);
      }

      final double signal = 0.75 * math.sin(2.0 * math.pi * frequency * t) +
          0.18 * math.sin(4.0 * math.pi * frequency * t) +
          0.07 * math.sin(6.0 * math.pi * frequency * t);

      buffer[sampleIndex] += signal * envelope * velScale * 24000.0;
    }
  }

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final double e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }
}

class _ScheduledVoiceAction {
  final int sampleIndex;
  final bool isNoteOn;
  final int midiPitch;
  final double velocity;

  const _ScheduledVoiceAction({
    required this.sampleIndex,
    required this.isNoteOn,
    required this.midiPitch,
    required this.velocity,
  });
}
