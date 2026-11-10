# ADR 0055: Arquitectura del Descomponedor de Partituras con Ensamble Virtual "Minus-One", Mezclador de Stems y Evaluacion Acustica

## Estado
Aprobado (Approved) - 2026-11-10

## Contexto
El estudio de obras musicales polifónicas (dúos, cuartetos, obras de cámara o ensambles modernos) requiere que el músico interprete su parte con afinación y ritmo correctos mientras escucha las demás voces sonando simultáneamente. Anteriormente, las herramientas `song_library`, `mixer`, `audio_synthesizer` y `practice_evaluator` operaban de manera fragmentada:
1. El usuario podía escuchar la partitura completa o reproducir stems en el mezclador, pero no existía un mecanismo automático que silenciara su propio instrumento para tocar como solista sobre la orquesta/acompañamiento (técnica Music Minus One).
2. El evaluador acústico evaluaba notas sin vincular dinámicamente qué pista del arreglo correspondía a la voz ejecutada.
3. No existía una entidad formal de sesión que coordinara el silenciamiento, la síntesis concurrente de stems y la evaluación acústica sincrónica.

## Decision
1. **Creación de la Entidad de Dominio `MinusOneSessionEntity`:**
   - Ubicada en `lib/features/song_library/domain/minus_one_session_entity.dart`.
   - Modela de forma inmutable el estado de la sesión Minus-One: obra de referencia (`songId`), pista del usuario (`userTrackId`), estado de silenciamiento, ganancia de la pista guía, y la serie de evaluaciones acumuladas.
2. **Implementación del Servicio de Dominio `MinusOneOrchestrator`:**
   - Ubicado en `lib/features/song_library/domain/minus_one_orchestrator.dart`.
   - Provee funciones puras de negocio para:
     - Detectar la pista del usuario a partir del instrumento activo o ID provisto.
     - Generar el estado adaptado de la consola de mezcla (`MixerConsoleEntity`) donde la pista del usuario se silencia (`isMuted: true`), mientras que los stems de acompañamiento y el metrónomo permanecen habilitados.
     - Resolver la transposición de instrumento para que la nota evaluada corresponda a la altura real de concierto.
3. **Orquestación en `TunerViewModel`:**
   - Incorporación del estado reactivo `MinusOneSessionEntity? _activeMinusOneSession`.
   - Métodos reactivos:
     - `toggleMinusOneMode({String? targetTrackId})`
     - `setMinusOneUserTrack(String trackId)`
     - `setMinusOneGuideTrackVolume(double volume)`
     - `startMinusOnePracticeSession()` y `stopMinusOnePracticeSession()`.
   - Coordinación del transporte maestro para que durante la reproducción los stems activos suenen por el sintetizador SoundFont mientras el micrófono alimenta al evaluador pedagógico.
4. **Interfaz de Usuario en `SongDecomposerModal`:**
   - Selector intuitivo de pista ("Tu Instrumento").
   - Interruptor maestro "Modo Minus-One (Ensamble Virtual)".
   - Indicador de estado de pista silenciada / pista guía.
   - Enlace directo a la consola de mezcla multicanal para ajustar balance de stems en post-escucha.

## Consecuencias

### Positivas
- **Pedagogía de Conservatorio Inmersiva:** Permite al estudiante experimentar la práctica orquestal y camerística 100% offline sin necesidad de acompañantes presenciales.
- **Evaluación Objetiva en Tiempo Real:** El evaluador acústico compara la ejecución contra la partitura silenciada con precisión centesimal y milimétrica sin interferencias de la voz solista en la síntesis.
- **Cero Rompimiento y Reutilización Total:** Reutiliza las entidades consolidadas `SongPackage`, `AudioTrack`, `MixerConsoleEntity` y `IPracticeEvaluatorService`.

### Negativas / Mitigaciones
- **Sangrado de Altavoces al Micrófono:** El sonido emitido por el altavoz puede ingresar al micrófono y alterar la detección MPM.
  *Mitigación:* Se recomienda formalmente el uso de auriculares para monitoreo en vivo; además, se aplica el filtro supresor de eco acústico (`AcousticEchoSuppressor`) del dominio.
