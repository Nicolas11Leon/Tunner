# Especificación Técnica y HCI: Segunda Auditoría UI/UX y Manipulación Directa (Ola 7: US-UX-11 a US-UX-18)

Este documento define la especificación técnica, matemática y de Interacción Humano-Computadora (HCI) para la **Ola 7** del proyecto **Tunner**, enfocada en eliminar brechas de sincronización reactiva, fricciones de manipulación directa sobre lienzos musicales, estados pasivos en módulos DSP y carencias cromáticas/comparativas detectadas durante la segunda auditoría integral UI/UX.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-UI-2026-203`
- **Título Oficial:** `Especificación Técnica de la Segunda Auditoría UI/UX: Manipulación Directa, Sincronización Reactiva y Cobertura Cromática Completa (US-UX-11 a US-UX-18)`
- **Estado:** `Draft`
- **Fecha de Creación:** `2026-11-26`
- **Última Modificación:** `2026-11-26`
- **Fase Asociada:** `Fase 2 / Ola 7 Segunda Auditoría UI/UX`
- **Autor / Revisor Principal:** `Nicolás León`

---

## 1. Resumen Ejecutivo (Executive Summary)

Tras consolidar la ergonomía base (Ola 5) y los puentes de hiperconectividad (Ola 6), la segunda auditoría de experiencia de usuario sobre el código fuente de **Tunner** identificó ocho puntos de fricción directa en la interfaz operativa: desincronización parcial del bucle A-B en navegación manual y entre `TunnerThemePalette` y `StudioThemeController` (`US-UX-11`), ausencia de previsualización fantasma SMuFL al pasar el cursor por el pentagrama (`US-UX-12`), un inspector contextual derecho y panel de herramientas laterales con contenido repetitivo o poco específico por pestaña (`US-UX-13`), sobrecarga de chips en el espacio de aprendizaje junto a tarjetas pasivas en el laboratorio acústico (`US-UX-14`), componentes de rack con colores fijos y módulos `djConsole`/`stemMixer` reducidos a texto estático (`US-UX-15`), ausencia de lanzador directo de bóveda, presets de stems en 1 clic y snap magnético central en el crossfader DJ (`US-UX-16`), omisión de botones inline de pre-escucha y regla de scrubbing temporal sobre la línea de tiempo en la Bóveda Multimedia (`US-UX-17`), y finalmente limitación a 7 tónicas diatónicas en el Tutor Armónico sin comparador directo JI vs 12-TET ni conmutador de comparación A/B en Vocal AutoTune (`US-UX-18`).

La Ola 7 resuelve estas ocho deficiencias manteniendo una arquitectura 100% local (Offline-First), separación estricta de capas (Clean Architecture), cero bucles `busy-waiting` y compatibilidad retroactiva con las suites de pruebas existentes.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema

1. **Desincronización de Transporte A-B y Temas (`US-UX-11`):**
   - `TunerViewModel` delega la reproducción de partitura a `ScorePlaybackCoordinator` (`lib/features/sheet_music/domain/score_playback_coordinator.dart`), pero `TunerViewModel.nextMeasure()` y `previousMeasure()` aplican aritmética modular global sobre `totalMeasures` ignorando el rango `[loopStartMeasureIndex, loopEndMeasureIndex]` activo. Además, `CompositionNotationWorkspaceView` mantiene copias locales (`_loopMeasureA`, `_loopMeasureB`, `_isAbLoopActive`) que pueden divergir ante reinicios o cambios de obra.
   - Paralelamente, `StudioThemeSwitcher` (`lib/core/design_system/atoms/studio_theme_switcher.dart`) actualiza únicamente `StudioThemeController` (`StudioThemeScope`), sin reflejar el cambio en `TunerViewModel.currentPalette` (`TunnerThemePalette`), provocando que `RealSheetMusicPainter` y `TunerScreen` conserven la paleta anterior hasta un cambio externo.
2. **Edición a Ciegas sobre Pentagrama SMuFL (`US-UX-12`):**
   - `CompositionNotationWorkspaceView` envuelve `RealSheetMusicPainter` en un `MouseRegion` sin manejadores `onHover` ni `onExit`, impidiendo previsualizar altura diatónica (según `InstrumentClef`) y subdivisión temporal antes de pulsar.
3. **Contexto Estático en Inspector y Modo Herramientas (`US-UX-13`):**
   - `MainAppShell._buildContextualRightInspectorContent` fija botones genéricos (`A4 = 442 Hz`, `A4 = 440 Hz`, `Activar Dron`) en todas las pestañas y ofrece contenido pasivo en las pestañas 1, 3, 4 y 5. En paralelo, el botón `'Herramientas'` (`sidebar_mode_tools_btn`) de `StudioDesktopAppShell` vuelve a mostrar el árbol de documentos del proyecto cuando `customSidebarExplorer` está activo.
4. **Entropía Visual en Práctica y Laboratorio (`US-UX-14`):**
   - `LearningPracticeWorkspaceView` apila verticalmente todos los bloques y 9 chips horizontales simultáneos. `ProductionAcousticLabWorkspaceView` obliga a abrir modales para acciones frecuentes como enviar un acorde detectado al Dron o conmutar AutoTune.
5. **Módulos Pasivos y Controles No Tokenizados en Rack (`US-UX-15`):**
   - `StudioRotaryKnob` y `RackUnitCard` emplean constantes hexadecimales hardcodeadas, y `RackModuleType.djConsole` / `stemMixer` solo muestran `_buildStudioAudioModuleSummary`.
6. **Fricción Operativa en Consola DJ (`US-UX-16`):**
   - `DjStudioWorkstationView` carece de acceso directo en 1 clic a la Bóveda Multimedia desde la estación, no agrupa presets de stems (`Acapella`, `Instrumental`, `Solo Drums`, `Reset`) y su `Slider` de crossfader no aplica zona muerta magnética en `0.0`.
7. **Controles Ocultos en Bóveda Multimedia (`US-UX-17`):**
   - `MediaVaultViewModel` ya implementa `togglePreviewAsset(assetId)` y `seekPlayheadMs(targetMs)`, pero `MediaVaultWorkspaceModal` no renderiza el botón de pre-escucha en cada fila ni una regla interactiva de scrubbing en el secuenciador.
8. **Restricción Diatónica y Falta de Comparación A/B (`US-UX-18`):**
   - `HarmonicTutorModal._standardRoots` solo lista 7 notas naturales (`Do` a `Si`), excluyendo las 5 tónicas cromáticas restantes y carece de conmutación directa JI vs 12-TET. `VocalAutoTuneModal` no incluye un botón rápido de Bypass / Comparación A/B para contrastar voz cruda frente a voz corregida.

### 2.2 Fundamento Teórico / Físico / Musical

1. **Invariante de Bucle A-B en Navegación y Transporte (`US-UX-11`):**
   Dado $N = \text{totalMeasures} \ge 1$ y un bucle activo $[M_A, M_B]$ con $0 \le M_A \le M_B < N$, la longitud efectiva del ciclo es $L = M_B - M_A + 1$. La navegación paso a paso dentro del bucle sigue:
   $$m_{\text{next}} = M_A + ((m - M_A + 1) \bmod L), \quad m_{\text{prev}} = M_A + ((m - M_A - 1 + L) \bmod L)$$
2. **Proyección Espacial en Pentagrama SMuFL (`US-UX-12`):**
   Sea $y_{\text{line1}}$ la ordenada de la primera línea del pentagrama y $s$ el espaciado entre líneas (`_computeStaffSpacing`). La distancia en semiespacios diatónicos respecto a la línea 1 para una coordenada $y$ del puntero es:
   $$\text{step} = \text{round}\left(\frac{y_{\text{line1}} - y}{s / 2}\right)$$
   Sumando $\text{step}$ al escalón diatónico de referencia de la clave (`treble`: $E_4 = 30$, `alto`: $F_3 = 24$, `bass`: $G_2 = 18$) se obtiene la octava $\lfloor \text{absStep} / 7 \rfloor$ y la nota diatónica $\text{absStep} \bmod 7$.
3. **Zona Muerta Magnética en Crossfader DJ (`US-UX-16`):**
   Para una posición cruda $x \in [-1.0, 1.0]$ y un radio de enganche $\delta = 0.04$ (`deadzone`):
   $$x_{\text{snapped}} = \begin{cases} 0.0 & \text{si } |x| \le \delta \\ \text{clamp}(x, -1.0, 1.0) & \text{en caso contrario} \end{cases}$$
4. **Conversión Espacial-Temporal en Regla de Scrubbing (`US-UX-17`):**
   Para un desplazamiento horizontal $x \ge 0$ sobre la pista de tiempo con escala $p = \text{pixelsPerSecond}$ ($\text{px/s}$), el instante temporal sin cuantizar es:
   $$t_{\text{ms}} = \text{round}\left(\frac{x}{p} \cdot 1000\right)$$
   Si `snapToBeatgrid` está activo a un tempo $B$ ($\text{BPM}$), la duración de un pulso en milisegundos es $\Delta_{\text{beat}} = \frac{60000}{B}$, cuantizando al pulso más cercano:
   $$t_{\text{snap}} = \text{round}\left(\frac{t_{\text{ms}}}{\Delta_{\text{beat}}}\right) \cdot \Delta_{\text{beat}}$$
5. **Comparación Cromática de 12 Tónicas e Intonación Justa vs 12-TET (`US-UX-18`):**
   Las 12 tónicas cromáticas de referencia en la octava central ($C_4 = 60$ a $B_4 = 71$) responden a:
   $$f_m = f_{A_4} \cdot 2^{(m - 69)/12}, \quad m \in \{60, 61, \dots, 71\}$$
   Para un rol armónico con razón justa $r = p/q$, la desviación estructural entre Entonación Justa (JI) y Temperamento Igual de 12 tonos (12-TET) a $k$ semitonos sobre la tónica es:
   $$\Delta_{\text{JI}-\text{12TET}} = 1200 \cdot \log_2\left(\frac{p}{q}\right) - 100 \cdot k \quad [\text{cents}]$$

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos

- **REQ-01 (`US-UX-11` - Transporte A-B en `TunerViewModel` y Sincronía de Paletas):**
  - `TunerViewModel` expone `setAbLoopRange(int startMeasureIndex, int endMeasureIndex)`, `clearAbLoop()`, `isAbLoopActive`, `abLoopStartMeasureIndex` y `abLoopEndMeasureIndex`, sincronizados con `ScorePlaybackCoordinator`.
  - `nextMeasure()` y `previousMeasure()` respetan el rango $[M_A, M_B]$ cuando el bucle está activo.
  - `CompositionNotationWorkspaceView` consume directamente el estado A-B de `TunerViewModel` (eliminando desincronización local) y `StudioThemeController` sincroniza bidireccionalmente sus presets con `TunerViewModel.currentPalette` y `activeStudioThemeId`.

- **REQ-02 (`US-UX-12` - Nota Fantasma SMuFL en Hover sobre Pentagrama):**
  - `RealSheetMusicPainter` expone `resolveNoteAtOffset(Offset localOffset, Size size, {int quantizeTicks = 4})` y pinta una nota fantasma SMuFL (`ghostNoteName`, `ghostTick`, `ghostDurationTicks`, `ghostIsRest`) a baja opacidad ($\alpha \approx 0.42$) con líneas adicionales si excede el pentagrama.
  - `CompositionNotationWorkspaceView` captura `onHover` y `onExit` en `MouseRegion`, actualiza el badge informativo `Key('score_ghost_note_badge')` y borra la nota fantasma al retirar el puntero.

- **REQ-03 (`US-UX-13` - Inspector Contextual Tab-Aware y Panel Lateral de Herramientas):**
  - `MainAppShell` construye el contenido del Inspector Contextual Derecho adaptado exclusivamente a la pestaña activa (`0..5`), eliminando acciones globales estáticas cuando no corresponden al flujo activo.
  - `StudioDesktopAppShell` añade `Widget? customSidebarTools` para mostrar un panel dedicado de herramientas (`Key('sidebar_tools_panel')`) cuando `_sidebarMode == 'tools'`, separado del explorador de archivos del proyecto (`_sidebarMode == 'explorer'`).

- **REQ-04 (`US-UX-14` - Jerarquía en 3 Etapas en Aprendizaje y Puentes Inline en Laboratorio):**
  - `LearningPracticeWorkspaceView` organiza sus controles en 3 etapas claras (`Key('learning_stage_1_tune_listen')`, `Key('learning_stage_2_guided_practice')`, `Key('learning_stage_3_evaluate_review')`) con selector de enfoque o secciones colapsables.
  - `ProductionAcousticLabWorkspaceView` añade botones de acción directa sin modal: envío de acorde detectado al Dron (`Key('lab_inline_chord_to_drone_btn')`), conmutador inline de Vocal AutoTune (`Key('lab_inline_autotune_toggle_btn')`) y selector rápido de tónica de temperamento (`Key('lab_inline_root_key_selector')`).

- **REQ-05 (`US-UX-15` - Módulos Vivos en Rack y Tokenización de `StudioRotaryKnob`):**
  - `StudioRotaryKnob` consume `StudioThemeScope.of(context)` para pista inactiva, etiquetas y texto de valor (preservando `activeColor` opcional).
  - `RackUnitCard` reemplaza colores fijos por `StudioDesignTokens`, corrige la clave mostrada en `_buildScoreNotationContent` usando `tuner.activeInstrument.clef.displayName` e implementa interfaces en vivo para `RackModuleType.stemMixer` (`Key('rack_stem_mixer_live_panel')`) y `RackModuleType.djConsole` (`Key('rack_dj_console_live_panel')`).

- **REQ-06 (`US-UX-16` - Lanzador de Bóveda, Presets de Stems y Snap Central de Crossfader DJ):**
  - `DjStudioWorkstationView` incorpora un lanzador directo a la Bóveda Multimedia (`Key('dj_open_media_vault_launcher_btn')`), presets de aislamiento de stems en 1 clic por deck (`Acapella`, `Instrumental`, `Drums Only`, `Reset`) y snap magnético en `0.0` (`±0.04`) más botón de centrado inmediato `Key('dj_crossfader_center_snap_btn')`.

- **REQ-07 (`US-UX-17` - Pre-escucha Inline y Regla de Scrubbing en Bóveda Multimedia):**
  - Cada fila de activo en `MediaVaultWorkspaceModal` expone `Key('vault_asset_preview_btn_${asset.id}')` enlazado a `MediaVaultViewModel.togglePreviewAsset(asset.id)`.
  - El secuenciador multi-pista incorpora la regla interactiva `Key('timeline_scrub_ruler')` en su franja superior que traduce clics y arrastres horizontales a `MediaVaultViewModel.seekPlayheadMs(...)`, reflejándose inmediatamente en `TimelineArrangementPainter`.

- **REQ-08 (`US-UX-18` - 12 Tónicas Cromáticas, Comparador JI vs 12-TET y Bypass A/B en AutoTune):**
  - `HarmonicTutorModal` expone las 12 tónicas cromáticas (`C4` a `B4`) y un selector/comparador visual y auditivo `JI vs 12-TET` (`Key('harmonic_tutor_ji_vs_12tet_toggle')`, `Key('harmonic_tutor_comparison_card')`).
  - `VocalAutoTuneModal` incorpora un conmutador rápido de comparación A/B (`Key('autotune_ab_compare_btn')`) que alterna entre señal cruda (Bypass) y señal cuantizada sin perder los parámetros configurados.

### 3.2 Casos de Borde y Condiciones de Error

- **Cambio de Obra con Bucle A-B Activo:** Al cargar un nuevo `SongPackage` en `TunerViewModel`, si el total de compases es menor que `abLoopEndMeasureIndex + 1`, los índices se ajustan o limpian deterministicamente sin provocar `RangeError`.
- **Hover Fuera del Área Útil de Pentagrama:** Si el puntero está en los márgenes de clave/armadura o sale del `MouseRegion`, `ghostNoteName` y `ghostTick` vuelven a `null` sin lanzar notificaciones espurias.
- **Crossfader en Transición Automix:** Durante `Smart Automix` activo, el arrastre manual o el snap central cancela o cede prioridad de forma determinista sin sobrescribir estados corruptos.
- **Bóveda Sin `MediaVaultViewModel` en Pruebas Aisladas de DJ:** Si `DjStudioWorkstationView` se monta sin `MediaVaultViewModel` en el árbol `Provider`, `dj_open_media_vault_launcher_btn` crea o recibe un callback/instancia segura sin fallar por `ProviderNotFoundException`.
- **Pre-escucha de Activos No Audio en Bóveda:** Si un activo es de tipo `score` o `midi` sin `pcmSamples`, `togglePreviewAsset` sintetiza o notifica estado informativo sin excepciones.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (Domain Layer)

- `ScorePlaybackCoordinator` (`lib/features/sheet_music/domain/score_playback_coordinator.dart`): Conserva la autoridad sobre el rango `[loopStartMeasureIndex, loopEndMeasureIndex]` y expone cálculo seguro de paso siguiente/anterior dentro de bucle.
- `DjStemPreset` (`lib/features/dj_console/domain/dj_stem_isolation_entity.dart`): Enumeración pura con configuraciones predefinidas de aislamiento (`acapella`, `instrumental`, `drumsOnly`, `fullMix`).
- `JustIntonationCalculator` & `HarmonicRole` (`lib/features/harmonic_tutor/domain/`): Provee cálculo puro de frecuencias objetivo en JI y 12-TET para las 12 tónicas cromáticas y el conmutador de comparación de referencia.
- `AutoTuneConfigEntity` (`lib/features/vocal_autotune/domain/autotune_config_entity.dart`): Añade soporte inmutable de `isBypassed` (comparación A/B) preservando `retuneSpeedMs`, `scaleType` y `rootNoteIndex`.

### 4.2 Capa de Infraestructura / Datos (Data Layer)

- Sin dependencias externas ni de red; toda síntesis de audio de pre-escucha, comparación JI/12-TET y renderizado de timeline se ejecuta localmente en memoria o mediante los servicios `IAudioSynthesizerService` y `IStudioAudioEngine` existentes.

### 4.3 Capa de Presentación (Presentation Layer)

- `TunerViewModel` + `StudioThemeController`: Puente reactivo bidireccional sin ciclos infinitos (`_isSyncingTheme`) y métodos A-B sincronizados.
- `RealSheetMusicPainter` + `CompositionNotationWorkspaceView`: Hit-testing inverso en hover, renderizado SMuFL fantasma y badge de previsualización.
- `StudioDesktopAppShell` + `MainAppShell`: Slot `customSidebarTools` y renderizado *tab-aware* completo en el Inspector Contextual Derecho.
- `LearningPracticeWorkspaceView` + `ProductionAcousticLabWorkspaceView`: Reestructuración en 3 etapas y controles inline.
- `StudioRotaryKnob` + `RackUnitCard`: Tokenización `StudioDesignTokens` y paneles vivos para `stemMixer` y `djConsole`.
- `DjConsoleViewModel` + `DjStudioWorkstationView`: Presets de stems, lanzador de Bóveda y snap magnético de crossfader.
- `MediaVaultWorkspaceModal` + `TimelineArrangementPainter`: Botón de preview inline por activo y regla superior interactiva con marcas de segundos/compases.
- `HarmonicTutorModal` + `VocalAutoTuneModal`: Selector cromático de 12 tónicas, tarjeta comparadora JI vs 12-TET y botón A/B Bypass.

---

## 5. Criterios de Rendimiento y Benchmarking

- **Latencia Visual Objetivo:** $\le 8.3\text{ ms}$ por frame (120 FPS) en el repintado de la nota fantasma SMuFL (`RealSheetMusicPainter`) y en el scrubbing del timeline (`TimelineArrangementPainter`).
- **Consumo de CPU:** Cero bucles `busy-waiting`; el hover y el scrub solo disparan repintados cuando cambia la celda cuantizada `(ghostTick, ghostNoteName)` o el milisegundo de `playheadMs`.
- **Consumo de Memoria:** Sin asignaciones de buffers PCM en `paint()`; los `Path` SMuFL de la nota fantasma reutilizan la caché inmutable de `SmuflGlyphPathEngine`.

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] `test/features/tuner/us_ux_11_ab_loop_transport_and_theme_sync_test.dart`: Validación de `nextMeasure`/`previousMeasure` dentro de bucle A-B, sincronización en `CompositionNotationWorkspaceView` y bidireccionalidad `StudioThemeController` <-> `TunerViewModel`.
- [ ] `test/features/workspaces/us_ux_12_smufl_ghost_note_hover_preview_test.dart`: Validación de `resolveNoteAtOffset`, renderizado de nota fantasma en hover y limpieza en `onExit`.
- [ ] `test/core/design_system/us_ux_13_tab_aware_inspector_and_sidebar_tools_test.dart`: Validación de contenido específico por pestaña en Inspector Derecho y alternancia `Explorer` vs `Herramientas` en `StudioDesktopAppShell`.
- [ ] `test/features/workspaces/us_ux_14_three_stage_learning_and_lab_inline_bridges_test.dart`: Validación de las 3 etapas en `LearningPracticeWorkspaceView` y los puentes inline en `ProductionAcousticLabWorkspaceView`.
- [ ] `test/features/modular_rack/us_ux_15_live_rack_modules_and_tokenized_knob_test.dart`: Validación de `StudioRotaryKnob` con `StudioDesignTokens` y paneles vivos `rack_stem_mixer_live_panel` y `rack_dj_console_live_panel`.
- [ ] `test/features/dj_console/us_ux_16_dj_vault_launcher_stem_presets_and_crossfader_snap_test.dart`: Validación de lanzador de bóveda, presets de 4 stems y snap magnético central en `0.0`.
- [ ] `test/features/media_vault/us_ux_17_vault_inline_preview_and_timeline_scrub_test.dart`: Validación de botón inline de pre-escucha por activo y scrub interactivo en `timeline_scrub_ruler`.
- [ ] `test/features/harmonic_tutor/us_ux_18_chromatic_roots_ji_compare_and_autotune_ab_test.dart`: Validación de 12 tónicas cromáticas, comparación JI vs 12-TET y conmutador Bypass A/B en `VocalAutoTuneModal`.

---

## 7. Referencias Técnicas y Bibliografía

1. *W3C Music Notation Community Group - Standard Music Font Layout (SMuFL) Specification.*
2. *Hick, W. E. (1952). On the rate of gain of information. Quarterly Journal of Experimental Psychology.*
3. *Duff, C. (2000). Just Intonation Explained & Helmholtz Consonance / Acoustic Beating Theory.*
4. *Steinberg Dorico, Ableton Live & Pioneer Rekordbox Direct Manipulation Ergonomic Patterns.*
