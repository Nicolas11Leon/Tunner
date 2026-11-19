import 'package:flutter/material.dart';
import '../domain/universal_instrument_definition.dart';
import 'visual_interface_profile_ui_ext.dart';

/// Cuadrícula táctil interactiva de pads de percusión con animación reactiva al golpe.
class DrumPadsTactileWidget extends StatefulWidget {
  final UniversalInstrumentDefinition instrument;
  final ValueChanged<int>? onDrumHit; // Retorna la nota GM (ej: 36 Bombo, 38 Caja)

  const DrumPadsTactileWidget({
    super.key,
    required this.instrument,
    this.onDrumHit,
  });

  @override
  State<DrumPadsTactileWidget> createState() => _DrumPadsTactileWidgetState();
}

class _DrumPadsTactileWidgetState extends State<DrumPadsTactileWidget> {
  int? _activeHitIndex;

  final List<Map<String, dynamic>> _pads = const [
    {'name': 'BOMBO', 'gm': 36, 'color': Color(0xFFEF4444), 'iconData': Icons.album_rounded, 'code': 'BD'},
    {'name': 'CAJA / SNARE', 'gm': 38, 'color': Color(0xFFF59E0B), 'iconData': Icons.radio_button_checked_rounded, 'code': 'SD'},
    {'name': 'HI-HAT CERRADO', 'gm': 42, 'color': Color(0xFF10B981), 'iconData': Icons.radio_button_unchecked_rounded, 'code': 'CHH'},
    {'name': 'HI-HAT ABIERTO', 'gm': 46, 'color': Color(0xFF06B6D4), 'iconData': Icons.trip_origin_rounded, 'code': 'OHH'},
    {'name': 'TOM ALTO', 'gm': 50, 'color': Color(0xFF8B5CF6), 'iconData': Icons.adjust_rounded, 'code': 'T1'},
    {'name': 'TOM PISO', 'gm': 43, 'color': Color(0xFFEC4899), 'iconData': Icons.adjust_rounded, 'code': 'FT'},
    {'name': 'CRASH', 'gm': 49, 'color': Color(0xFFEAB308), 'iconData': Icons.blur_circular_rounded, 'code': 'CR'},
    {'name': 'RIDE', 'gm': 51, 'color': Color(0xFF38BDF8), 'iconData': Icons.circle_outlined, 'code': 'RD'},
  ];

  void _triggerPad(int index, int gm) {
    setState(() => _activeHitIndex = index);
    widget.onDrumHit?.call(gm);

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _activeHitIndex = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.instrument.visualProfile.primaryAccentColor;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: widget.instrument.visualProfile.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(widget.instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    widget.instrument.displayName.toUpperCase(),
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const Text(
                'PADS DINÁMICOS CANAL 10 (MIDI GM)',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              itemCount: _pads.length,
              itemBuilder: (context, index) {
                final pad = _pads[index];
                final isHit = _activeHitIndex == index;
                final padColor = pad['color'] as Color;

                return GestureDetector(
                  onTapDown: (_) => _triggerPad(index, pad['gm'] as int),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    decoration: BoxDecoration(
                      color: isHit
                          ? padColor.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHit ? padColor : Colors.white12,
                        width: isHit ? 2.0 : 1.0,
                      ),
                      boxShadow: isHit
                          ? [
                              BoxShadow(
                                color: padColor.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(pad['iconData'] as IconData, size: 14, color: isHit ? Colors.white : padColor),
                        const SizedBox(height: 2),
                        Text(
                          pad['name'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isHit ? Colors.white : Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
