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
  final VoidCallback? onOpenTerminal;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToTab,
    this.onOpenTerminal,
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;
    final instrument = viewModel.activeInstrument;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 720;
            final isWideGrid = constraints.maxWidth >= 950;
            final cardRadius = isDesktop ? 6.0 : 16.0;

            final cards = [
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
                borderRadius: cardRadius,
                onTap: () => onNavigateToTab(1),
              ),
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
                borderRadius: cardRadius,
                onTap: () => onNavigateToTab(2),
              ),
              _DashboardActionCard(
                key: const Key('card_action_recorder'),
                title: 'Rack Modular & Consola Multitarea',
                subtitle: 'Arrastra módulos, enruta señales por ID, afina y graba con la Consola Central.',
                badge: 'Modular Drag & Drop',
                badgeColor: palette.secondaryAccent,
                icon: Icons.dashboard_customize,
                accentColor: palette.secondaryAccent,
                palette: palette,
                actionLabel: 'Abrir Rack de Estudio',
                borderRadius: cardRadius,
                onTap: () => onNavigateToTab(3),
              ),
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
                borderRadius: cardRadius,
                onTap: () => onNavigateToTab(4),
              ),
              _DashboardActionCard(
                key: const Key('card_action_dj'),
                title: 'Consola DJ Pro Workstation',
                subtitle: 'Mezcla profesional de 2 Decks, Jog Wheels con Scratch, 4-Stems Isolator, Sampler de 8 pads y grabación en vivo.',
                badge: 'Club Mixer 2-Decks',
                badgeColor: const Color(0xFF00E5FF),
                icon: Icons.album,
                accentColor: const Color(0xFF00E5FF),
                palette: palette,
                actionLabel: 'Abrir Mesa DJ',
                borderRadius: cardRadius,
                onTap: () => onNavigateToTab(5),
              ),
            ];

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 24 : 20,
                vertical: isDesktop ? 20 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra Superior: Bienvenida & Buscador Spotlight
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('home_search_icon_btn'),
                        tooltip: 'Buscar herramienta...',
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.cardBackground,
                            borderRadius: BorderRadius.circular(isDesktop ? 6 : 12),
                            border: Border.all(
                              color: palette.staffLinesColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Icon(Icons.search, color: palette.primaryAccent, size: 20),
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
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(
                          color: palette.staffLinesColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: palette.textMutedColor, size: 18),
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
                              borderRadius: BorderRadius.circular(4),
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
                          palette.primaryAccent.withValues(alpha: 0.12),
                          palette.secondaryAccent.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(cardRadius),
                      border: Border.all(
                        color: palette.primaryAccent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.cardBackground,
                            borderRadius: BorderRadius.circular(isDesktop ? 4 : 12),
                          ),
                          child: Text(
                            instrument.clef.symbol,
                            style: TextStyle(
                              color: palette.primaryAccent,
                              fontSize: 18,
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                instrument.name,
                                style: TextStyle(
                                  color: palette.textColor,
                                  fontSize: 14,
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const Key('home_audition_drone_btn'),
                              tooltip: viewModel.isDronePlaying
                                  ? 'Detener Tono Diapasón'
                                  : 'Audicionar Tono Diapasón (${viewModel.referencePitch.toInt()} Hz)',
                              icon: Icon(
                                viewModel.isDronePlaying ? Icons.volume_up_rounded : Icons.hearing_rounded,
                                color: viewModel.isDronePlaying ? palette.correctPitchColor : palette.secondaryAccent,
                                size: 20,
                              ),
                              onPressed: () => viewModel.toggleDrone(),
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton(
                              key: const Key('home_change_instrument_btn'),
                              onPressed: () => InstrumentSelectorModal.show(context, viewModel),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.primaryAccent,
                                side: BorderSide(color: palette.primaryAccent.withValues(alpha: 0.4)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: const Text('Cambiar', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // HUD de Telemetría Core Audio en Vivo
                  Container(
                    key: const Key('home_core_audio_hud'),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.cardBackground,
                      borderRadius: BorderRadius.circular(cardRadius),
                      border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CORE AUDIO DSP:',
                          style: TextStyle(
                            color: palette.textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '48.0 kHz • 24-bit • Buffer: 1024 (< 8 ms) • RingBuffer: 16k lock-free',
                            style: TextStyle(
                              color: palette.secondaryAccent,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (onOpenTerminal != null)
                          InkWell(
                            key: const Key('home_open_terminal_hud_btn'),
                            onTap: onOpenTerminal,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.terminal, size: 12, color: Color(0xFF00E5FF)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Terminal OS (Ctrl+~)',
                                    style: TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Título de Sección
                  Text(
                    'Módulos de Trabajo Principales',
                    style: TextStyle(
                      color: palette.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tarjetas Principales (Grid de 2 Columnas con Hero Card para DJ Console)
                  if (isWideGrid) ...[
                    LayoutBuilder(
                      builder: (context, gridConstraints) {
                        final cardWidth = (gridConstraints.maxWidth - 16) / 2;
                        return Column(
                          children: [
                            // Fila 1: Afinador y Lecciones
                            Row(
                              children: [
                                SizedBox(width: cardWidth, child: cards[0]),
                                const SizedBox(width: 16),
                                SizedBox(width: cardWidth, child: cards[1]),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Fila 2: Rack Modular y Biblioteca de Partituras
                            Row(
                              children: [
                                SizedBox(width: cardWidth, child: cards[2]),
                                const SizedBox(width: 16),
                                SizedBox(width: cardWidth, child: cards[3]),
                              ],
                            ),
                            if (cards.length > 4) ...[
                              const SizedBox(height: 16),
                              // Fila 3: Consola DJ Pro Workstation (Hero Card que abarca el ancho completo)
                              SizedBox(width: gridConstraints.maxWidth, child: cards[4]),
                            ],
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    Column(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          cards[i],
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Plantillas Canónicas de Inicio Rápido
                  Text(
                    'Plantillas de Creación Rápida & Proyectos Canónicos',
                    style: TextStyle(
                      color: palette.textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _TemplateCard(
                        key: const Key('template_score_bach'),
                        title: 'Bach: Suite No. 1 Preludio',
                        extension: '.tunner',
                        subtitle: 'Partitura polifónica & stems',
                        icon: Icons.menu_book,
                        accentColor: palette.primaryAccent,
                        palette: palette,
                        onTap: () {
                          if (viewModel.workspaceScores.isNotEmpty) {
                            viewModel.loadSongPackage(viewModel.workspaceScores.first);
                          }
                          onNavigateToTab(4);
                        },
                      ),
                      _TemplateCard(
                        key: const Key('template_dj_elisa'),
                        title: 'Para Elisa Club Mix (126 BPM)',
                        extension: '.tndj',
                        subtitle: 'Sesión DJ 2-Decks & Beats',
                        icon: Icons.album,
                        accentColor: const Color(0xFF00E5FF),
                        palette: palette,
                        onTap: () => onNavigateToTab(5),
                      ),
                      _TemplateCard(
                        key: const Key('template_take_acoustic'),
                        title: 'Toma Acústica 440 Hz',
                        extension: '.wav',
                        subtitle: 'Audio estéreo 24-bit',
                        icon: Icons.graphic_eq,
                        accentColor: const Color(0xFF10B981),
                        palette: palette,
                        onTap: () => onNavigateToTab(3),
                      ),
                      _TemplateCard(
                        key: const Key('template_preset_philharmonic'),
                        title: 'Afinación Filarmónica (442 Hz)',
                        extension: '.tnpreset',
                        subtitle: 'Estándar orquestal sinfónico',
                        icon: Icons.tune,
                        accentColor: const Color(0xFFF59E0B),
                        palette: palette,
                        onTap: () => onNavigateToTab(1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Fila de Accesos Rápidos
                  Text(
                    'Ajustes & Calibración Rápida',
                    style: TextStyle(
                      color: palette.textColor,
                      fontSize: 13,
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
            );
          },
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
  final double borderRadius;
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
    this.borderRadius = 16.0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.cardBackground,
            Color.alphaBlend(accentColor.withValues(alpha: 0.05), palette.cardBackground),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
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
                          const SizedBox(width: 8),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
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

/// Tarjeta de plantilla de inicio rápido (.tunner, .tndj, .wav, .tnpreset).
class _TemplateCard extends StatelessWidget {
  final String title;
  final String extension;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final TunnerThemePalette palette;
  final VoidCallback onTap;

  const _TemplateCard({
    super.key,
    required this.title,
    required this.extension,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.cardBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        extension,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: palette.textMutedColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
