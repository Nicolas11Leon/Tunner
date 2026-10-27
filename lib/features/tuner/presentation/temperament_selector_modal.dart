import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../tuner_viewmodel.dart';
import '../domain/temperament_engine.dart';

/// Modal de grado conservatorio para la selección e inspección de temperamentos
/// históricos y microtonales con modulación de nota fundamental / tónica.
class TemperamentSelectorModal extends StatelessWidget {
  const TemperamentSelectorModal({super.key});

  static Future<void> show(BuildContext context) {
    final vm = Provider.of<TunerViewModel>(context, listen: false);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<TunerViewModel>.value(
        value: vm,
        child: const TemperamentSelectorModal(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    final allTemperaments = vm.availableTemperaments;
    final activeId = vm.selectedTemperament.id;
    final activeRoot = vm.temperamentRootKey;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: palette.staffLinesColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: palette.staffLinesColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.secondaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.history_edu, color: palette.secondaryAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TEMPERAMENTOS HISTÓRICOS",
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        "Sistemas acústicos no-iguales de conservatorio y música antigua",
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Selector de Tónica / Nota Raíz
            Text(
              "TÓNICA / NOTA FUNDAMENTAL",
              style: TextStyle(
                color: palette.secondaryAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 12,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final noteName = TemperamentEngine.chromaticNoteNames[index];
                  final isSelected = activeRoot == index;
                  return InkWell(
                    onTap: () => vm.setTemperamentRoot(index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.secondaryAccent
                            : palette.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? palette.secondaryAccent
                              : palette.staffLinesColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          noteName,
                          style: TextStyle(
                            color: isSelected ? Colors.black : palette.textColor,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Lista Desplazable de Sistemas de Temperamento
            Expanded(
              child: ListView.separated(
                itemCount: allTemperaments.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final temp = allTemperaments[index];
                  final isSelected = temp.id == activeId;

                  return InkWell(
                    key: Key('temperament_card_${temp.id}'),
                    onTap: () => vm.setTemperament(temp.id),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.primaryAccent.withValues(alpha: 0.12)
                            : palette.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? palette.primaryAccent
                              : palette.staffLinesColor.withValues(alpha: 0.2),
                          width: isSelected ? 1.6 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  temp.name,
                                  style: TextStyle(
                                    color: isSelected ? palette.primaryAccent : palette.textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: palette.staffLinesColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  temp.historicalEra,
                                  style: TextStyle(
                                    color: palette.textMutedColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            temp.description,
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 11,
                              height: 1.25,
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
      ),
    );
  }
}
