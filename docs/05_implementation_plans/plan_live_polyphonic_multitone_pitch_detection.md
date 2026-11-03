# Plan de Implementación: Detección Polifónica Multitonal en Vivo

Este documento define la estructura obligatoria redactada y validada antes de ejecutar cambios en el código fuente de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-MULTITONE-POLY-2026-037`
- **Título de la Implementación:** Detección Polifónica Multitonal en Vivo y Descomposición de Voces
- **Fase del Proyecto:** Fase 3 (Laboratorio Acústico y Análisis Polifónico Profesional)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0033](docs/04_adrs/0033_live_polyphonic_multitone_pitch_detection.md)
- **Documento Funcional Base:** [Caso de Uso 37](docs/02_use_cases/37_uc_live_polyphonic_multitone_pitch_detection.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Evolucionar el motor de análisis polifónico para descomponer en tiempo real las frecuencias fundamentales simultáneas ($f_0$) de múltiples notas tocadas en guitarra o piano, extrayendo las voces activas con octava, desviación en cents y función armónica dentro del espacio **Producir**.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras: `DetectedPolyphonicVoice`, `PolyphonicMultiToneAnalysisResult`.
  - Algoritmo DSP de Tamiz Armónico y Función de Salience: `PolyphonicMultiToneDetector`.
  - Integración en `TunerViewModel`: propiedad reactiva `polyphonicAnalysisResult`, método `updatePolyphonicMultiTones()`.
  - Componente de visualización `MultiToneVoicingWidget` e integración en `ChordAnalyzerModal`.
  - Cobertura de pruebas unitarias de dominio y widgets de presentación al 100%.
- **Excluido (Out-of-Scope):**
  - Transcripción polifónica a partitura polifónica a múltiples pentagramas (se enfoca en análisis espectral multitonal instantáneo para guitarra/piano).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`.
  - Flutter SDK: Canal oficial estable.
  - Dependencias añadidas: Cero (0). Se emplean las capacidades nativas de `dart:math`.
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI?: No.
  - ¿Afecta el bucle principal?: No; el tamiz armónico procesa búferes finitos con límites de búsqueda optimizados para 60 FPS.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Crear `lib/features/chord_analyzer/domain/polyphonic_pitch_entity.dart` con `DetectedPolyphonicVoice` y `PolyphonicMultiToneAnalysisResult`.
- [x] Implementar `lib/features/chord_analyzer/domain/polyphonic_multitone_detector.dart` con cálculo de salience armónico y sustracción iterativa de peines armónicos.
- [x] Crear suite de pruebas de dominio `test/features/chord_analyzer/polyphonic_multitone_detector_test.dart` y validar el 100% de aserciones.

### Paso 2: Integración en Capa de Datos / ViewModel
- [x] Integrar `PolyphonicMultiToneDetector` en `TunerViewModel`.
- [x] Proveer actualización continua de voces polifónicas cuando el análisis de acordes está activo.

### Paso 3: Capa de Presentación (Visualizador Multitonal)
- [x] Implementar `lib/features/chord_analyzer/presentation/multi_tone_voicing_widget.dart` con desglose de voces, cents y roles armónicos.
- [x] Integrar el widget en `ChordAnalyzerModal`.
- [x] Crear pruebas de UI `test/features/chord_analyzer/polyphonic_multitone_ui_test.dart`.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecución de `flutter analyze` (cero advertencias de linter).
- [x] Ejecución de `flutter test` verificando que todas las pruebas pasen al 100%.
- [x] Merge limpio de la rama feature hacia `main`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit base de main (`631885f`).
- **Mitigación Inmediata:** Desactivación de la sección multitonal en el modal o reversión del commit de merge.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](AGENTS.md).
- [x] Cero emojis en código, commits y comentarios.
- [x] 100% Clean Architecture (capa de dominio en Pure Dart).
- [x] Pruebas unitarias y de integración pasando al 100%.
- [x] Documentación técnica, caso de uso 37 y ADR 0033 redactados.
