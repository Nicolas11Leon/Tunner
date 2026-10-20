# ADR 0001: Arquitectura del Reloj de Audio No Bloqueante en Isolate y Pipeline DSP Local

---

## Estado
**Aprobado (Approved)** - Fecha: 2026-10-19

## Contexto
En aplicaciones de práctica musical interactiva y afinación acústica, la sincronización rítmica y la latencia son factores de éxito determinantes. En la versión preliminar del proyecto:
1. El reloj del metrónomo utilizaba un bucle `while (true)` sin descanso dentro de un `Isolate`, generando una condición de espera activa (*busy-waiting*) que consumía el 100% de la capacidad de un núcleo de CPU, agotando la batería y sobrecalentando el dispositivo del usuario.
2. La detección de tono imponía un filtro estático de $200\text{ a }3000\text{ Hz}$, imposibilitando la afinación de voces masculinas (bajos/barítonos), guitarras y bajos eléctricos.
3. Se contempló en discusiones iniciales la posibilidad de delegar procesamiento a microservicios externos o procesos distribuidos.

## Decisión
1. **Rechazo estricto de microservicios / servicios remotos:** Toda la arquitectura de audio y cómputo se consolida como un **Monolito Modular Local (In-Process)**. La música en vivo no tolera latencias de red ($>50\text{ ms}$). El procesamiento se ejecuta 100% en el procesador del dispositivo local.
2. **Reloj de Audio en Isolate con Rendición de CPU:** Se sustituye el bucle infinito del Isolate por un modelo de temporización determinista basado en `Timer.periodic` o suspensión compensada en microsegundos, rindiendo el tiempo ocioso al planificador del sistema operativo.
3. **Pipeline DSP Monofónico de Amplio Espectro con Noise Gate:**
   - Se amplía el espectro admisible al rango de $27.5\text{ Hz}$ ($A_0$) a $4186\text{ Hz}$ ($C_8$).
   - Se implementa un filtro de energía cuadrática media (RMS) previo al algoritmo de pitch para descartar ruido ambiente antes de consumir ciclos de cómputo en la autocorrelación.

## Consecuencias

### Positivas:
- **Reducción radical de consumo de energía:** El uso de CPU pasa del 100% a valores residuales inferiores al $1\%$, preservando la batería del móvil/portátil.
- **Universalidad de instrumentos y registros vocales:** La aplicación admite a cualquier cantante (desde bajo hasta soprano ligera) y a cualquier instrumento acústico o eléctrico.
- **Determinismo y 0 latencia de red:** Funciona en cualquier lugar sin necesidad de conexión a internet (offline-first).

### Negativas / Mitigaciones:
- La precisión de temporización en algunos sistemas operativos de escritorio puede tener jitter menor a $1-2\text{ ms}$; mitigado mediante compensación de drift acumulado en cada ciclo de pulso.
