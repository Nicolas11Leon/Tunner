import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../../audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
import '../../instrument/domain/procedural_instrument_synthesizer.dart';
import '../../tuner_viewmodel.dart';

/// Modal de control interactivo para los parámetros tímbricos y envolvente acústica
/// del sintetizador polifónico acoplado al pentagrama SMuFL.
class PolyphonicSynthModal extends StatefulWidget {
  final TunerViewModel viewModel;
  final TunnerThemePalette palette;

  const PolyphonicSynthModal({
    super.key,
    required this.viewModel,
    required this.palette,
  });

  static Future<void> show(
    BuildContext context,
    TunerViewModel viewModel,
    TunnerThemePalette palette,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PolyphonicSynthModal(
        viewModel: viewModel,
        palette: palette,
      ),
    );
  }

  @override
  State<PolyphonicSynthModal> createState() => _PolyphonicSynthModalState();
}

class _PolyphonicSynthModalState extends State<PolyphonicSynthModal> {
  Timer? _testChordTimer;

  @override
  void dispose() {
    _testChordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pool = widget.viewModel.polyphonicVoicePool;
    final tokens = StudioThemeScope.of(context);

    return Dialog(
      backgroundColor: tokens.panelBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.borderRadiusLarge),
        side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        StudioIcon(
                          StudioIconId.modulePianoRoll,
                          color: tokens.accentPrimary,
                          size: 20,
                          tintCustomAsset: true,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'SINTETIZADOR POLIFÓNICO SMuFL',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: StudioIcon(
                      StudioIconId.uiCloseConfirm,
                      color: tokens.textMuted,
                      size: 16,
                      tintCustomAsset: true,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector de Forma de Onda
              Text(
                'FORMA DE ONDA DEL OSCILADOR',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SynthWaveform.values.map((wf) {
                  final isSelected = pool.waveform == wf;
                  String label = '';
                  switch (wf) {
                    case SynthWaveform.sine:
                      label = 'SENOIDAL';
                      break;
                    case SynthWaveform.sawtooth:
                      label = 'DIENTE DE SIERRA';
                      break;
                    case SynthWaveform.pulse:
                      label = 'PULSO / CUADRADA';
                      break;
                    case SynthWaveform.triangle:
                      label = 'TRIANGULAR';
                      break;
                  }

                  return ChoiceChip(
                    key: Key('synth_waveform_${wf.name}'),
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: tokens.elevatedSurface,
                    backgroundColor: tokens.inputSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? tokens.textPrimary : tokens.textSecondary,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected ? tokens.borderFocus : tokens.borderHairline,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          pool.waveform = wf;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Envolvente ADSR
              Text(
                'ENVOLVENTE ACÚSTICA ADSR',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSliderRow(
                        tokens: tokens,
                        keyName: 'adsr_attack_slider',
                        label: 'Ataque (Attack)',
                        valueLabel: '${(pool.attackSeconds * 1000).round()} ms',
                        value: pool.attackSeconds,
                        min: 0.001,
                        max: 0.25,
                        onChanged: (val) {
                          setState(() {
                            pool.attackSeconds = val;
                          });
                        },
                      ),
                      _buildSliderRow(
                        tokens: tokens,
                        keyName: 'adsr_decay_slider',
                        label: 'Decaimiento (Decay)',
                        valueLabel: '${(pool.decaySeconds * 1000).round()} ms',
                        value: pool.decaySeconds,
                        min: 0.005,
                        max: 0.5,
                        onChanged: (val) {
                          setState(() {
                            pool.decaySeconds = val;
                          });
                        },
                      ),
                      _buildSliderRow(
                        tokens: tokens,
                        keyName: 'adsr_sustain_slider',
                        label: 'Sostenimiento (Sustain)',
                        valueLabel: '${(pool.sustainLevel * 100).round()}%',
                        value: pool.sustainLevel,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            pool.sustainLevel = val;
                          });
                        },
                      ),
                      _buildSliderRow(
                        tokens: tokens,
                        keyName: 'adsr_release_slider',
                        label: 'Liberación (Release)',
                        valueLabel: '${(pool.releaseSeconds * 1000).round()} ms',
                        value: pool.releaseSeconds,
                        min: 0.01,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            pool.releaseSeconds = val;
                          });
                        },
                      ),
                      if (pool.waveform == SynthWaveform.pulse)
                        _buildSliderRow(
                          tokens: tokens,
                          keyName: 'synth_pulse_width_slider',
                          label: 'Ancho de Pulso (PWM)',
                          valueLabel: '${(pool.pulseWidth * 100).round()}%',
                          value: pool.pulseWidth,
                          min: 0.1,
                          max: 0.9,
                          onChanged: (val) {
                            setState(() {
                              pool.pulseWidth = val;
                            });
                          },
                        ),
                      _buildSliderRow(
                        tokens: tokens,
                        keyName: 'synth_master_gain_slider',
                        label: 'Ganancia del Sintetizador',
                        valueLabel: '${(pool.masterGain * 100).round()}%',
                        value: pool.masterGain,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          setState(() {
                            pool.masterGain = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              // Telemetría y Botones de Acción
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  Text(
                    'Voces activas: ${pool.activeVoiceCount} / ${pool.maxPolyphony}',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('synth_panic_btn'),
                        icon: StudioIcon(
                          StudioIconId.transportStop,
                          size: 14,
                          color: tokens.accentDanger,
                          tintCustomAsset: true,
                        ),
                        label: const Text('Silenciar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.accentDanger,
                          side: BorderSide(color: tokens.accentDanger.withValues(alpha: 0.45)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            pool.panic();
                          });
                        },
                      ),
                      ElevatedButton.icon(
                        key: const Key('synth_test_chord_btn'),
                        icon: StudioIcon(
                          StudioIconId.transportPlay,
                          size: 14,
                          color: tokens.textOnAccent,
                          tintCustomAsset: true,
                        ),
                        label: Text(
                          'Probar Acorde',
                          style: TextStyle(
                            color: tokens.textOnAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.accentPrimary,
                          foregroundColor: tokens.textOnAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusSmall),
                          ),
                        ),
                        onPressed: () {
                          _testChordTimer?.cancel();
                          // Toca acorde Do Mayor (Do4, Mi4, Sol4) y renderiza audio real audible
                          pool.noteOn(60, 0.85);
                          pool.noteOn(64, 0.85);
                          pool.noteOn(67, 0.85);
                          final numSamples = (pool.sampleRate * 0.6).round();
                          final leftOut = Float64List(numSamples);
                          final rightOut = Float64List(numSamples);
                          pool.renderBlock(
                            leftOut: leftOut,
                            rightOut: rightOut,
                            numSamples: numSamples,
                          );
                          final monoFloat = Float32List(numSamples);
                          for (int i = 0; i < numSamples; i++) {
                            monoFloat[i] = ((leftOut[i] + rightOut[i]) * 0.5).clamp(-1.0, 1.0);
                          }
                          if (monoFloat.isNotEmpty) {
                            final wavBytes = ProceduralInstrumentSynthesizer.floatBufferToWavBytes(
                              monoFloat,
                              sampleRate: pool.sampleRate.round(),
                            );
                            widget.viewModel.audioSynthesizer.playPcmWav(wavBytes);
                          }
                          setState(() {});
                          _testChordTimer = Timer(const Duration(milliseconds: 600), () {
                            pool.noteOff(60);
                            pool.noteOff(64);
                            pool.noteOff(67);
                            if (mounted) setState(() {});
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required StudioDesignTokens tokens,
    required String keyName,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: tokens.accentPrimary,
                inactiveTrackColor: tokens.inputSurface,
                thumbColor: tokens.accentPrimary,
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                key: Key(keyName),
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              valueLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: tokens.accentPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
