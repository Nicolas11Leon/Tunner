# Implementation Plan: Instrument Acoustic Isolation and Speech Rejection (Tone Lock)

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-INST-ISOLATION-2026-044`
- **Título de la Implementación:** `Aislamiento Acústico por Tesitura Instrumental, Filtro de Claridad y Rechazo de Habla Humana`
- **Fase del Proyecto:** `Fase 1 / Fase 3 (DSP & Ergonomía Acústica)`
- **Estado:** `Completado`
- **ADR Relacionado:** `docs/04_adrs/0039_instrument_acoustic_isolation_and_speech_rejection.md`
- **Documento Funcional Base:** `docs/02_use_cases/43_uc_instrument_acoustic_isolation_and_speech_rejection.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un discriminador acústico inteligente que evite que el habla cotidiana, ruidos de respiración o sonidos del entorno activen el afinador como notas musicales espurias, garantizando que el afinador solo capture notas sostenidas pertenecientes al instrumento musical activo.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio `InstrumentAcousticFilter` y tracker `ToneLockTracker` en `lib/features/tuner/domain/`.
  - Integración en `IPitchDetectorService` y el worker Isolate de `PitchDetectorService`.
  - Sincronización en `TunerViewModel` al cambiar `activeInstrument` y exposición de `isInstrumentIsolationActive`.
  - Toggle visual en la AppBar de `TunerScreen` (Modo Esencial y Modo Pro).
  - Pruebas unitarias completas de rechazo de frecuencias fuera de tesitura y rechazo de prosodia vocal errática.
- **Excluido (Out-of-Scope):**
  - Redes neuronales de aprendizaje profundo (innecesarias y con sobrecarga de batería; el enfoque determinista MPM + Tone Lock resuelve el problema a la perfección en sub-microsegundos).

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK:** `^3.11.5`.
- **Cero dependencias externas adicionales.** Pure Dart matemático.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Filtro de Aislamiento)
- [x] Crear `lib/features/tuner/domain/instrument_acoustic_filter.dart`:
  - `InstrumentAcousticFilterConfig`: límites de frecuencia $f_{\text{min}}, f_{\text{max}}$, claridad mínima $c_{\text{min}}$ y tolerancia en cents.
  - `InstrumentAcousticFilter`: lógica de validación de tesitura y seguimiento de estabilidad tonal (`ToneLockTracker`).

### Paso 2: Capa de Infraestructura / Audio Isolate
- [x] Modificar `IPitchDetectorService` para soportar `setInstrumentAcousticFilter(InstrumentAcousticFilterConfig config)`.
- [x] En `PitchDetectorService` y su worker Isolate:
  - Recibir mensajes de configuración de filtro.
  - Aplicar el filtrado antes de transmitir las frecuencias a la UI.

### Paso 3: Capa de Integración & ViewModel
- [x] Actualizar `TunerViewModel`:
  - Variable `_isInstrumentIsolationActive = true`.
  - Método `toggleInstrumentIsolation()` y sincronización con el Isolate en `setInstrumentProfile()`.

### Paso 4: Capa de Presentación (UI)
- [x] Integrar botón / chip de **Aislamiento de Instrumento** en las barras de herramientas de `TunerScreen`.

### Paso 5: Pruebas Unitarias y Verificación
- [x] Crear `test/features/tuner/instrument_acoustic_filter_test.dart`.
- [x] Ejecutar `flutter analyze` y `flutter test`.

---

## 4. Estrategia de Rollback
- Revertir cambios en `pitch_detector_service.dart` desactivando el filtro si se reportase rechazo indeseado.

---

## 5. Criterios de Aceptación (Definition of Done)
- [x] Las frecuencias fuera de la tesitura del instrumento son descartadas.
- [x] Las variaciones bruscas de tono ($> 30\text{ cents}$) del habla son rechazadas.
- [x] Las notas reales del instrumento son aceptadas fluidamente tras 2 frames.
- [x] Cero issues en `flutter analyze` y 100% de tests pasando en `flutter test`.
