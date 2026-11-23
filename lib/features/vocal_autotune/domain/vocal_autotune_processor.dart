import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import '../../../core/audio/domain/offline_wav_decoder.dart';
import '../../practice_recorder/domain/multitrack_session_entity.dart';
import '../../tuner/domain/offline_pitch_contour_analyzer.dart';
import 'autotune_config_entity.dart';
import 'scale_quantizer.dart';
import 'td_psola_pitch_shifter.dart';

/// Procesador central unificado de Vocal AutoTune en Pure Dart.
/// Soporta procesamiento de buffers continuos en tiempo real para monitoreo
/// y post-procesamiento de tomas multitrack grabadas.
class VocalAutoTuneProcessor {
  AutoTuneConfigEntity _config;
  final ScaleQuantizer _quantizer;
  final TdPsolaPitchShifter _pitchShifter;

  VocalAutoTuneProcessor({
    AutoTuneConfigEntity? config,
    ScaleQuantizer? quantizer,
    TdPsolaPitchShifter? pitchShifter,
  })  : _config = config ?? const AutoTuneConfigEntity(),
        _quantizer = quantizer ?? ScaleQuantizer(),
        _pitchShifter = pitchShifter ?? const TdPsolaPitchShifter();

  AutoTuneConfigEntity get config => _config;

  void updateConfig(AutoTuneConfigEntity newConfig) {
    _config = newConfig;
    _quantizer.reset();
  }

  /// Procesa exclusivamente el valor escalar de afinación para retroalimentación visual rápida.
  ScaleQuantizationResult evaluatePitchFrame({
    required double detectedPitchHz,
    double deltaSeconds = 0.02,
  }) {
    return _quantizer.quantize(
      detectedPitchHz: detectedPitchHz,
      config: _config,
      deltaSeconds: deltaSeconds,
    );
  }

  /// Procesa un bloque de audio PCM en tiempo real.
  /// Aplica cuantización de escala, filtro de inercia y resíntesis TD-PSOLA.
  Float64List processAudioBlock({
    required Float64List pcmSamples,
    required double detectedPitchHz,
    required int sampleRate,
    double deltaSeconds = 0.02,
  }) {
    if (!_config.isEnabled || pcmSamples.isEmpty) {
      return Float64List.fromList(pcmSamples);
    }

    final quantResult = _quantizer.quantize(
      detectedPitchHz: detectedPitchHz,
      config: _config,
      deltaSeconds: deltaSeconds,
    );

    if (!quantResult.isVoiced) {
      return Float64List.fromList(pcmSamples);
    }

    return _pitchShifter.shiftPitch(
      inputSamples: pcmSamples,
      pitchShiftRatio: quantResult.pitchShiftRatio,
      detectedPitchHz: detectedPitchHz,
      sampleRate: sampleRate,
      preserveFormants: _config.formantPreservation,
      leadVocalMix: _config.leadVocalMix,
    );
  }

  /// Aplica el procesamiento de AutoTune en post-producción sobre una toma grabada
  /// de la consola multitrack (`PracticeTakeEntity`).
  PracticeTakeEntity processPracticeTake({
    required PracticeTakeEntity take,
    AutoTuneConfigEntity? customConfig,
  }) {
    final effectiveConfig = customConfig ?? _config;
    final tempQuantizer = ScaleQuantizer();

    final List<TimedPitchSample> tunedPitchTrack = [];

    for (final sample in take.pitchTrack) {
      if (sample.isSilent || sample.frequencyHz <= 20.0) {
        tunedPitchTrack.add(sample);
        continue;
      }

      final quant = tempQuantizer.quantize(
        detectedPitchHz: sample.frequencyHz,
        config: effectiveConfig,
        deltaSeconds: 0.05,
      );

      // En la toma afinada, la frecuencia converge hacia la nota objetivo
      // y la desviación en cents se escala por (1.0 - correctionAmount)
      final double residualCents = quant.centsDeviation * (1.0 - effectiveConfig.correctionAmount.clamp(0.0, 1.0));

      tunedPitchTrack.add(
        TimedPitchSample(
          timeMs: sample.timeMs,
          frequencyHz: quant.targetFrequencyHz,
          centsDeviation: residualCents,
          targetNoteName: quant.targetNoteName,
          isSilent: false,
        ),
      );
    }

    // Retorna una nueva toma inmutable con sufijo de AutoTune
    return take.copyWith(
      id: '${take.id}_autotuned_${DateTime.now().millisecondsSinceEpoch}',
      name: '${take.name} (AutoTuned)',
      pitchTrack: tunedPitchTrack,
    );
  }

  /// Ejecuta [processPracticeTake] fuera del hilo de UI mediante [Isolate.run].
  Future<PracticeTakeEntity> processPracticeTakeAsync({
    required PracticeTakeEntity take,
    AutoTuneConfigEntity? customConfig,
  }) {
    final effectiveConfig = customConfig ?? _config;
    return Isolate.run(() {
      final worker = VocalAutoTuneProcessor(config: effectiveConfig);
      return worker.processPracticeTake(take: take, customConfig: effectiveConfig);
    });
  }

  /// Ejecuta [processWavBytes] fuera del hilo de UI mediante [Isolate.run].
  /// Si [pitchTrack] se omite, el contorno f0 se extrae automaticamente desde el WAV.
  Future<Uint8List> processWavBytesAsync({
    required Uint8List wavBytes,
    List<TimedPitchSample>? pitchTrack,
    AutoTuneConfigEntity? customConfig,
    int windowSize = OfflinePitchContourAnalyzer.defaultWindowSize,
    int hopSize = OfflinePitchContourAnalyzer.defaultHopSize,
    double crossfadeMs = 8.0,
  }) {
    final effectiveConfig = customConfig ?? _config;
    return Isolate.run(() {
      final worker = VocalAutoTuneProcessor(config: effectiveConfig);
      return worker.processWavBytes(
        wavBytes: wavBytes,
        pitchTrack: pitchTrack,
        customConfig: effectiveConfig,
        windowSize: windowSize,
        hopSize: hopSize,
        crossfadeMs: crossfadeMs,
      );
    });
  }

  /// Procesa un archivo WAV (PCM 16-bit, PCM 24-bit o IEEE Float 32-bit, mono o estereo)
  /// aplicando TD-PSOLA con crossfade suave en bordes de segmento.
  ///
  /// Si [pitchTrack] es `null`, extrae automaticamente el contorno de afinacion
  /// mediante [OfflinePitchContourAnalyzer] antes de ejecutar la correccion vocal.
  Uint8List processWavBytes({
    required Uint8List wavBytes,
    List<TimedPitchSample>? pitchTrack,
    AutoTuneConfigEntity? customConfig,
    int windowSize = OfflinePitchContourAnalyzer.defaultWindowSize,
    int hopSize = OfflinePitchContourAnalyzer.defaultHopSize,
    double crossfadeMs = 8.0,
  }) {
    final decoded = OfflineWavDecoder.decode(wavBytes);
    final int sampleRate = decoded.sampleRate;
    final Float64List monoSamples = decoded.samples;
    final int totalFrames = monoSamples.length;
    if (sampleRate < 8000 || totalFrames <= 0) {
      return wavBytes;
    }

    final effectiveConfig = customConfig ?? _config;
    if (!effectiveConfig.isEnabled) {
      return wavBytes;
    }

    final bool autoExtractedTrack = pitchTrack == null;
    final List<TimedPitchSample> activePitchTrack = pitchTrack ??
        const OfflinePitchContourAnalyzer()
            .analyzeSamples(
              monoSamples,
              sampleRate: sampleRate,
              windowSize: windowSize,
              hopSize: hopSize,
              a4Ref: effectiveConfig.a4Reference,
            )
            .samples;

    if (activePitchTrack.isEmpty) {
      return wavBytes;
    }

    final outSamples = Float64List.fromList(monoSamples);
    final tempQuantizer = ScaleQuantizer();
    final int tailDurationMs = autoExtractedTrack
        ? math.max(50, ((windowSize / sampleRate) * 1000.0).round())
        : 50;
    final int maxGapMs = autoExtractedTrack
        ? math.max(80, ((hopSize / sampleRate) * 1000.0 * 2.5).round())
        : 80;
    final int requestedFadeSamples =
        math.max(0, ((crossfadeMs.clamp(0.0, 40.0) / 1000.0) * sampleRate).round());

    // Agrupar muestras sonoras contiguas con afinacion objetivo equivalente
    // para evitar saltos de fase en fronteras de ventanas de 20-50 ms.
    int p = 0;
    while (p < activePitchTrack.length) {
      final firstSample = activePitchTrack[p];
      final int firstNextMs = (p + 1 < activePitchTrack.length)
          ? activePitchTrack[p + 1].timeMs
          : firstSample.timeMs + tailDurationMs;

      if (firstSample.isSilent || firstSample.frequencyHz <= 20.0) {
        tempQuantizer.quantize(
          detectedPitchHz: 0.0,
          config: effectiveConfig,
          deltaSeconds: (firstNextMs - firstSample.timeMs).clamp(1, 1000) / 1000.0,
        );
        p++;
        continue;
      }

      final firstQuant = tempQuantizer.quantize(
        detectedPitchHz: firstSample.frequencyHz,
        config: effectiveConfig,
        deltaSeconds: (firstNextMs - firstSample.timeMs).clamp(1, 1000) / 1000.0,
      );

      final int groupStartMs = firstSample.timeMs;
      int groupEndMs = firstNextMs;
      double weightedFreqSum = firstSample.frequencyHz;
      double weightedRatioSum = firstQuant.pitchShiftRatio;
      int groupCount = 1;

      int nextIndex = p + 1;
      while (nextIndex < activePitchTrack.length) {
        final candidate = activePitchTrack[nextIndex];
        if (candidate.isSilent || candidate.frequencyHz <= 20.0) break;
        if ((candidate.timeMs - groupEndMs).abs() > maxGapMs) break;

        final int candNextMs = (nextIndex + 1 < activePitchTrack.length)
            ? activePitchTrack[nextIndex + 1].timeMs
            : candidate.timeMs + tailDurationMs;
        final candQuant = tempQuantizer.quantize(
          detectedPitchHz: candidate.frequencyHz,
          config: effectiveConfig,
          deltaSeconds: (candNextMs - candidate.timeMs).clamp(1, 1000) / 1000.0,
        );

        final bool sameNote = candQuant.targetNoteName == firstQuant.targetNoteName;
        final bool closeRatio =
            (candQuant.pitchShiftRatio - firstQuant.pitchShiftRatio).abs() < 0.01;
        if (!sameNote || !closeRatio) break;

        groupEndMs = candNextMs;
        weightedFreqSum += candidate.frequencyHz;
        weightedRatioSum += candQuant.pitchShiftRatio;
        groupCount++;
        nextIndex++;
      }

      p = nextIndex;

      final double avgDetectedHz = weightedFreqSum / groupCount;
      final double avgRatio = weightedRatioSum / groupCount;
      if (!firstQuant.isVoiced || (avgRatio - 1.0).abs() < 0.005) continue;

      final int startSample =
          ((groupStartMs / 1000.0) * sampleRate).round().clamp(0, totalFrames);
      final int endSample =
          ((groupEndMs / 1000.0) * sampleRate).round().clamp(startSample, totalFrames);
      final int segmentLen = endSample - startSample;
      if (segmentLen < 48) continue;

      final segment = Float64List.sublistView(monoSamples, startSample, endSample);
      final shifted = _pitchShifter.shiftPitch(
        inputSamples: segment,
        pitchShiftRatio: avgRatio,
        detectedPitchHz: avgDetectedHz,
        sampleRate: sampleRate,
        preserveFormants: effectiveConfig.formantPreservation,
        leadVocalMix: effectiveConfig.leadVocalMix,
      );

      final int usableLen = math.min(shifted.length, totalFrames - startSample);
      final int fadeSamples = math.min(requestedFadeSamples, usableLen ~/ 4);

      for (int i = 0; i < usableLen; i++) {
        final int targetIdx = startSample + i;
        double blend = 1.0;
        if (fadeSamples > 0) {
          if (i < fadeSamples) {
            blend = i / fadeSamples;
          } else if (i >= usableLen - fadeSamples) {
            blend = (usableLen - 1 - i) / fadeSamples;
          }
        }
        outSamples[targetIdx] =
            outSamples[targetIdx] * (1.0 - blend) + shifted[i] * blend;
      }
    }

    // Re-empaquetar WAV PCM 16-bit mono
    final outDataBytes = totalFrames * 2;
    final outWav = Uint8List(44 + outDataBytes);
    final outView = ByteData.sublistView(outWav);
    outWav.setRange(0, 4, 'RIFF'.codeUnits);
    outView.setUint32(4, 36 + outDataBytes, Endian.little);
    outWav.setRange(8, 12, 'WAVE'.codeUnits);
    outWav.setRange(12, 16, 'fmt '.codeUnits);
    outView.setUint32(16, 16, Endian.little);
    outView.setUint16(20, 1, Endian.little);
    outView.setUint16(22, 1, Endian.little);
    outView.setUint32(24, sampleRate, Endian.little);
    outView.setUint32(28, sampleRate * 2, Endian.little);
    outView.setUint16(32, 2, Endian.little);
    outView.setUint16(34, 16, Endian.little);
    outWav.setRange(36, 40, 'data'.codeUnits);
    outView.setUint32(40, outDataBytes, Endian.little);

    for (int i = 0; i < totalFrames; i++) {
      final clamped = (outSamples[i] * 32767.0).round().clamp(-32768, 32767);
      outView.setInt16(44 + i * 2, clamped, Endian.little);
    }
    return outWav;
  }
}
