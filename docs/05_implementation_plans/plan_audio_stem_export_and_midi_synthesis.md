# Plan de Implementación: Exportación de Stems de Audio Multicanal y Síntesis MIDI

Este documento define la estructura obligatoria redactada y validada antes de ejecutar cualquier cambio en el código fuente de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-STEMS-MIDI-2026-036`
- **Título de la Implementación:** Exportación de Stems de Audio Multicanal y Síntesis MIDI Local
- **Fase del Proyecto:** Fase 3 (Plataforma y Experiencia Integral de Producción)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0032](docs/04_adrs/0032_audio_stem_export_and_midi_synthesis.md)
- **Documento Funcional Base:** [Caso de Uso 36](docs/02_use_cases/36_uc_audio_stem_export_and_midi_synthesis.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Diseñar e implementar el subsistema integral de exportación de stems de audio en formato WAV (16-bit PCM 44.1 kHz) y secuencias Standard MIDI File (SMF) directamente desde el espacio de trabajo de **Componer**, permitiendo la síntesis paramétrica de melodías, metrónomo, pistas de acompañamiento y mezcla maestra (mixdown) sin latencia ni dependencias de red.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras: `StemExportConfig`, `ExportedStemFile`, `ExportBundleResult`.
  - Motor de síntesis y mezcla en Pure Dart: `StemAudioSynthesizer` (renderizado de notas acústicas, clics métricos, suma ponderada y limitador suave `tanh`).
  - Generador MIDI multitrack a través de `CanonicalMidiExporter`.
  - Servicio de almacenamiento local offline: `StemExportPersistenceService`.
  - Modal interactivo de usuario: `AudioMidiExportModal`.
  - Integración en `CompositionNotationWorkspaceView` mediante el botón `export_stems_midi_btn`.
  - Cobertura de pruebas unitarias de dominio y widgets de presentación al 100%.
- **Excluido (Out-of-Scope):**
  - Códecs privativos con pérdida como MP3 o AAC para exportación (se prioriza el estándar de la industria WAV PCM sin pérdidas).
  - Carga a servicios cloud o redes sociales (mantenimiento del principio 100% Offline-First).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`.
  - Flutter SDK: Canal estable.
  - Dependencias añadidas: Cero (0). Se emplean las capacidades nativas de `dart:typed_data`, `dart:math` y `dart:io`.
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI?: No.
  - ¿Afecta el rendimiento del bucle principal de Flutter?: No; los cálculos de mezcla operan sobre búferes tipados de longitud finita y se invocan de forma asíncrona.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Crear `lib/features/audio_synthesizer/domain/stem_export_entity.dart` con `StemExportConfig`, `ExportedStemFile`, `ExportBundleResult`.
- [x] Implementar `lib/features/audio_synthesizer/domain/stem_audio_synthesizer.dart` con síntesis de pistas melódicas, metrónomo, acompañamiento y mixdown maestro con limitación anti-clipping.
- [x] Crear suite de pruebas de dominio `test/features/audio_synthesizer/stem_audio_synthesizer_test.dart` y validar el 100% de aserciones.

### Paso 2: Capa de Infraestructura / Datos (Servicio de Persistencia de Exportación)
- [x] Implementar `lib/features/audio_synthesizer/data/stem_export_persistence_service.dart` para escritura atómica en disco local (`exports/`).
- [x] Integrar el servicio y métodos de exportación en `TunerViewModel`.

### Paso 3: Capa de Presentación (Modal Interactivo y Enlace en Workspace)
- [x] Diseñar `lib/features/audio_synthesizer/presentation/audio_midi_export_modal.dart` con selector de stems, switches de formato (WAV Master, Stems WAV, MIDI) y resumen de exportación.
- [x] Incorporar el chip de acción `export_stems_midi_btn` en `CompositionNotationWorkspaceView`.
- [x] Crear pruebas de UI `test/features/audio_synthesizer/audio_midi_export_ui_test.dart`.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecución de `flutter analyze` (cero advertencias).
- [x] Ejecución completa de `flutter test` verificando que todas las pruebas (324+) sigan pasando.
- [x] Merge limpio de la rama feature hacia `main`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit base previo en rama `main` (`7f4ab3c`).
- **Mitigación Inmediata:** Desactivación del botón de exportación en `CompositionNotationWorkspaceView` o reversión del commit de merge.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](AGENTS.md).
- [x] Cero emojis en código, commits y comentarios.
- [x] 100% Clean Architecture (capa de dominio en Pure Dart sin dependencias de UI).
- [x] Pruebas unitarias y de integración pasando al 100%.
- [x] Documentación técnica, caso de uso 36 y ADR 0032 redactados.
