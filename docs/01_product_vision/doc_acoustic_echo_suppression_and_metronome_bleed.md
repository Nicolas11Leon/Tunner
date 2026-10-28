# Especificación Técnica: Supresión de Eco Acústico y Eliminación de Sangrado del Metrónomo (Acoustic Echo Suppression - AES)

## Metadatos del Documento
- **ID del Documento:** `DOC-AUDIO-2026-AES-01`
- **Título Oficial:** Supresión de Eco Acústico, Filtrado de Sangrado del Metrónomo y Clic Percusivo Atonal
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-27
- **Fase Asociada:** Fase 10 (Acoustic Hardening & Audio Cleanliness)
- **Autor / Revisor Principal:** Equipo de Arquitectura de Audio Digital Tunner

---

## 1. Resumen Ejecutivo (Executive Summary)

Durante la práctica musical con el micrófono y el metrónomo activos simultáneamente en altavoces de dispositivos móviles o computadores, el transductor del micrófono capta inevitablemente el sonido emitido por el altavoz (acoplamiento acústico o *bleed*). 

Cuando el clic del metrónomo se sintetiza mediante ondas senoidales puras, los detectores de tono basados en autocorrelación (como el Método de McLeod / MPM) detectan el clic como una nota musical legítima (típicamente $C\#_7 \approx 2200\text{ Hz}$ o $F_6 \approx 1400\text{ Hz}$), desestabilizando el afinador, contaminando la transcripción y marcando falsos errores en la evaluación de notas.

Este documento establece la arquitectura de **Supresión de Eco Acústico (Acoustic Echo Suppression - AES)** y rediseño de síntesis percusiva de Tunner para garantizar que el metrónomo jamás sea detectado como nota musical, preservando la detección transparente y precisa de los instrumentos del músico.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
1. **Acoplamiento Físico Altavoz-Micrófono:** La distancia física entre el altavoz y el micrófono en un teléfono inteligente o portátil es de apenas 5 a 15 centímetros, resultando en un retardo acústico de propagación menor a 0.5 ms ($c \approx 343\text{ m/s}$).
2. **Periodicidad Espuria de Ondas Senoidales:** El algoritmo McLeod Pitch Method (MPM) calcula la función de diferencia cuadrada normalizada (NSDF):
$$r_t(\tau) = \frac{2 \sum_{j=0}^{W-1} x_j x_{j+\tau}}{\sum_{j=0}^{W-1} x_j^2 + \sum_{j=0}^{W-1} x_{j+\tau}^2}$$
Para una onda senoidal pura de $2200\text{ Hz}$, $r_t(\tau)$ alcanza un pico máximo cercano a $1.0$ en $\tau = \frac{f_s}{2200} \approx 20\text{ muestras}$, superando con creces el umbral de claridad de tono ($k_{\text{clarity}} \ge 0.80$). El detector clasifica el clic como un tono musical continuo.

### 2.2 Fundamento de la Solución Acústica

#### Pilar A: Síntesis de Clic Percusivo Atonal con Barrido de Frecuencia (Chirp)
En lugar de una onda senoidal estática, el clic se sintetiza como un transitorio percusivo de madera (*woodblock transient*) con barrido descendente de frecuencia exponencial en menos de 4 ms:
$$f(t) = f_{\text{start}} \cdot e^{-\alpha t}$$
Donde la frecuencia se dispersa rápidamente a través de múltiples retardos $\tau$ dentro de la ventana de análisis de 46 ms. Al no existir una periodicidad sostenida, la autocorrelación $r_t(\tau)$ se dispersa uniformemente, arrojando picos de claridad inferiores a $0.35$ ($< 0.80$). El algoritmo MPM descarta la señal automáticamente como ruido no tonal (`pitched = false`).

#### Pilar B: Ventana de Atenuación Temporal (Acoustic Blanking Gate)
En el dominio de la aplicación, el software conoce con precisión de microsegundos el instante exacto en que emite el pulso del metrónomo ($T_{\text{click}}$). Se implementa una compuerta temporal inteligente:
$$\Delta t_{\text{gate}} = [T_{\text{click}}, T_{\text{click}} + \tau_{\text{decay}}]$$
con $\tau_{\text{decay}} \approx 65\text{ ms}$. Durante este intervalo:
- Si el frame detectado es un pico aislado en frecuencias de clic o transitorio, se suprime.
- Si el instrumentista ya se encontraba sosteniendo una nota continua (e.g. $A_4 = 440\text{ Hz}$ mantenida durante 500 ms), la nota sostenida se preserva sin interrupción, evitando que el transitorio del metrónomo introduzca notas fantasma en la partitura.

---

## 3. Especificación Funcional

- **REQ-AES-01:** La síntesis del metrónomo debe generar un sonido percusivo nítido y audible para el oído humano, pero con función de autocorrelación plana y dispersa, de modo que el motor MPM no reporte `pitched == true`.
- **REQ-AES-02:** El componente `AcousticEchoSuppressor` debe interceptar y descartar frames de tono atribuibles al sangrado del clic en un radio de 65 ms tras la emisión de cada pulso.
- **REQ-AES-03:** Las notas sostenidas legítimas del instrumentista no deben sufrir pausas perceptibles ni interrupciones durante el clic del metrónomo.
- **REQ-AES-04:** Cero asignaciones pesadas o pausas en el bucle principal de la interfaz de usuario.
