import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';
import '../domain/harmonic_role_entity.dart';
import '../domain/just_intonation_calculator.dart';
import 'harmonic_beat_gauge.dart';
import 'harmonic_tutor_view_model.dart';

/// Conservatory-grade modal for practicing Dynamic Just Intonation and
/// canceling acoustic beating in real time.
class HarmonicTutorModal extends StatelessWidget {
  final HarmonicTutorViewModel viewModel;
  final TunnerThemePalette palette;

  const HarmonicTutorModal({
    super.key,
    required this.viewModel,
    required this.palette,
  });

  static Future<void> show(
    BuildContext context, {
    required HarmonicTutorViewModel viewModel,
    required TunnerThemePalette palette,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HarmonicTutorModal(viewModel: viewModel, palette: palette),
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
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final session = viewModel.session;
        final analysis = session.activeAnalysis ??
            JustIntonationCalculator.analyze(
              userFrequency: session.rootFrequency,
              rootFrequency: session.rootFrequency,
            );

        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: BoxDecoration(
            color: palette.scaffoldBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              // 1. Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.waves, color: palette.primaryAccent, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tutor de Entonación Armónica Adaptativa',
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Afinación Justa (JI), roles armónicos y anulación de batimientos',
                            style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: palette.textColor),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),

              // 2. Main Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Context Setup Card (Root + Chord Type + Drone Switch)
                      Material(
                        color: palette.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.15)),
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
                                      color: palette.textMutedColor,
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
                                    icon: Icon(
                                      session.isDroneActive ? Icons.volume_up : Icons.volume_off,
                                      size: 14,
                                      color: session.isDroneActive ? const Color(0xFF00E676) : palette.textMutedColor,
                                    ),
                                    label: Text(
                                      session.isDroneActive ? 'Dron Guía Activo' : 'Activar Dron Guía',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: session.isDroneActive ? const Color(0xFF00E676) : palette.textColor,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: session.isDroneActive
                                            ? const Color(0xFF00E676)
                                            : palette.staffLinesColor.withValues(alpha: 0.3),
                                      ),
                                      backgroundColor: session.isDroneActive
                                          ? const Color(0xFF00E676).withValues(alpha: 0.1)
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
                                    selectedColor: palette.primaryAccent.withValues(alpha: 0.3),
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
                                    style: TextStyle(color: palette.textColor, fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: DropdownButton<HarmonicChordType>(
                                      value: session.chordType,
                                      dropdownColor: palette.cardBackground,
                                      isDense: true,
                                      style: TextStyle(color: palette.textColor, fontSize: 12),
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
                        color: palette.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: analysis.isLocked
                                ? const Color(0xFF00E676).withValues(alpha: 0.5)
                                : palette.staffLinesColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              Text(
                                'VELOCIDAD DE BATIMIENTO ACÚSTICO',
                                style: TextStyle(
                                  color: palette.textMutedColor,
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
                                accentColor: palette.primaryAccent,
                              ),
                              const SizedBox(height: 8),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: analysis.status == HarmonicLockStatus.pureConsonance
                                      ? const Color(0xFF00E676).withValues(alpha: 0.2)
                                      : analysis.status == HarmonicLockStatus.adjusting
                                          ? const Color(0xFFFFB300).withValues(alpha: 0.2)
                                          : const Color(0xFFE53935).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: analysis.status == HarmonicLockStatus.pureConsonance
                                        ? const Color(0xFF00E676)
                                        : analysis.status == HarmonicLockStatus.adjusting
                                            ? const Color(0xFFFFB300)
                                            : const Color(0xFFE53935),
                                  ),
                                ),
                                child: Text(
                                  analysis.status.label,
                                  style: TextStyle(
                                    color: analysis.status == HarmonicLockStatus.pureConsonance
                                        ? const Color(0xFF00E676)
                                        : analysis.status == HarmonicLockStatus.adjusting
                                            ? const Color(0xFFFFB300)
                                            : const Color(0xFFE53935),
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
                        color: palette.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.15)),
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
                                      color: palette.primaryAccent.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: palette.primaryAccent),
                                    ),
                                    child: Text(
                                      analysis.role.symbol,
                                      style: TextStyle(
                                        color: palette.primaryAccent,
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
                                            color: palette.textColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          analysis.role.description,
                                          style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Frequency & Cents Comparisons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn('Frecuencia Usuario', '${analysis.userFrequency.toStringAsFixed(2)} Hz', palette),
                                  _buildStatColumn('Diana Justa (JI)', '${analysis.targetFrequencyJi.toStringAsFixed(2)} Hz', palette),
                                  _buildStatColumn('Desviación JI', '${analysis.centsOffsetFromJi >= 0 ? "+" : ""}${analysis.centsOffsetFromJi.toStringAsFixed(1)} c', palette),
                                  _buildStatColumn('Offset 12-TET', '${analysis.role.tetOffsetCents >= 0 ? "+" : ""}${analysis.role.tetOffsetCents.toStringAsFixed(1)} c', palette),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Pedagogical Advice Box
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  analysis.tuningAdvice,
                                  style: TextStyle(
                                    color: palette.textColor,
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

                      // Interactive Quick-Practice Buttons
                      Material(
                        color: palette.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: palette.staffLinesColor.withValues(alpha: 0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SIMULACIÓN DE PRÁCTICA AUDITIVA',
                                style: TextStyle(
                                  color: palette.textMutedColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    key: const Key('sim_3rd_tempered_btn'),
                                    onPressed: () {
                                      // 12-TET Major Third: 261.63 * 2^(4/12) ≈ 329.63 Hz (+13.7 cents above JI)
                                      viewModel.onPitchDetected(session.rootFrequency * 1.259921);
                                    },
                                    child: const Text('Tercera 12-TET (+13.7 c)', style: TextStyle(fontSize: 11)),
                                  ),
                                  OutlinedButton(
                                    key: const Key('sim_3rd_just_btn'),
                                    onPressed: () {
                                      // Pure JI Major Third: 261.63 * 1.25 = 327.0375 Hz (0 cents, 0 Hz beat)
                                      viewModel.onPitchDetected(session.rootFrequency * 1.25);
                                    },
                                    child: const Text('Tercera Justa 5/4 (Lock 0.0 Hz)', style: TextStyle(fontSize: 11)),
                                  ),
                                  OutlinedButton(
                                    key: const Key('sim_5th_just_btn'),
                                    onPressed: () {
                                      // Pure JI Fifth: 261.63 * 1.5 = 392.445 Hz
                                      viewModel.onPitchDetected(session.rootFrequency * 1.50);
                                    },
                                    child: const Text('Quinta Justa 3/2 (Pura)', style: TextStyle(fontSize: 11)),
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

  Widget _buildStatColumn(String label, String value, TunnerThemePalette palette) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: palette.textMutedColor, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: palette.textColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
