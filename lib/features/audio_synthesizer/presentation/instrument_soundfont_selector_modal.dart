import 'package:flutter/material.dart';
import '../data/soundfont_synthesizer_service.dart';

/// Modal bottom sheet para explorar y seleccionar timbres acústicos SoundFont SF2
/// y probar su afinación con retorno auditivo inmediato.
class InstrumentSoundFontSelectorModal extends StatefulWidget {
  final SoundFontSynthesizerService synthService;
  final Function(int patch, String name)? onInstrumentSelected;

  const InstrumentSoundFontSelectorModal({
    super.key,
    required this.synthService,
    this.onInstrumentSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required SoundFontSynthesizerService synthService,
    Function(int patch, String name)? onInstrumentSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14141E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => InstrumentSoundFontSelectorModal(
        synthService: synthService,
        onInstrumentSelected: onInstrumentSelected,
      ),
    );
  }

  @override
  State<InstrumentSoundFontSelectorModal> createState() =>
      _InstrumentSoundFontSelectorModalState();
}

class _InstrumentSoundFontSelectorModalState
    extends State<InstrumentSoundFontSelectorModal> {
  late int _selectedPatch;
  int _previewMidiPitch = 60; // C4
  bool _isSynthesizing = false;

  @override
  void initState() {
    super.initState();
    _selectedPatch = widget.synthService.activePatch;
  }

  IconData _iconForPatch(int patch) {
    switch (patch) {
      case 0:
        return Icons.piano;
      case 73:
        return Icons.air;
      case 40:
      case 42:
        return Icons.music_note;
      case 24:
        return Icons.straighten;
      default:
        return Icons.graphic_eq;
    }
  }

  void _previewNote(int midiPitch) {
    setState(() {
      _previewMidiPitch = midiPitch;
      _isSynthesizing = true;
    });

    widget.synthService.synthesizeNoteWav(
      midiPitch: midiPitch,
      durationSeconds: 0.8,
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isSynthesizing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final presets = widget.synthService.availablePresets;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.piano, color: Colors.amberAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timbres Acústicos SoundFont',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Motor SF2 Wavetable en Pure Dart',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Instrumentos Disponibles:',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: presets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isSelected = preset.patch == _selectedPatch;

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? Colors.amberAccent : Colors.white10,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                tileColor: isSelected
                    ? Colors.amberAccent.withValues(alpha: 0.08)
                    : const Color(0xFF1E1E2C),
                leading: Icon(
                  _iconForPatch(preset.patch),
                  color: isSelected ? Colors.amberAccent : Colors.white60,
                ),
                title: Text(
                  preset.name,
                  style: TextStyle(
                    color: isSelected ? Colors.amberAccent : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  'General MIDI Patch #${preset.patch}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.amberAccent)
                    : null,
                onTap: () {
                  setState(() => _selectedPatch = preset.patch);
                  widget.synthService.selectPatch(preset.patch);
                  widget.onInstrumentSelected?.call(preset.patch, preset.name);
                  _previewNote(_previewMidiPitch);
                },
              );
            },
          ),

          const SizedBox(height: 20),
          const Text(
            'Probar Tono con el Instrumento Activo:',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          // Mini teclado de prueba C4, E4, G4, A4, C5
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPitchButton(name: 'Do4', midi: 60),
              _buildPitchButton(name: 'Mi4', midi: 64),
              _buildPitchButton(name: 'Sol4', midi: 67),
              _buildPitchButton(name: 'La4', midi: 69),
              _buildPitchButton(name: 'Do5', midi: 72),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPitchButton({required String name, required int midi}) {
    final isPlaying = _isSynthesizing && _previewMidiPitch == midi;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isPlaying ? Colors.amberAccent : const Color(0xFF262638),
        foregroundColor: isPlaying ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => _previewNote(midi),
      child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
