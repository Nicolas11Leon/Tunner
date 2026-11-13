# ADR 0057: Arquitectura de Transcripcion Polifonica Mic-to-Score en Tiempo Real

## Estado
Aprobado (Approved) - 2026-11-11

## Contexto
El motor de transcripción acústica en vivo de Tunner (`LiveTranscriptionEngine`) estaba limitado a flujos monofónicos: un frame de micrófono generaba una sola nota fundamental aislada calculada por el algoritmo MPM. Cuando un músico toca un instrumento polifónico (guitarra, piano, cuarteto de cuerdas o ensamble), el detector monofónico confunde la fundamental con el bajo o con la frecuencia media dominante, saltando erráticamente de octava e imposibilitando transcribir acordes, dobles cuerdas o polifonía real.
Por otra parte, Tunner ya cuenta con `PolyphonicMultiToneDetector` y `PolyphonicChordRecognizer`, los cuales aíslan voces simultáneas mediante tamices armónicos pero no disponían de un puente directo hacia el árbol de partituras (`ScoreTree`).

## Decision
1. **Actualización de la Validación Métrica de `MeasureEntity`:**
   - Modificar la propiedad `isValidMeasure` en `lib/features/sheet_music/domain/score_tree.dart`.
   - En lugar de sumar linealmente las duraciones de todas las notas (lo que invalida compases con acordes donde varias notas comparten inicio), calcular la unión de sub-ticks únicos ocupados en el intervalo del compás. De este modo, un acorde con 3 notas de 4 ticks en el tick 0 ocupa los sub-ticks [0, 1, 2, 3], preservando la validez del compás de forma compatible tanto con melodías monofónicas como con acordes densos.
2. **Creación del Servicio de Dominio `PolyphonicTranscriptionEngine`:**
   - Ubicado en `lib/features/transcription/domain/polyphonic_transcription_engine.dart`.
   - Consume listas de notas polifónicas detectadas (`List<PolyphonicPitchEntity>` o nombres de notas simultáneas).
   - Acumula estabilidad en un candidato de acorde (`PolyphonicChordCandidate`).
   - Al detectarse un cambio de acorde o silencio, cuantiza la duración del cluster e inserta las notas con el mismo `startTick` en el compás activo de `SongPackage`.
3. **Orquestación en `TunerViewModel`:**
   - Incorporar `bool _isPolyphonicTranscriptionActive`.
   - Método `togglePolyphonicLiveTranscription()`.
   - Durante el procesamiento de búferes PCM en modo polifónico, el resultado de `PolyphonicMultiToneDetector.detectFromSamples()` alimenta al `PolyphonicTranscriptionEngine`, actualizando reactivamente la partitura activa.

## Consecuencias

### Positivas
- **Transcripción Armónica Realista:** Los guitarristas y pianistas pueden transcribir progresiones de acordes reales al pentagrama directamente desde el micrófono.
- **Retrocompatibilidad Absoluta:** La actualización de `MeasureEntity.isValidMeasure` no rompe ningún test ni partitura monofónica existente; extiende la capacidad del árbol para soportar polifonía.
- **Rendimiento Óptimo:** La cuantización rítmica opera en tiempo determinista $O(K)$ por frame (donde $K \le 6$ voces simultáneas).

### Negativas / Mitigaciones
- **Complejidad de Glifos en Acordes Densos:** Dibujar 5 notas simultáneas requiere ordenamiento vertical estricto para evitar colisiones de cabezas de nota.
  *Mitigación:* El renderizador vectorial `RealSheetMusicPainter` ya agrupa notas por `startTick` y ordena de grave a agudo.
