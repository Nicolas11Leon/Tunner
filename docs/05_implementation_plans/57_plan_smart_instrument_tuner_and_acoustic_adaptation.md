# Plan de Implementación: Afinador Inteligente por Reconocimiento Tímbrico y Adaptación Acústica

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-SMART-TUNER-2026-057`
- **Título de la Implementación:** Motor de Detección Tímbrica de Instrumentos, Auto-Adaptación de Filtros Acústicos y Síntesis de Diapasón Real
- **Fase del Proyecto:** Fase 5 (Modular Studio & Hiper-Sinergia)
- **Estado:** En Progreso
- **ADR Relacionado:** [`0053_smart_instrument_tuner_and_timbre_detection_architecture.md`](../04_adrs/0053_smart_instrument_tuner_and_timbre_detection_architecture.md)
- **Documento Funcional Base:** [`doc_smart_instrument_tuner_and_acoustic_adaptation.md`](../01_product_vision/doc_smart_instrument_tuner_and_acoustic_adaptation.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Implementar el motor de reconocimiento tímbrico `SmartInstrumentDetector` en la capa de dominio puro de `lib/features/instrument/domain/` y conectarlo con `TunerViewModel`, `acoustic_lab`, el filtro del afinador MPM y el sintetizador SoundFont para completar la Hiper-Sinergia 3 del sistema.

### 1.2 Límites del Alcance
- **In-Scope:**
  - Value Objects `AcousticSignature` y `SmartInstrumentMatch`.
  - Servicio de dominio puro `SmartInstrumentDetector` con perfiles acústicos calibrados para flauta, clarinete, trompeta, saxofón, violín, violonchelo, guitarra acústica, bajo y voz humana.
  - Métodos y getters en `TunerViewModel`: `isSmartInstrumentTuningActive`, `toggleSmartInstrumentTuning`, `autoSwitchInstrumentEnabled`, `lastDetectedInstrumentMatch`, `applyDetectedInstrumentMatch`.
  - Sincronización del patch SoundFont al cambiar o detectar instrumento.
  - Componente UI atómico `SmartInstrumentBadge` en la interfaz del afinador.
  - Pruebas unitarias de dominio y pruebas de integración en ViewModel.
- **Out-of-Scope:**
  - Redes neuronales en la nube o modelos pesados (estrictamente prohibido por la regla Offline-First de AGENTS.md; todo corre localmente en Dart puro).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio Puro
- [ ] Crear `lib/features/instrument/domain/smart_instrument_detector.dart`.
- [ ] Implementar la clasificación multivariada de armónicos $H_1-H_8$, relación par/impar y rango fundamental.
- [ ] Pruebas unitarias completas en `test/features/instrument/smart_instrument_detector_test.dart`.

### Paso 2: Integración en Capa de Presentación / ViewModel
- [ ] Agregar soporte de detección inteligente en `TunerViewModel`.
- [ ] Sincronizar el patch SoundFont SF2 (`selectSoundFontPatch`) según el instrumento activo.
- [ ] Pruebas unitarias de integración en `test/features/tuner/smart_tuner_viewmodel_test.dart`.

### Paso 3: Componente Atómico de UI
- [ ] Crear widget atómico `SmartInstrumentBadge` en `lib/features/instrument/presentation/widgets/smart_instrument_badge.dart`.
- [ ] Incluir badge interactivo en `lib/features/tuner_screen.dart`.

### Paso 4: Verificación, Análisis y Merge
- [ ] `flutter analyze` con 0 errores y 0 advertencias.
- [ ] 100% de pruebas pasando.
- [ ] Push a origin, crear PR y squash-merge en `main`.
