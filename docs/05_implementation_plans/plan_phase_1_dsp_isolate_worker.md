# Implementation Plan: Dedicated Background Isolate for DSP Pitch Estimation

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-DSP-ISOLATE-2026-003`
- **Título de la Implementación:** `Aislamiento del Pipeline DSP y Estimación de Tono en Hilo Secundario (Dedicated Worker Isolate)`
- **Fase del Proyecto:** `Fase 1`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `docs/04_adrs/0001_in_process_isolate_clock_and_dsp_pipeline.md`
- **Documento Funcional Base:** `docs/02_use_cases/01_uc_acoustic_pitch_detection.md` y `docs/02_use_cases/04_uc_virtual_strobe_tuner.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Trasladar la carga computacional pesada del procesamiento de señales digitales (cálculo de potencia cuadrática media RMS y el algoritmo de autocorrelación/YIN de `pitch_detector_dart`) desde el hilo principal de la aplicación hacia un `Isolate` de fondo dedicado en Dart. Con esto se asegura que el hilo de renderizado de Flutter tenga **0 microsegundos de consumo por DSP**, garantizando que el widget estroboscópico (`StrobeTunerWidget`) opere a 60/120 FPS sin tirones (*zero frame drops*), incluso en pasajes rápidos de violín, flauta o guitarra con alta densidad de muestras de audio.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Refactorización de `lib/data/pitch_detector_service.dart`:
    - Creación de un `Isolate` persistente (`_dspIsolate`) con puertos bidireccionales (`SendPort` / `ReceivePort`).
    - Delegación del cálculo de energía RMS y de `PitchDetector().getPitchFromIntBuffer(data)` exclusivamente al Isolate.
    - Envío del resultado final ($F_0$ en Hz) al hilo principal a través del puerto de mensajes.
    - Ciclo de vida limpio: terminación del `Isolate` y cierre de puertos al detener la grabación (`stopRecording()`).
- **Excluido (Out-of-Scope):**
  - Modificaciones en la UI (la interfaz ya está integrada y consumiendo el stream a través de `TunerViewModel`).
  - Síntesis de audio (UC-05).

---

## 2. Análisis de Dependencias y Tecnologías

- **Librerías:** `dart:isolate`, `dart:async`, `package:flutter/foundation.dart`, `package:record/record.dart`, `package:pitch_detector_dart/pitch_detector.dart`.
- **Riesgo Tecnológico:** **Bajo**. El paso de buffers PCM entre Isolates en Dart moderno se realiza por copia optimizada o transferencia directa de memoria en hilos nativos del sistema operativo, sin sobrecarga de recolección de basura (*Garbage Collection*).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Verificar que no existan dependencias circulares entre el Isolate de audio y la UI. Los mensajes transferidos a través del puerto deben ser tipos de datos primitivos (`Uint8List`, `List<int>`, `double`).

### Paso 2: Capa de Infraestructura / Datos (Implementación del Worker Isolate)
- [ ] Definir la función estática de punto de entrada del Isolate: `_dspWorkerEntrypoint(SendPort toMainPort)`.
- [ ] Establecer el protocolo de comunicación por mensajes:
  - Inicialización: El worker crea un `ReceivePort` y envía su `SendPort` al hilo principal.
  - Flujo de datos: El hilo principal captura el paquete PCM del micrófono y lo envía al worker: `workerSendPort.send(data)`.
  - Procesamiento en el worker:
    1. Cálculo de energía RMS: Si la energía es inferior al umbral, descarta el buffer y retorna `0.0`.
    2. Ejecución de `pitchDetector.getPitchFromIntBuffer(data)`.
    3. Si detecta tono dentro del espectro ($27.5\text{ a }4186.0\text{ Hz}$), envía el valor al hilo principal: `toMainPort.send(pitch)`.
- [ ] Implementar la destrucción segura del Isolate en `stopRecording()`.

### Paso 3: Capa de Presentación (Verificación de Rendimiento UI)
- [ ] Verificar que `TunerViewModel` recibe los eventos de tono idénticos sin necesidad de alterar su lógica de negocio.
- [ ] Comprobar que la rotación estroboscópica y el movimiento del playhead se mantienen completamente fluidos.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecutar `flutter analyze` (0 errores).
- [ ] Ejecutar `flutter test` (100% pruebas pasando).
- [ ] Commit y sincronización con GitHub en la rama `main`.

---

## 4. Estrategia de Rollback

- Si la comunicación entre Isolates genera latencia de mensajes en plataformas web o móviles antiguas, se conservará la posibilidad de conmutar a ejecución síncrona mediante un flag interno.
- Punto de restauración Git: `eda5c75`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Cero llamadas al algoritmo de pitch en el hilo principal de Flutter.
- [ ] Detección acústica instantánea y reactiva ante solos rápidos.
- [ ] Destrucción y liberación completa de memoria del Isolate al detener el micrófono.
- [ ] Suite de pruebas pasando sin fallos.
- [ ] Sincronizado en `main`.
