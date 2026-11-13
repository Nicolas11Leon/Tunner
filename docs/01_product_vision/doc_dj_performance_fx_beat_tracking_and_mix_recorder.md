# Architecture & Technical Specification: DJ Performance FX Suite, Algorithmic Beat Tracking and Live Mixdown Master Recorder

Este documento define la arquitectura técnica, modelos matemáticos, algoritmos de procesamiento de señal (DSP) e interfaces de usuario para la suite unificada de efectos en vivo, detección automática de BPM y grabación de mezcla maestra en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-066`
- **Título Oficial:** Suite Integral de Performance DJ: Filtro Bipolar Sweep, Retardo Cuantizado por Tempo, Estimador Algorítmico de BPM por Transientes y Grabador de Sesión Master a 0 dBFS
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-11-13
- **Última Modificación:** 2026-11-13
- **Fase Asociada:** Fase 3 (Herramientas Creativas Avanzadas) & Fase 4 (Estudio de Producción)
- **Autor / Revisor Principal:** Mantenedor de Arquitectura de Audio Digital Tunner

---

## 1. Resumen Ejecutivo (Executive Summary)

Esta especificación consolida la evolución de la Consola de DJ Virtual de Tunner en una estación de trabajo completa para mezcla en vivo. La arquitectura introduce tres pilares sinérgicos:
1. **Detección Algorítmica de Tempo (BpmBeatTrackerEngine):** Análisis de energía temporal y flujo de transientes (*Onset Energy Flux*) para deducir el tempo de pistas de audio locales y stems en menos de 50 milisegundos sin requerir intervención manual.
2. **Rack de Efectos de Canal en Vivo (DjChannelFxEntity):** Filtro bipolar de barrido continuo (Low-Pass resonante al girar a la izquierda, High-Pass al girar a la derecha con corte neutral en $0.0$) y unidad de Delay/Echo sincronizada métricamente con las subdivisiones del reloj del metrónomo ($1/2, 1/4, 1/8, 1/16$ de compás).
3. **Grabador de Mezcla Maestra en Vivo (DjLiveMixRecorderEntity):** Sistema de captura no bloqueante en buffer circular que registra la suma post-crossfader y la masteriza directamente a formato WAV PCM lineal de 16 bits sin pérdida, aplicando compresión suave (*soft-clipping tanh*) para garantizar la integridad dinámica por debajo de $0\text{ dBFS}$.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema

Una consola DJ sin procesamiento de efectos, estimación de tempo y grabación limita la capacidad expresiva del intérprete a meros cortes de volumen. La transición entre temas requiere tradicionalmente:
- Conocer de antemano el tempo de las canciones o calcularlo mediante toques manuales repetidos (*Tap Tempo*).
- Modificar el balance espectral mediante filtros dinámicos (barridos de filtro que limpian frecuencias graves o agudas progresivamente).
- Crear transiciones espaciales mediante ecos temporizados (*Dub Delays*) que ocultan el cambio de compás.
- Preservar el resultado final de la sesión de mezcla para estudio posterior, evaluación docente o publicación.

### 2.2 Fundamento Matemático y Físico

#### 2.2.1 Filtro Bipolar de Barrido Resonante (Dual Filter Sweep)

El parámetro de filtro de canal $k \in [-1.0, 1.0]$ modula una estructura biquad de segundo orden:
- **Posición Neutral ($k = 0.0$):** Bypass absoluto (filtro desactivado, respuesta plana en todo el espectro $20\text{ Hz} - 20\text{ kHz}$).
- **Barrido Low-Pass ($k < 0.0$):**
  La frecuencia de corte $f_c$ decrece logarítmicamente desde $20\text{ kHz}$ hasta $60\text{ Hz}$:
  $$f_c(k) = 20000 \cdot 10^{2.52 \cdot k} \quad (k \in [-1.0, 0.0))$$
  A medida que $k \to -1.0$, se suprimen los armónicos agudos y medios, aislando únicamente el sub-grave percusivo.
- **Barrido High-Pass ($k > 0.0$):**
  La frecuencia de corte $f_c$ se incrementa exponencialmente desde $20\text{ Hz}$ hasta $12\text{ kHz}$:
  $$f_c(k) = 20 \cdot 10^{2.78 \cdot k} \quad (k \in (0.0, 1.0])$$
  A medida que $k \to +1.0$, se eliminan por completo los bombos y bajos, permitiendo transiciones suaves de pistas entrantes sin saturar el rango sub-grave.
- **Resonancia $Q$:** Se aplica un factor de calidad constante $Q = 1.414$ (Butterworth) con elevación suave de $+2\text{ dB}$ en la vecindad de $f_c$ para otorgar el carácter percusivo característico de las mesas de club.

#### 2.2.2 Retardo Sincronizado a Beat (Beat-Synced Delay)

El retardo temporal $\tau$ en muestras depende del tempo efectivo del deck ($\text{BPM}$) y la tasa de muestreo $f_s$:
$$T_{\text{beat}} = \frac{60.0}{\text{BPM}} \quad (\text{segundos por negra})$$
Para una subdivisión musical configurable $S \in \{1/2, 1/4, 1/8, 1/16\}$:
$$\tau = \left\lfloor S \cdot T_{\text{beat}} \cdot f_s \right\rfloor \quad (\text{muestras})$$
La ecuación en diferencias finitas de la línea de retardo con realimentación (*feedback* $g_{\text{fb}} \in [0.0, 0.8]$) y balance *Dry/Wet* ($w \in [0.0, 1.0]$) se define como:
$$y[n] = (1 - w) \cdot x[n] + w \cdot d[n]$$
$$d[n] = x[n - \tau] + g_{\text{fb}} \cdot d[n - \tau]$$

#### 2.2.3 Estimación de BPM por Flujo de Transientes (Onset Beat Tracker)

Dado un búfer de audio $x[n]$, se calcula la energía enventanada en bloques de $M = 1024$ muestras con solapamiento del 50%:
$$E[m] = \sum_{k=0}^{M-1} x[m \cdot H + k]^2, \quad H = 512$$
La función de detección de transientes (*Onset Detection Function*) representa la primera derivada rectificada de la energía:
$$O[m] = \max(0, E[m] - E[m - 1])$$
Se calcula la autocorrelación de $O[m]$ para retardos $\ell$ correspondientes al rango de tempos estándar de música de club ($60\text{ BPM} \le \text{BPM} \le 180\text{ BPM}$):
$$R[\ell] = \sum_{m} O[m] \cdot O[m - \ell]$$
El período de beat estimado $\ell^*$ corresponde al máximo argumento de $R[\ell]$ dentro del rango permitido, permitiendo deducir el tempo con error inferior a $0.5\text{ BPM}$:
$$\text{BPM} = \frac{60 \cdot f_s}{H \cdot \ell^*}$$

---

## 3. Especificación Funcional Detallada

### 3.1 Requerimientos Funcionales del Sistema

- **REQ-01 (Dual Bipolar Filter Knobs):** Cada deck posee un control de filtro rotativo/deslizante centrado en $0.0$. Mover a la izquierda activa LPF; mover a la derecha activa HPF.
- **REQ-02 (Beat-Synced Delay Unit):** Control de encendido/apagado de retardo, selector de división rítmica ($1/2, 1/4, 1/8, 1/16$) y perilla de mezcla Dry/Wet por canal.
- **REQ-03 (Automated Onset Beat Tracking):** Al cargar cualquier archivo de audio o stem en un deck, el motor estima el BPM automáticamente y actualiza la entidad del deck.
- **REQ-04 (Live Mixdown Recorder):** Botón maestro de grabación (REC) con temporizador en vivo. Al detener la grabación, se compila un archivo WAV canónico estéreo y se notifica al usuario con el tamaño y ruta del archivo exportado.
- **REQ-05 (Stem Ingestion Synergy):** Modal de carga rápida que permite seleccionar cualquier pista generada por el sintetizador SoundFont o la biblioteca de canciones y asignarla directamente al Deck A o Deck B.

---

## 4. Diseño Técnico y Arquitectura de la Solución

```
+---------------------------------------------------------------------------------+
|                            Presentation Layer                                   |
|   DjConsoleModal (Knobs Filtro, Delay Chips, REC Button, Stem Loader Modal)     |
+----------------------------------------+----------------------------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                            DjConsoleViewModel                                   |
|  - Coordina despacho de acciones FX, grabación y actualización reactiva         |
+----------------------------------------+----------------------------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                             Domain Layer (Puro Dart)                            |
|  - DjChannelFxEntity: Modelado matemático de filtro bipolar y retardo sincronizado|
|  - BpmBeatTrackerEngine: Algoritmo de detección de transientes y autocorrelación|
|  - DjLiveMixRecorderEntity: Buffer circular de grabación y metadata de toma     |
|  - DjPerformanceOrchestrator: Despacho unificado de acciones FX y transporte     |
+----------------------------------------+----------------------------------------+
                                         |
                                         v
+---------------------------------------------------------------------------------+
|                       Data / Infrastructure Layer                               |
|  - DjAudioProcessor: Procesamiento de líneas de delay y filtros biquad en audio |
|  - DjMixWavEncoder: Serialización binaria canónica a formato RIFF WAV 16-bit    |
+---------------------------------------------------------------------------------+
```

---

## 5. Criterios de Rendimiento y Benchmarking

- **Latencia de Procesamiento FX:** $\le 2\text{ ms}$ adicionales en el buffer de mezcla estéreo.
- **Consumo de Memoria en Grabación:** Buffer preasignado en memoria con escritura secuencial determinista sin fugas ni fragmentación de memoria.
- **Estimación de Tempo:** Cálculo de BPM en menos de $45\text{ ms}$ para un búfer de análisis de 5 segundos.

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] Pruebas unitarias de corte de filtro bipolar en frecuencias agudas y graves.
- [ ] Pruebas unitarias del algoritmo de detección de BPM con ondas sintéticas a 120, 128 y 140 BPM.
- [ ] Pruebas unitarias de línea de retardo (cálculo de muestras de delay y realimentación).
- [ ] Pruebas de grabación y exportación de encabezado RIFF WAV.
- [ ] Pruebas de widgets e interfaz de usuario para los nuevos controles de consola.

---

## 7. Referencias Técnicas

1. *Bristow-Johnson, R. (2001). Cookbook formulae for audio EQ biquad filter coefficients.*
2. *Dixon, S. (2001). Automatic Extraction of Tempo and Beat from Acoustic Musical Signals. Journal of New Music Research.*
3. *Roads, C. (1996). The Computer Music Tutorial. MIT Press.*