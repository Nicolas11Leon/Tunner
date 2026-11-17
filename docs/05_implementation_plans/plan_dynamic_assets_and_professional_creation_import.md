# Template: Implementation Plan (Plantilla Plan de Implementación)

Este documento define la estructura obligatoria previa a la implementación de las carpetas de assets dinámicas vacías por defecto, con capacidades profesionales de creación (`+`) e importación (`⬇`) para partituras, tomas de audio, sesiones de estudio y presets en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-DYNAMIC-ASSETS-CREATION-IMPORT-2026-075`
- **Título de la Implementación:** `Implementación del Sistema de Carpetas de Assets Dinámicas con Estado Vacío Inicial, Creación de Nuevos Documentos (Partituras, Tomas, Presets) y Canal de Importación Profesional`
- **Fase del Proyecto:** `Fase 2 (Estudio de Grabación & Sistema de Archivos Musicales)`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0016_dynamic_workspace_assets_and_import_pipeline.md`
- **Documento Funcional Base:** `docs/02_use_cases/75_uc_dynamic_assets_creation_and_import.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Reemplazar los elementos de demostración hardcodeados en el árbol lateral por un **sistema dinámico de carpetas de assets**:
1. Las carpetas inician vacías por defecto (o reflejando únicamente los assets creados/importados por el usuario y los registros de persistencia).
2. Cada carpeta de assets expone de manera visible, limpia y profesional las opciones de:
   - **`[+] Crear Nuevo`**: Diálogo modal de precisión para configurar y generar nuevas partituras MusicXML, iniciar tomas de grabación WAV, o guardar presets de afinación.
   - **`[⬇] Importar`**: Selector de importación para incorporar archivos MusicXML, SMF MIDI, audio WAV o repertorio canónico a la biblioteca del usuario.
3. Al crear o importar cualquier asset, este se integra reactivamente como nodo hijo dentro de su respectiva carpeta en `StudioTreeView`, permitiendo su apertura, visualización y gestión directa.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Soporte en `StudioTreeFolder` para botón de acción rápida en cabecera (`actionButton`) y estado vacío con acciones (`emptyPlaceholderAction`).
  - Creación de diálogos profesionales atómicos:
    - `StudioNewScoreDialog`: creación de partituras en blanco con compás, tonalidad y tempo.
    - `StudioImportScoreDialog`: importador de partituras MusicXML / MIDI y catálogo canónico.
    - `StudioNewRecordingDialog`: asistente de toma de grabación WAV.
    - `StudioNewTuningPresetDialog`: creador de presets de afinación A4 / temperamento.
  - Vinculación reactiva con `TunerViewModel` (`addSongPackage`, `importScoreFromBytes`, `startPracticeRecording`, `recordingHistory`, `curatedLibrary`).
  - Pruebas unitarias de carpetas vacías, creación de partituras e importación.
- **Excluido (Out-of-Scope):**
  - Almacenamiento en servidores remotos en la nube (el diseño es 100% offline y local en disco).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.x`
- **Flutter SDK:** Canal estable de Linux Desktop.
- **Riesgo Tecnológico:** Cero dependencias adicionales. Todo el pipeline de MusicXML, MIDI y WAV opera sobre los motores de dominio puros ya verificados (`CanonicalMusicXmlExporter`, `UniversalScoreImporterService`, `PracticeRecorderService`).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Extensión del Modelo `StudioTreeFolder`
- [x] Añadir soporte para `Widget? actionButton` en la cabecera de la carpeta.
- [x] Añadir soporte para renderizar acciones de estado vacío (`emptyAction`) cuando `items.isEmpty`.

### Paso 2: Creación de Diálogos Atómicos de Gestión de Assets
- [x] Implementar `StudioNewScoreDialog` (creación de partitura en blanco).
- [x] Implementar `StudioImportScoreDialog` (importación de MusicXML / MIDI / repertorio).
- [x] Implementar `StudioNewTuningPresetDialog` (presets de afinación personalizados).

### Paso 3: Conexión Reactiva en `MainAppShell`
- [x] Vincular las carpetas del sidebar a las listas vivas de `TunerViewModel`:
  - 📁 `Biblioteca de Partituras`: enlazar a partituras creadas/importadas del usuario.
  - 📁 `Tomas de Audio & WAV`: enlazar a `viewModel.recordingHistory`.
  - 📁 `Presets de Afinación`: enlazar a calibraciones guardadas.
- [x] Proveer los callbacks de creación e importación en cada carpeta.

### Paso 4: Pruebas y Validación
- [x] Suite de pruebas en `test/core/design_system/studio_assets_creation_test.dart`.
- [x] Ejecutar `flutter analyze` y asegurar cero advertencias.
- [x] Compilar y verificar en vivo en Linux Desktop.
