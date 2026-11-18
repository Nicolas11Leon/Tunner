# Plan de Implementación: Matriz de Paneo Binaural y Espacialización 3D para Auriculares (HRTF)

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE7-BINAURAL-2026-0100`
- **Título de la Implementación:** Matriz de Paneo Binaural y Espacialización 3D para Auriculares (HRTF)
- **Fase del Proyecto:** Fase 7 (Procesamiento de Señal Acústica Avanzado y Espacialización 3D)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0100](../04_adrs/0100_binaural_hrtf_3d_spatial_panner.md)
- **Documento Funcional Base:** [Caso de Uso 111](../02_use_cases/111_uc_binaural_hrtf_3d_spatial_panner.md)
- **Issue Asociado:** [#38](https://github.com/Nicolas11Leon/Tunner/issues/38)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir en Dart puro el motor de espacialización binaural `BinauralPannerEngine` en `lib/core/audio/domain/spatial/`, implementando el modelo analítico de Woodworth para diferencias interaurales temporales (ITD) y filtros de sombra craneal para diferencias de nivel (ILD), integrándolo con la consola maestra de Tunner y el lenguaje declarativo Tunner DSL.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de coordenadas espaciales `BinauralPannerEntity` en `lib/core/audio/domain/spatial/`.
  - Motor DSP `BinauralPannerEngine` con líneas de retardo circular de ITD y filtros de sombra craneal ILD.
  - Integración en `StudioOsAudioKernelBridge` para órdenes `@spatial` en Tunner DSL.
  - Comando `spatial` en `TunnerOsKernel` para inspección y calibración interactiva.
  - Pruebas unitarias de física acústica, ángulos azimutales, ITD máximo y estabilidad matemática.
- **Excluido (Out-of-Scope):**
  - Algoritmo de entrenamiento auditivo y curva Ebbinghaus (asignado a Fase 8 e Issue #39).

---

## 2. Análisis de Dependencias y Tecnologías

- **Lenguaje:** Dart Puro (Domain Layer).
- **Estructura:** Búferes circulares de tamaño estático (64 muestras) en `Float32List`.
- **Rendimiento:** Latencia de cómputo $< 0.1\text{ ms}$ por búfer de 512 muestras.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Entidad de Coordenadas y Configuración Binaural (`binaural_panner_entity.dart`)
- Modelo inmutable con `azimuthDegrees`, `elevationDegrees`, `distanceMeters`, `headRadiusMeters` y métodos de copia.

### Paso 2: Motor de Paneo Binaural (`binaural_panner_engine.dart`)
- Algoritmo de Woodworth para cálculo de ITD:
  $$\text{ITD}(\theta) = \frac{r}{c}(\theta + \sin\theta)$$
- Filtros paso-bajo de 1 polo para simular la atenuación de agudos en el oído opuesto.
- Procesamiento estéreo `processStereo` y `processSample`.

### Paso 3: Integración en Micro-Kernel y CLI
- Registrar manejador `@spatial` en `StudioOsAudioKernelBridge` (`azimuth`, `elevation`, `distance`).
- Comando `spatial` en `TunnerOsKernel` (`spatial pan <azimuth> [elevation]`, `spatial status`).

### Paso 4: Pruebas Unitarias y de Regresión (`test/core/audio/`)
- `test/core/audio/binaural_panner_engine_test.dart`:
  - Prueba de ITD a $0^\circ$ (simétrico), $+90^\circ$ (retardo máximo izquierdo), $-90^\circ$ (retardo máximo derecho).
  - Prueba de ILD y atenuación de frecuencias en oído contralateral.
  - Prueba de atenuación por distancia.
  - Prueba de comandos CLI y script DSL.

---

## 4. Criterios de Aceptación (Definition of Done)

1. Localización binaural acústica matemáticamente precisa con ITD $\le 0.7\text{ ms}$.
2. Transición suave de parámetros sin clics auditivos ni discontinuidades en la señal.
3. Cobertura de pruebas unitarias al 100% pasando sin errores.
4. `flutter analyze` sin incidencias.
