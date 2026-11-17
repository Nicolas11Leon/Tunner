import 'package:flutter/material.dart';
import '../studio_theme_provider.dart';
import '../studio_design_tokens.dart';
import '../atoms/studio_hairline.dart';
import '../atoms/studio_status_led.dart';
import '../atoms/studio_theme_switcher.dart';
import '../atoms/studio_splitter.dart';
import '../molecules/studio_tree_view.dart';
import '../molecules/studio_command_prompt_bar.dart';
import '../molecules/studio_workspace_tab_bar.dart';

/// Organismo de UI: Estación de Trabajo Desktop Profesional (StudioDesktopAppShell).
///
/// Implementa la arquitectura visual y ergonómica de software de audio comercial de alta gama (DAW / IDE):
/// 1. Top Window & Menu Bar: Menús nativos estilizados, selector de espacios de trabajo fijado,
///    breadcrumbs contextuales, conmutadores de paneles y temas.
/// 2. Left Hierarchical Sidebar: Explorador de proyectos ajustable con splitter táctil,
///    accesos directos a utilidades y pie con ajustes del estudio.
/// 3. Central Canvas Viewport: Sistema de división dual interactivo (Split Dual View)
///    para trabajar en múltiples herramientas a la vez con divisores arrastrables.
/// 4. Bottom Telemetry Status Bar: Lecturas de audio en tiempo real, latencia y DSP en línea.
class StudioDesktopAppShell extends StatefulWidget {
  final String appTitle;
  final String appVersion;
  final String currentBreadcrumb;
  final List<StudioTreeSection> navigationSections;
  final String activeItemId;
  final int currentTabIndex;
  final Widget activeView;
  final Widget? secondaryView;
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
  final Widget? customSidebarExplorer;

  const StudioDesktopAppShell({
    super.key,
    this.appTitle = 'Tunner',
    this.appVersion = 'v2.29.0',
    required this.currentBreadcrumb,
    required this.navigationSections,
    required this.activeItemId,
    this.currentTabIndex = 0,
    required this.activeView,
    this.secondaryView,
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
    this.customSidebarExplorer,
  });

  @override
  State<StudioDesktopAppShell> createState() => _StudioDesktopAppShellState();
}

class _StudioDesktopAppShellState extends State<StudioDesktopAppShell> {
  double _sidebarWidth = 260.0;
  bool _isSidebarVisible = true;
  bool _isDualSplitActive = false;
  double _dualSplitRatio = 0.50;
  String _sidebarMode = 'explorer'; // 'explorer' o 'tools'

  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  void _toggleDualSplit() {
    setState(() {
      _isDualSplitActive = !_isDualSplitActive;
    });
  }

  void _onResizeSidebar(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(180.0, 520.0);
    });
  }

  void _onResizeSplit(double delta, double totalWidth) {
    if (totalWidth <= 0) return;
    setState(() {
      final deltaRatio = delta / totalWidth;
      _dualSplitRatio = (_dualSplitRatio + deltaRatio).clamp(0.20, 0.80);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = StudioThemeScope.tokensOf(context);

    return Scaffold(
      backgroundColor: tokens.canvasBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Barra de Menú Superior de Alta Gama (Top App Bar & Menus estilo DAW / IDE Pro)
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
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
                        'Version ${widget.appVersion}',
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
                          widget.currentBreadcrumb,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                  // Controles de Gestión de Paneles y Ventanas
                  IconButton(
                    icon: Icon(
                      _isSidebarVisible ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                      size: 16,
                      color: _isSidebarVisible ? tokens.accentPrimary : tokens.textSecondary,
                    ),
                    tooltip: _isSidebarVisible ? 'Ocultar Barra Lateral (Ctrl+B)' : 'Mostrar Barra Lateral (Ctrl+B)',
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: _toggleSidebar,
                  ),
                  if (widget.secondaryView != null) ...[
                    IconButton(
                      icon: Icon(
                        _isDualSplitActive ? Icons.vertical_split_rounded : Icons.splitscreen_rounded,
                        size: 16,
                        color: _isDualSplitActive ? tokens.accentPrimary : tokens.textSecondary,
                      ),
                      tooltip: _isDualSplitActive
                          ? 'Desactivar Vista Dividida Dual (Ctrl+Shift+D)'
                          : 'Activar Vista Dividida Dual (Ctrl+Shift+D)',
                      splashRadius: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      onPressed: _toggleDualSplit,
                    ),
                  ],

                  const SizedBox(width: 4),
                  const StudioHairline(orientation: Axis.vertical, length: 14),
                  const SizedBox(width: 4),

                  // Acciones rápidas (Buscador, Atajos, Tema)
                  IconButton(
                    icon: Icon(Icons.search_rounded, size: 16, color: tokens.textSecondary),
                    tooltip: 'Búsqueda Rápida (Ctrl+K)',
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: widget.onOpenSearch,
                  ),
                  IconButton(
                    icon: Icon(Icons.keyboard_outlined, size: 16, color: tokens.textSecondary),
                    tooltip: 'Guía de Atajos de Teclado (?)',
                    splashRadius: 14,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: widget.onOpenShortcuts,
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
                      if (val == 'settings') widget.onOpenSettings?.call();
                      if (val == 'shortcuts') widget.onOpenShortcuts();
                      if (val == 'automations') widget.onOpenAutomations?.call();
                      if (val == 'customizations') widget.onOpenCustomizations?.call();
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
              );
            },
          ),
        ),

            // 2. Área Central (Sidebar Ajustable + Viewport con Splitter Interactivo)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barra Lateral Izquierda (Ajustable con Splitter)
                  if (_isSidebarVisible) ...[
                    SizedBox(
                      width: _sidebarWidth,
                      child: Container(
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
                                    onTap: widget.onOpenAutomations ?? () {},
                                  ),
                                  _buildSidebarUtilityItem(
                                    icon: Icons.tune_rounded,
                                    title: 'Customizations',
                                    tokens: tokens,
                                    onTap: widget.onOpenCustomizations ?? () {},
                                  ),
                                ],
                              ),
                            ),

                            const StudioHairline(orientation: Axis.horizontal),

                            // Conmutador de Modo de Barra Lateral (Archivos VS Code / Suite de Herramientas)
                            if (widget.customSidebarExplorer != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F121C),
                                  border: Border(bottom: BorderSide(color: Color(0xFF1E2538))),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        key: const Key('sidebar_mode_explorer_btn'),
                                        onTap: () => setState(() => _sidebarMode = 'explorer'),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _sidebarMode == 'explorer'
                                                ? const Color(0xFF1E283C)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(4),
                                            border: _sidebarMode == 'explorer'
                                                ? Border.all(color: const Color(0xFF00E5FF), width: 1)
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.folder_outlined,
                                                size: 12,
                                                color: _sidebarMode == 'explorer'
                                                    ? const Color(0xFF00E5FF)
                                                    : const Color(0xFF8E9BAE),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Archivos',
                                                style: TextStyle(
                                                  color: _sidebarMode == 'explorer'
                                                      ? Colors.white
                                                      : const Color(0xFF8E9BAE),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: InkWell(
                                        key: const Key('sidebar_mode_tools_btn'),
                                        onTap: () => setState(() => _sidebarMode = 'tools'),
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _sidebarMode == 'tools'
                                                ? const Color(0xFF1E283C)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(4),
                                            border: _sidebarMode == 'tools'
                                                ? Border.all(color: const Color(0xFF00E5FF), width: 1)
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.grid_view_outlined,
                                                size: 12,
                                                color: _sidebarMode == 'tools'
                                                    ? const Color(0xFF00E5FF)
                                                    : const Color(0xFF8E9BAE),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Herramientas',
                                                style: TextStyle(
                                                  color: _sidebarMode == 'tools'
                                                      ? Colors.white
                                                      : const Color(0xFF8E9BAE),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Árbol Jerárquico de Proyectos y Carpetas (VS Code Explorer o Suite de Herramientas)
                            Expanded(
                              child: (_sidebarMode == 'explorer' && widget.customSidebarExplorer != null)
                                  ? widget.customSidebarExplorer!
                                  : StudioTreeView(
                                      sections: widget.navigationSections,
                                      selectedItemId: widget.activeItemId,
                                    ),
                            ),

                            // Instrumento Activo
                            if (widget.sidebarFooter != null) ...[
                              const StudioHairline(orientation: Axis.horizontal),
                              widget.sidebarFooter!,
                            ],

                            // Pie Fijo de la Barra Lateral: Settings
                            const StudioHairline(orientation: Axis.horizontal),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                              child: _buildSidebarUtilityItem(
                                icon: Icons.settings_outlined,
                                title: 'Settings',
                                tokens: tokens,
                                onTap: widget.onOpenSettings ?? () {},
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Divisor interactivo de redimensionamiento de sidebar
                    StudioSplitter(
                      orientation: Axis.horizontal,
                      onDelta: _onResizeSidebar,
                      onDoubleTapReset: () => setState(() => _sidebarWidth = 260.0),
                    ),
                  ],

                  // Viewport Principal (con soporte para División Dual)
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        return Container(
                          color: tokens.canvasBackground,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Barra de Espacios de Trabajo estilo DAW comercial
                              Container(
                                height: 34.0,
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
                                child: LayoutBuilder(
                                  builder: (ctx, headerConstraints) {
                                    return Row(
                                      children: [
                                        // Pestañas de Espacios de Trabajo (Workspace Tabs adaptativas)
                                        Expanded(
                                          child: StudioWorkspaceTabBar(
                                            activeIndex: widget.currentTabIndex,
                                            onTabSelected: (idx) => widget.onNavigateToTabIndex?.call(idx),
                                          ),
                                        ),
                                        if (headerConstraints.maxWidth >= 640) ...[
                                          const SizedBox(width: 8),
                                          if (_isDualSplitActive && widget.secondaryView != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                                              decoration: BoxDecoration(
                                                color: tokens.accentPrimary.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(3.0),
                                                border: Border.all(color: tokens.accentPrimary.withValues(alpha: 0.3)),
                                              ),
                                              child: Text(
                                                'MODO DUAL SPLIT ACTIVO',
                                                style: TextStyle(
                                                  color: tokens.accentPrimary,
                                                  fontSize: 9.0,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            'Workspace: ${widget.currentBreadcrumb.split("/").last.trim()}',
                                            style: TextStyle(
                                              color: tokens.textMuted,
                                              fontSize: 10.0,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),

                              // Viewport central interactivo (Individual o Split Dual)
                              Expanded(
                                child: (_isDualSplitActive && widget.secondaryView != null)
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            width: (constraints.maxWidth * _dualSplitRatio)
                                                .clamp(200.0, constraints.maxWidth - 200.0),
                                            child: widget.activeView,
                                          ),
                                          StudioSplitter(
                                            orientation: Axis.horizontal,
                                            onDelta: (d) => _onResizeSplit(d, constraints.maxWidth),
                                            onDoubleTapReset: () => setState(() => _dualSplitRatio = 0.50),
                                          ),
                                          Expanded(
                                            child: widget.secondaryView!,
                                          ),
                                        ],
                                      )
                                    : widget.activeView,
                              ),

                              // Barra de Comandos / Prompt Acústico estilo Antigravity IDE
                              if (widget.promptSuggestions != null && widget.promptSuggestions!.isNotEmpty)
                                StudioCommandPromptBar(
                                  suggestions: widget.promptSuggestions!,
                                  onOpenHelp: widget.onOpenHelp ?? widget.onOpenShortcuts,
                                  onCommandExecuted: widget.onCommandSubmitted,
                                  engineName: widget.engineName,
                                  isRecording: widget.isRecording,
                                  onToggleRecording: widget.onToggleRecording,
                                )
                              else
                                _buildStudioPromptBar(tokens),
                            ],
                          ),
                        );
                      },
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
                  if (widget.customStatusItems != null) ...[
                    for (int i = 0; i < widget.customStatusItems!.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(width: 8),
                        const StudioHairline(orientation: Axis.vertical, length: 12),
                        const SizedBox(width: 8),
                      ],
                      widget.customStatusItems![i],
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
        if (val == 'shortcuts') widget.onOpenShortcuts();
        if (val == 'settings') widget.onOpenSettings?.call();
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
        if (val == 'new_score') widget.onMenuNewScore?.call();
        if (val == 'import_file') widget.onMenuImportFile?.call();
        if (val == 'new_preset') widget.onMenuNewPreset?.call();
        if (val == 'save_workspace') widget.onMenuSaveWorkspace?.call();
        if (val == 'reset_workspace') widget.onMenuResetWorkspace?.call();
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
        if (val == 'toggle_sidebar') _toggleSidebar();
        if (val == 'toggle_dual_split') _toggleDualSplit();
        if (val == 'toggle_rack') widget.onMenuToggleRack?.call();
        if (val == 'search') widget.onOpenSearch();
        if (val == 'automations') widget.onOpenAutomations?.call();
        if (val == 'customizations') widget.onOpenCustomizations?.call();
        if (val == 'spectrogram') widget.onOpenSpectrogram?.call();
      },
      items: [
        _buildPopupMenuItem('toggle_sidebar', 'Alternar Barra Lateral', Icons.view_sidebar_rounded, tokens, shortcut: 'Ctrl+B'),
        _buildPopupMenuItem('toggle_dual_split', 'Alternar Vista Dividida Dual', Icons.vertical_split_rounded, tokens, shortcut: 'Ctrl+Shift+D'),
        const PopupMenuDivider(height: 8),
        _buildPopupMenuItem('search', 'Búsqueda Rápida Omnibox', Icons.search_rounded, tokens, shortcut: 'Ctrl+K'),
        _buildPopupMenuItem('toggle_rack', 'Rack Modular de Estudio', Icons.developer_board_rounded, tokens, shortcut: 'F2'),
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
        if (val == 'tuner') widget.onNavigateToTabIndex?.call(1);
        if (val == 'metronome') widget.onNavigateToTabIndex?.call(0);
        if (val == 'learning') widget.onNavigateToTabIndex?.call(2);
        if (val == 'studio') widget.onNavigateToTabIndex?.call(3);
        if (val == 'library') widget.onNavigateToTabIndex?.call(4);
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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: tokens.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(tokens.radiusSmall),
                        border: Border.all(color: tokens.accentPrimary.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'T',
                        style: TextStyle(
                          color: tokens.accentPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tunner Studio Workstation',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Version ${widget.appVersion} • Licencia Libre y Abierta',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const StudioHairline(orientation: Axis.horizontal),
                const SizedBox(height: 14),
                Text(
                  'Tunner es una estación de trabajo acústica y pedagógica de alta fidelidad, construida bajo Clean Architecture para educación musical y producción de audio profesional.',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Diseñada con rendimiento determinista, sin bucles activos de CPU y operando 100% offline.',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Cerrar',
                      style: TextStyle(color: tokens.accentPrimary, fontSize: 12),
                    ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        child: Row(
          children: [
            Icon(icon, size: 14, color: tokens.textMuted),
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
      height: 38.0,
      margin: const EdgeInsets.all(10.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: tokens.panelHeaderBackground,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(color: tokens.borderHairline, width: tokens.borderWidth),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, size: 15, color: tokens.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Escribe un comando acústico o presiona "/" para acciones rápidas...',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 11.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
            decoration: BoxDecoration(
              color: tokens.canvasBackground,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(color: tokens.borderHairline),
            ),
            child: Text(
              widget.engineName,
              style: TextStyle(
                color: tokens.accentPrimary,
                fontSize: 9.0,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
