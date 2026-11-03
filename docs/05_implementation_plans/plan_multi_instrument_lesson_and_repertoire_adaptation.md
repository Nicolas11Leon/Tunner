# Implementation Plan: Adaptación Universal de Lecciones y Repertorio a Cualquier Instrumento

Este documento define la estructura y ejecución paso a paso para desacoplar el sistema pedagógico (lecciones guiadas interactivas y biblioteca de canciones) de la afinación exclusiva de flauta, permitiendo la adaptación automática de tesituras, octavas, claves de transposición y consejos biomecánicos para cualquier instrumento musical disponible en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-PEDAGOGY-2026-0045`
- **Título de la Implementación:** Adaptación Universal de Lecciones y Repertorio Didáctico Multi-Instrumento
- **Fase del Proyecto:** Fase 3 (Educación Musical Universal y Monolito Modular)
- **Estado:** Completado
- **ADR Relacionado:** `docs/04_adrs/0041_multi_instrument_pedagogy_adaptation_engine.md`
- **Documento Funcional Base:** `docs/02_use_cases/45_uc_multi_instrument_lesson_and_repertoire_adaptation.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Desarrollar un motor de dominio puro (`InstrumentPedagogyAdapterEngine`) que permita que tanto las lecciones guiadas interactivas como las canciones de la biblioteca se adapten de forma dinámica y automática a la tesitura natural, clave de transposición (Do, Si♭, Mi♭, Fa, Sol, La, etc.), clave de notación (Sol / Fa) y particularidades biomecánicas de cualquier instrumento seleccionado por el usuario (Guitarras, Bajos, Violines, Cellos, Trompetas, Saxofones, Trombón, Tuba, Voz, Flautas, etc.).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio `InstrumentPedagogyAdapterEngine`:
    - Algoritmo de cálculo de octava óptima dentro del rango `[minFrequencyHz, maxFrequencyHz]` del instrumento.
    - Algoritmo de cálculo de notas transpuestas (nota escrita vs nota sonada de concierto).
    - Generador de consejos biomecánicos contextuales según la familia acústica (`woodwinds`, `brass`, `strings`, `vocals`, `percussion`).
  - Extensión de `curated_guided_lessons.dart` y `guided_lesson_entity.dart` para soportar notas transpuestas y tips adaptativos.
  - Extensión de `SongDecomposerService` para que los paquetes y pistas de canciones adapten sus títulos y rangos al instrumento activo.
  - Actualización de `TunerViewModel`:
    - `availableGuidedLessons` retorna la lista de lecciones adaptadas al `activeInstrument`.
    - Método `adaptScoreToActiveInstrument()` para transponer piezas al rango del instrumento.
  - Actualización de `GuidedLessonsModal`:
    - Visualización del instrumento activo en chip superior.
    - Notación escrita vs real para instrumentos transpositores (ej. Trompeta Bb o Saxo Eb).
    - Renderizado de consejos biomecánicos adaptados (ej. trastes y dedos en guitarra, arco en cello/violín, boquilla/vibración labial en trompeta).
- **Excluido (Out-of-Scope):**
  - Reconocimiento polifónico de acordes complejos en guitarra durante lecciones (permanece enfocado en entonación y notas melódicas estables).
  - Descarga de archivos de audio externos (sigue siendo 100% offline).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal estable oficial
- **Riesgo Tecnológico:**
  - Cero dependencias nativas o plugins externos. 100% Pure Dart en la capa de dominio.
  - Cero loops de espera o busy-waiting.
  - Los cálculos de frecuencia y transposición se resuelven en $O(1)$ sin impacto en el hilo de renderizado de 60/120 FPS.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Crear `lib/features/guided_lessons/domain/instrument_pedagogy_adapter_engine.dart`.
  - Mapeo de frecuencias exactas según la fórmula $f = 440 \times 2^{(n - 69)/12}$.
  - Algoritmo de transposición y octave-shifting para mantener cada nota dentro del rango ergonómico del instrumento.
  - Generador de tips biomecánicos clasificados por `InstrumentFamily` (digitación, embocadura, arco, respiración).
- [x] Extender `GuidedLessonStepEntity` para incluir campos opcionales: `writtenNoteName` (nota para lectura transpuesta) y `familyTips` (consejos por familia).
- [x] Crear tests unitarios en `test/features/guided_lessons/instrument_pedagogy_adapter_test.dart`.

### Paso 2: Capa de Biblioteca y Servicios (`song_library`)
- [x] Actualizar `SongDecomposerService` para eliminar referencias fijas de flauta en las pistas curadas ("Melodía de Flauta" -> Dinámico según instrumento).
- [x] Añadir método `adaptScoreToInstrument(HierarchicalScore score, InstrumentProfileEntity instrument)` para ajustar octavas y claves.
- [x] Añadir nuevas obras didácticas populares multi-instrumento en las plantillas.

### Paso 3: Capa de Aplicación (`TunerViewModel`)
- [x] Integrar `InstrumentPedagogyAdapterEngine` en `TunerViewModel`.
- [x] Modificar `availableGuidedLessons` para devolver lecciones adaptadas al `activeInstrument`.
- [x] Re-evaluar lección activa automáticamente si el usuario cambia de instrumento durante la práctica.

### Paso 4: Capa de Presentación (UI / Modals)
- [x] Actualizar `GuidedLessonsModal`:
  - Mostrar badge con el instrumento activo y clave de transposición si aplica.
  - Mostrar nota escrita y nota real sonada cuando el instrumento es transpositor.
  - Mostrar el consejo biomecánico adaptado a la familia del instrumento.
- [x] Actualizar `SongDecomposerModal`:
  - Botón de ajuste rápido de tesitura al instrumento activo.

### Paso 5: Verificación, Documentación y DoD
- [x] Redactar Caso de Uso canónico `docs/02_use_cases/45_uc_multi_instrument_lesson_and_repertoire_adaptation.md`.
- [x] Redactar ADR `docs/04_adrs/0041_multi_instrument_pedagogy_adaptation_engine.md`.
- [x] Actualizar `docs/06_qa_and_manual_testing/bitacora_maestra_pruebas_manuales.md`.
- [x] Ejecutar `flutter analyze` y `flutter test`.
- [x] Git commit y push.
