# Plan de Implementacion: US-4.4 Reloj Musical Real en Transcripcion en Vivo, Silencios y Soporte A0 / Multi-Bit WAV

Este documento define el plan tecnico paso a paso para implementar la historia de usuario **US-4.4** en **Tunner**, respetando Clean Architecture y las reglas de `AGENTS.md`.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-TRANSCRIPTION-US44-2026-152`
- **Titulo de la Implementacion:** Reloj Musical Real (ms a subTicks), Insercion de Silencios, Division de Compas y WAV Multi-Bit / 27.5 Hz
- **Fase del Proyecto:** Fase 4 (Transcripcion Inteligente En Vivo y Offline)
- **Estado:** Completado
- **ADR Relacionado:** [docs/04_adrs/0152_transcription_real_clock_rests_and_multibit_wav.md](../04_adrs/0152_transcription_real_clock_rests_and_multibit_wav.md)
- **Documento Funcional Base:** [docs/02_use_cases/160_uc_transcription_real_clock_rests_and_multibit_wav.md](../02_use_cases/160_uc_transcription_real_clock_rests_and_multibit_wav.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Proveer medicion temporal real en milisegundos convertida a sub-ticks musicales (`subTicks = (durationMs / (15000.0 / bpm)).round()`), insercion de silencios `HierarchicalNote.rest`, division de figuras que crucen barras de compas y soporte completo en transcripcion offline para frecuencias desde `25.0 Hz` ($A_0 = 27.5\text{ Hz}$), WAV multi-bit (`8/16/24/32` PCM e `IEEE Float`) y metricas `TimeSignature` configurables.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/score_editor/domain/score_editor_domain.dart` (soporte limpio en `insertOrUpdateNote` para generar `HierarchicalNote.rest` cuando `noteName` es vacio).
  - `lib/features/transcription/domain/live_transcription_engine.dart` (reloj musical `ms -> subTicks`, helper compartido de particion entre compases, insercion de silencios y eliminacion de `math.min(startTick, 15)`).
  - `lib/features/transcription/domain/polyphonic_transcription_engine.dart` (misma integracion de reloj real, silencios y division entre compases para acordes polifonicos).
  - `lib/features/transcription/domain/audio_to_score_transcription_engine.dart` (ventana `4096`, umbral `25.0 Hz`, decodificador WAV 8/16/24/32 PCM + IEEE Float `audioFormat == 3`, `TimeSignature` parametrizado).
  - `lib/features/score_editor/presentation/score_editor_controller.dart`, `lib/features/tuner/presentation/tuner_viewmodel.dart` y `lib/features/universal_importer/data/universal_score_importer_service.dart` (conexion limpia de `bpm`, timestamps en vivo y `timeSignature`).
  - `test/features/transcription/us_4_4_transcription_real_clock_test.dart`.
- **Excluido (Out-of-Scope):**
  - Decodificacion de formatos comprimidos con perdida (MP3, AAC, OGG).
  - Cambios en la UI de `ScoreEditorModal`.

---

## 2. Analisis de Dependencias y Tecnologias

- **Versiones de Librerias / SDKs:**
  - Pure Dart en toda la capa `lib/features/transcription/domain/` utilizando `dart:math` y `dart:typed_data`.
  - Cero dependencias de Flutter UI o plugins externos.
- **Riesgo Tecnologico:**
  - Introduce dependencias nativas o FFI: No.
  - Mantiene compatibilidad hacia atras con pruebas y llamadas existentes sin parametros temporales.

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Reloj Musical y Motores de Transcripcion)
- [x] Redactar Caso de Uso 160, ADR 0152 y este Plan de Implementacion.
- [x] Asegurar que `ScoreEditorOperations.insertOrUpdateNote` cree `HierarchicalNote.rest` cuando `noteName.isEmpty`.
- [x] Implementar reloj musical en `LiveTranscriptionEngine` y `PolyphonicTranscriptionEngine` (`frameDurationMs`, `timestampMs`, `bpm`, formula `subTicks = (durationMs / (15000.0 / bpm)).round()`, insercion de `HierarchicalNote.rest`, division de notas/silencios en barra de compas, eliminacion de `math.min(startTick, 15)`).
- [x] Actualizar `AudioToScoreTranscriptionEngine` con `windowSize = 4096`, umbral `25.0 Hz`, decodificador WAV PCM 8/16/24/32 bits e IEEE Float (`audioFormat == 3`, `32/64` bits y `0xFFFE` extensible) y `TimeSignature` parametrizado.

### Paso 2: Integracion en Controladores e Importador
- [x] Pasar `bpm` y `timestampMs` reales durante captura en vivo desde `TunerViewModel` y `ScoreEditorController`.
- [x] Exponer `timeSignature` opcional en `UniversalScoreImporterService.transcribeAudioToScoreResult`.

### Paso 3: Pruebas, Verificacion y Limpieza
- [x] Crear `test/features/transcription/us_4_4_transcription_real_clock_test.dart` cubriendo reloj `ms -> subTicks` a distintos BPM, silencios en vivo mono y polifonicos, division entre compases, metricas no-4/4 (`6/8`, `3/4`, `12/8`), deteccion $A_0 = 27.5\text{ Hz}$ y WAV 8/16/24/32/64 PCM + IEEE Float + `0xFFFE`.
- [x] Ejecutar `flutter analyze --no-fatal-infos` (0 issues).
- [x] Ejecutar pruebas nuevas y toda la suite existente en `test/features/transcription/` y `test/features/notation/` (100% pass).

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauracion Git:** Commit base de `origin/qa` (`e946b95`).
- **Mitigacion Inmediata:** Reversion atomica de la rama `feature/us-4.4-transcription-real-clock-rests-and-multibit-wav` sin afectar formatos persistidos.

---

## 5. Criterios de Aceptacion (Definition of Done)

- [x] Codigo adherido estrictamente a Clean Architecture y reglas de `AGENTS.md` (cero emojis).
- [x] `flutter analyze --no-fatal-infos` reporta 0 issues.
- [x] `flutter test` pasa al 100% en las pruebas de US-4.4 y pruebas existentes relacionadas.
- [x] Documentacion tecnica completa (UC 160 con 2 diagramas Mermaid, ADR 0152 y Plan).
- [x] Pull Request abierto hacia `qa` vinculado al Issue de GitHub sin ejecutar merge.
