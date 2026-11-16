import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../studio_design_tokens.dart';
import '../atoms/studio_hairline.dart';
import '../atoms/studio_status_led.dart';
import '../atoms/studio_theme_switcher.dart';
import '../molecules/studio_tree_view.dart';

/// Organismo de UI: Estación de Trabajo Desktop Profesional (StudioDesktopAppShell).
///
/// Implementa la arquitectura visual de tres niveles idéntica a Antigravity IDE,
/// VS Code y Adobe Creative Cloud (Audition / Premiere):
/// 1. Top Window & Menu Bar (Menús nativos, versión, breadcrumbs y acciones de panel).
/// 2. Left Hierarchical Sidebar (Accesos directos a Automations/Customizations,
///    árbol jerárquico de proyectos con carpetas y pie con Settings fijo).
/// 3. Central Canvas Viewport con Barra de Comandos / Prompt Acústico integrado.
/// 4. Bottom Telemetry Status Bar (Lecturas DSP, latencia, tono de concierto y BPM).
class StudioDesktopAppShell extends StatelessWidget {
  final String appTitle;
  final String appVersion;
  final String currentBreadcrumb;
  final List<StudioTreeSection> navigationSections;
  final String activeItemId;
  final Widget activeView;
  final Widget? sidebarFooter;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenShortcuts;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenAutomations;
  final VoidCallback? onOpenCustomizations;
  final List<Widget>? customStatusItems;
  final ValueChanged<String>? onCommandSubmitted;

  const StudioDesktopAppShell({
    super.key,
    this.appTitle = 'Tunner',
    this.appVersion = 'v2.29.0',
    required this.currentBreadcrumb,
    required this.navigationSections,
    required this.activeItemId,
    required this.activeView,
    this.sidebarFooter,
    required this.onOpenSearch,
    required this.onOpenShortcuts,
    this.onOpenSettings,
    this.onOpenAutomations,
    this.onOpenCustomizations,
    this.customStatusItems,
    this.onCommandSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Barra de Menú Superior (Top App Bar & Menus estilo Antigravity IDE)
            Container(
              height: 38.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                color: tokens.panelHeaderBackground,
                border: Border(
                  bottom: BorderSide(
                    color: tokens.borderHairline,
                    width: tokens.borderWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Menús de Aplicación de Escritorio
                  _buildTopMenuItem('Tunner', tokens, isBrand: true),
                  _buildTopMenuItem('Workspace', tokens),
                  _buildTopMenuItem('View', tokens),
                  _buildTopMenuItem('Window', tokens),

                  const SizedBox(width: 8),
                  const StudioHairline(orientation: Axis.vertical, length: 14),
                  const SizedBox(width: 8),

                  // Versión / Badge
                  Text(
                    'Version $appVersion',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 10.0,
                      fontFamily: 'monospace',
                    ),
                  ),

                  const SizedBox(width: 12),
                  const StudioHairline(orientation: Axis.vertical, length: 14),
                  const SizedBox(width: 12),

                  // Breadcrumb del módulo activo
                  Expanded(
                    child: Text(
                      currentBreadcrumb,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Acciones rápidas (Buscador, Atajos, Tema)
                  IconButton(
                    icon: Icon(Icons.search_rounded, size: 16, color: tokens.textSecondary),
                    tooltip: 'Búsqueda Rápida (Ctrl+K)',
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: onOpenSearch,
                  ),
                  IconButton(
                    icon: Icon(Icons.keyboard_outlined, size: 16, color: tokens.textSecondary),
                    tooltip: 'Guía de Atajos de Teclado (?)',
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: onOpenShortcuts,
                  ),
                  const SizedBox(width: 4),
                  const StudioThemeSwitcher(),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.more_vert_rounded,
                    size: 16,
                    color: tokens.textMuted,
                  ),
                ],
              ),
            ),

            // 2. Área Central (Sidebar + Viewport con Prompt)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra Lateral Izquierda (Hierarchical Treeview Sidebar estilo Antigravity)
                  Container(
                    width: 260.0,
                    color: tokens.panelBackground,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Accesos directos superiores de nivel de sistema
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSidebarUtilityItem(
                                icon: Icons.access_time_rounded,
                                title: 'Automations',
                                tokens: tokens,
                                onTap: onOpenAutomations ?? () {},
                              ),
                              _buildSidebarUtilityItem(
                                icon: Icons.tune_rounded,
                                title: 'Customizations',
                                tokens: tokens,
                                onTap: onOpenCustomizations ?? () {},
                              ),
                            ],
                          ),
                        ),

                        const StudioHairline(orientation: Axis.horizontal),

                        // Árbol Jerárquico de Proyectos y Carpetas
                        Expanded(
                          child: StudioTreeView(
                            sections: navigationSections,
                            selectedItemId: activeItemId,
                          ),
                        ),

                        // Instrumento Activo
                        if (sidebarFooter != null) ...[
                          const StudioHairline(orientation: Axis.horizontal),
                          sidebarFooter!,
                        ],

                        // Pie Fijo de la Barra Lateral: Settings (idéntico a Antigravity)
                        const StudioHairline(orientation: Axis.horizontal),
                        InkWell(
                          onTap: onOpenSettings ?? () {},
                          child: Container(
                            height: 38.0,
                            padding: const EdgeInsets.symmetric(horizontal: 14.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.settings_outlined,
                                  size: 15,
                                  color: tokens.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Settings',
                                  style: TextStyle(
                                    color: tokens.textSecondary,
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divisor vertical hairline entre sidebar y viewport
                  const StudioHairline(orientation: Axis.vertical),

                  // Área Principal de Trabajo (Canvas Viewport + Prompt Bar)
                  Expanded(
                    child: Column(
                      children: [
                        // Cabecera de Contexto del Workspace
                        Container(
                          height: 34.0,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          decoration: BoxDecoration(
                            color: tokens.panelBackground.withValues(alpha: 0.5),
                            border: Border(
                              bottom: BorderSide(
                                color: tokens.borderHairline,
                                width: tokens.borderWidth,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  currentBreadcrumb,
                                  style: TextStyle(
                                    color: tokens.textPrimary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.more_horiz_rounded,
                                size: 16,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.view_sidebar_outlined,
                                size: 15,
                                color: tokens.textMuted,
                              ),
                            ],
                          ),
                        ),

                        // Contenido del Viewport
                        Expanded(
                          child: activeView,
                        ),

                        // Barra de Comandos / Prompt Acústico estilo Antigravity IDE
                        _buildStudioPromptBar(tokens),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Barra Inferior de Telemetría (Bottom Status Bar)
            Container(
              height: 24.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              decoration: BoxDecoration(
                color: tokens.panelHeaderBackground,
                border: Border(
                  top: BorderSide(
                    color: tokens.borderHairline,
                    width: tokens.borderWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const StudioStatusLed(state: StudioLedState.active, size: 6.0),
                  const SizedBox(width: 6),
                  Text(
                    'MOTOR DSP EN LÍNEA',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const StudioHairline(orientation: Axis.vertical, length: 12),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'BUFFER: 2048 • LATENCIA: < 8ms',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 9.0,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (customStatusItems != null) ...[
                    for (int i = 0; i < customStatusItems!.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(width: 8),
                        const StudioHairline(orientation: Axis.vertical, length: 12),
                        const SizedBox(width: 8),
                      ],
                      customStatusItems![i],
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMenuItem(String label, StudioDesignTokens tokens, {bool isBrand = false}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
        child: Text(
          label,
          style: TextStyle(
            color: isBrand ? tokens.accentPrimary : tokens.textPrimary,
            fontSize: 11.5,
            fontWeight: isBrand ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarUtilityItem({
    required IconData icon,
    required String title,
    required StudioDesignTokens tokens,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.5),
        child: Row(
          children: [
            Icon(icon, size: 14, color: tokens.textSecondary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioPromptBar(StudioDesignTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: tokens.panelBackground,
        border: Border(
          top: BorderSide(
            color: tokens.borderHairline,
            width: tokens.borderWidth,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: tokens.inputSurface,
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          border: Border.all(
            color: tokens.borderHairline,
            width: tokens.borderWidth,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Comandos de audio (@ para módulos, / para afinación, tempo)...',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: tokens.elevatedSurface,
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                border: Border.all(color: tokens.borderHairline, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tartini DSP 2.1',
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 10.0,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 12, color: tokens.textMuted),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.mic_none_rounded, size: 15, color: tokens.accentPrimary),
          ],
        ),
      ),
    );
  }
}
