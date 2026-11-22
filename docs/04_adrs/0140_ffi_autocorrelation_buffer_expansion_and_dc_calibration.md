# ADR 0140: Optimización FFI de Autocorrelación, Expansión de Búfer a 4096 para La0, Anclaje A4 y Calibración DC

## Estado
Aprobado

## Contexto
Durante la auditoría forense se encontraron las siguientes restricciones en la detección de tono y temperamentos:
1. `McleodPitchMethod.computeNsdf` recalculaba la suma de cuadrados de la señal en dos bucles anidados para cada retardo $\tau = 1 \dots \text{maxLag}$, incurriendo en una complejidad computacional $O(N \cdot \text{maxLag})$ en Dart puro, a pesar de existir la función de producto cruzado SIMD `tunner_autocorrelate` en C99.
2. A $44.1\text{ kHz}$, la nota más grave del espectro orquestal (La0 = 27.5 Hz) posee un periodo de $1603.6\text{ muestras}$. Disparar la detección con sólo 2048 muestras dejaba apenas 284 muestras de correlación útil ($2048 - 1764$), lo que producía una caída crítica en la claridad del pico NSDF e impedía detectar La0 con estabilidad.
3. En `TunerViewModel`, la llamada a `_temperamentEngine.getTargetFrequency` omitía el parámetro `anchorA4: true`, provocando que temperamentos históricos como Werckmeister o Mesotónico desplazaran la frecuencia de afinación de La4 respecto a la referencia seleccionada (440 Hz).
4. `SignalConditioningFilter` poseía la función estática `analyzeNoiseFrames` que medía el offset DC, pero su valor nunca se inyectaba en la instancia del filtro para sustraerlo de las muestras continuas.

## Decisión
1. **Optimización de NSDF:**
   - Precalcular el arreglo de sumas acumuladas de energía al cuadrado $E[k] = \sum_{i=0}^{k-1} x[i]^2$ en una sola pasada $O(N)$.
   - Para cada retardo $\tau$, computar el denominador en tiempo constante $O(1)$:
     $$\text{energySum} = E[n - \tau] + E[n] - E[\tau]$$
   - Habilitar la integración de `tunner_autocorrelate` para evaluar el numerador de convolución cruzada mediante C99 y aceleración vectorial cuando el enlace FFI esté disponible.
2. **Horizonte de Análisis de 4096 Muestras:**
   - En `PitchDetectorService`, permitir acumular hasta 4096 muestras completas ($92.8\text{ ms}$ a 44.1 kHz) para análisis de señales con componentes graves por debajo de 50 Hz, asegurando al menos 2.5 ciclos completos de La0 ($27.5\text{ Hz}$).
3. **Anclaje Inmutable de La4:**
   - En `TunerViewModel`, pasar explícitamente `anchorA4: true` al calcular desviaciones en cents con cualquier temperamento histórico.
4. **Calibración Activa de DC Offset:**
   - Agregar el campo mutable `double calibratedDcOffset` en `SignalConditioningFilter` que se sustrae directamente antes del acondicionamiento y ganancia.

## Consecuencias
- **Positivas:**
  - Reducción drástica del tiempo de CPU por frame en el Isolate de audio.
  - Soporte físico verificable de afinación para piano de 88 teclas, bajo eléctrico y contrabajo hasta La0 ($27.5\text{ Hz}$).
  - Coherencia acústica estricta con los estándares de afinación histórica (La4 = referencia).
- **Negativas:**
  - Un búfer de 4096 muestras añade aproximadamente 46 ms de latencia inicial de llenado para notas graves, balanceado adecuadamente por la ventana deslizante que se actualiza cada 512 muestras.
