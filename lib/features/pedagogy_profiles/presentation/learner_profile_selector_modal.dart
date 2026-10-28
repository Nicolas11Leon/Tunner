import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/learner_profile_entity.dart';
import '../../tuner_viewmodel.dart';

/// Modal interactivo para la selección y calibración del perfil pedagógico de aprendizaje.
class LearnerProfileSelectorModal extends StatelessWidget {
  const LearnerProfileSelectorModal({super.key});

  static Future<void> show(BuildContext context) {
    final vm = Provider.of<TunerViewModel>(context, listen: false);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: vm.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const LearnerProfileSelectorModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final palette = vm.currentPalette;
    final activeProfile = vm.learnerProfile;
    final cardBorder = palette.staffLinesColor.withValues(alpha: 0.3);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: palette.textMutedColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Encabezado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.primaryAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.psychology,
                      size: 22, color: palette.primaryAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perfil Pedagógico y Andamiaje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: palette.textColor,
                        ),
                      ),
                      Text(
                        'Adaptación Cognitiva: Niños, Adultos y Conservatorio',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textMutedColor,
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
          ),
          const Divider(height: 1),

          // Lista de perfiles y ajustes
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'FILOSOFÍAS DE APRENDIZAJE ADAPTATIVO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: palette.primaryAccent,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Tarjeta Infantil / Lúdico
                _buildProfileCard(
                  key: const Key('profile_child_card'),
                  title: 'Modo Lúdico Infantil',
                  badge: 'Tolerancia +-25c | Andamiaje Progresivo',
                  description:
                      'Exploración del sonido libre de frustración. Sin juicios ni números intimidantes. '
                      'La tolerancia se afina suavemente a medida que el niño acumula aciertos.',
                  icon: Icons.child_care_rounded,
                  isSelected: activeProfile.type == LearnerProfileType.childPlayful,
                  accentColor: const Color(0xFF00E676),
                  palette: palette,
                  cardBorder: cardBorder,
                  onTap: () =>
                      vm.setLearnerProfileType(LearnerProfileType.childPlayful),
                ),
                const SizedBox(height: 12),

                // 2. Tarjeta Adulto - Práctica Deliberada
                _buildProfileCard(
                  key: const Key('profile_adult_card'),
                  title: 'Modo Adulto (Práctica Deliberada)',
                  badge: 'Tolerancia +-10c | Pautas Biomecánicas',
                  description:
                      'Andragogía científica y mentalidad de crecimiento. Reduce la carga cognitiva extraña '
                      'y aporta pautas físicas de respiración, apoyo y relajación laringea.',
                  icon: Icons.self_improvement_rounded,
                  isSelected: activeProfile.type == LearnerProfileType.adultDeliberate,
                  accentColor: palette.primaryAccent,
                  palette: palette,
                  cardBorder: cardBorder,
                  onTap: () =>
                      vm.setLearnerProfileType(LearnerProfileType.adultDeliberate),
                ),
                const SizedBox(height: 12),

                // 3. Tarjeta Conservatorio / Maestría
                _buildProfileCard(
                  key: const Key('profile_conservatory_card'),
                  title: 'Modo Conservatorio y Maestría',
                  badge: 'Tolerancia +-5c | Rigor Microtonal',
                  description:
                      'Estación acústica para músicos de concierto. Cero concesiones en centésimas, '
                      'análisis espectral FFT de 8 armónicos, centroide y métricas de pulso.',
                  icon: Icons.workspace_premium_rounded,
                  isSelected:
                      activeProfile.type == LearnerProfileType.conservatoryMastery,
                  accentColor: const Color(0xFFFFB300),
                  palette: palette,
                  cardBorder: cardBorder,
                  onTap: () => vm.setLearnerProfileType(
                      LearnerProfileType.conservatoryMastery),
                ),
                const SizedBox(height: 24),

                // Calibración Manual Fina de Tolerancia Microtonal
                Text(
                  'CALIBRACIÓN DE TOLERANCIA MICROTONAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: palette.primaryAccent,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ventana de afinación válida:',
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.primaryAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+-${activeProfile.centsTolerance.toStringAsFixed(1)} cents',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: palette.primaryAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        key: const Key('cents_tolerance_slider'),
                        min: 3.0,
                        max: 30.0,
                        divisions: 27,
                        value: activeProfile.centsTolerance.clamp(3.0, 30.0),
                        activeColor: palette.primaryAccent,
                        inactiveColor:
                            palette.staffLinesColor.withValues(alpha: 0.3),
                        onChanged: (val) {
                          vm.updateLearnerProfile(
                            activeProfile.copyWith(
                              type: LearnerProfileType.custom,
                              centsTolerance: val,
                            ),
                          );
                        },
                      ),
                      Text(
                        'Una tolerancia más amplia permite explorar notas sin fatiga motriz; una más estrecha entrena el oído para tocar en ensamble.',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.textMutedColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Diagnóstico Pedagógico en Vivo (si existe)
                if (vm.lastPedagogicalDiagnostic != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    'RETROALIMENTACIÓN FORMATIVA EN VIVO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: palette.primaryAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: vm.lastPedagogicalDiagnostic!.isInTune
                            ? palette.correctPitchColor.withValues(alpha: 0.5)
                            : palette.warningPitchColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vm.lastPedagogicalDiagnostic!.primaryFeedback,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: palette.textColor,
                          ),
                        ),
                        if (vm.lastPedagogicalDiagnostic!.biomechanicalCue !=
                            null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Pauta biomecánica: ${vm.lastPedagogicalDiagnostic!.biomechanicalCue!}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: palette.primaryAccent,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          vm.lastPedagogicalDiagnostic!.motivationalCue,
                          style: TextStyle(
                            fontSize: 11,
                            color: palette.textMutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required Key key,
    required String title,
    required String badge,
    required String description,
    required IconData icon,
    required bool isSelected,
    required Color accentColor,
    required TunnerThemePalette palette,
    required Color cardBorder,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : palette.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : cardBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: palette.textColor,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, size: 20, color: accentColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.textMutedColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
