import 'dart:math' as math;
import 'dart:typed_data';

import '../../audio_synthesizer/domain/pcm_wav_synthesizer.dart';
import 'tempo_entity.dart';

/// Resultado inmutable de la generacion offline de una pista de metronomo en formato WAV.
class OfflineMetronomeTrackResult {
  final Uint8List wavBytes;
  final int bpm;
  final int numerator;
  final int denominator;
  final int bars;
  final int countInBars;
  final int subdivision;
  final int sampleRate;
  final int totalBeats;
  final double durationSeconds;
  final bool isCompoundMeter;
  final TempoMark tempoMark;

  const OfflineMetronomeTrackResult({
    required this.wavBytes,
    required this.bpm,
    required this.numerator,
    required this.denominator,
    required this.bars,
    required this.countInBars,
    required this.subdivision,
    required this.sampleRate,
    required this.totalBeats,
    required this.durationSeconds,
    required this.isCompoundMeter,
    required this.tempoMark,
  });

  String get meter => '$numerator/$denominator';

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'meter': meter,
        'numerator': numerator,
        'denominator': denominator,
        'bars': bars,
        'countInBars': countInBars,
        'subdivision': subdivision,
        'sampleRate': sampleRate,
        'totalBeats': totalBeats,
        'durationSeconds': durationSeconds,
        'isCompoundMeter': isCompoundMeter,
        'sizeBytes': wavBytes.lengthInBytes,
        'tempoMark': tempoMark.toJson(),
      };
}

/// Generador offline determinista de pistas de clics de metronomo (click-track WAV PCM 16-bit).
/// Pure Dart: cero dependencias de Flutter ni relojes de hardware.
///
/// Soporta compases simples (2/4, 3/4, 4/4, 5/4) y compuestos (6/8, 9/8, 12/8),
/// subdivisiones por pulso y compases de cuenta previa ([countInBars]).
class OfflineMetronomeTrackGenerator {
  static const int defaultSampleRate = 44100;

  const OfflineMetronomeTrackGenerator();

  /// Determina si la signatura metrica corresponde a un compas compuesto (ej. 6/8, 9/8, 12/8).
  static bool isCompoundTimeSignature(int numerator, int denominator) {
    return denominator == 8 && numerator >= 6 && numerator % 3 == 0;
  }

  /// Sintetiza una pista WAV PCM 16-bit mono de metronomo y retorna sus bytes y metadatos.
  OfflineMetronomeTrackResult generateTrack({
    required int bpm,
    int numerator = 4,
    int denominator = 4,
    int bars = 4,
    int countInBars = 0,
    int subdivision = 1,
    int sampleRate = defaultSampleRate,
  }) {
    final int safeBpm = bpm.clamp(20, 300);
    final int safeNumerator = numerator.clamp(1, 32);
    final int safeDenominator = denominator.clamp(1, 16);
    final int safeBars = math.max(1, bars);
    final int safeCountInBars = math.max(0, countInBars);
    final int safeSubdivision = subdivision.clamp(1, 4);
    final int safeSampleRate = sampleRate >= 8000 ? sampleRate : defaultSampleRate;

    final int totalBars = safeCountInBars + safeBars;
    final int totalBeats = totalBars * safeNumerator;
    final bool isCompound = isCompoundTimeSignature(safeNumerator, safeDenominator);

    // Duracion de cada pulso de denominador: negra (den=4) = 60/bpm, corchea (den=8) = 30/bpm.
    final double secondsPerDenominatorBeat = (60.0 / safeBpm) * (4.0 / safeDenominator);
    final double secondsPerSubTick = secondsPerDenominatorBeat / safeSubdivision;
    final double totalDurationSeconds = totalBeats * secondsPerDenominatorBeat;
    final int totalSamples = math.max(1, (totalDurationSeconds * safeSampleRate).round());

    final Float64List downbeatClick = _extractPcm16FromWav(
      PcmWavSynthesizer.generateMetronomeClickWav(
        isDownbeat: true,
        sampleRate: safeSampleRate,
      ),
    );
    final Float64List normalClick = _extractPcm16FromWav(
      PcmWavSynthesizer.generateMetronomeClickWav(
        isDownbeat: false,
        sampleRate: safeSampleRate,
      ),
    );

    final Float64List mixBuffer = Float64List(totalSamples);
    final int totalSubTicks = totalBeats * safeSubdivision;

    for (int step = 0; step < totalSubTicks; step++) {
      final int beatIndexGlobal = step ~/ safeSubdivision;
      final int subIndex = step % safeSubdivision;
      final int beatInBar = beatIndexGlobal % safeNumerator;
      final int barIndex = beatIndexGlobal ~/ safeNumerator;
      final bool isCountIn = barIndex < safeCountInBars;

      final int sampleOffset = (step * secondsPerSubTick * safeSampleRate).round();
      if (sampleOffset >= totalSamples) break;

      final Float64List clickSource;
      final double gain;

      if (subIndex == 0) {
        if (beatInBar == 0) {
          clickSource = downbeatClick;
          gain = isCountIn ? 0.95 : 1.0;
        } else if (isCompound && beatInBar % 3 == 0) {
          // Acento secundario de compas compuesto (ej. pulso 4 de 6/8, pulsos 4 y 7 de 9/8)
          clickSource = downbeatClick;
          gain = 0.75;
        } else {
          clickSource = normalClick;
          gain = isCountIn ? 0.65 : 0.70;
        }
      } else {
        clickSource = normalClick;
        gain = 0.38;
      }

      final int writable = math.min(clickSource.length, totalSamples - sampleOffset);
      for (int i = 0; i < writable; i++) {
        mixBuffer[sampleOffset + i] += clickSource[i] * gain;
      }
    }

    final ByteData pcmBytes = ByteData(totalSamples * 2);
    for (int i = 0; i < totalSamples; i++) {
      final int sampleInt16 = mixBuffer[i].round().clamp(-32768, 32767);
      pcmBytes.setInt16(i * 2, sampleInt16, Endian.little);
    }

    final header = PcmWavSynthesizer.buildWavHeader(
      pcmDataBytes: pcmBytes.lengthInBytes,
      sampleRate: safeSampleRate,
      channels: 1,
      bitsPerSample: 16,
    );

    final wavBuilder = BytesBuilder(copy: false);
    wavBuilder.add(header);
    wavBuilder.add(pcmBytes.buffer.asUint8List());

    return OfflineMetronomeTrackResult(
      wavBytes: wavBuilder.toBytes(),
      bpm: safeBpm,
      numerator: safeNumerator,
      denominator: safeDenominator,
      bars: safeBars,
      countInBars: safeCountInBars,
      subdivision: safeSubdivision,
      sampleRate: safeSampleRate,
      totalBeats: totalBeats,
      durationSeconds: totalDurationSeconds,
      isCompoundMeter: isCompound,
      tempoMark: TempoMark.fromBpm(safeBpm),
    );
  }

  /// Conveniencia: retorna directamente el buffer WAV PCM 16-bit de la pista de metronomo.
  Uint8List generateClickTrackWav({
    required int bpm,
    int numerator = 4,
    int denominator = 4,
    int bars = 4,
    int countInBars = 0,
    int subdivision = 1,
    int sampleRate = defaultSampleRate,
  }) {
    return generateTrack(
      bpm: bpm,
      numerator: numerator,
      denominator: denominator,
      bars: bars,
      countInBars: countInBars,
      subdivision: subdivision,
      sampleRate: sampleRate,
    ).wavBytes;
  }

  static Float64List _extractPcm16FromWav(Uint8List wavBytes) {
    if (wavBytes.length <= 44) return Float64List(0);
    final pcmData = ByteData.sublistView(wavBytes, 44);
    final int sampleCount = pcmData.lengthInBytes ~/ 2;
    final out = Float64List(sampleCount);
    for (int i = 0; i < sampleCount; i++) {
      out[i] = pcmData.getInt16(i * 2, Endian.little).toDouble();
    }
    return out;
  }
}
