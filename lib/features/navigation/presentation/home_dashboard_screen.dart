import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/tunner_theme.dart';
import '../../tuner_viewmodel.dart';
import 'tool_search_modal.dart';
import '../../tuner/presentation/concert_pitch_selector_modal.dart';
import '../../tuner/presentation/temperament_selector_modal.dart';
import '../../tuner/presentation/microphone_calibration_modal.dart';
import '../../pedagogy_report/presentation/pedagogical_report_modal.dart';
import '../../instrument/presentation/instrument_selector_modal.dart';

/// Pantalla de bienvenida y Dashboard Principal de Tunner.
/// Organiza las capacidades del software en tarjetas grandes y accesibles
/// según la intención del músico, eliminando la sobrecarga cognitiva.
class HomeDashboardScreen extends StatelessWidget {
  final void Function(int tabIndex) onNavigateToTab;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;
    final instrument = viewModel.activeInstrument;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra Superior: Bienvenida & Buscador Spotlight
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TUNNER STUDIO',
                        style: TextStyle(
                          color: palette.secondaryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¿Qué deseas hacer hoy?',
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: const Key('home_search_icon_btn'),
                    tooltip: 'Buscar herramienta...',
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.staffLinesColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(Icons.search, color: palette.primaryAccent, size: 22),
                    ),
                    onPressed: () => ToolSearchModal.show(
                      context,
                      viewModel,
                      onNavigateToTab: onNavigateToTab,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Barra de Búsqueda Falsa Táctil (Search Trigger)
              GestureDetector(
                key: const Key('home_search_trigger_bar'),
                onTap: () => ToolSearchModal.show(
                  context,
                  viewModel,
                  onNavigateToTab: onNavigateToTab,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: palette.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: palette.staffLinesColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: palette.textMutedColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Buscar herramienta, canción, metrónomo o ajuste...',
                          style: TextStyle(color: palette.textMutedColor, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.primaryAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ctrl+K',
                          style: TextStyle(
                            color: palette.primaryAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Banner de Instrumento Musical Activo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.primaryAccent.withValues(alpha: 0.15),
                      palette.secondaryAccent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: palette.primaryAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        instrument.clef.symbol,
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instrumento Activo',
                            style: TextStyle(
                              color: palette.textMutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            instrument.name,
                            style: TextStyle(
                              color: palette.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${instrument.family.displayName} • ${instrument.key.displayName}',
                            style: TextStyle(
                              color: palette.secondaryAccent,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      key: const Key('home_change_instrument_btn'),
                      onPressed: () => InstrumentSelectorModal.show(context, viewModel),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primaryAccent,
                        side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Título de Sección
              Text(
                'Módulos Principales',
                style: TextStyle(
                  color: palette.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Tarjeta 1: Afinador de Precisión
              _DashboardActionCard(
                key: const Key('card_action_tuner'),
                title: 'Afinador de Precisión',
                subtitle: 'Afinación en tiempo real con aguja centesimal, estroboscopio y tono de concierto.',
                badge: 'A4 = ${viewModel.referencePitch.toInt()} Hz',
                badgeColor: palette.primaryAccent,
                icon: Icons.tune,
                accentColor: palette.primaryAccent,
                palette: palette,
                actionLabel: 'Afinar Ahora',
                onTap: () => onNavigateToTab(1),
              ),
              const SizedBox(height: 12),

              // Tarjeta 2: Aprender a Tocar (Tutor Interactivo)
              _DashboardActionCard(
                key: const Key('card_action_lessons'),
                title: 'Aprender a Tocar',
                subtitle: 'Lecciones estructuradas paso a paso adaptadas a la tesitura de ${instrument.name}.',
                badge: '${viewModel.availableGuidedLessons.length} Rutinas Didácticas',
                badgeColor: palette.correctPitchColor,
                icon: Icons.school,
                accentColor: palette.correctPitchColor,
                palette: palette,
                actionLabel: 'Iniciar Lección',
                onTap: () => onNavigateToTab(2),
              ),
              const SizedBox(height: 12),

              // Tarjeta 3: Estudio de Grabación & Práctica
              _DashboardActionCard(
                key: const Key('card_action_recorder'),
                title: 'Estudio de Grabación & Práctica',
                subtitle: 'Registra tomas de audio, compara espectrogramas FFT y evalúa tu estabilidad.',
                badge: 'WAV & Análisis FFT',
                badgeColor: palette.secondaryAccent,
                icon: Icons.fiber_manual_record,
                accentColor: palette.secondaryAccent,
                palette: palette,
                actionLabel: 'Ir al Estudio',
                onTap: () => onNavigateToTab(3),
              ),
              const SizedBox(height: 12),

              // Tarjeta 4: Biblioteca de Canciones & Partituras
              _DashboardActionCard(
                key: const Key('card_action_library'),
                title: 'Biblioteca & Partituras',
                subtitle: 'Repertorio curado con pistas separadas (stems), importador MusicXML y editor.',
                badge: 'Partituras & Stems',
                badgeColor: palette.primaryAccent,
                icon: Icons.menu_book,
                accentColor: palette.primaryAccent,
                palette: palette,
                actionLabel: 'Explorar Obras',
                onTap: () => onNavigateToTab(4),
              ),
              const SizedBox(height: 24),

              // Fila de Accesos Rápidos
              Text(
                'Ajustes & Calibración Rápida',
                style: TextStyle(
                  color: palette.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickChip(
                    key: const Key('home_quick_mic_btn'),
                    icon: Icons.mic_external_on,
                    label: 'Mic: ${viewModel.acousticRigorProfile.preset.displayName.split(' ').first}',
                    palette: palette,
                    onTap: () => MicrophoneCalibrationModal.show(context, viewModel),
                  ),
                  _QuickChip(
                    key: const Key('home_quick_concert_pitch_btn'),
                    icon: Icons.waves,
                    label: '${viewModel.referencePitch.toInt()} Hz',
                    palette: palette,
                    onTap: () => ConcertPitchSelectorModal.show(context),
                  ),
                  _QuickChip(
                    key: const Key('home_quick_temperament_btn'),
                    icon: Icons.history_edu,
                    label: viewModel.selectedTemperament.name.split(' ').first,
                    palette: palette,
                    onTap: () => TemperamentSelectorModal.show(context),
                  ),
                  if (viewModel.lastReport != null)
                    _QuickChip(
                      key: const Key('home_quick_report_btn'),
                      icon: Icons.picture_as_pdf,
                      label: 'Reporte PDF',
                      palette: palette,
                      onTap: () => PedagogicalReportModal.show(context),
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta táctil de gran formato para los módulos principales del software.
class _DashboardActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final IconData icon;
  final Color accentColor;
  final TunnerThemePalette palette;
  final String actionLabel;
  final VoidCallback onTap;

  const _DashboardActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.accentColor,
    required this.palette,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.18)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: palette.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: palette.textMutedColor,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            actionLabel,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: accentColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de acceso rápido con icono y texto.
class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final TunnerThemePalette palette;
  final VoidCallback onTap;

  const _QuickChip({
    super.key,
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: palette.secondaryAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: palette.textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
