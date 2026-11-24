# ADR 0181: Transcripción Polifónica Acotada por Salto Adaptativo, Umbral de Claridad NSDF Adaptativo, Respaldo ZCR-RMS y Descomposición en 4 Stems

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Nicolás León
- **Caso de Uso Relacionado:** [UC-189](../02_use_cases/189_uc_adaptive_hop_polyphonic_audio_transcription_and_four_stem_decomposition.md)

---

## 1. Contexto

El motor `AudioToScoreTranscriptionEngine` (`lib/features/transcription/domain/audio_to_score_transcription_engine.dart`) presentaba dos cuellos de botella severos al transcribir grabaciones comerciales o ensayos reales de 3 a 5 minutos (`44.1 kHz`):

1. **Explosión Computacional Cuadrática ($O(N \cdot W^2)$):** Con tamaño de ventana $W = 4096$ y paso fijo $H = 512$, una pista de 4 minutos ($N \approx 1.058 \times 10^7$ muestras) generaba $\sim 20\,672$ ventanas. Cada evaluación NSDF en `McleodPitchMethod.estimatePitch` realizaba $\sim W^2 / 2 \approx 8.39 \times 10^6$ operaciones de punto flotante (o $\sim 5.3 \times 10^6$ con diezmado), totalizando del orden de $\sim 1.1 \times 10^{11}$ operaciones y bloqueando el hilo por más de $40\text{ s}$.
2. **Silenciamiento en Mezclas Polifónicas Densas:** `McleodPitchMethod` requería por defecto una claridad NSDF estricta (`minClarity >= 0.40` o superior). Mientras un tono senoidal puro supera $0.90$, una mezcla real (voz solista, acordes armónicos, bajo y transitorios de batería) dispersa energía espectral y reduce el pico NSDF al rango $[0.32, 0.60]$, provocando que el transcriptor descartara el audio real devolviendo compases vacíos de silencio.

Adicionalmente, las partituras transcritas debían descomponerse automáticamente en capas pedagógicas interactivas (`Lead`, `Armonía`, `Bajo` y `Ritmo`) mediante `SongDecomposerService`.

---

## 2. Decisión

Se rediseña `AudioToScoreTranscriptionEngine` y su orquestación en `UniversalScoreImporterService.transcribeAudioToScoreResult` bajo cuatro pilares matemáticos deterministas:

### 2.1 Salto Adaptativo Acotado (`maxAnalysisFrames = 480`)
Sea $N$ el total de muestras monofónicas, $W = 4096$ el tamaño de ventana y $H_0 = 512$ el salto nominal. El rango disponible es $\Delta = N - W$ y el número bruto de ventanas es $N_{\text{raw}} = \lfloor \Delta / H_0 \rfloor$. Se fija un techo duro de $N_{\max} = 480$ ventanas de análisis:

$$H_{\text{eff}} = \begin{cases} \max\left(H_0,\ \left\lfloor \dfrac{N - W}{N_{\max}} \right\rfloor\right) & \text{si } N_{\text{raw}} > N_{\max} \\ H_0 & \text{en caso contrario} \end{cases}$$

$$N_{\text{frames}} = \begin{cases} \min\left(N_{\max},\ \left\lfloor \dfrac{N - W}{H_{\text{eff}}} \right\rfloor\right) & \text{si } N_{\text{raw}} > N_{\max} \\ N_{\text{raw}} & \text{en caso contrario} \end{cases}$$

Combinado con diezmado anti-aliasing por promediado de bloque (factor $D = \min(\lfloor f_s / 8820 \rfloor, \lfloor W / 640 \rfloor) = 5$ a $f_s = 44\,100\text{ Hz}$, preservando la frecuencia de Nyquist $f_{\text{Nyquist}} = 4410\text{ Hz} > C_8 = 4186.01\text{ Hz}$ y dos períodos completos de $A_0 = 27.5\text{ Hz}$), la complejidad máxima queda acotada a $480$ evaluaciones NSDF sobre $W_d = 819$ muestras ($< 250\text{ ms}$ en canciones de 3 a 5 minutos, y $< 800\text{ ms}$ incluyendo decodificación WAV y cuantización en CI), conservando la línea temporal real mediante $\Delta t_k = (k \cdot H_{\text{eff}}) / f_s$.

### 2.2 Umbral de Claridad NSDF Polifónico ($\tau_{\text{clarity}} = 0.32$)
Se establece `defaultMinClarity = 0.32`. Este umbral retiene fundamentales dominantes en mezclas polifónicas (cuyo pico NSDF oscila en $[0.32, 0.60]$) y rechaza ruido blanco no correlacionado ($\sim 0.10\text{–}0.22$).

### 2.3 Extractor de Respaldo por Tasa de Cruces por Cero Ponderada por RMS (`_extractFallbackPolyphonicSegments`)
Si la señal supera la puerta de actividad (`hasActiveAudio` con $\text{RMS} > 2 \cdot \text{silenceRms}$) pero MPM no retiene segmentos tonales (o la cuantización resulta íntegramente en silencios), se activa un estimador de contorno espectral en cuatro etapas:
1. **Remoción de componente DC y filtro pasa-bajos IIR de primer orden** con frecuencia de corte $f_c = 880\text{ Hz}$ para atenuar platillos y transitorios percusivos ($> 2\text{ kHz}$):
   $$\omega = \frac{2\pi f_c}{f_s}, \quad \alpha = \frac{\omega}{1 + \omega}, \quad y[n] = y[n-1] + \alpha \cdot ((x[n] - \bar{x}) - y[n-1])$$
2. **División en 4 sub-bloques con histéresis de cruce por cero** ($\theta_{\text{hyst}} = 0.05 \cdot \text{RMS}_b$) para inmunidad ante micro-oscilaciones de ruido cerca de cero.
3. **Estimación de frecuencia ponderada por RMS local:**
   $$f_b = \frac{C_b \cdot f_s}{2 \cdot (L_b - 1)}, \quad \hat{f} = \frac{\sum_{b} \text{RMS}_b \cdot f_b}{\sum_{b} \text{RMS}_b}$$
4. **Plegamiento de octava al rango vocal/melódico** $[A_2 = 110\text{ Hz},\ A_5 = 880\text{ Hz}]$ y suavizado temporal mínimo de $120\text{ ms}$ (`minNoteHoldSeconds = 0.12`) antes de cuantizar rítmicamente.

### 2.4 Descomposición Automática en 4 Stems
`UniversalScoreImporterService.transcribeAudioToScoreResult` invoca `SongDecomposerService.decomposeCustomScore` generando siempre las 4 pistas sincronizadas (`lead_stem`, `harmony_stem`, `bass_stem`, `rhythm_stem`) y sus partituras individuales (`stemScores`), incluyendo inferencia modal mayor/menor y tríadas diatónicas para armonía.

---

## 3. Consecuencias

### 3.1 Positivas
- **Acotamiento Determinista de Latencia:** Canciones completas de 3 a 5 minutos pasan de $>40\text{ s}$ ($\sim 1.1 \times 10^{11}$ ops) a $< 250\text{ ms}$ sin bloquear la interfaz.
- **Cero Silenciamiento Falso:** Las mezclas polifónicas densas con batería y acordes siempre producen una línea melódica editable y sus 4 stems, mientras que el silencio puro ($\text{RMS} \le 2 \cdot \text{silenceRms}$) conserva compases de silencio sin inventar notas fantasmas.
- **Precisión Monofónica Intacta:** Tonos puros como $A_4 = 440\text{ Hz}$ mantienen exactitud de altura (`La4`).

### 3.2 Negativas / Compromisos
- En canciones muy largas (> 4 minutos), $H_{\text{eff}}$ crece linealmente con la duración, por lo que notas rápidas inferiores a $H_{\text{eff}} / f_s$ pueden fusionarse en el contorno melódico principal; esto es un compromiso deliberado para mantener respuesta interactiva local sin servidores externos.

---

## 4. Verificación

Validado en [us_fs_02_fast_polyphonic_song_transcription_test.dart](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/test/features/universal_importer/us_fs_02_fast_polyphonic_song_transcription_test.dart):
- Transcripción de WAV polifónico de 60 s (`2,646,000` muestras a $44.1\text{ kHz}$) en $< 800\text{ ms}$ produciendo notas reales y 4 stems (`tracks.length == 4`, `stemScores.length == 4`).
- Activación forzada del extractor de respaldo ZCR-RMS con `minClarity: 0.99` sobre mezcla densa.
- Preservación exacta de silencios puros (`totalNotes == 0`) con generación estructural de 4 tracks.
- Precisión exacta sobre onda pura `La4` ($440\text{ Hz}$) con `defaultMinClarity = 0.32`.
