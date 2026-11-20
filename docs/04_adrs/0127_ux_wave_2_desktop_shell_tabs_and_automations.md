# ADR 0127: Remediacion de Navegacion en Shell Desktop, Carga de Archivos y Automatizaciones Reales

## Estado
Aprobado

## Contexto
Durante la auditoria forense de integracion y experiencia de usuario en Linux Desktop, se detectaron deficiencias estructurales en el shell de aplicacion:
1. `StudioWorkspaceTabBar` definia unicamente 4 pestanas y asignaba de forma incorrecta el indice 0 a 'Aprender' (en lugar de 'Inicio'), provocando que las herramientas de Afinador (1) y Aprender (2) fueran inaccesibles o confusas desde la barra superior de pestanas.
2. El menu `Window` del shell de escritorio omitia por completo la Consola DJ (Pestana 5) y apuntaba el Metronomo al Dashboard de Inicio.
3. El metodo `_handleOpenFile` en `MainAppShell` no deserializaba los archivos seleccionados en el explorador VS Code (`.tunner`, `.tnpreset`, `.tnt`, `.tndj`), limitandose a mostrar un `SnackBar` informativo sin modificar los ViewModels.
4. Las plantillas de creacion rapida de `HomeDashboardScreen` navegaban de pestana sin aplicar los presets ni cargar los temas correspondientes.
5. El menu `Guardar Estado de Sesion` no invocaba `viewModel.savePersistedState()`.
6. En `Dual Split View`, la vista secundaria estaba fija a `ModularStudioRackView`, impidiendo el uso util de la pantalla dividida si el usuario ya se encontraba en el Rack.
7. Los modales `StudioCustomizationsModal` y `StudioAutomationsModal` funcionaban como stubs visuales desconectados de la logica interna de audio.

## Decision
1. **Normalizacion Canónica de Pestañas (0..5):**
   Actualizar `StudioWorkspaceTabBar` y el menu `Window` para exponer formalmente las 6 vistas:
   - `0`: Inicio & Dashboard de Rendimiento
   - `1`: Afinador Estroboscópico de Ultra Precisión
   - `2`: Conservatorio & Tutor de Compás
   - `3`: Rack Modular de Estudio & Efectos DSP
   - `4`: Biblioteca & Editor de Partituras SMuFL
   - `5`: Consola DJ Studio & Mezclador 4-Stems
2. **Carga Real en el Explorador de Archivos:**
   Implementar en `_handleOpenFile` el parseo real del contenido (`file.payload`):
   - `.tunner`: Deserializar paquete con `TunnerProjectSerializer` o decodificar MusicXML / JSON y cargar en `viewModel.loadSongPackage(...)`.
   - `.tnpreset`: Extraer afinacion de referencia en Hz y temperamento, aplicandolos a `viewModel.setReferencePitch(...)`.
   - `.tnt`: Deserializar configuracion modular y asignarla a `_modularRackViewModel`.
   - `.tndj`: Cargar preset DJ o pista curada en `_djConsoleViewModel`.
3. **Plantillas Funcionales:** Configurar en `HomeDashboardScreen` las acciones previas de calibracion, carga de audio y ruteo a DJ.
4. **Persistencia Activa:** Llamar a `viewModel.savePersistedState()` en `onMenuSaveWorkspace` y mostrar confirmacion fidedigna.
5. **Selector de Marco Secundario:** Incorporar estado `_secondaryViewMode` en `StudioDesktopAppShell` / `MainAppShell` para alternar entre Rack Modular, Afinador, Espectrograma o Metronomo en la vista dividida.
6. **Automatizaciones Reales:** Conectar `StudioAutomationsModal` para que la rampa programe un `Timer` real o escuche compases para subir +2 BPM cada 4 compases de reproduccion, y enlazar `StudioCustomizationsModal` a `viewModel.setPitchAlgorithm(...)`.
7. **Sincronizacion de Temas:** Asegurar que `StudioThemeController` comunique los cambios de paleta a `viewModel.setPaletteById(...)`.

## Consecuencias
- **Positivas:** El flujo de trabajo del shell opera como una estacion de trabajo digital autentica, eliminando disparidades entre lo visual y el estado en memoria.
- **Negativas / Mitigaciones:** La carga de proyectos pesados desde el explorador debe ejecutarse con manejo de excepciones para proteger la interfaz ante archivos corruptos o vacios.
