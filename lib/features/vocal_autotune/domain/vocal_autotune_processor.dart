import 'dart:isolate';
import 'dart:typed_data';
import 'autotune_config_entity.dart';
import 'scale_quantizer.dart';
import 'td_psola_pitch_shifter.dart';
import '../../practice_recorder/domain/multitrack_session_entity.dart';

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
  Future<Uint8List> processWavBytesAsync({
    required Uint8List wavBytes,
    required List<TimedPitchSample> pitchTrack,
    AutoTuneConfigEntity? customConfig,
  }) {
    final effectiveConfig = customConfig ?? _config;
    return Isolate.run(() {
      final worker = VocalAutoTuneProcessor(config: effectiveConfig);
      return worker.processWavBytes(
        wavBytes: wavBytes,
        pitchTrack: pitchTrack,
        customConfig: effectiveConfig,
      );
    });
  }

  /// Procesa un archivo WAV PCM de 16 bits aplicando TD-PSOLA por cada ventana sonora
  /// registrada en [pitchTrack], retornando un nuevo buffer WAV afinado en memoria.
  Uint8List processWavBytes({
    required Uint8List wavBytes,
    required List<TimedPitchSample> pitchTrack,
    AutoTuneConfigEntity? customConfig,
  }) {
    if (wavBytes.length < 44) return wavBytes;
    final headerData = ByteData.sublistView(wavBytes, 0, 44);
    final channels = headerData.getUint16(22, Endian.little).clamp(1, 2);
    final sampleRate = headerData.getUint32(24, Endian.little);
    final bitsPerSample = headerData.getUint16(34, Endian.little);
    if (sampleRate < 8000 || bitsPerSample != 16) return wavBytes;

    // Localizar chunk 'data' de forma segura
    int dataOffset = 44;
    int dataSize = wavBytes.length - 44;
    int cursor = 12;
    while (cursor + 8 <= wavBytes.length) {
      final chunkId = String.fromCharCodes(wavBytes.sublist(cursor, cursor + 4));
      final chunkSize = ByteData.sublistView(wavBytes, cursor + 4, cursor + 8)
          .getUint32(0, Endian.little);
      if (chunkId == 'data') {
        dataOffset = cursor + 8;
        dataSize = chunkSize.clamp(0, wavBytes.length - dataOffset);
        break;
      }
      cursor += 8 + chunkSize + (chunkSize & 1);
    }

    final int totalFrames = dataSize ~/ (2 * channels);
    if (totalFrames <= 0) return wavBytes;

    final pcmView = ByteData.sublistView(wavBytes, dataOffset, dataOffset + dataSize);
    final monoSamples = Float64List(totalFrames);
    for (int i = 0; i < totalFrames; i++) {
      double sum = 0.0;
      for (int ch = 0; ch < channels; ch++) {
        final s = pcmView.getInt16((i * channels + ch) * 2, Endian.little);
        sum += s / 32768.0;
      }
      monoSamples[i] = sum / channels;
    }

    final effectiveConfig = customConfig ?? _config;
    if (!effectiveConfig.isEnabled || pitchTrack.isEmpty) {
      return wavBytes;
    }

    final outSamples = Float64List.fromList(monoSamples);
    final tempQuantizer = ScaleQuantizer();

    for (int p = 0; p < pitchTrack.length; p++) {
      final sample = pitchTrack[p];
      if (sample.isSilent || sample.frequencyHz <= 20.0) continue;

      final int startSample = ((sample.timeMs / 1000.0) * sampleRate).round().clamp(0, totalFrames);
      final int nextMs = (p + 1 < pitchTrack.length)
          ? pitchTrack[p + 1].timeMs
          : sample.timeMs + 50;
      final int endSample = ((nextMs / 1000.0) * sampleRate).round().clamp(startSample, totalFrames);
      final int segmentLen = endSample - startSample;
      if (segmentLen < 48) continue;

      final quant = tempQuantizer.quantize(
        detectedPitchHz: sample.frequencyHz,
        config: effectiveConfig,
        deltaSeconds: (nextMs - sample.timeMs).clamp(1, 1000) / 1000.0,
      );
      if (!quant.isVoiced || (quant.pitchShiftRatio - 1.0).abs() < 0.005) continue;

      final segment = Float64List.sublistView(monoSamples, startSample, endSample);
      final shifted = _pitchShifter.shiftPitch(
        inputSamples: segment,
        pitchShiftRatio: quant.pitchShiftRatio,
        detectedPitchHz: sample.frequencyHz,
        sampleRate: sampleRate,
        preserveFormants: effectiveConfig.formantPreservation,
        leadVocalMix: effectiveConfig.leadVocalMix,
      );
      for (int i = 0; i < shifted.length && (startSample + i) < totalFrames; i++) {
        outSamples[startSample + i] = shifted[i];
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
