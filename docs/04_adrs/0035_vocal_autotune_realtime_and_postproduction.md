# ADR 0035: Arquitectura del Motor de AutoTune Vocal en Tiempo Real y Post-Producción

## Estado
Aprobado

## Contexto
En los espacios de trabajo de **Producción** y **Aprender**, los usuarios requieren herramientas para mejorar y calibrar la afinación de la voz humana. La corrección tonal vocal (*Auto-Tune*) es un pilar estándar tanto en la práctica vocal pedagógica asistida (donde el estudiante necesita escuchar el centro tonal exacto para corregir su propio oído) como en la producción musical profesional (donde se corrigen tomas vocales grabadas y se aplican estilos estéticos desde afinación transparente de estudio hasta el clásico *Hard Tune* urbano).

Se evaluaron tres enfoques arquitectónicos:
1. **Modelos Neuronales Profundos (DDSP / RVC):** Descartados por requerir inferencia pesada (50 a 150 ms de latencia), pesos de modelos de decenas de megabytes y alto consumo de batería incompatible con dispositivos móviles.
2. **Phase Vocoder Frecuencial Puro:** Descartado para el flujo central de baja latencia por la latencia inherente de las ventanas STFT (15 a 30 ms) y la tendencia a generar artefactos de fase metálicos en voces solistas.
3. **TD-PSOLA (Time-Domain Pitch Synchronous Overlap-Add) con Scale Snapping y Filtro de Inercia:** Seleccionado como el estándar óptimo. Opera en el dominio del tiempo con latencia inferior a 5 ms, complejidad computacional $O(N)$ y preservación natural de los formantes del tracto vocal.

## Decisión
1. **Dominio Puro (`lib/features/vocal_autotune/domain/`):**
   - `AutoTuneConfigEntity`: Modela la configuración inmutable del efecto:
     - `scaleRoot`: Tónica de la escala (0 = Do, 1 = Do#, ..., 11 = Si).
     - `scaleType`: Tipo de escala musical (Cromática, Mayor, Menor Natural, Menor Armónica, Pentatónica Mayor, Pentatónica Menor, Blues).
     - `retuneSpeedMs`: Velocidad de corrección en milisegundos (0 ms para Hard Tune instantáneo, 15 a 50 ms para afinación natural de estudio).
     - `correctionAmount`: Grado de aproximación a la afinación perfecta (0.0 a 1.0).
     - `formantPreservation`: Booleano para fijar los formantes acústicos y evitar el efecto ardilla.
     - `leadVocalMix`: Nivel de mezcla seco/procesado (*dry/wet*).
     - Presets canónicos: *Estudio Natural*, *Pop Suave*, *Hard Tune Urbano*, *Armonizador Sutil*.
   - `ScaleQuantizer`: Motor matemático que cuantiza cualquier frecuencia fundamental $f_0$ a la frecuencia exacta de la nota permitida más cercana según la escala activa y calcula el ratio de corrección $\alpha = f_{\text{target}} / f_0$, suavizado mediante un filtro unipolar según `retuneSpeedMs`.
   - `TdPsolaPitchShifter`: Motor DSP en Pure Dart que aplica ventanas de Hann superpuestas sobre los periodos glóticos de las muestras PCM de audio, desplazando la fundamental en el ratio $\alpha$ calculado.
   - `VocalAutoTuneProcessor`: Procesador integral que orquesta la ingesta de audio, detección de tono, cuantización y resíntesis tanto para buffers continuos en tiempo real como para tomas completas grabadas.

2. **Integración en ViewModel y Flujo de Audio:**
   - Incorporar `VocalAutoTuneProcessor` en `TunerViewModel`.
   - Soporte dual:
     - *Tiempo Real:* Procesa los bloques de audio del micrófono cuando `isAutoTuneActive` está habilitado.
     - *Post-Producción:* Método `applyAutoTuneToRecordingTake(String takeId)` que genera una toma procesada en la grabadora multitrack, disponible para escucha comparativa y exportación de stems.

3. **Capa de Presentación (`lib/features/vocal_autotune/presentation/`):**
   - `VocalAutoTuneModal`: Modal con selectores de escala, perilla/slider de retune speed, visor de notas activas en la escala, barra de presets instantáneos y selector de tomas de grabación para post-procesamiento.
   - Acceso rápido en la barra de herramientas del espacio de Producción y Práctica.

## Consecuencias
- **Positivas:**
  - Latencia sub-10ms en monitoreo en vivo sin necesidad de servidores ni librerías binarias externas.
  - Soporte completo tanto para cantantes en práctica como para productores en edición de pistas grabadas.
  - Preservación de Clean Architecture (dominio 100% Pure Dart).
- **Negativas / Mitigaciones:**
  - El procesamiento intensivo de señales de audio en tiempo real debe ejecutarse con estructuras de datos eficientes (`Float64List` / `Int16List`) para minimizar la presión sobre el recolector de basura de Dart.
