# Plan de Implementación: Procesador de Reverberación Algorítmica Schroeder-Moorer y Convolución IR 100% Offline

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE7-REVERB-2026-0099`
- **Título de la Implementación:** Procesador de Reverberación Algorítmica Schroeder-Moorer y Convolución IR 100% Offline
- **Fase del Proyecto:** Fase 7 (Procesamiento de Señal Acústica Avanzado y Espacialización 3D)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0099](../04_adrs/0099_schroeder_moorer_reverb_and_convolution.md)
- **Documento Funcional Base:** [Caso de Uso 110](../02_use_cases/110_uc_schroeder_moorer_reverb_and_convolution.md)
- **Issue Asociado:** [#37](https://github.com/Nicolas11Leon/Tunner/issues/37)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Desarrollar en Dart puro los componentes matemáticos de reverberación espacial en `lib/core/audio/domain/reverb/`, que incluyen el filtro en peine con amortiguación, el filtro paso-todo de Schroeder, el motor completo de reverberación estéreo `SchroederReverbEngine` y el procesador de convolución offline `IrConvolutionProcessor`, integrándolos con la cadena DSP de masterización y el micro-kernel DSL.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `comb_filter.dart`: Búfer circular Float32List, retardo fijo y filtro paso-bajo de amortiguación.
  - `all_pass_filter.dart`: Búfer circular Float32List, retardo fijo y factor de dispersión de fase.
  - `schroeder_reverb_engine.dart`: Matriz de 4 filtros en peine + 2 paso-todo, soporte estéreo decorrelacionado, parámetros Room Size, Damping, Pre-Delay y Dry/Wet.
  - `ir_convolution_processor.dart`: Convolución acústica en el dominio temporal para respuestas al impulso offline.
  - Integración en `StudioOsAudioKernelBridge` para modulación vía Tunner DSL (`set @reverb...`).
  - Pruebas unitarias exhaustivas de estabilidad numérica, respuesta en frecuencia y mezcla.
- **Excluido (Out-of-Scope):**
  - Matriz de paneo binaural con funciones de transferencia relativa a la cabeza (HRTF) (asignado a Épica 7.2 e Issue #38).

---

## 2. Análisis de Dependencias y Tecnologías

- **Lenguaje:** Dart Puro (Domain Layer).
- **Estructuras de Datos:** `Float32List` preasignado para procesamiento SIMD/DSP sin sobrecarga de memoria ni GC.
- **Rendimiento:** Menos de 2 ms por bloque estéreo de 1024 muestras.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Primitivas DSP de Filtros (`lib/core/audio/domain/reverb/`)
- Implementar `CombFilter` con búfer circular indexado con puntero rotativo y filtro de realimentación de un polo.
- Implementar `AllPassFilter` con dispersión de fase uniforme sin alteración de amplitud.

### Paso 2: Motor Estéreo Schroeder-Moorer (`schroeder_reverb_engine.dart`)
- Construir `SchroederReverbEngine` con banco de filtros por canal izquierdo y derecho con compensación de decorrelación estéreo.
- Proporcionar métodos `processStereo` y `processSample`.

### Paso 3: Convolución Discreta Offline (`ir_convolution_processor.dart`)
- Implementar convolución directa $y[n] = \sum x[n-k] h[k]$ con soporte para normalización de ganancia pico.

### Paso 4: Integración en el Micro-Kernel y Tunner DSL
- Añadir el target `@reverb` en `StudioOsAudioKernelBridge` para soporte de comandos como:
  - `set @reverb.room = 0.8;`
  - `set @reverb.wet = 0.3;`
  - `set @reverb.damping = 0.4;`

### Paso 5: Pruebas Unitarias y de Regresión (`test/core/audio/`)
- `test/core/audio/schroeder_reverb_engine_test.dart`: Verificar respuesta al impulso, estabilidad de feedback, decorrelación estéreo y convolución de Dirac.

---

## 4. Criterios de Aceptación (Definition of Done)

1. `SchroederReverbEngine` procesa búferes de audio estéreo sin derivas numéricas ni pausas de GC.
2. `IrConvolutionProcessor` produce convolución matemáticamente idéntica a la respuesta ideal ante un impulso Dirac unitario.
3. Cobertura de pruebas unitarias al 100% pasando sin fallos.
4. `flutter analyze` reporta 0 advertencias.
