# Plan de Implementacion: Descomponedor de Partituras, Ensamble Virtual "Minus-One" y Mezclador de Stems

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-MINUS-ONE-2026-059`
- **Título de la Implementación:** Implementación del Ensamble Virtual Minus-One con Síntesis SoundFont SF2, Mezclador de Stems y Evaluación Acústica Concurrente
- **Fase del Proyecto:** Fase 2 (Suites Sinérgicas Multi-Herramienta)
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0055: Arquitectura del Descomponedor de Partituras con Ensamble Virtual Minus-One](../04_adrs/0055_score_decomposer_minus_one_virtual_ensemble.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-061](../01_product_vision/doc_score_decomposer_minus_one_virtual_ensemble.md) y [UC-61](../02_use_cases/61_uc_score_decomposer_minus_one_virtual_ensemble.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Integrar funcional y pedagógicamente el descomponedor de partituras (`song_library` / `song_decomposer`), la consola de mezcla multicanal (`mixer`), el sintetizador SoundFont SF2 (`audio_synthesizer`) y el evaluador pedagógico (`practice_evaluator`) en un flujo coordinado de práctica "Minus-One", donde el estudiante silencia su instrumento en el arreglo, ejecuta sobre el acompañamiento sintetizado y recibe evaluación acústica en tiempo real con opción de mezcla y balance final.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de la entidad inmutable `MinusOneSessionEntity` en `lib/features/song_library/domain/minus_one_session_entity.dart`.
  - Creación del servicio de dominio puro `MinusOneOrchestrator` en `lib/features/song_library/domain/minus_one_orchestrator.dart`.
  - Métodos y estado reactivo en `TunerViewModel`: `_activeMinusOneSession`, `toggleMinusOneMode()`, `setMinusOneUserTrack()`, `setMinusOneGuideTrackVolume()`, `startMinusOnePracticeSession()`, `stopMinusOnePracticeSession()`.
  - Integración visual en `SongDecomposerModal` con selector de pista de usuario, interruptor maestro Minus-One, estado de pista silenciada y botón de práctica evaluada.
  - Suite de pruebas unitarias (`test/features/song_library/minus_one_orchestrator_test.dart`) y de integración (`test/features/song_library/minus_one_integration_test.dart`).
- **Excluido (Out-of-Scope):**
  - Modificación del parser binario RIFF SF2 (la síntesis usa los métodos existentes del sintetizador).
  - Algoritmos de separación ciega de fuentes de audio sobre archivos WAV mezclados (el descomponedor opera sobre partituras y stems polifónicos discretos estructurados).

---

## 2. Analisis de Dependencias y Tecnologias

- **Dart SDK:** `^3.11.5` (puro en Dominio, sin paquetes de UI).
- **Flutter SDK:** Canal estable (Widgets reactivos y diseño de consola de audio).
- **Riesgo Tecnológico:** Cero. Reutiliza la arquitectura modular sinérgica y las entidades de datos existentes.
- **Rendimiento:** Latencia determinista en Isolate de audio, cero bucles de espera activa (*zero busy-waiting*).

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matematicos y Logica Pura)
- [ ] Crear `MinusOneSessionEntity` con propiedades inmutables (`songId`, `userTrackId`, `isMinusOneActive`, `isMutedUserTrack`, `guideTrackVolume`, `evaluations`).
- [ ] Implementar `MinusOneOrchestrator` con métodos:
  - `detectUserTrack(SongPackage package, String activeInstrumentId)`
  - `configureMinusOneMixer(MixerConsoleEntity console, String userTrackId, {bool muteUserTrack = true, double guideVolume = 0.0})`
  - `evaluateLiveSample({required MinusOneSessionEntity session, required SongPackage package, required double detectedPitchHz, required int currentSubTick, required int timingDeltaMs})`
  - `calculateSessionScore(List<NoteEvaluationEntity> evaluations)`

### Paso 2: Orquestacion en el ViewModel
- [ ] En `TunerViewModel`, agregar `MinusOneSessionEntity? _activeMinusOneSession` y getter público.
- [ ] Conectar la activación/desactivación del modo Minus-One con la mutación de `_mixerConsole`.
- [ ] Asegurar que al reproducir en modo Minus-One, los stems activos sean sintetizados mientras el micrófono alimenta al evaluador pedagógico.
- [ ] Compilar el reporte final al detener la sesión de práctica.

### Paso 3: Capa de Presentacion (UI)
- [ ] Enriquecer `SongDecomposerModal` con controles de Ensamble Virtual Minus-One:
  - Dropdown o chips para seleccionar la pista del usuario.
  - Switch interactivo `Modo Minus-One`.
  - Visualización del estado de silencio en la pista del usuario.
  - Botón de inicio de práctica con acompañamiento.

### Paso 4: Pruebas y Verificacion Rigurosa
- [ ] Escribir `test/features/song_library/minus_one_orchestrator_test.dart` verificando la configuración del mezclador, transposición y cálculo de score.
- [ ] Escribir `test/features/song_library/minus_one_integration_test.dart` verificando el flujo completo de activación, síntesis y evaluación.
- [ ] Ejecutar `flutter analyze` (garantizar 0 issues).
- [ ] Ejecutar `flutter test` (garantizar 100% de pruebas passing).

---

## 4. Criterios de Aceptacion y Definition of Done (DoD)

1. Cero dependencias de Flutter o plugins en `lib/features/song_library/domain/`.
2. Todos los cálculos acústicos y temporales libres de números mágicos no documentados.
3. 100% de la suite de pruebas aprobada sin regresiones.
4. 0 advertencias y 0 errores en análisis estático (`flutter analyze`).
5. Rama publicada en GitHub con enlace al Pull Request para revisión del usuario.
