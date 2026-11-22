# ADR-0159: Cableado Integral de MediaVault, Interaccion Timeline X-Offset y Exportadores Canonicos

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-5.4 (EPIC-05)
- **Issue:** #161

## Contexto

`DjConsoleModal` instanciaba `MediaVaultViewModel` sin servicios de I/O, `MainAppShell` dejaba `onDispatchToTool` desconectado, el timeline ignoraba `details.offset`, `moveClip` no estaba conectado a gestos, `waveformPeaks` no se renderizaba, faltaba `track_sampler_sfx` en el menu contextual y `UniversalMediaIoService` exportaba MIDI/MusicXML/ABC vacios o hardcodeaba BPM/Camelot en WAV.

## Decision

1. **Inyeccion completa y 5 targets de sinergia:** Reutilizar `StudioCompositionRoot.createMediaVaultViewModel()` en `DjConsoleModal` (inyectando `onDispatchToTool` en `MediaVaultViewModel` o asignandolo) y conectar los 5 `MediaSynergyTarget`s tanto en `DjConsoleModal` como en `MainAppShell`.
2. **Coordenada X real y arrastre horizontal:** Calcular `dropMs` usando `RenderBox.globalToLocal(details.offset)` descontando el ancho fijo de la cabecera (`155.0`), envolver cada clip en `GestureDetector` para invocar `vm.moveClip`, y pintar `waveformPeaks` mediante `CustomPainter`.
3. **Exportadores canonicos y analisis DSP real en `UniversalMediaIoService`:** Reutilizar `CanonicalMidiExporter`, `CanonicalMusicXmlExporter` y `CanonicalAbcExporter` construyendo un `HierarchicalScore` unificado desde las notas reales de los clips; serializar `timeline` y `rawBytesBase64` en `.tunner.json`; y estimar BPM/Camelot reales usando `BpmBeatTrackerEngine` y `DjHarmonicCamelotEngine`.

## Consecuencias

- **Positivas:**
  - Cero stubs o hardcodes en importacion/exportacion multimedia y timeline interactivo completo.
  - Reutilizacion directa de los motores canonicos de notacion y analisis armonico/ritmico ya validados.
- **Negativas / Compensaciones:**
  - `UniversalMediaIoService` ahora depende de `UniversalScoreImporterService` y los motores puros de `dj_console/domain` y `universal_importer/domain` (todas dependencias puras de dominio sin violar Clean Architecture).
