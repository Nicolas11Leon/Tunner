import 'package:flutter/material.dart';
import '../../../core/design_system/studio_design_system.dart';
import '../domain/harmonic_role_entity.dart';
import '../domain/just_intonation_calculator.dart';
import 'harmonic_beat_gauge.dart';
import 'harmonic_tutor_view_model.dart';

/// Conservatory-grade modal for practicing Dynamic Just Intonation and
/// canceling acoustic beating in real time.
class HarmonicTutorModal extends StatelessWidget {
  final HarmonicTutorViewModel viewModel;
  final TunnerThemePalette? palette;
  final bool Function()? isMicrophoneActive;
  final Future<void> Function()? onToggleMicrophone;
  final Listenable? microphoneListenable;

  const HarmonicTutorModal({
    super.key,
    required this.viewModel,
    this.palette,
    this.isMicrophoneActive,
    this.onToggleMicrophone,
    this.microphoneListenable,
  });

  static Future<void> show(
    BuildContext context, {
    required HarmonicTutorViewModel viewModel,
    TunnerThemePalette? palette,
    bool Function()? isMicrophoneActive,
    Future<void> Function()? onToggleMicrophone,
    Listenable? microphoneListenable,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HarmonicTutorModal(
        viewModel: viewModel,
        palette: palette,
        isMicrophoneActive: isMicrophoneActive,
        onToggleMicrophone: onToggleMicrophone,
        microphoneListenable: microphoneListenable,
      ),
    );
  }

  static const List<({String name, double freq})> _standardRoots = [
    (name: 'Do (C4)', freq: 261.63),
    (name: 'Re (D4)', freq: 293.66),
    (name: 'Mi (E4)', freq: 329.63),
    (name: 'Fa (F4)', freq: 349.23),
    (name: 'Sol (G3)', freq: 196.00),
    (name: 'La (A3)', freq: 220.00),
    (name: 'Si (B3)', freq: 246.94),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        viewModel,
        ?microphoneListenable,
      ]),
      builder: (context, _) {
        final session = viewModel.session;
        final analysis = session.activeAnalysis ??
            JustIntonationCalculator.analyze(
              userFrequency: session.rootFrequency,
              rootFrequency: session.rootFrequency,
            );

        final statusColor = analysis.status == HarmonicLockStatus.pureConsonance
            ? tokens.accentSuccess
            : analysis.status == HarmonicLockStatus.adjusting
                ? tokens.accentWarning
                : tokens.accentDanger;

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: tokens.canvasBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: tokens.borderHairline),
          ),
          child: Column(
            children: [
              // 1. Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    StudioIcon(
                      StudioIconId.moduleDrone,
                      color: tokens.accentPrimary,
                      size: 22,
                      tintCustomAsset: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tutor de Entonación Armónica Adaptativa',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Afinación Justa (JI), roles armónicos y anulación de batimientos',
                            style: TextStyle(color: tokens.textMuted, fontSize: 11),
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

              // 2. Main Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Context Setup Card (Root + Chord Type + Drone Switch)
                      Material(
                        color: tokens.panelBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: tokens.borderHairline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'ACORDE GUÍA DE ENSAMBLE',
                                    style: TextStyle(
                                      color: tokens.textMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Drone toggle button
                                  OutlinedButton.icon(
                                    key: const Key('toggle_harmonic_drone_btn'),
                                    onPressed: () => viewModel.toggleDrone(),
                                    icon: StudioIcon(
                                      StudioIconId.audioVolumeOn,
                                      size: 14,
                                      color: session.isDroneActive
                                          ? tokens.accentSuccess
                                          : tokens.textMuted,
                                      tintCustomAsset: true,
                                    ),
                                    label: Text(
                                      session.isDroneActive ? 'Dron Guía Activo' : 'Activar Dron Guía',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: session.isDroneActive
                                            ? tokens.accentSuccess
                                            : tokens.textPrimary,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: session.isDroneActive
                                            ? tokens.accentSuccess
                                            : tokens.borderHairline,
                                      ),
                                      backgroundColor: session.isDroneActive
                                          ? tokens.accentSuccess.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: const Size(0, 30),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Root note selector
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _standardRoots.map((root) {
                                  final isSelected = (session.rootFrequency - root.freq).abs() < 0.5;
                                  return ChoiceChip(
                                    label: Text(root.name, style: const TextStyle(fontSize: 11)),
                                    selected: isSelected,
                                    backgroundColor: tokens.elevatedSurface,
                                    selectedColor: tokens.accentPrimary.withValues(alpha: 0.2),
                                    side: BorderSide(
                                      color: isSelected
                                          ? tokens.accentPrimary
                                          : tokens.borderHairline,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? tokens.accentPrimary
                                          : tokens.textPrimary,
                                    ),
                                    onSelected: (val) {
                                      if (val) viewModel.setRootNote(root.name, root.freq);
                                    },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),

                              // Chord quality dropdown
                              Row(
                                children: [
                                  Text(
                                    'Modalidad:',
                                    style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<HarmonicChordType>(
                                      value: session.chordType,
                                      dropdownColor: tokens.panelBackground,
                                      isDense: true,
                                      style: TextStyle(color: tokens.textPrimary, fontSize: 12),
                                      items: HarmonicChordType.values.map((type) {
                                        return DropdownMenuItem(
                                          value: type,
                                          child: Text(type.label),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) viewModel.setChordType(val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Real-time Acoustic Beat & Consonance Gauge
                      Material(
                        color: tokens.panelBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: analysis.isLocked
                                ? tokens.accentSuccess.withValues(alpha: 0.5)
                                : tokens.borderHairline,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              Text(
                                'VELOCIDAD DE BATIMIENTO ACÚSTICO',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),

                              HarmonicBeatGauge(
                                centsOffset: analysis.centsOffsetFromJi,
                                beatFrequencyHz: analysis.beatFrequencyHz,
                                status: analysis.status,
                                accentColor: tokens.accentPrimary,
                              ),
                              const SizedBox(height: 8),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  analysis.status.label,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Harmonic Role & Acoustic Physics Breakdown
                      Material(
                        color: tokens.panelBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: tokens.borderHairline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tokens.elevatedSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: tokens.accentPrimary),
                                    ),
                                    child: Text(
                                      analysis.role.symbol,
                                      style: TextStyle(
                                        color: tokens.accentPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rol: ${analysis.role.labelEs} (${analysis.role.numerator}/${analysis.role.denominator})',
                                          style: TextStyle(
                                            color: tokens.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          analysis.role.description,
                                          style: TextStyle(color: tokens.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 20, color: tokens.borderSubtle),

                              // Frequency & Cents Comparisons
                              Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _buildStatColumn('Frecuencia Usuario', '${analysis.userFrequency.toStringAsFixed(2)} Hz', tokens),
                                  _buildStatColumn('Diana Justa (JI)', '${analysis.targetFrequencyJi.toStringAsFixed(2)} Hz', tokens),
                                  _buildStatColumn('Desviación JI', '${analysis.centsOffsetFromJi >= 0 ? "+" : ""}${analysis.centsOffsetFromJi.toStringAsFixed(1)} c', tokens),
                                  _buildStatColumn('Offset 12-TET', '${analysis.role.tetOffsetCents >= 0 ? "+" : ""}${analysis.role.tetOffsetCents.toStringAsFixed(1)} c', tokens),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Pedagogical Advice Box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tokens.inputSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: tokens.borderSubtle),
                                ),
                                child: Text(
                                  analysis.tuningAdvice,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Live Acoustic Capture Control
                      Material(
                        color: tokens.panelBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: tokens.borderHairline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CAPTURA ACÚSTICA EN VIVO (MICRÓFONO)',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (isMicrophoneActive?.call() ?? false)
                                          ? 'Microfono activo: ${analysis.userFrequency > 0 ? "${analysis.userFrequency.toStringAsFixed(2)} Hz" : "escuchando señal..."}'
                                          : 'Activa el microfono para medir batimientos e intervalos reales.',
                                      style: TextStyle(color: tokens.textPrimary, fontSize: 11.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    key: const Key('harmonic_tutor_mic_toggle_btn'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: tokens.accentPrimary,
                                      foregroundColor: tokens.textOnAccent,
                                    ),
                                    onPressed: onToggleMicrophone == null
                                        ? null
                                        : () async {
                                            await onToggleMicrophone!();
                                          },
                                    icon: StudioIcon(
                                      (isMicrophoneActive?.call() ?? false)
                                          ? StudioIconId.audioMicOff
                                          : StudioIconId.audioMicOn,
                                      size: 16,
                                      color: tokens.textOnAccent,
                                      tintCustomAsset: true,
                                    ),
                                    label: Text(
                                      (isMicrophoneActive?.call() ?? false)
                                          ? 'Detener Mic'
                                          : 'Activar Mic',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, StudioDesignTokens tokens) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: tokens.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: tokens.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
