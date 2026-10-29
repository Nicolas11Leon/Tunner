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
}
