import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../atoms/studio_hairline.dart';
import '../atoms/studio_status_led.dart';
import '../atoms/studio_theme_switcher.dart';
import '../molecules/studio_tree_view.dart';

/// Organismo de UI: Estación de Trabajo Desktop Profesional (StudioDesktopAppShell).
///
/// Implementa la arquitectura visual de tres niveles idéntica a Antigravity, VS Code y Adobe CC:
/// 1. Top Menu Bar (Marca, Menús desplegables, Breadcrumbs y Acciones de ventana).
/// 2. Left Hierarchical Sidebar (Árbol de navegación jerárquica con categorías colapsables y footer de instrumento).
/// 3. Central Canvas Viewport (Área de trabajo maximizada sin elementos móviles intrusivos).
/// 4. Bottom Telemetry Status Bar (Lecturas DSP, latencia, tono de concierto y BPM).
class StudioDesktopAppShell extends StatelessWidget {
  final String appTitle;
  final String currentBreadcrumb;
  final List<StudioTreeSection> navigationSections;
  final String activeItemId;
  final Widget activeView;
  final Widget? sidebarFooter;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenShortcuts;
  final List<Widget>? customStatusItems;

  const StudioDesktopAppShell({
    super.key,
    this.appTitle = 'TUNNER STUDIO',
    required this.currentBreadcrumb,
    required this.navigationSections,
    required this.activeItemId,
    required this.activeView,
    this.sidebarFooter,
    required this.onOpenSearch,
    required this.onOpenShortcuts,
    this.customStatusItems,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Barra de Menú Superior (Top App Bar & Menus)
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
                  // Marca / Logo Studio
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: tokens.accentPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      border: Border.all(
                        color: tokens.accentPrimary.withValues(alpha: 0.4),
                        width: tokens.borderWidth,
                      ),
                    ),
                    child: Text(
                      appTitle,
                      style: TextStyle(
                        color: tokens.accentPrimary,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Menús de Aplicación de Escritorio
                  _buildTopMenuItem('Archivo', tokens),
                  _buildTopMenuItem('Herramientas', tokens),
                  _buildTopMenuItem('Acústica', tokens),
                  _buildTopMenuItem('Vista', tokens),
                  _buildTopMenuItem('Ayuda', tokens),

                  const SizedBox(width: 8),
                  const StudioHairline(orientation: Axis.vertical, length: 14),
                  const SizedBox(width: 8),

                  // Breadcrumb del módulo activo
                  Expanded(
                    child: Text(
                      currentBreadcrumb,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.0,
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
                ],
              ),
            ),

            // 2. Área Central (Sidebar + Viewport)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra Lateral Izquierda (Hierarchical Treeview Sidebar)
                  Container(
                    width: 250.0,
                    color: tokens.panelBackground,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Árbol Jerárquico
                        Expanded(
                          child: StudioTreeView(
                            sections: navigationSections,
                            selectedItemId: activeItemId,
                          ),
                        ),

                        // Pie de barra lateral (Instrumento activo)
                        if (sidebarFooter != null) ...[
                          const StudioHairline(orientation: Axis.horizontal),
                          sidebarFooter!,
                        ],
                      ],
                    ),
                  ),

                  // Separador vertical hairline 1px
                  const StudioHairline(orientation: Axis.vertical),

                  // Viewport Principal (Espacio de trabajo activo)
                  Expanded(
                    child: Container(
                      color: tokens.canvasBackground,
                      child: activeView,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Barra de Estado Inferior (Bottom Status Bar)
            Container(
              height: 24.0,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                  const StudioStatusLed(state: StudioLedState.success, size: 5),
                  const SizedBox(width: 6),
                  Text(
                    'MOTOR DSP: 60 FPS',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 14),
                  const StudioHairline(orientation: Axis.vertical, length: 12),
                  const SizedBox(width: 14),

                  if (customStatusItems != null) ...[
                    for (int i = 0; i < customStatusItems!.length; i++) ...[
                      customStatusItems![i],
                      if (i < customStatusItems!.length - 1) ...[
                        const SizedBox(width: 12),
                        const StudioHairline(orientation: Axis.vertical, length: 12),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ],

                  const Spacer(),
                  Text(
                    'TUNNER PRO WORKSTATION v2.29',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 8.5,
                      fontFamily: 'monospace',
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

  Widget _buildTopMenuItem(String label, dynamic tokens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Text(
        label,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 11.0,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
