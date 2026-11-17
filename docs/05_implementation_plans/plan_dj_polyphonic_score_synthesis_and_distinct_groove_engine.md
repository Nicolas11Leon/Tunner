# Template: Implementation Plan (Plantilla Plan de Implementación)

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-DJ-SCORE-SYNTH-2026-97`
- **Título de la Implementación:** Síntesis Acústica Real de Partituras Curadas (Für Elise, Canon, Beethoven) y Motor de Grooves Diferenciados para la Consola DJ Pro Studio
- **Fase del Proyecto:** Fase 1
- **Estado:** Propuesto
- **ADR Relacionado:** [`docs/04_adrs/0087_dj_polyphonic_score_synthesis_and_distinct_groove_engine.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/04_adrs/0087_dj_polyphonic_score_synthesis_and_distinct_groove_engine.md)
- **Documento Funcional Base:** [`docs/02_use_cases/97_uc_dj_polyphonic_score_synthesis_and_distinct_groove_engine.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/docs/02_use_cases/97_uc_dj_polyphonic_score_synthesis_and_distinct_groove_engine.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Erradicar la emisión de un tono/groove genérico idéntico (onda fija a 55 Hz) al seleccionar obras del repertorio musical clásico (como "Para Elisa", "Canon en Re Mayor", "Himno a la Alegría") o presets electrónicos en la Consola DJ. Implementar un sintetizador procedural polifónico que traduzca las notas reales de la partitura jerárquica (`HierarchicalScore`), sus acordes y su métrica temporal a audio PCM reproducible y manipulable mediante EQ, pitch bend y 4-Stem isolation en los Decks A y B.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de un método de síntesis acústica en `DjAudioProcessor` (`synthesizeScoreAudio` y `synthesizeSongPackageTrack`) que toma las notas reales de la partitura (`Mi5`, `Re#5`, `Si4`, `La4`, etc.), las frecuencias en Hz exactas y las envuelve en envolventes ADSR y tímbricas de piano/cuerdas.
  - Generación de stems rítmicos adaptativos (bombo, percusión, hi-hats) sincronizados al tempo nominal de la obra para permitir beatmatching y separación de stems en la cabina de DJ.
  - Implementación de perfiles tímbricos acústicos únicos para cada uno de los 5 presets de club (`Midnight Cyber Synthwave`, `Deep Techno Underground`, `Liquid Drum & Bass`, `Vocal House Anthem`, `Afro House Sunset`).
  - Actualización de `DjTrackLoaderModal` para despachar el audio procedural real correspondiente a la obra seleccionada.
  - Actualización de los chips de carga rápida de `DjStudioWorkstationView` (`Canon 68`, `Mozart 118`, `House 124`, `Cyber 128`) para disparar las partituras auténticas.
  - Actualización de `DjDeckAudioService` para que el estado inicial de Deck A y Deck B cargue grooves acústicamente distinguibles.
- **Excluido (Out-of-Scope):**
  - Modificación de la estructura de base de datos de partituras existentes.
  - Introducción de librerías nativas externas o llamadas de red.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `>=3.0.0 <4.0.0`.
  - Flutter SDK: Canal estable Linux/Desktop.
  - Audioplayers: `6.1.1` (emisión mediante `BytesSource` WAV PCM 16-bit 44.1 kHz).
- **Riesgo Tecnológico:**
  - Cero dependencias nativas externas: 100% Pure Dart matemático.
  - Algoritmos de síntesis acotados en memoria RAM: buffers generados en <15 ms para fragmentos de 15 a 20 segundos sin sobrecarga de recolección de basura.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio y Procesamiento DSP (`DjAudioProcessor`)
- [ ] Implementar la función `synthesizeSongPackageTrack` en `DjAudioProcessor`.
- [ ] Calcular la frecuencia exacta de cada nota:
  $$f = 440.0 \cdot 2^{\frac{\text{midiPitch} - 69}{12}}$$
- [ ] Sintetizar la melodía de "Para Elisa", "Canon en Re Mayor" y cualquier `SongPackage` iterando sobre `score.measures` y `measure.notes`.
- [ ] Sintetizar acordes de acompañamiento basados en la armonía y clave de la partitura.
- [ ] Generar ritmos club específicos y diferenciados para cada uno de los presets de música electrónica (Cyber, Techno, DnB, House, Afro).

### Paso 2: Capa de Datos e Infraestructura (`DjDeckAudioService`)
- [ ] Configurar buffers iniciales `_demoGrooveABytes` y `_demoGrooveBBytes` con sonoridades e instrumentaciones radicalmente diferentes.
- [ ] Garantizar que `loadDeckTrack` almacene y despache los bytes de la partitura sin pérdida de estado.

### Paso 3: Capa de Presentación (`DjTrackLoaderModal` y `DjStudioWorkstationView`)
- [ ] Vincular `_loadCuratedSong` a `synthesizeSongPackageTrack`.
- [ ] Vincular `_loadPreset` al sintetizador de presets diferenciados.
- [ ] Actualizar los Quick Chips en `DjStudioWorkstationView` para invocar la síntesis correspondiente a cada obra.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Crear suite de pruebas unitarias y de integración en `test/features/dj_console/dj_score_synthesis_test.dart`.
- [ ] Verificar que "Para Elisa" sintetice las frecuencias de E5 (659.25 Hz) y D#5 (622.25 Hz).
- [ ] Ejecutar la suite completa de pruebas de DJ (`test/features/dj_console/`).
- [ ] Compilar y verificar el binario de Linux release.
