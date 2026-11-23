import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../domain/learner_profile_entity.dart';
import '../../tuner_viewmodel.dart';

/// Modal interactivo para la selección y calibración del perfil pedagógico de aprendizaje.
class LearnerProfileSelectorModal extends StatelessWidget {
  const LearnerProfileSelectorModal({super.key});

  static Future<void> show(BuildContext context) {
    final tokens = StudioThemeScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: tokens.panelBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const LearnerProfileSelectorModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TunerViewModel>();
    final tokens = StudioThemeScope.of(context);
    final activeProfile = vm.learnerProfile;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: tokens.borderHairline),
      ),
      child: Column(
        children: [
          // Barra de arrastre superior
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: tokens.borderHairline,
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
                    color: tokens.elevatedSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.borderHairline),
                  ),
                  child: StudioIcon(
                    StudioIconId.modulePedagogy,
                    size: 20,
                    color: tokens.accentPrimary,
                    tintCustomAsset: true,
                  ),
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
                          color: tokens.textPrimary,
                        ),
                      ),
                      Text(
                        'Adaptación Cognitiva: Niños, Adultos y Conservatorio',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: StudioIcon(
                    StudioIconId.uiCloseConfirm,
                    size: 18,
                    color: tokens.textSecondary,
                    tintCustomAsset: true,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.borderSubtle),

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
                    color: tokens.accentPrimary,
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
                  iconId: StudioIconId.modulePedagogy,
                  fallbackIcon: Icons.child_care_rounded,
                  isSelected: activeProfile.type == LearnerProfileType.childPlayful,
                  accentColor: tokens.accentSuccess,
                  tokens: tokens,
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
                  iconId: StudioIconId.moduleTuner,
                  fallbackIcon: Icons.self_improvement_rounded,
                  isSelected: activeProfile.type == LearnerProfileType.adultDeliberate,
                  accentColor: tokens.accentPrimary,
                  tokens: tokens,
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
                  iconId: StudioIconId.moduleSpectrogram,
                  fallbackIcon: Icons.workspace_premium_rounded,
                  isSelected:
                      activeProfile.type == LearnerProfileType.conservatoryMastery,
                  accentColor: tokens.accentWarning,
                  tokens: tokens,
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
                    color: tokens.accentPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: tokens.canvasBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tokens.borderHairline),
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
                              color: tokens.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tokens.elevatedSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: tokens.borderHairline),
                            ),
                            child: Text(
                              '+-${activeProfile.centsTolerance.toStringAsFixed(1)} cents',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: tokens.accentPrimary,
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
                        activeColor: tokens.accentPrimary,
                        inactiveColor: tokens.borderHairline,
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
                          color: tokens.textMuted,
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
                      color: tokens.accentPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.canvasBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: vm.lastPedagogicalDiagnostic!.isInTune
                            ? tokens.accentSuccess.withValues(alpha: 0.5)
                            : tokens.accentWarning.withValues(alpha: 0.5),
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
                            color: tokens.textPrimary,
                          ),
                        ),
                        if (vm.lastPedagogicalDiagnostic!.biomechanicalCue !=
                            null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Pauta biomecánica: ${vm.lastPedagogicalDiagnostic!.biomechanicalCue!}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: tokens.accentPrimary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          vm.lastPedagogicalDiagnostic!.motivationalCue,
                          style: TextStyle(
                            fontSize: 11,
                            color: tokens.textMuted,
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
    required StudioIconId iconId,
    required IconData fallbackIcon,
    required bool isSelected,
    required Color accentColor,
    required StudioDesignTokens tokens,
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
              : tokens.canvasBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : tokens.borderHairline,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.18),
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
                color: accentColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: StudioIcon(
                iconId,
                size: 22,
                color: accentColor,
                tintCustomAsset: true,
                fallbackOverride: fallbackIcon,
              ),
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
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        StudioIcon(
                          StudioIconId.uiCloseConfirm,
                          size: 18,
                          color: accentColor,
                          tintCustomAsset: true,
                          fallbackOverride: Icons.check_circle,
                        ),
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
                      color: tokens.textMuted,
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
