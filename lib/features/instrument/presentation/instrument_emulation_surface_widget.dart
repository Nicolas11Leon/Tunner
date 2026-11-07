import 'package:flutter/material.dart';
import '../domain/universal_instrument_definition.dart';
import '../domain/visual_interface_profile.dart';
import 'fretboard_tactile_widget.dart';
import 'keybed_tactile_widget.dart';
import 'drum_pads_tactile_widget.dart';

/// Superficie interactiva polimórfica que emula cualquier instrumento según su perfil visual y acústico.
class InstrumentEmulationSurfaceWidget extends StatelessWidget {
  final UniversalInstrumentDefinition instrument;
  final ValueChanged<double>? onFrequencyTriggered;
  final ValueChanged<int>? onDrumHitTriggered;

  const InstrumentEmulationSurfaceWidget({
    super.key,
    required this.instrument,
    this.onFrequencyTriggered,
    this.onDrumHitTriggered,
  });

  @override
  Widget build(BuildContext context) {
    switch (instrument.visualProfile.rendererType) {
      case VisualRendererType.fretboard:
      case VisualRendererType.fingerboard:
        return FretboardTactileWidget(
          instrument: instrument,
          onNoteTriggered: onFrequencyTriggered,
        );

      case VisualRendererType.keybed:
      case VisualRendererType.malletBars:
        return KeybedTactileWidget(
          instrument: instrument,
          onNoteTriggered: onFrequencyTriggered,
        );

      case VisualRendererType.drumPads:
        return DrumPadsTactileWidget(
          instrument: instrument,
          onDrumHit: onDrumHitTriggered,
        );

      case VisualRendererType.valvesPads:
      case VisualRendererType.vocalFormants:
        // Renderizador de columna de aire / curva continua
        return _buildGenericAcousticSurface(context);
    }
  }

  Widget _buildGenericAcousticSurface(BuildContext context) {
    final primaryColor = instrument.visualProfile.primaryAccentColor;
    final labels = instrument.visualProfile.tactileLabels;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: instrument.visualProfile.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    instrument.displayName.toUpperCase(),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  instrument.isTransposing
                      ? 'TRANSPOSICIÓN: ${instrument.transpositionSemitones > 0 ? "+" : ""}${instrument.transpositionSemitones} SEM'
                      : 'TONO DE CONCIERTO (C)',
                  style: TextStyle(color: primaryColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'CONTROLES DINÁMICOS & DIGITACIÓN',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: labels.map((label) {
                return InkWell(
                  onTap: () {
                    // Dispara la frecuencia central fundamental
                    final midFreq = (instrument.acousticRange.minFrequencyHz + instrument.acousticRange.maxFrequencyHz) / 2.0;
                    onFrequencyTriggered?.call(midFreq);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, size: 14, color: primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
