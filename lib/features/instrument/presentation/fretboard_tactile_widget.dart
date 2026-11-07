import 'package:flutter/material.dart';
import '../domain/universal_instrument_definition.dart';

/// Visualizador y emulador táctil interactivo de diapasón con trastes (Fretboard).
/// Permite visualizar la digitación de escalas y tocar notas al aire o trastes en vivo.
class FretboardTactileWidget extends StatelessWidget {
  final UniversalInstrumentDefinition instrument;
  final ValueChanged<double>? onNoteTriggered;
  final int totalFrets;

  const FretboardTactileWidget({
    super.key,
    required this.instrument,
    this.onNoteTriggered,
    this.totalFrets = 12,
  });

  @override
  Widget build(BuildContext context) {
    final tuningFrequencies = instrument.acousticRange.standardTuningFrequencies;
    final noteNames = instrument.acousticRange.standardTuningNoteNames;
    final stringsCount = tuningFrequencies.isNotEmpty ? tuningFrequencies.length : 6;
    final primaryColor = instrument.visualProfile.primaryAccentColor;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: instrument.visualProfile.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Encabezado del diapasón
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          instrument.displayName.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${noteNames.join("-")})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          // Cuerdas y trastes interactivos
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fretWidth = constraints.maxWidth / (totalFrets + 1);
                final stringHeight = constraints.maxHeight / stringsCount;

                return Stack(
                  children: [
                    // Líneas de trastes verticales metálicos
                    for (int f = 1; f <= totalFrets; f++)
                      Positioned(
                        left: f * fretWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: (f == 12) ? 3.0 : 1.5,
                          color: (f == 3 || f == 5 || f == 7 || f == 9 || f == 12)
                              ? primaryColor.withValues(alpha: 0.7)
                              : Colors.white24,
                        ),
                      ),

                    // Marcadores de posición redondos (Dots) en los trastes 3, 5, 7, 9 y doble en 12
                    for (int f in [3, 5, 7, 9])
                      Positioned(
                        left: (f - 0.5) * fretWidth - 4,
                        top: constraints.maxHeight / 2 - 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 11.5 * fretWidth - 4,
                      top: constraints.maxHeight / 3 - 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 11.5 * fretWidth - 4,
                      top: 2 * constraints.maxHeight / 3 - 4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Cuerdas horizontales interactivas
                    for (int s = 0; s < stringsCount; s++)
                      Positioned(
                        top: (s + 0.5) * stringHeight - 1,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            // Botón de cuerda al aire
                            InkWell(
                              onTap: () {
                                if (s < tuningFrequencies.length) {
                                  onNoteTriggered?.call(tuningFrequencies[s]);
                                }
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                width: fretWidth,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s < noteNames.length ? noteNames[s] : 'S${s + 1}',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Línea de la cuerda de acero/nylon
                            Expanded(
                              child: Container(
                                height: (stringsCount - s) * 0.6 + 0.8,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
