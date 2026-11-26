# Especificación Técnica y de Interacción Humano-Computadora (HCI): Excelencia UX Pro-Workstation (Ola 5: US-UX-05 a US-UX-10)

Este documento define la estructura técnica, ergonómica y arquitectónica para la Ola 5 de Excelencia UX Pro-Workstation del proyecto **Tunner**, inspirada en estándares de la industria del audio y notación musical digital (Ableton Live, Cubase, Celemony Melodyne, Steinberg Dorico, Yousician/SmartMusic, Apple Logic Pro y VS Code/Raycast).

---

## Metadatos del Documento

- **ID del Documento:** `DOC-UI-2026-197`
- **Título Oficial:** `Especificación HCI y Arquitectura de Interacción de la Estación de Trabajo Musical Profesional (US-UX-05 a US-UX-10)`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-25`
- **Última Modificación:** `2026-11-25`
- **Fase Asociada:** `Fase 2 / Excelencia UX Pro-Workstation`
- **Autor / Revisor Principal:** `Nicolás León`

---

## 1. Resumen Ejecutivo (Executive Summary)

Esta especificación formaliza seis mejoras estructurales de Interacción Humano-Computadora (HCI) en **Tunner** que eliminan la sobrecarga cognitiva por proliferación de ventanas modales, barras de acciones saturadas y herramientas desconectadas. La Ola 5 introduce un Panel Inspector Contextual Derecho junto con una barra de telemetría de ayuda viva (Hover Info View) en el shell de escritorio (`US-UX-05`), la compactación de la barra del afinador a 5 controles esenciales junto con un monitor de trazos históricos de afinación estilo Melodyne (`US-UX-06`), la consolidación del espacio de trabajo de partituras en 4 modos de tarea estilo Dorico (`Escribir`, `Reproducir`, `Mezcla Stems`, `Exportar`) más un popover rápido de notación (`US-UX-07`), el coloreado pedagógico de notas en vivo estilo Yousician con bucle de práctica de compases A-B (`US-UX-08`), una barra macro de 8 controles inteligentes estilo Logic Pro Smart Controls en el Rack Modular (`US-UX-09`) y la evolución de la Paleta de Comandos (`Ctrl+K`) hacia un buscador universal con filtros rápidos por categoría e indexación en vivo de canciones, archivos e instrumentos (`US-UX-10`).

El impacto directo en la plataforma es una reducción drástica de saltos de foco visual, preservando 60/120 FPS deterministas en el lienzo SMuFL y en los monitores DSP en tiempo real, bajo una arquitectura 100% local (Offline-First) y fiel a la separación de capas de Clean Architecture.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
En las iteraciones previas de **Tunner**, el crecimiento del catálogo funcional produjo cuatro cuellos de botella ergonómicos:
1. **Dependencia excesiva de diálogos modales bloqueantes:** Configurar el perfil acústico del afinador, las propiedades de una nota en el pentagrama o los parámetros del módulo del rack requería abrir diálogos superpuestos que ocultaban el área de trabajo principal.
2. **Saturación horizontal en barras de herramientas:** En `TunerScreen` y `CompositionNotationWorkspaceView`, más de una docena de botones y chips competían simultáneamente por la atención del músico, dificultando la lectura rápida durante la ejecución con el instrumento en mano.
3. **Ausencia de memoria visual continua de afinación y acierto por nota:** El músico disponía del valor instantáneo de desviación en cents, pero carecía de un rastro histórico de estabilidad temporal por nota (blobs de centro tonal y deriva) y de un código cromático directo sobre las cabezas de nota del pentagrama con repetición focalizada entre dos compases `[A, B]`.
4. **Fragmentación en la búsqueda y control macro:** El Rack Modular exigía desplazarse verticalmente entre tarjetas para ajustar niveles maestros, y la Paleta de Comandos (`ProCommandPaletteModal`) solo listaba acciones estáticas sin filtrar por categorías ni indexar el repertorio, los archivos del proyecto o el catálogo de instrumentos.

### 2.2 Fundamento Teórico / Físico / Musical

1. **Ley de Hick-Hyman y Reducción de Entropía Visual:**
   El tiempo de decisión $T$ ante $n$ alternativas equiprobables sigue la relación logarítmica:
   $$T = b \cdot \log_2(n + 1)$$
   Al reducir la barra principal del afinador de $n \ge 11$ acciones a $n = 5$ controles primarios y agrupar el resto en un menú de configuración junto con el Inspector Contextual Derecho, el tiempo de reacción visual del instrumentista disminuye significativamente durante la práctica en vivo.

2. **Desviación Microtonal en Cents y Ventana de Evaluación Pedagógica:**
   La desviación tonal $\Delta c$ respecto a la frecuencia temperada o microtonal objetivo $f_{\text{target}}$ se define como:
   $$\Delta c = 1200 \cdot \log_2\left(\frac{f_{\text{detected}}}{f_{\text{target}}}\right)$$
   Para el coloreado de notas en vivo (`US-UX-08`) y los blobs de afinación estilo Melodyne (`US-UX-06`), el clasificador pedagógico evalúa $\Delta c$ frente a la tolerancia activa $\tau_{\text{cents}}$ (en cents):
   - **Afinado (In-Tune / Verde Semántico):** $|\Delta c| \le \tau_{\text{cents}}$
   - **Cercano / Advertencia (Warning / Ámbar Semántico):** $\tau_{\text{cents}} < |\Delta c| \le 2 \cdot \tau_{\text{cents}}$
   - **Desafinado (Out-of-Tune / Rojo Semántico):** $|\Delta c| > 2 \cdot \tau_{\text{cents}}$

3. **Aritmética Modular de Bucle de Compases A-B (`US-UX-08`):**
   Dado un rango de práctica con compás inicial $M_A$ y compás final $M_B$ tales que $0 \le M_A \le M_B < N_{\text{measures}}$, la transición del cursor de reproducción al finalizar el compás $m$ sigue la función determinista:
   $$m_{\text{next}} = \begin{cases} M_A & \text{si } \text{isLoopActive} \land m \ge M_B \\ m + 1 & \text{en caso contrario} \end{cases}$$

4. **Normalización Paramétrica en Smart Controls (`US-UX-09`):**
   Cada macro control $k \in \{1, \dots, 8\}$ mapea un parámetro físico continuo $x_k \in [x_{k,\min}, x_{k,\max}]$ a un valor normalizado adimensional $u_k \in [0, 1]$ para su representación uniforme en diales de alta precisión:
   $$u_k = \frac{\text{clamp}(x_k, x_{k,\min}, x_{k,\max}) - x_{k,\min}}{x_{k,\max} - x_{k,\min}}$$

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos

- **REQ-01 (`US-UX-05` - Inspector Contextual Derecho y Hover Info View):**
  - `StudioDesktopAppShell` incorpora un botón de alternancia `Key('btn_toggle_right_inspector')` en la barra superior y un contenedor lateral derecho colapsable `Key('studio_right_inspector_panel')` con estado inicial configurable mediante `initialRightInspectorVisible` (por defecto `false`) y métodos `toggleRightInspector()` / `isRightInspectorVisible`.
  - Cuando el inspector está abierto, renderiza contenido contextual según la herramienta activa sin lanzar diálogos modales: propiedades de calibración, referencia $A_4$, temperamento y perfil de rigor en el Afinador; propiedades de nota seleccionada, compás, armadura y transposición en Partituras; o controles rápidos de cadena DSP en Rack/DJ.
  - La barra de estado inferior incorpora `Key('studio_hover_info_view_text')`, que muestra en tiempo real la explicación funcional y el atajo de teclado del control bajo el cursor (`setHoverInfo(String? message)`), restaurando un texto guía por defecto al retirar el puntero.

- **REQ-02 (`US-UX-06` - Barra Enfocada del Afinador y Monitor Melodyne Pitch Blobs):**
  - La barra superior de `TunerScreen` (tanto en modo Essential como Conservatory Pro) expone un máximo de 5 controles primarios directos:
    1. `Key('tuner_focused_concert_pitch_btn')` (Referencia $A_4$ Hz).
    2. `Key('tuner_focused_instrument_btn')` (Selector de instrumento activo).
    3. `Key('tuner_focused_temperament_btn')` (Temperamento activo).
    4. `Key('tuner_focused_drone_btn')` (Generador de pedal armónico Drone).
    5. `Key('tuner_focused_more_menu_btn')` (`PopupMenuButton` que consolida calibración de micrófono, aislamiento, SoundFont, perfil de rigor, espectrograma, reporte y personalización).
  - Se incorpora el monitor `Key('melodyne_pitch_blobs_monitor')`, un lienzo horizontal de tiempo frente a semitonos que dibuja las últimas notas detectadas como cápsulas ("blobs") con su centro tonal y línea de deriva en cents en vivo.

- **REQ-03 (`US-UX-07` - Modos de Tarea Dorico en Partitura y Popover Rápido):**
  - `CompositionNotationWorkspaceView` reemplaza la barra saturada por un selector superior de 4 modos de tarea estilo Steinberg Dorico:
    1. `Key('score_task_mode_write_tab')` (`Escribir`): Herramientas de inserción, duración, alteraciones y compases.
    2. `Key('score_task_mode_play_tab')` (`Reproducir`): Controles de transporte, tempo, metrónomo y bucle A-B.
    3. `Key('score_task_mode_stems_tab')` (`Mezcla Stems`): Barra integrada de 4 Stems y Minus-One.
    4. `Key('score_task_mode_export_tab')` (`Exportar`): Acciones de importación/exportación MIDI/WAV/MusicXML y sintetizador polifónico.
  - Incluye el botón `Key('score_quick_popover_btn')` (accesible también vía `Shift+N`), que despliega una barra flotante compacta `Key('score_quick_notation_popover')` con `TextField` `Key('score_quick_popover_input')` para insertar notas o cambios por texto rápido (p. ej. `C4 q`, `F#5 e`, `tempo 120`, `4/4`).

- **REQ-04 (`US-UX-08` - Coloreado de Notas en Vivo Yousician y Bucle A-B):**
  - `TunerViewModel` mantiene un mapa de estado de evaluación por nota `(measureIndex, startTick) -> LiveNoteHitStatus` (`pending`, `inTune`, `warning`, `outOfTune`) alimentado por la comparación entre la nota detectada en tiempo real y la nota activa del compás.
  - `RealSheetMusicPainter` colorea cada cabeza de nota evaluada con los colores semánticos de acierto (`accentSuccess`, `accentWarning`, `accentDanger`), exponiendo el indicador `Key('yousician_live_feedback_badge')` con el resumen de precisión del pasaje.
  - El modo `Reproducir` incorpora controles de bucle A-B: `Key('score_ab_loop_toggle_btn')`, `Key('score_ab_loop_set_a_btn')`, `Key('score_ab_loop_set_b_btn')` y etiqueta `Key('score_ab_loop_range_label')`, haciendo que el avance de compás retorne automáticamente de $M_B$ a $M_A$.

- **REQ-05 (`US-UX-09` - Barra Macro Smart Controls Estilo Logic Pro en Rack Modular):**
  - `ModularStudioRackView` incorpora en su cabecera el panel colapsable `Key('rack_smart_controls_macro_bar')` con botón de alternancia `Key('rack_smart_controls_toggle_btn')`.
  - Presenta 8 controles macro unificados (`Key('smart_control_macro_0')` a `Key('smart_control_macro_7')`):
    1. `Master Gain` (Ganancia maestra del bus).
    2. `Concert A4` (Frecuencia de referencia $A_4$ en Hz).
    3. `Tempo BPM` (Tempo maestro del reloj).
    4. `Noise Gate` (Umbral de puerta de ruido en dB).
    5. `Cents Tol.` (Tolerancia pedagógica en cents).
    6. `Drone Level` (Nivel de mezcla del generador Drone).
    7. `Auto-Tune` (Intensidad de corrección vocal/instrumental).
    8. `Room Ambience` (Reverberación / ambiente de sala del sintetizador).
  - La modificación de cualquier macro sincroniza inmediatamente el estado de `ModularRackViewModel` y `TunerViewModel` sin desplazarse por la lista de módulos.

- **REQ-06 (`US-UX-10` - Paleta de Comandos Universal Unificada con Filtros de Categoría):**
  - `ProCommandPaletteModal` incorpora chips interactivos de filtrado por categoría:
    - `Key('command_palette_filter_all')` (`Todo`)
    - `Key('command_palette_filter_actions')` (`Acciones`)
    - `Key('command_palette_filter_songs')` (`Canciones`)
    - `Key('command_palette_filter_files')` (`Archivos`)
    - `Key('command_palette_filter_instruments')` (`Instrumentos`)
  - `StudioCommandCatalogBuilder.build` indexa dinámicamente, además de las acciones del sistema, todas las obras de `viewModel.curatedLibrary` y `viewModel.workspaceScores` (categoría `Canciones`), los nodos de archivo de `IStudioWorkspaceFileSystem` (categoría `Archivos`) y las definiciones de `UniversalInstrumentDefinition.all` (categoría `Instrumentos`).

### 3.2 Casos de Borde y Condiciones de Error
- **Silencio o Ruido Ambiental (Noise Gate):** Cuando `frequency <= 0`, el monitor `melodyne_pitch_blobs_monitor` congela el último trazo sin generar cápsulas espurias, y el coloreado de notas en vivo mantiene las notas futuras en estado `pending`.
- **Rango de Bucle A-B Inválido:** Si el usuario intenta fijar $M_B < M_A$, el sistema ajusta automáticamente $M_B = M_A$; si se eliminan compases dejando $M_B \ge N_{\text{measures}}$, los límites se recortan a $[0, N_{\text{measures}} - 1]$.
- **Entrada Inválida en Popover Rápido de Notación:** Si la expresión escrita en `score_quick_popover_input` no coincide con un patrón válido de nota (`[A-G][#b]?[0-8] [w|h|q|e|s]?`) ni comando de compás/tempo, el popover conserva el foco y muestra un mensaje de validación no intrusivo sin mutar la partitura.
- **Sistemas de Archivos Vacíos en la Paleta Universal:** Si `IStudioWorkspaceFileSystem` no contiene archivos importados, el filtro `Archivos` muestra un estado vacío informativo sin lanzar excepciones de puntero nulo.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (Domain Layer)
- **Entidades y Value Objects Puros:**
  - `PitchBlobTraceEntry`: Representa una cápsula histórica de afinación con `midiNote`, `noteName`, `targetFrequencyHz`, `meanCentsDeviation`, `centsTrajectory` (lista acotada de muestras), `startTimestampMs` y `durationMs`.
  - `LiveNoteHitStatus` (`pending`, `inTune`, `warning`, `outOfTune`): Enumeración pura para clasificar la precisión de cada evento de nota en el pentagrama.
  - `ScoreTaskMode` (`write`, `play`, `stems`, `export`): Enumeración de modos de tarea del espacio de trabajo de notación.
  - `SmartControlMacroSpec`: Especificación inmutable de cada uno de los 8 controles macro (`id`, `label`, `unit`, `minValue`, `maxValue`, `currentValue`, `normalizedValue`).

### 4.2 Capa de Infraestructura / Datos (Data Layer)
- No se introducen dependencias externas ni llamadas de red.
- La indexación de archivos en `StudioCommandCatalogBuilder` consume de manera síncrona y en memoria la instantánea del árbol de `IStudioWorkspaceFileSystem`, garantizando latencia sub-milisegundo al abrir `ProCommandPaletteModal`.

### 4.3 Capa de Presentación (Presentation Layer)
- **`StudioDesktopAppShell` (`lib/core/design_system/organisms/studio_desktop_app_shell.dart`):**
  - Añade soporte para `rightInspectorBuilder` / `rightInspectorWidget`, `initialRightInspectorVisible`, `toggleRightInspector()`, `setHoverInfo(String?)` y regiones `MouseRegion` en controles clave que actualizan `Key('studio_hover_info_view_text')`.
- **`TunerScreen` y `MelodynePitchBlobsMonitor` (`lib/features/tuner/presentation/`):**
  - Refactoriza la barra de acciones a los 5 controles enfocados y añade un `CustomPainter` ligero para renderizar los blobs de afinación a 60 FPS usando un buffer circular acotado (máximo 24 cápsulas visibles).
- **`CompositionNotationWorkspaceView` y `RealSheetMusicPainter` (`lib/features/workspaces/presentation/` y `lib/features/sheet_music/presentation/`):**
  - Filtra las barras secundarias según `ScoreTaskMode`, integra el popover rápido de entrada por texto, los controles de bucle A-B y el mapa de colores de acierto por nota en `RealSheetMusicPainter`.
- **`ModularStudioRackView` (`lib/features/modular_rack/presentation/`):**
  - Renderiza `rack_smart_controls_macro_bar` encima del lienzo de unidades de rack, enlazado bidireccionalmente con `ModularRackViewModel` y `TunerViewModel`.
- **`ProCommandPaletteModal` y `StudioCommandCatalogBuilder` (`lib/features/navigation/presentation/`):**
  - Añade la fila de `ChoiceChip` / `FilterChip` por categoría y amplía el constructor del catálogo para incluir canciones, archivos del proyecto e instrumentos.

---

## 5. Criterios de Rendimiento y Benchmarking

- **Latencia Visual Objetivo:** $\le 8.3\text{ ms}$ por frame (presupuesto de 120 FPS) en el repintado de `MelodynePitchBlobsMonitor` y `RealSheetMusicPainter`.
- **Consumo de CPU:** Cero bucles `busy-waiting`; todas las actualizaciones del inspector, hover info view, blobs y coloreado de notas se disparan exclusivamente por eventos de `ValueListenable` o interacciones de usuario.
- **Consumo de Memoria:** El historial de blobs de afinación está estrictamente acotado a una cola FIFO de longitud fija ($N_{\max} = 24$ cápsulas y $M_{\max} = 32$ puntos de deriva por cápsula), impidiendo el crecimiento ilimitado de memoria en sesiones largas.

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] `test/core/design_system/us_ux_05_contextual_right_inspector_and_hover_info_test.dart`: Verificación de apertura/cierre del inspector derecho, contenido contextual sin modales y actualización de `studio_hover_info_view_text`.
- [ ] `test/features/tuner/us_ux_06_focused_tuner_toolbar_and_pitch_blobs_test.dart`: Verificación del límite de 5 acciones en la barra del afinador, menú desplegable `Más` y renderizado de `melodyne_pitch_blobs_monitor`.
- [ ] `test/features/workspaces/us_ux_07_dorico_score_task_modes_and_popover_test.dart`: Verificación de conmutación entre los 4 modos de tarea (`Escribir`, `Reproducir`, `Mezcla Stems`, `Exportar`) e inserción de notas mediante `score_quick_notation_popover`.
- [ ] `test/features/workspaces/us_ux_08_yousician_live_note_coloring_and_ab_loop_test.dart`: Verificación del coloreado de cabezas de nota según precisión en cents y retorno cíclico del cursor entre los compases $M_A$ y $M_B$.
- [ ] `test/features/modular_rack/us_ux_09_logic_pro_smart_controls_macro_bar_test.dart`: Verificación de los 8 controles macro en el Rack Modular y su sincronización inmediata con el estado DSP/ViewModel.
- [ ] `test/features/navigation/us_ux_10_unified_universal_command_palette_test.dart`: Verificación de los filtros de categoría (`Todo`, `Acciones`, `Canciones`, `Archivos`, `Instrumentos`) y ejecución de elementos indexados en `ProCommandPaletteModal`.

---

## 7. Referencias Técnicas y Bibliografía

1. *W3C Music Notation Community Group - Standard Music Font Layout (SMuFL) Specification.*
2. *Hick, W. E. (1952). On the rate of gain of information. Quarterly Journal of Experimental Psychology.*
3. *Celemony Melodyne & Steinberg Dorico Human Interface Guidelines for Music Workstations.*
4. *Apple Logic Pro Smart Controls & Ableton Live Info View Ergonomic Patterns.*
