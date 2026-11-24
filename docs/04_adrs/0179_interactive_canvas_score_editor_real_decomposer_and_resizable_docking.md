# ADR 0179: Edición Directa en Lienzo de Partituras SMuFL, Descomponedor de Audio WAV/Stems, Ventanas Flotantes Redimensionables, Inspector Patchbay y Afinador Permanente

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-187](../02_use_cases/187_uc_interactive_score_canvas_decomposer_docking_and_tuner_remediation.md)

---

## 1. Contexto

Durante la validación práctica de escritorio de Tunner v1.0.0 se identificaron cinco fricciones críticas de experiencia de usuario y acoplamiento visual:
1. **Pentagrama y Editor de Partituras:** `RealSheetMusicPainter` escalaba `staffSpacing = size.height / 14.0` sin límite superior manteniendo márgenes horizontales fijos (`26px`, `75px`), provocando que en pantallas de escritorio la clave de Sol se recortara a la izquierda. Además, el lienzo solo permitía seleccionar notas existentes pero no insertar, arrastrar o borrar notas haciendo clic directamente en el pentagrama.
2. **Descomponedor de Audio:** `SongDecomposerModal` dependía exclusivamente de entrada manual de texto en solfeo o plantillas estáticas, careciendo de un flujo directo para importar archivos WAV/MIDI o seleccionar tomas grabadas del proyecto y descomponerlas acústicamente en 4 Stems interactivos.
3. **Ventanas Movibles y Docking:** `StudioWorkspaceDockingContainer` omitía del árbol de widgets los `StudioDockDropZoneTarget` cuando las zonas laterales o inferior estaban vacías, impidiendo arrastrar ventanas hacia ellas. Asimismo, las ventanas flotantes tenían tamaño fijo (`420x300`) y capturaban `onPanUpdate` sobre toda su superficie en lugar de solo en la barra de título.
4. **Canales Patchbay y Consola DJ:** Hacer clic en un canal de `StudioChannelPatchbayBarWidget` solo abría un diálogo de renombrado, sin ofrecer controles reales de ruteo (Fuente -> Destino), volumen, ganancia, Mute/Solo ni envío directo a los Decks de la Consola DJ.
5. **Pestaña Afinador en Modo Pro:** Al cambiar a `conservatoryPro`, `TunerScreen` ocultaba por completo el `EssentialTunerPanel` (estroboscopio y micrófono) y renderizaba vistas duplicadas de otras pestañas (`Partituras`, `Aprender`).

---

## 2. Decisión

1. **Geometría SMuFL Proporcional y Edición Directa en Lienzo:**
   - Acotar `staffSpacing` en `[10.0, 18.0]` píxeles y derivar `clefX`, `timeSigX` y `leftMargin` proporcionalmente a `staffSpacing`.
   - Añadir métodos `resolveTickAndNoteAtOffset(Offset, Size)` en `RealSheetMusicPainter` y una barra de herramientas de edición directa en `CompositionNotationWorkspaceView` (Modo Escritura/Audición, figuras Redonda a Semicorchea, alteraciones `#`/`b`, Silencio, Borrador y `+ Compás`) para insertar, arrastrar verticalmente o eliminar notas con clic directo sobre el pentagrama.
2. **Ingesta y Descomposición Acústica Real en `SongDecomposerModal`:**
   - Integrar carga de archivos WAV/MIDI/MusicXML desde disco y selector directo de Tomas WAV grabadas del estudio (`viewModel.recordingHistory`), procesando el audio PCM mediante `OfflineWavDecoder` y `AudioToScoreTranscriptionEngine` para transcribir la melodía y sintetizar/separar los 4 Stems (Melodía, Armonía, Bajo, Ritmo) con previsualización y controles Mute/Solo.
3. **Zonas de Acople Siempre Activas y Ventanas Flotantes Redimensionables:**
   - Mostrar objetivos de caída (`StudioDockDropZoneTarget`) en zonas vacías durante el arrastre o mediante bordes de acoplamiento activos.
   - Restringir el arrastre de ventanas flotantes a su barra de cabecera, añadir redimensionamiento libre con tirador en esquina inferior derecha (`_floatingSizes`) y permitir desacoplar módulos del Rack Modular en ventanas flotantes.
4. **Inspector y Mezclador de Canal en `StudioChannelPatchbayBarWidget`:**
   - Reemplazar la acción de clic simple en las píldoras de canal por un **Inspector & Mezclador de Canal** completo con fader de nivel, Mute, conexión interactiva de fuentes/destinos del Patchbay, carga rápida de pistas hacia Decks A/B de la Consola DJ y opción de renombrado.
5. **Unificación de la Pestaña Afinador (`TunerScreen`):**
   - Mantener el panel del Afinador Estroboscópico y la tarjeta de Nota/Hz/Cents (suscrita en tiempo real a `telemetryListenable`) siempre visibles en la pestaña "Afinador", mostrando en Modo Pro el panel de Calibración Acústica y Laboratorio debajo del afinador en lugar de reemplazarlo.

---

## 3. Consecuencias

- **Positivas:** Todas las funciones principales responden con manipulación directa, audio real y geometría tipográfica impecable en cualquier resolución de escritorio o móvil, sin pantallas duplicadas ni flujos que parezcan mocks.
- **Mantenibilidad:** Se preservan todos los contratos de Clean Architecture (`lib/domain` 100% Pure Dart) y la compatibilidad hacia atrás con la suite de pruebas existente.
