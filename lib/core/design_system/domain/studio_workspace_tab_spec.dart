import 'studio_icon_catalog.dart';

/// Identificador canónico de las 6 pestañas DAW principales de Tunner Studio.
enum StudioWorkspaceTabId {
  home('home'),
  tuner('tuner'),
  learning('learning'),
  studio('studio'),
  library('library'),
  dj('dj');

  const StudioWorkspaceTabId(this.id);

  /// Clave textual estable usada en menús, comandos y serialización.
  final String id;
}

/// Especificación canónica e inmutable de una pestaña de espacio de trabajo DAW.
///
/// Reside en la capa de Dominio en Dart puro para garantizar una única fuente de
/// verdad entre `StudioWorkspaceTabBar`, `StudioDesktopAppShell` y `MainAppShell`.
class StudioWorkspaceTabSpec {
  final StudioWorkspaceTabId tabId;
  final int index;
  final String navKey;
  final String desktopLabel;
  final String mobileLabel;
  final String windowMenuTitle;
  final String desktopShortcut;
  final String windowShortcut;
  final String breadcrumb;
  final String activeItemId;
  final StudioIconId iconId;

  const StudioWorkspaceTabSpec({
    required this.tabId,
    required this.index,
    required this.navKey,
    required this.desktopLabel,
    required this.mobileLabel,
    required this.windowMenuTitle,
    required this.desktopShortcut,
    required this.windowShortcut,
    required this.breadcrumb,
    required this.activeItemId,
    required this.iconId,
  });

  /// Identificador de texto canónico (`home`, `tuner`, `learning`, `studio`, `library`, `dj`).
  String get id => tabId.id;

  /// Catálogo canónico ordenado de las 6 pestañas DAW de Tunner Studio.
  static const List<StudioWorkspaceTabSpec> canonicalTabs =
      <StudioWorkspaceTabSpec>[
    StudioWorkspaceTabSpec(
      tabId: StudioWorkspaceTabId.home,
      index: 0,
      navKey: 'nav_tab_home',
      desktopLabel: 'Inicio',
      mobileLabel: 'Inicio',
      windowMenuTitle: '1. Inicio & Dashboard de Rendimiento',
      desktopShortcut: 'F1',
      windowShortcut: 'Alt+1',
      breadcrumb: 'tunner / Inicio / Dashboard de Rendimiento',
      activeItemId: 'item_home',
      iconId: StudioIconId.uiWorkspaceLayout,
    ),
    StudioWorkspaceTabSpec(
      tabId: StudioWorkspaceTabId.tuner,
      index: 1,
      navKey: 'nav_tab_tuner',
      desktopLabel: 'Afinador',
      mobileLabel: 'Afinador',
      windowMenuTitle: '2. Afinador Estroboscópico Pro',
      desktopShortcut: 'F2',
      windowShortcut: 'Alt+2',
      breadcrumb: 'tunner / Afinación / Afinador Estroboscópico de Precisión',
      activeItemId: 'item_tuner',
      iconId: StudioIconId.moduleTuner,
    ),
    StudioWorkspaceTabSpec(
      tabId: StudioWorkspaceTabId.learning,
      index: 2,
      navKey: 'nav_tab_learning',
      desktopLabel: 'Aprender',
      mobileLabel: 'Aprender',
      windowMenuTitle: '3. Conservatorio & Pedagogía',
      desktopShortcut: 'F3',
      windowShortcut: 'Alt+3',
      breadcrumb: 'tunner / Conservatorio / Tutor de Compás & Detección Rushing',
      activeItemId: 'item_learning',
      iconId: StudioIconId.modulePedagogy,
    ),
    StudioWorkspaceTabSpec(
      tabId: StudioWorkspaceTabId.studio,
      index: 3,
      navKey: 'nav_tab_studio',
      desktopLabel: 'Rack Modular',
      mobileLabel: 'Estudio',
      windowMenuTitle: '4. Rack Modular de Estudio',
      desktopShortcut: 'F4',
      windowShortcut: 'Alt+4',
      breadcrumb: 'tunner / Estudio & Grabación / Rack Modular de Efectos DSP',
      activeItemId: 'item_rack',
      iconId: StudioIconId.moduleRack,
    ),
    StudioWorkspaceTabSpec(
      tabId: StudioWorkspaceTabId.library,
      index: 4,
      navKey: 'nav_tab_library',
      desktopLabel: 'Partituras',
      mobileLabel: 'Partituras',
      windowMenuTitle: '5. Biblioteca de Canciones',
      desktopShortcut: 'F5',
      windowShortcut: 'Alt+5',
      breadcrumb: 'tunner / Biblioteca / Editor & Reproductor MusicXML',
      activeItemId: 'item_composition',
      iconId: StudioIconId.moduleScoreSheet,
    ),
    StudioWorkspaceTabSpec(
      tabId: StudioWorkspaceTabId.dj,
      index: 5,
      navKey: 'nav_tab_dj',
      desktopLabel: 'Consola DJ',
      mobileLabel: 'Mesa DJ',
      windowMenuTitle: '6. Consola DJ Studio & Stems',
      desktopShortcut: 'F6',
      windowShortcut: 'Alt+6',
      breadcrumb:
          'tunner / Consola DJ Studio / Mezclador de Grado Club & 4-Stems',
      activeItemId: 'item_dj',
      iconId: StudioIconId.moduleDjConsole,
    ),
  ];

  /// Resuelve una pestaña por índice con fallback determinista a `home` (0).
  static StudioWorkspaceTabSpec byIndex(int index) {
    if (index < 0 || index >= canonicalTabs.length) {
      return canonicalTabs.first;
    }
    return canonicalTabs[index];
  }

  /// Resuelve una pestaña por su [StudioWorkspaceTabId].
  static StudioWorkspaceTabSpec byTabId(StudioWorkspaceTabId tabId) {
    return canonicalTabs.firstWhere((spec) => spec.tabId == tabId);
  }

  /// Busca una pestaña por su identificador textual (`home`, `tuner`, `learning`, `studio`, `library`, `dj`).
  static StudioWorkspaceTabSpec? findById(String id) {
    final normalized = id.trim().toLowerCase();
    for (final spec in canonicalTabs) {
      if (spec.id == normalized) {
        return spec;
      }
    }
    return null;
  }
}
