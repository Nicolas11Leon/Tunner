import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/universal_instrument_definition.dart';

/// Visualizador y emulador táctil interactivo de teclado de concierto (Keybed).
/// Renderiza 2 octavas de teclas blancas y negras con respuesta háptica y auditiva.
class KeybedTactileWidget extends StatelessWidget {
  final UniversalInstrumentDefinition instrument;
  final ValueChanged<double>? onNoteTriggered;
  final int startMidiNote; // Por defecto 60 (C4)
  final int totalWhiteKeys;

  const KeybedTactileWidget({
    super.key,
    required this.instrument,
    this.onNoteTriggered,
    this.startMidiNote = 60,
    this.totalWhiteKeys = 14, // 2 octavas diatónicas
  });

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      instrument.displayName.toUpperCase(),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  'TECLADO DE CONCIERTO (C4 - B5)',
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

          // Teclado interactivo con teclas blancas y negras superpuestas
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final whiteKeyWidth = constraints.maxWidth / totalWhiteKeys;
                final blackKeyWidth = whiteKeyWidth * 0.65;
                final blackKeyHeight = constraints.maxHeight * 0.62;

                // Mapeo diatónico de notas blancas desde startMidiNote
                final whiteNoteOffsets = [0, 2, 4, 5, 7, 9, 11]; // C, D, E, F, G, A, B
                final whiteNames = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];

                // Posiciones de las teclas negras relativas a las blancas
                // Negras en C# (0), D# (1), F# (3), G# (4), A# (5)
                final hasBlackKeyAfter = [true, true, false, true, true, true, false];

                return Stack(
                  children: [
                    // Capa inferior: Teclas blancas
                    Row(
                      children: List.generate(totalWhiteKeys, (i) {
                        final octave = i ~/ 7;
                        final noteIndex = i % 7;
                        final midiNote = startMidiNote + octave * 12 + whiteNoteOffsets[noteIndex];
                        final freqHz = 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);

                        return Expanded(
                          child: InkWell(
                            onTap: () => onNoteTriggered?.call(freqHz),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                                border: Border.all(color: Colors.black26),
                              ),
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${whiteNames[noteIndex]}${4 + octave}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    // Capa superior: Teclas negras
                    for (int i = 0; i < totalWhiteKeys - 1; i++)
                      if (hasBlackKeyAfter[i % 7])
                        Positioned(
                          left: (i + 1) * whiteKeyWidth - (blackKeyWidth / 2),
                          top: 0,
                          width: blackKeyWidth,
                          height: blackKeyHeight,
                          child: InkWell(
                            onTap: () {
                              final octave = i ~/ 7;
                              final noteIndex = i % 7;
                              final midiNote = startMidiNote + octave * 12 + whiteNoteOffsets[noteIndex] + 1;
                              final freqHz = 440.0 * math.pow(2.0, (midiNote - 69) / 12.0);
                              onNoteTriggered?.call(freqHz);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                                border: Border.all(color: Colors.white12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
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
