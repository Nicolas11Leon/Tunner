# Architecture Decision Record (ADR): 0142

## 1. Contexto y Problema
En la auditoría forense de la Consola DJ se constató que:
1. `mixBuffers` en `DjAudioProcessor` no recibía ni procesaba los estados de aislamiento de stems (`DjStemIsolationEntity`), por lo cual silenciar voces, bajo o percusión en la vista Pro Workstation no se reflejaba en el audio mezclado ni en las grabaciones.
2. Los kill switches de ecualización (`isKillLow`, `isKillMid`, `isKillHigh`) no eran pasados al método `mixBuffers` en el ViewModel; se enviaban únicamente las ganancias `gainLow`, `gainMid`, `gainHigh`.
3. El filtro de ecualización de 3 bandas sufría fugas armónicas hacia la banda media debido a una estructura de filtro monopolar simple, impidiendo el corte total tipo isolator (-infinito dB).
4. El procesamiento de retardo (`applyDelay`) era completamente sin estado (`stateless`): asignaba un buffer nuevo en cada llamada, eliminando las colas de delay y los ecos entre bloques consecutivos del ticker de reproducción.

## 2. Decisión Tomada
1. **Integración de Stems en `mixBuffers`:**
   Incorporar parámetros opcionales `stemsA` y `stemsB` en `DjAudioProcessor.mixBuffers`, invocando `applyStemIsolation` de forma determinista antes de la etapa de ecualización y filtrado.
2. **Soporte de Kill Switches con Corte Total:**
   Conectar los estados `isKillLow`, `isKillMid`, `isKillHigh` en `DjConsoleViewModel` para evaluar ganancias de cero absoluto cuando el kill esté activo. En `apply3BandEq`, forzar ganancia cero estricta y asegurar atenuación total de la banda eliminando fugas hacia la banda media.
3. **Línea de Retardo de Estado Persistente (`StatefulDelayLine`):**
   Implementar una estructura circular con punteros persistentes de lectura/escritura y búfer estático preasignado para Deck A y Deck B en `DjAudioProcessor`. Esto garantiza que los ecos y reflexiones de delay persistan de forma natural y sin clics a través de bloques sucesivos de audio en tiempo real.
4. **Filtro Bipolar Continuo:**
   Garantizar que el filtro bipolar responda sin discontinuidades en todo el recorrido: [-1.0, 0.0) como paso-bajo y (0.0, 1.0] como paso-alto, con 0.0 como bypass puro.

## 3. Consecuencias
- **Positivas:**
  - Acoples, mashups en vivo y mezclas aisladas de acapellas e instrumentales son 100% audibles y capturados en la grabación de mezcla en vivo.
  - El efecto de delay produce colas rítmicas auténticas y sincronizadas al tempo.
  - Cero clics y cero fugas en los cortes de kill switch.
- **Negativas / Mitigaciones:**
  - Mayor consumo de memoria para los buffers de delay persistentes (~88,200 muestras por deck a 44.1 kHz, ~350 KB por canal), lo cual es despreciable en dispositivos móviles modernos.
