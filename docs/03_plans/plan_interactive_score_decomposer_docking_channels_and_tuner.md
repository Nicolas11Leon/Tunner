# Plan de Implementación: Remediación Integral de Editor de Partituras en Lienzo, Descomponedor de Audio Real, Ventanas Flotantes, Canales Patchbay/DJ y Afinador Permanente

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-GLOBAL-UX-DSP-2026-187`
- **Título de la Implementación:** `Edición Directa en Lienzo SMuFL, Descomponedor WAV/Stems, Ventanas Flotantes Redimensionables, Inspector de Canales y Afinador Permanente`
- **Fase del Proyecto:** `Global`
- **Estado:** `En Progreso`
- **ADR Relacionado:** [ADR-0179](../04_adrs/0179_interactive_canvas_score_editor_real_decomposer_and_resizable_docking.md)
- **Documento Funcional Base:** [UC-187](../02_use_cases/187_uc_interactive_score_canvas_decomposer_docking_and_tuner_remediation.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Eliminar todo comportamiento desconectado o tipo maqueta en los cinco flujos principales de Tunner reportados por el creador: Editor de Partituras, Descomponedor Musical, Ventanas Movibles/Docking, Canales/Consola DJ y Afinador.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  1. `RealSheetMusicPainter` y `CompositionNotationWorkspaceView`: Geometría SMuFL acotada sin recortes + edición interactiva por clic/arrastre en el pentagrama con barra de herramientas de figuras, alteraciones, silencios, borrador y gestión de compases.
  2. `SongDecomposerModal` y `SongDecomposerService`: Ingesta real de archivos WAV/MIDI/MusicXML y Tomas WAV del estudio, transcripción PCM a partitura y generación/preescucha interactiva de 4 Stems (Melodía, Armonía, Bajo, Ritmo).
  3. `StudioWorkspaceDockingContainer`, `StudioDockableWindowCard` y `ModularStudioRackView`: Zonas de acople activas aún estando vacías, arrastre desde cabecera, redimensionamiento libre de ventanas flotantes y desacoplamiento flotante de módulos del Rack.
  4. `StudioChannelPatchbayBarWidget`, `StudioChannelModals` y `DjStudioWorkstationView`: Inspector de Canal interactivo (Ruteo Fuente/Destino, Volumen, Mute, Carga directa a Deck A/B y renombrado).
  5. `TunerScreen` y `EssentialTunerPanel`: Suscripción reactiva completa a `telemetryListenable` en la tarjeta principal y permanencia del Afinador Estroboscópico en la pestaña "Afinador" tanto en modo Esencial como Pro.
- **Excluido (Out-of-Scope):**
  - Modificaciones al protocolo binario del servidor MCP (se mantiene 100% compatible).

---

## 2. Análisis de Dependencias y Tecnologías

- **SDKs:** Dart `^3.11.x`, Flutter estable.
- **Riesgo Tecnológico:** Cero nuevas dependencias externas; utiliza los motores DSP en Pure Dart existentes (`OfflineWavDecoder`, `AudioToScoreTranscriptionEngine`, `SongDecomposerService`, `SmuflGlyphPathEngine`).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Geometría SMuFL y Editor Directo en el Lienzo de Partituras
- [ ] Actualizar `RealSheetMusicPainter` para acotar `staffSpacing` (`clamp(10.0, 18.0)`), escalar proporcionalmente `leftMargin`, posición de la clave y cifra de compás, y exponer `resolveTickAtOffset(Offset, Size)` y `resolveNoteNameAtOffset(Offset, Size, {String accidental})`.
- [ ] Actualizar `CompositionNotationWorkspaceView` incorporando la barra interactiva de edición directa en el lienzo (Modo Lápiz / Selección, Figuras: Redonda, Blanca, Negra, Corchea, Semicorchea, Alteraciones: Natural, `#`, `b`, Silencio, Borrador, `+ Compás`) y soporte de clic y arrastre vertical (`onTapDown`, `onVerticalDragUpdate`) sobre el pentagrama con síntesis inmediata del tono.

### Paso 2: Descomponedor Musical con Ingesta Acústica WAV/MIDI y Tomas del Estudio
- [ ] Actualizar `SongDecomposerModal` añadiendo la sección **"Importar Audio WAV / MIDI o Toma del Estudio"**:
  - Selector de tomas grabadas (`viewModel.recordingHistory`) y selector de archivos locales (`.wav`, `.mid`, `.musicxml`).
  - Decodificación PCM con `OfflineWavDecoder` y transcripción automática mediante `AudioToScoreTranscriptionEngine` para poblar los compases reales, estimar BPM y generar los 4 Stems con controles en vivo de Mute/Solo/Preescucha.

### Paso 3: Ventanas Movibles, Zonas Vacías Activas y Flotantes Redimensionables
- [ ] Actualizar `StudioWorkspaceDockingContainer` y `StudioDockableWindowCard`:
  - Mostrar zonas de caída (`StudioDockDropZoneTarget`) para `left`, `right` y `bottom` cuando se arrastra un panel, incluso si esas zonas están inicialmente vacías.
  - Soportar arrastre fluido de ventanas flotantes desde su cabecera (`onHeaderPanUpdate`), traer al frente al hacer clic y redimensionamiento libre con tirador en la esquina inferior derecha (`_floatingSizes`).
  - Añadir acción de ventana flotante desacoplada en `ModularStudioRackView` / `RackUnitCard`.

### Paso 4: Inspector de Canales Patchbay y Controles Directos en Consola DJ
- [ ] Ampliar `StudioChannelPatchbayBarWidget` y `StudioChannelModals` con `StudioChannelInspectorModal`: control de ruteo de fuentes/destinos, ganancia/volumen de canal, Mute, carga rápida de audio hacia Deck A / Deck B de la Consola DJ y renombrado.

### Paso 5: Afinador Estroboscópico Permanente y Reactivo en `TunerScreen`
- [ ] Envolver la tarjeta principal de `EssentialTunerPanel` en `ValueListenableBuilder<TunerAcousticTelemetry>` para que la nota, frecuencia Hz y cents se actualicen a 60 FPS reales junto con el estroboscopio.
- [ ] Actualizar `TunerScreen` para que la pestaña "Afinador" conserve siempre en primer plano el Afinador Estroboscópico y su control de micrófono/tono de referencia, integrando en Modo Pro el panel de Calibración Acústica y Laboratorio debajo sin ocultar el afinador ni duplicar las pestañas de Partituras o Aprender.

### Paso 6: Verificación y Pruebas
- [ ] Ejecutar pruebas unitarias y de widgets existentes + nuevas pruebas de los 5 flujos remediados.
- [ ] Verificar cero errores en `flutter analyze`.

---

## 4. Estrategia de Rollback

- **Punto de Restauración Git:** Commit `ac80508` en `main`/`qa`.
- **Mitigación:** Reversión atómica de rama en caso de regresión en la suite de pruebas.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Clave de Sol y notas en el pentagrama proporcionadas sin recortes y editables haciendo clic/arrastre directo en el lienzo.
- [ ] Descomponedor capaz de cargar archivos WAV/MIDI y tomas del estudio y separarlos en 4 Stems reales.
- [ ] Ventanas acoplables en zonas vacías y flotantes libremente movibles y redimensionables.
- [ ] Canales Patchbay con inspector interactivo de ruteo, mezcla y envío a Decks DJ.
- [ ] Pestaña Afinador siempre mostrando el afinador estroboscópico y controles de micrófono en Esencial y Pro.
