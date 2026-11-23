# ADR-0171: SignalBus Reiniciable sin Disposicion, Renderizado de Zona Flotante en Docking y Sintesis Perezosa en Media Vault

## Estado
Aprobado — 2026-11-23 (Fase 6: Hardening de Produccion y Enrutamiento v1.0, US-11.1 #189 y US-11.3 #191)

## Contexto
Durante la auditoria forense de las herramientas de estudio (`Modular Rack`, `Docking` y `Media Vault`), se identificaron los siguientes defectos estructurales:
1. **Destruccion prematura del `SignalBus`:** `ModularRackViewModel.loadPreset()` y `loadProjectPackage()` invocaban `signalBus.dispose()`, cerrando todos los `StreamController`s de los puertos registrados. Si un consumidor externo o nodo mantenia una suscripcion o intentaba reutilizar un controlador cerrado, el bus quedaba inoperativo.
2. **Desaparicion de paneles en `StudioDockZone.floating` y fragilidad en `StudioWorkspaceDockingContainer`:** El contenedor de docking renderizaba unicamente `left`, `center`, `right` y `bottom`, ignorando `StudioDockZone.floating`. Ademas, el uso de `.clamp(100.0, double.infinity)` provocaba `ArgumentError` o desbordamientos cuando la altura total era menor a `134.0` px; `DefaultTabController` carecia de `Key` vinculada a `zonePanels.length`; `widget.panels.first` no estaba protegido ante listas vacias; y los componentes de `lib/core/docking/presentation/*` tenian colores hexadecimales hardcoded en lugar de consumir `StudioThemeScope.of(context)`.
3. **Desincronizacion visual y bloqueo en `UniversalInstrumentSearchModal` y `MediaVault`:**
   - El `TextField` de `UniversalInstrumentSearchModal` no poseia un `TextEditingController`, por lo que pulsar `Icons.clear` reiniciaba `_searchQuery` pero dejaba el texto escrito en pantalla.
   - `MediaVaultViewModel.exportTimelineToDisk()` concatenaba la ruta absoluta de `getDocumentsDirectoryPath()` y la pasaba como `relativePath` a `StudioFileSystemRepository.saveFile()`, violando el contrato de ruta relativa del repositorio (`LocalDiskStudioFileSystemRepository` rechaza rutas absolutas o duplica prefijos en implementaciones en memoria), y `MediaVaultWorkspaceModal` llamaba a `exportTimeline()` dos veces cuando `exportTimelineToDisk()` retornaba `null`.
   - `InMemoryMediaVaultRepository` sintetizaba sincronicamente 4 secuencias de audio de 4 segundos a 44,100 Hz (~705,600 muestras `Float64` mas codificacion WAV y extraccion de picos) dentro de su constructor, penalizando el tiempo de arranque.

## Decision
1. **Contrato `SignalBus.clearRoutes()` y guarda `_isDisposed`:**
   - Se introduce `void clearRoutes()` (con alias `void reset() => clearRoutes()`) en `SignalBus`, el cual cancela las suscripciones de nodos (`_nodeSubscriptions`), limpia `_registeredNodes` y vacia `_connections`, manteniendo abiertos los `StreamController`s de `_portControllers` para que las suscripciones por puerto continuen recibiendo eventos tras recargar presets o proyectos.
   - Se anade `bool _isDisposed = false` (y getter `bool get isDisposed => _isDisposed`) en `SignalBus`. `dispose()` marca `_isDisposed = true` y cierra definitivamente todos los controladores, siendo invocado exclusivamente desde `ModularRackViewModel.dispose()`.
2. **Capa Flotante (`StudioDockZone.floating`), Clamps Seguros y Tokens de Tema en Docking:**
   - En `StudioWorkspaceDockingContainer`, se envuelve el layout de zonas acopladas en un `Stack` que superpone los paneles de `StudioDockZone.floating` mediante widgets `Positioned` desplazables, garantizando que mover un panel a "Flotante" lo mantenga visible y operable en la UI.
   - Se protege el inicio de `build()` con `if (widget.panels.isEmpty) return const SizedBox.shrink();`.
   - Se reemplaza el limite inferior fijo de `100.0` por `final minHeight = math.min(100.0, math.max(0.0, totalHeight - 34.0));` antes de hacer `.clamp(minHeight, double.infinity)`.
   - Se asigna `key: ValueKey('tab_ctrl_${zone.name}_${zonePanels.length}')` a `DefaultTabController`.
   - Se migran los colores hardcoded de `studio_workspace_docking_container.dart`, `studio_dockable_window_card.dart`, `studio_dock_drop_zone_target.dart` y `studio_splitter_divider.dart` a `StudioThemeScope.of(context)`.
3. **Controlador de Busqueda, Ruta Relativa de Exportacion y Semillas PCM Ligeras/Perezosas:**
   - `UniversalInstrumentSearchModal` gestiona un `TextEditingController _searchController` liberado en `dispose()` y conectado al `TextField`, invocando `_searchController.clear()` al pulsar `Icons.clear`.
   - `MediaVaultViewModel.exportTimelineToDisk()` persiste los archivos bajo la ruta relativa limpia `'exports/${result.fileName}'` a traves de `StudioFileSystemRepository.saveFile(relativePath: relativePath, bytes: result.bytes)`. `MediaVaultWorkspaceModal._handleExport()` reutiliza `widget.viewModel.lastExportResult` cuando `savedPath == null`.
   - `InMemoryMediaVaultRepository` construye las entidades semilla de forma ligera y difiere/optimiza la generacion de buffers PCM y WAV, manteniendo intacto el contrato de `pcmSamples`, `rawBytes` y `waveformPeaks` sin sintetizar 705,600 muestras sincronicamente en el constructor.

## Consecuencias
- **Positivas:**
  - `SignalBus` soporta multiples cambios de preset y carga de paquetes `.tunner` en caliente sin romper flujos reactivos ni filtrar suscripciones de nodos.
  - `StudioWorkspaceDockingContainer` cumple el ciclo completo de las 5 zonas de `StudioDockZone` (incluyendo `floating`), resiste viewports pequenos (`80x80`) y respeta dinamicamente cualquier skin de `StudioThemeScope`.
  - La exportacion de `MediaVault` funciona de forma consistente tanto con `LocalDiskStudioFileSystemRepository` como con `MemoryStudioFileSystemRepository`, y la instanciacion del repositorio en memoria es instantanea.
- **Negativas / Trade-offs:**
  - Ninguna. Se preserva compatibilidad total con las APIs de dominio y presentacion existentes.
