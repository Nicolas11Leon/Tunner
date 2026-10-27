import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';

/// Modal pro para la calibración acústica de la afinación de concierto del tono A4.
/// Permite seleccionar presets orquestales/históricos (432, 440, 442, 444 Hz) y calibración fina.
class ConcertPitchSelectorModal extends StatelessWidget {
  const ConcertPitchSelectorModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ConcertPitchSelectorModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;

    final presets = const [
      {'hz': 432.0, 'title': '432 Hz', 'desc': 'Filosófico / Verdi'},
      {'hz': 440.0, 'title': '440 Hz', 'desc': 'Estándar ISO 16'},
      {'hz': 442.0, 'title': '442 Hz', 'desc': 'Orquesta Sinfónica'},
      {'hz': 444.0, 'title': '444 Hz', 'desc': 'Brillante / Solista'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Handle superior
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: palette.textMutedColor.withValues(alpha: 0.4),
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
                    color: palette.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.tune,
                    color: palette.primaryAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calibración de Concierto A4',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        'Centro tonal estándar para aguja y strobe',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: palette.textMutedColor),
                  tooltip: 'Cerrar',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Visualizador Central Heroico
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: palette.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.primaryAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'A4 = ',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        vm.referencePitch.toStringAsFixed(1),
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hz',
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stepper de ajuste fino (-0.5 / +0.5)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StepButton(
                        icon: Icons.remove,
                        label: '-0.5',
                        palette: palette,
                        onPressed: () => vm.setReferencePitch(vm.referencePitch - 0.5),
                      ),
                      const SizedBox(width: 12),
                      _StepButton(
                        icon: Icons.refresh,
                        label: '440',
                        palette: palette,
                        onPressed: () => vm.setReferencePitch(440.0),
                      ),
                      const SizedBox(width: 12),
                      _StepButton(
                        icon: Icons.add,
                        label: '+0.5',
                        palette: palette,
                        onPressed: () => vm.setReferencePitch(vm.referencePitch + 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Slider Continuo (415 Hz - 466 Hz)
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: palette.primaryAccent,
                inactiveTrackColor: palette.staffLinesColor.withValues(alpha: 0.3),
                thumbColor: palette.primaryAccent,
                overlayColor: palette.primaryAccent.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: vm.referencePitch,
                min: 415.0,
                max: 466.0,
                divisions: 510, // 0.1 Hz por paso
                onChanged: (newVal) => vm.setReferencePitch(newVal),
              ),
            ),

            const SizedBox(height: 12),

            // Presets Estándar
            Text(
              'PRESETS CANÓNICOS',
              style: TextStyle(
                color: palette.textMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((p) {
                final isSelected = (vm.referencePitch - (p['hz'] as double)).abs() < 0.2;
                return Material(
                  color: isSelected
                      ? palette.primaryAccent.withValues(alpha: 0.2)
                      : palette.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => vm.setReferencePitch(p['hz'] as double),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? palette.primaryAccent
                              : palette.staffLinesColor.withValues(alpha: 0.3),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            p['title'] as String,
                            style: TextStyle(
                              color: isSelected ? palette.primaryAccent : palette.textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            p['desc'] as String,
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Botón de Diapasón Acústico Senoidal
            OutlinedButton.icon(
              icon: Icon(
                vm.isDiapasonPlaying ? Icons.volume_up : Icons.hearing,
                color: vm.isDiapasonPlaying ? palette.primaryAccent : palette.textColor,
                size: 20,
              ),
              label: Text(
                vm.isDiapasonPlaying
                    ? 'Detener Diapasón (${vm.referencePitch.toStringAsFixed(1)} Hz)'
                    : 'Escuchar Diapasón A4 (${vm.referencePitch.toStringAsFixed(1)} Hz)',
                style: TextStyle(
                  color: vm.isDiapasonPlaying ? palette.primaryAccent : palette.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: vm.isDiapasonPlaying ? palette.primaryAccent : palette.surfaceBorderColor,
                  width: vm.isDiapasonPlaying ? 1.5 : 1.0,
                ),
                backgroundColor: vm.isDiapasonPlaying
                    ? palette.primaryAccent.withValues(alpha: 0.15)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => vm.toggleDiapasonTone(),
            ),

            const SizedBox(height: 12),

            // Botón de Confirmación
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.primaryAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                vm.stopDiapasonTone();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Confirmar y Aplicar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final TunnerThemePalette palette;
  final VoidCallback onPressed;

  const _StepButton({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.scaffoldBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: palette.staffLinesColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: palette.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
