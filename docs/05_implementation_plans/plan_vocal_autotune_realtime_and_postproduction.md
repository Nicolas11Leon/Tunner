# Plan de Implementación: Motor de Corrección Tonal Vocal en Tiempo Real y Post-Producción (Vocal AutoTune)

Este documento define la estructura obligatoria redactada y validada antes de ejecutar cambios en el código fuente de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-VOCAL-AUTOTUNE-2026-039`
- **Título de la Implementación:** Motor de Corrección Tonal Vocal en Tiempo Real y Post-Producción (Vocal AutoTune)
- **Fase del Proyecto:** Fase 3 (Plataforma y Experiencia Integral de Aprendizaje y Producción)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0035](docs/04_adrs/0035_vocal_autotune_realtime_and_postproduction.md)
- **Documento Funcional Base:** [Caso de Uso 39](docs/02_use_cases/39_uc_vocal_autotune_and_pitch_correction.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Diseñar e implementar el motor de corrección de afinación vocal asistida (*Vocal AutoTune*) en Pure Dart y su integración en la arquitectura de Tunner, permitiendo afinar voces en tiempo real durante la escucha o monitoreo de práctica y aplicar procesamiento destructivo/no destructivo sobre tomas grabadas en la consola multitrack para exportación de stems y mezclas de alta fidelidad.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras: `VocalScaleType`, `AutoTuneConfigEntity`, `AutoTunePreset`.
  - Cuantizador matemático de escala y suavizador de inercia: `ScaleQuantizer`.
  - Desplazador de tono y formantes en dominio temporal: `TdPsolaPitchShifter`.
  - Procesador unificado para streaming de bloques y tomas completas: `VocalAutoTuneProcessor`.
  - Integración en `TunerViewModel`: estado reactivo `isAutoTuneActive`, configuración activa `autoTuneConfig`, métodos `toggleAutoTune()`, `updateAutoTuneConfig()`, `applyAutoTuneToTake()`.
  - Modal interactivo de presentación: `VocalAutoTuneModal` con selectores de escala, slider de retune speed, chips de notas activas en escala y selector de tomas de grabación.
  - Botón de acceso `open_autotune_chip` en `ProductionWorkspaceView` y `LearningPracticeWorkspaceView`.
  - Cobertura completa de pruebas unitarias de dominio y pruebas de interfaz de usuario.
- **Excluido (Out-of-Scope):**
  - Descargas de modelos pesados de redes neuronales (se mantiene el principio de baja latencia sub-10ms y 100% Offline-First en Pure Dart).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`.
  - Flutter SDK: Canal oficial estable.
  - Dependencias añadidas: Cero (0).
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI?: No.
  - ¿Afecta el rendimiento?: No; el algoritmo TD-PSOLA opera con aritmética flotante lineal $O(N)$ y buffers reutilizados de audio.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos de Configuración, Cuantizador y TD-PSOLA)
- [x] Crear `lib/features/vocal_autotune/domain/autotune_config_entity.dart` con tipos de escala, configuración inmutable y presets canónicos.
- [x] Implementar `lib/features/vocal_autotune/domain/scale_quantizer.dart` con cuantización exacta de escala musical, tónica y cálculo de ratio $\alpha = f_{\text{target}} / f_{\text{in}}$ con filtro de inercia temporal (`retuneSpeedMs`).
- [x] Implementar `lib/features/vocal_autotune/domain/td_psola_pitch_shifter.dart` para pitch-shifting en el dominio temporal sincronizado con marcas de cierre glótico (GCI) y ventanas de Hann.
- [x] Implementar `lib/features/vocal_autotune/domain/vocal_autotune_processor.dart` para procesar bloques PCM en tiempo real y tomas grabadas completas de audio.
- [x] Crear suite de pruebas de dominio `test/features/vocal_autotune/vocal_autotune_domain_test.dart` y validar el 100% de aserciones.

### Paso 2: Integración en Capa de Datos / ViewModel
- [x] Integrar `VocalAutoTuneProcessor` en `TunerViewModel`.
- [x] Exponer getters y métodos de control: `isAutoTuneActive`, `autoTuneConfig`, `toggleAutoTune()`, `updateAutoTuneConfig()`, `applyAutoTuneToTake()`.
- [x] Conectar el procesador en el ciclo de muestreo de audio y en la grabadora multitrack.

### Paso 3: Capa de Presentación (Modal y Acceso en Workspaces)
- [x] Diseñar `lib/features/vocal_autotune/presentation/vocal_autotune_modal.dart` con diales de retune speed, selectores de escala/tónica, tira de semitonos activos y botón de afinación de toma grabada.
- [x] Integrar `open_autotune_chip` en `ProductionWorkspaceView` y `LearningPracticeWorkspaceView`.
- [x] Crear pruebas de UI `test/features/vocal_autotune/vocal_autotune_ui_test.dart`.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecución de `flutter analyze` (cero advertencias).
- [x] Ejecución completa de `flutter test` verificando que todas las pruebas pasen al 100%.
- [x] Merge limpio de la rama feature hacia `main`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit base previo en rama `main` (`c87b7a6`).
- **Mitigación Inmediata:** Desactivación del chip de AutoTune en la interfaz o reversión del commit de merge.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Código adherido estrictamente a las reglas de [AGENTS.md](AGENTS.md).
- [x] Cero emojis en código, commits y comentarios.
- [x] 100% Clean Architecture (capa de dominio en Pure Dart).
- [x] Pruebas unitarias y de integración pasando al 100%.
- [x] Documentación técnica, caso de uso 39 y ADR 0035 redactados.
