import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../studio_design_tokens.dart';
import '../atoms/studio_hairline.dart';
import '../atoms/studio_status_led.dart';
import '../atoms/studio_theme_switcher.dart';
import '../molecules/studio_tree_view.dart';
import '../molecules/studio_command_prompt_bar.dart';

/// Organismo de UI: Estación de Trabajo Desktop Profesional (StudioDesktopAppShell).
///
/// Implementa la arquitectura visual de tres niveles idéntica a Antigravity IDE,
/// VS Code y consolas profesionales de audio digital (DAWs):
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
  final List<PromptSuggestion>? promptSuggestions;
  final VoidCallback? onOpenHelp;
  final bool isRecording;
  final VoidCallback? onToggleRecording;
  final String engineName;
  final VoidCallback? onMenuNewScore;
  final VoidCallback? onMenuImportFile;
  final VoidCallback? onMenuNewPreset;
  final VoidCallback? onMenuSaveWorkspace;
  final VoidCallback? onMenuResetWorkspace;
  final VoidCallback? onMenuToggleRack;
  final ValueChanged<int>? onNavigateToTabIndex;
  final VoidCallback? onOpenSpectrogram;

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
    this.promptSuggestions,
    this.onOpenHelp,
    this.isRecording = false,
    this.onToggleRecording,
    this.engineName = 'Tartini DSP 2.1',
    this.onMenuNewScore,
    this.onMenuImportFile,
    this.onMenuNewPreset,
    this.onMenuSaveWorkspace,
    this.onMenuResetWorkspace,
    this.onMenuToggleRack,
    this.onNavigateToTabIndex,
    this.onOpenSpectrogram,
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
                  _buildTunnerMenu(context, tokens),
                  _buildWorkspaceMenu(context, tokens),
                  _buildViewMenu(context, tokens),
                  _buildWindowMenu(context, tokens),

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
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de la Estación',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    icon: Icon(Icons.more_vert_rounded, size: 16, color: tokens.textMuted),
                    color: tokens.panelBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
                    ),
                    onSelected: (val) {
                      if (val == 'settings') onOpenSettings?.call();
                      if (val == 'shortcuts') onOpenShortcuts();
                      if (val == 'automations') onOpenAutomations?.call();
                      if (val == 'customizations') onOpenCustomizations?.call();
                      if (val == 'about') _showAboutTunnerDialog(context, tokens);
                    },
                    itemBuilder: (ctx) => [
                      _buildPopupMenuItem('settings', 'Ajustes del Estudio', Icons.settings_outlined, tokens),
                      _buildPopupMenuItem('shortcuts', 'Atajos de Teclado', Icons.keyboard_outlined, tokens, shortcut: '?'),
                      _buildPopupMenuItem('automations', 'Automatizaciones', Icons.access_time_rounded, tokens),
                      _buildPopupMenuItem('customizations', 'Personalización Técnica', Icons.tune_rounded, tokens),
                      const PopupMenuDivider(height: 8),
                      _buildPopupMenuItem('about', 'Acerca de Tunner', Icons.info_outline_rounded, tokens),
                    ],
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
                        if (promptSuggestions != null && promptSuggestions!.isNotEmpty)
                          StudioCommandPromptBar(
                            suggestions: promptSuggestions!,
                            onOpenHelp: onOpenHelp ?? onOpenShortcuts,
                            onCommandExecuted: onCommandSubmitted,
                            engineName: engineName,
                            isRecording: isRecording,
                            onToggleRecording: onToggleRecording,
                          )
                        else
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

  Widget _buildTunnerMenu(BuildContext context, StudioDesignTokens tokens) {
    return _buildTopPopupMenu(
      context: context,
      label: 'Tunner',
      tokens: tokens,
      isBrand: true,
      onSelected: (val) {
        if (val == 'about') _showAboutTunnerDialog(context, tokens);
        if (val == 'shortcuts') onOpenShortcuts();
        if (val == 'settings') onOpenSettings?.call();
        if (val == 'updates') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tunner v2.29.0 está actualizado con el motor acústico más reciente.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      items: [
        _buildPopupMenuItem('about', 'Acerca de Tunner', Icons.info_outline_rounded, tokens),
        _buildPopupMenuItem('shortcuts', 'Guía de Atajos de Teclado', Icons.keyboard_outlined, tokens, shortcut: '?'),
        _buildPopupMenuItem('settings', 'Preferencias del Estudio...', Icons.tune_rounded, tokens, shortcut: 'Ctrl+,'),
        const PopupMenuDivider(height: 8),
        _buildPopupMenuItem('updates', 'Comprobar Actualizaciones', Icons.system_update_alt_rounded, tokens),
      ],
    );
  }

  Widget _buildWorkspaceMenu(BuildContext context, StudioDesignTokens tokens) {
    return _buildTopPopupMenu(
      context: context,
      label: 'Workspace',
      tokens: tokens,
      onSelected: (val) {
        if (val == 'new_score') onMenuNewScore?.call();
        if (val == 'import_file') onMenuImportFile?.call();
        if (val == 'new_preset') onMenuNewPreset?.call();
        if (val == 'save_workspace') onMenuSaveWorkspace?.call();
        if (val == 'reset_workspace') onMenuResetWorkspace?.call();
      },
      items: [
        _buildPopupMenuItem('new_score', 'Nueva Partitura...', Icons.post_add_rounded, tokens, shortcut: 'Ctrl+N'),
        _buildPopupMenuItem('import_file', 'Importar Archivo Universal...', Icons.file_open_outlined, tokens, shortcut: 'Ctrl+O'),
        _buildPopupMenuItem('new_preset', 'Nuevo Preset de Afinación...', Icons.bookmark_add_outlined, tokens),
        const PopupMenuDivider(height: 8),
        _buildPopupMenuItem('save_workspace', 'Guardar Estado de Sesión', Icons.save_outlined, tokens, shortcut: 'Ctrl+S'),
        _buildPopupMenuItem('reset_workspace', 'Reiniciar Espacio de Trabajo', Icons.refresh_rounded, tokens),
      ],
    );
  }

  Widget _buildViewMenu(BuildContext context, StudioDesignTokens tokens) {
    return _buildTopPopupMenu(
      context: context,
      label: 'View',
      tokens: tokens,
      onSelected: (val) {
        if (val == 'toggle_rack') onMenuToggleRack?.call();
        if (val == 'search') onOpenSearch();
        if (val == 'automations') onOpenAutomations?.call();
        if (val == 'customizations') onOpenCustomizations?.call();
        if (val == 'spectrogram') onOpenSpectrogram?.call();
      },
      items: [
        _buildPopupMenuItem('search', 'Búsqueda Rápida Omnibox', Icons.search_rounded, tokens, shortcut: 'Ctrl+K'),
        _buildPopupMenuItem('toggle_rack', 'Alternar Rack Modular', Icons.dashboard_customize_outlined, tokens, shortcut: 'Tab'),
        _buildPopupMenuItem('spectrogram', 'Espectrograma FFT Pantalla Completa', Icons.graphic_eq_rounded, tokens),
        const PopupMenuDivider(height: 8),
        _buildPopupMenuItem('automations', 'Panel de Automatizaciones', Icons.access_time_rounded, tokens),
        _buildPopupMenuItem('customizations', 'Personalización Técnica DSP', Icons.tune_rounded, tokens),
      ],
    );
  }

  Widget _buildWindowMenu(BuildContext context, StudioDesignTokens tokens) {
    return _buildTopPopupMenu(
      context: context,
      label: 'Window',
      tokens: tokens,
      onSelected: (val) {
        if (val == 'tuner') onNavigateToTabIndex?.call(1);
        if (val == 'metronome') onNavigateToTabIndex?.call(0);
        if (val == 'learning') onNavigateToTabIndex?.call(2);
        if (val == 'studio') onNavigateToTabIndex?.call(3);
        if (val == 'library') onNavigateToTabIndex?.call(4);
      },
      items: [
        _buildPopupMenuItem('tuner', '1. Afinador Estroboscópico Pro', Icons.tune_rounded, tokens, shortcut: 'Alt+1'),
        _buildPopupMenuItem('metronome', '2. Metrónomo Determinista', Icons.access_time_rounded, tokens, shortcut: 'Alt+2'),
        _buildPopupMenuItem('learning', '3. Conservatorio & Pedagogía', Icons.school_outlined, tokens, shortcut: 'Alt+3'),
        _buildPopupMenuItem('studio', '4. Rack Modular de Estudio', Icons.dashboard_customize_outlined, tokens, shortcut: 'Alt+4'),
        _buildPopupMenuItem('library', '5. Biblioteca de Canciones', Icons.menu_book_outlined, tokens, shortcut: 'Alt+5'),
      ],
    );
  }

  Widget _buildTopPopupMenu({
    required BuildContext context,
    required String label,
    required StudioDesignTokens tokens,
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
    bool isBrand = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: tokens.panelBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusSmall),
            side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: label,
        offset: const Offset(0, 26),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
        color: tokens.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
        ),
        onSelected: onSelected,
        itemBuilder: (ctx) => items,
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
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
    String value,
    String title,
    IconData icon,
    StudioDesignTokens tokens, {
    String? shortcut,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 32,
      child: Row(
        children: [
          Icon(icon, size: 14, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: 8),
            Text(
              shortcut,
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 9.5,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAboutTunnerDialog(BuildContext context, StudioDesignTokens tokens) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: tokens.panelBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          side: BorderSide(color: tokens.borderHairline, width: tokens.borderWidth),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.elevatedSurface,
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: tokens.borderHairline, width: 0.5),
                      ),
                      child: Icon(Icons.waves_rounded, size: 22, color: tokens.accentPrimary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tunner Audio Workstation',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Version $appVersion (Offline-First Pro Suite)',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 10.5,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const StudioHairline(orientation: Axis.horizontal),
                const SizedBox(height: 14),
                Text(
                  'Estación de trabajo acústica modular y conservatorio digital. Diseñada para pedagogía musical avanzada, entonación pura, transcriptor en tiempo real y análisis acústico sin latencia.',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '• Motor DSP: $engineName\n• Precisión: ±0.1 cents (MPM/NSDF)\n• Estándar Notación: SMuFL 1.4\n• Arquitectura: Monolito Modular Limpio',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.accentPrimary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                      ),
                    ),
                    child: const Text('Entendido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
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
