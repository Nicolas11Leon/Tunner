import 'package:flutter/material.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import '../../tuner_viewmodel.dart';

/// Modal interactivo y desacoplado para la selección de instrumento musical activo.
class InstrumentSelectorModal extends StatelessWidget {
  final TunerViewModel viewModel;

  const InstrumentSelectorModal({
    super.key,
    required this.viewModel,
  });

  static Future<void> show(BuildContext context, TunerViewModel viewModel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InstrumentSelectorModal(viewModel: viewModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = viewModel.currentPalette;

    return Container(
      key: const Key('instrument_selector_modal'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: palette.staffLinesColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.piano, color: palette.secondaryAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    "SELECTOR DE INSTRUMENTO",
                    style: TextStyle(
                      color: palette.secondaryAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Transposición armónica automática de partitura y afinador según la clave del instrumento",
            style: TextStyle(color: palette.textMutedColor, fontSize: 11),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: InstrumentProfileEntity.standardInstruments.length,
              itemBuilder: (ctx, index) {
                final inst = InstrumentProfileEntity.standardInstruments[index];
                final isSelected = viewModel.activeInstrument.id == inst.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? palette.primaryAccent.withValues(alpha: 0.15)
                        : palette.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? palette.primaryAccent : palette.staffLinesColor.withValues(alpha: 0.2),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                    key: Key('instrument_option_${inst.id}'),
                    onTap: () {
                      viewModel.setInstrumentProfile(inst);
                      Navigator.pop(context);
                    },
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? palette.primaryAccent
                          : palette.scaffoldBackground,
                      child: Icon(
                        inst.family == InstrumentFamily.brass
                            ? Icons.sports_bar
                            : (inst.family == InstrumentFamily.strings
                                ? Icons.queue_music
                                : Icons.music_note),
                        color: isSelected ? Colors.black : palette.primaryAccent,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      inst.name,
                      style: TextStyle(
                        color: palette.textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "${inst.family.displayName} • ${inst.key.displayName}",
                      style: TextStyle(
                        color: isSelected
                            ? palette.primaryAccent
                            : palette.textMutedColor,
                        fontSize: 11,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: palette.primaryAccent, size: 20)
                        : Text(
                            inst.clef.symbol,
                            style: TextStyle(color: palette.textMutedColor, fontSize: 16),
                          ),
                  ),
                ),
              );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
