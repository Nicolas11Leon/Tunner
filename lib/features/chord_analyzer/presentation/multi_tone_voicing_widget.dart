import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/polyphonic_pitch_entity.dart';

/// Widget de presentación para la visualización en tiempo real de la descomposición
/// multitonal polifónica (voces concurrentes, octavas, cents y roles armónicos).
class MultiToneVoicingWidget extends StatelessWidget {
  final PolyphonicMultiToneAnalysisResult analysisResult;
  final TunnerThemePalette palette;

  const MultiToneVoicingWidget({
    super.key,
    required this.analysisResult,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final voices = analysisResult.voices;
    final hasVoices = voices.isNotEmpty;

    return Container(
      key: const Key('multitone_voicing_section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: palette.staffLinesColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de la sección
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.graphic_eq, color: palette.primaryAccent, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Descomposición Multitonal',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                key: const Key('multitone_voicing_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: hasVoices
                      ? palette.primaryAccent.withValues(alpha: 0.18)
                      : palette.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasVoices
                        ? palette.primaryAccent.withValues(alpha: 0.5)
                        : palette.staffLinesColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  analysisResult.voicingName,
                  style: TextStyle(
                    color: hasVoices ? palette.primaryAccent : palette.textMutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (!hasVoices)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.multitrack_audio,
                    color: palette.textMutedColor.withValues(alpha: 0.4),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca un acorde en guitarra o piano para descomponer sus notas en tiempo real',
                    style: TextStyle(
                      color: palette.textMutedColor,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else ...[
            // Lista de tarjetas de notas/voces concurrentes
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(voices.length, (index) {
                final voice = voices[index];
                return _buildVoiceCard(context, voice, index);
              }),
            ),

            const SizedBox(height: 16),

            // Teclado cromático mini de alturas activas
            _buildChromaticPitchStrip(context, voices),
          ],
        ],
      ),
    );
  }

  Widget _buildVoiceCard(BuildContext context, DetectedPolyphonicVoice voice, int index) {
    Color centsColor = palette.secondaryAccent;
    final absCents = voice.centsDeviation.abs();
    if (absCents <= 5.0) {
      centsColor = palette.secondaryAccent; // En tono
    } else if (absCents <= 15.0) {
      centsColor = Colors.orangeAccent;
    } else {
      centsColor = palette.errorPitchColor;
    }

    return Container(
      key: Key('multitone_voice_card_$index'),
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.staffBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: palette.primaryAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                voice.fullNoteNameInternational,
                style: TextStyle(
                  color: palette.primaryAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${voice.fullNoteName})',
                style: TextStyle(
                  color: palette.textMutedColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            voice.harmonicRole,
            style: TextStyle(
              color: palette.textColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                voice.formattedFrequency,
                style: TextStyle(
                  color: palette.textMutedColor,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: centsColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  voice.formattedCents,
                  style: TextStyle(
                    color: centsColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChromaticPitchStrip(BuildContext context, List<DetectedPolyphonicVoice> voices) {
    const noteLabels = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final activeClasses = voices.map((v) => v.pitchClassIndex).toSet();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: palette.staffBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución de Alturas Activas en Acorde:',
            style: TextStyle(color: palette.textMutedColor, fontSize: 10),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(12, (i) {
              final isActive = activeClasses.contains(i);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? palette.primaryAccent
                      : palette.cardBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive
                        ? palette.primaryAccent
                        : palette.staffLinesColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  noteLabels[i],
                  style: TextStyle(
                    color: isActive ? Colors.black : palette.textMutedColor,
                    fontSize: 9.5,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
                  ),
                ),
              );
            }),
          ),
        ),
        ],
      ),
    );
  }
}
