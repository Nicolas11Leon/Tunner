import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../audio_synthesizer/domain/polyphonic/polyphonic_synth_voice.dart';
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
    final palette = widget.palette;

    return Dialog(
      backgroundColor: palette.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.3)),
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
                        Icon(Icons.piano, color: palette.secondaryAccent, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'SINTETIZADOR POLIFÓNICO SMuFL',
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 15,
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
                    icon: Icon(Icons.close, color: palette.textMutedColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector de Forma de Onda
              Text(
                'FORMA DE ONDA DEL OSCILADOR',
                style: TextStyle(
                  color: palette.textMutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
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
                    selectedColor: palette.primaryAccent.withValues(alpha: 0.25),
                    backgroundColor: palette.scaffoldBackground,
                    labelStyle: TextStyle(
                      color: isSelected ? palette.primaryAccent : palette.textMutedColor,
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    side: BorderSide(
                      color: isSelected ? palette.primaryAccent : palette.staffLinesColor.withValues(alpha: 0.3),
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
                  color: palette.textMutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSliderRow(
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
                      color: palette.textMutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('synth_panic_btn'),
                        icon: const Icon(Icons.volume_off, size: 16),
                        label: const Text('Silenciar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.errorPitchColor,
                          side: BorderSide(color: palette.errorPitchColor.withValues(alpha: 0.4)),
                        ),
                        onPressed: () {
                          setState(() {
                            pool.panic();
                          });
                        },
                      ),
                      ElevatedButton.icon(
                        key: const Key('synth_test_chord_btn'),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Probar Acorde'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.secondaryAccent,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          _testChordTimer?.cancel();
                          // Toca acorde Do Mayor (Do4, Mi4, Sol4)
                          pool.noteOn(60, 0.85);
                          pool.noteOn(64, 0.85);
                          pool.noteOn(67, 0.85);
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
    required String keyName,
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final palette = widget.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: palette.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: palette.secondaryAccent,
                inactiveTrackColor: palette.scaffoldBackground,
                thumbColor: palette.secondaryAccent,
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
                color: palette.secondaryAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
