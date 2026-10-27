# Product Vision: McLeod Pitch Method (MPM) High-Precision Pitch Detection

Este documento define la especificación técnica, fundamento matemático y valor educativo del motor acústico de detección de tono basado en el algoritmo **McLeod Pitch Method (MPM)** en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-DSP-2026-MPM`
- **Título Oficial:** Motor Acústico de Detección de Frecuencia Fundamental mediante McLeod Pitch Method con NSDF e Interpolación Parabólica
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** Fase 5 (Vanguardia Acústica y Aprendizaje Musical)
- **Autor / Revisor Principal:** Equipo de Arquitectura Acústica y DSP de Tunner

---

## 1. Resumen Ejecutivo (Executive Summary)

El afinador y la suite de evaluación de **Tunner** requieren una detección instantánea y sin ambigüedad de la frecuencia fundamental ($f_0$) de instrumentos melódicos (flauta travesera, vientos, cuerdas, voz humana). Los algoritmos tradicionales de autocorrelación y versiones básicas de YIN son vulnerables a "saltos de octava" (octave doubling o octave halving) cuando los armónicos superiores o formantes superan en energía al tono fundamental.

El **McLeod Pitch Method (MPM)**, desarrollado por Philip McLeod y Geoff Wyvill (2005), resuelve este problema fundamental mediante el cálculo de la **Función de Diferencia Cuadrada Normalizada (NSDF)**, la selección de picos con umbral dinámico (*dynamic peak picking*) y el refinamiento mediante **interpolación parabólica sub-muestra**. Con esta integración en puro Dart en el Isolate de audio, Tunner alcanza una exactitud de submúltiplos de cent ($\pm 0.1$ cents) y una resiliencia acústica de nivel orquestal sin dependencias externas propietarias.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Instrumentos como la flauta travesera producen un timbre acústico con sobretonos armónicos prominentes y ruido de soplido (breath noise). En el registro grave o medio, el segundo armónico ($2 f_0$) puede presentar una amplitud superior al fundamental ($f_0$). Los detectores simples caen en el error de salto de octava hacia arriba, desestabilizando el visualizador estroboscópico y la puntuación de práctica.

### 2.2 Fundamento Matemático del McLeod Pitch Method (MPM)

#### 2.2.1 Conversión y Normalización PCM 16-bit
El flujo de entrada proporciona muestras continuas cuantizadas en 16 bits little-endian:
$$x[n] = \frac{\text{pcm16}[n]}{32768.0} \in [-1.0, 1.0]$$

#### 2.2.2 Función de Diferencia Cuadrada Normalizada (NSDF)
Para una ventana de análisis de longitud $W$ y un desfase temporal (*lag*) $\tau$:
$$r'_t(\tau) = \frac{2 \sum_{j=0}^{W - \tau - 1} x[j] \cdot x[j + \tau]}{\sum_{j=0}^{W - \tau - 1} \left( x[j]^2 + x[j + \tau]^2 \right)}$$

Propiedades críticas de la NSDF:
1. $r'_t(0) = 1.0$ (autocorrelación perfecta en retardo cero).
2. $-1.0 \le r'_t(\tau) \le 1.0$ para todo $\tau$.
3. Los cruces por cero delimitados de negativo a positivo determinan las regiones donde buscar máximos locales.

#### 2.2.3 Detección de Picos con Umbral Dinámico (Dynamic Peak Picking)
Se detectan todos los máximos locales en regiones positivas ($r'_t(\tau_p) > 0$). Sea $M$ el valor del pico máximo global de la NSDF. El algoritmo selecciona el **primer pico local** $\tau_k$ que satisfaga:
$$r'_t(\tau_k) \ge k_{\text{threshold}} \cdot M \quad (k_{\text{threshold}} \approx 0.90)$$
Esta regla matemática selecciona el período fundamental verdadero y rechaza de forma determinista los armónicos y sobretonos de octava.

#### 2.2.4 Interpolación Parabólica Sub-Muestra
Para el pico seleccionado $\tau_k$, con valores vecinos $\alpha = r'[\tau_k - 1]$, $\beta = r'[\tau_k]$, $\gamma = r'[\tau_k + 1]$:
$$\delta = \frac{\alpha - \gamma}{2(\alpha - 2\beta + \gamma)}$$
$$\tau_{\text{exact}} = \tau_k + \delta$$
$$f_0 = \frac{f_s}{\tau_{\text{exact}}}$$

Donde $f_s$ es la frecuencia de muestreo del hardware ($44100\text{ Hz}$).

---

## 3. Especificación Funcional

- **REQ-MPM-01:** Implementación 100% pura Dart en `lib/features/tuner/domain/mcleod_pitch_method.dart` sin dependencias de Flutter UI ni plugins externos.
- **REQ-MPM-02:** Umbral de Noise Gate acústico basado en RMS real de muestras flotantes (descarte de señales $< -46\text{ dBFS}$).
- **REQ-MPM-03:** Rango de detección continua de $27.5\text{ Hz}$ ($A_0$) a $4186.0\text{ Hz}$ ($C_8$).
- **REQ-MPM-04:** Reporte de métrica de claridad (*clarity / confidence score*) $c \in [0.0, 1.0]$.
- **REQ-MPM-05:** Procesamiento no bloqueante en Isolate de cómputo en segundo plano.

---

## 4. Referencias
1. McLeod, P., & Wyvill, G. (2005). *A Smarter Way to Find Pitch*. ICMC.
2. de Cheveigné, A., & Kawahara, H. (2002). *YIN, a fundamental frequency estimator for speech and music*. JASA.
