# ADR 0045: Protocolo de Interoperabilidad Atómica y Bus de Eventos Desacoplado para Herramientas del Estudio

- **Estado:** Accepted
- **Fecha:** 2026-11-07
- **Fase:** Fase 4 & Global
- **Autor:** Tunner Architecture & DSP Core Team

---

## 1. Contexto

Tunner integra múltiples herramientas profesionales de audio y educación musical: afinador estroboscópico, metrónomo, pentagrama interactivo, grabador, analizador de acordes, espectrograma, procesador de afinación vocal y dron armónico. Cada herramienta fue diseñada con Clean Architecture de manera autónoma, pero el usuario requiere una experiencia de estudio cohesionada donde todas las herramientas se beneficien mutuamente (ej: el metrónomo marcando el pulso en el pentagrama y sincronizando la grabación, o el tono detectado por el micrófono alimentando el autotune y el espectrograma simultáneamente).

Conectar estas herramientas directamente entre sí (haciendo que el grabador importe al metrónomo, o el pentagrama al afinador) causaría un acoplamiento cuadrático $O(N^2)$, violaría los principios de Clean Architecture y rompería la atomicidad modular.

---

## 2. Decisión

Se adopta un **Bus de Eventos y Señales Fuertemente Tipadas (`SignalBus`)** basado en el patrón Publish/Subscribe en memoria local (`StreamController.broadcast`), complementado con contratos de puertos tipados (`PortId`, `SignalType`):

1. **Atomicidad de Nodos:** Cada módulo en el rack implementa la interfaz `InteroperableModuleNode` con métodos para registrar sus puertos y procesar eventos entrantes `handleIncomingSignal(AtomicSignalEvent event)`.
2. **Payloads Tipados Polimórficos (`AtomicSignalEvent`):**
   - `ClockTickEvent`: Pulsos temporales (tick, BPM, compás, tiempo en microsegundos).
   - `AudioPcmEvent`: Búfer de audio PCM en punto flotante `Float64List` / `List<double>`.
   - `PitchDetectionEvent`: Frecuencia fundamental $f_0$, desviación en cents, claridad armónica y nota musical.
   - `TransportEvent`: Acciones globales de reproducción, pausa, detención y grabación.
   - `TuningCalibrationEvent`: Frecuencia base de referencia $A_4$, temperamento musical y afinación microtonal.
3. **Cero Microservicios / 100% In-Process:** El bus opera enteramente en memoria local del proceso Flutter/Dart, garantizando latencias inferiores a $1\text{ ms}$ y cero dependencia de red.

---

## 3. Consecuencias

### Positivas:
- **Desacoplamiento Absoluto:** Los módulos no se conocen entre sí; solo conocen las interfaces y eventos del dominio de señales.
- **Extensibilidad Ilimitada:** Se puede agregar cualquier nueva herramienta (ej: un generador de ritmos o un sintetizador FM) simplemente registrando sus puertos de entrada y salida en el bus.
- **Sinergia en Vivo:** Múltiples herramientas pueden suscribirse a la misma señal (ej: el audio del micrófono fluye al afinador, al grabador y al espectrograma simultáneamente).

### Negativas / Mitigaciones:
- **Sobrecarga de Eventos de Alta Frecuencia:** Para señales de audio PCM completas, se transfieren referencias inmutables sin clonar la lista de muestras para evitar recolector de basura (GC pressure).
