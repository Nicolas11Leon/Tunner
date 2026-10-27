# Documentación Técnica: Espectrograma de Armónicos y Análisis de Timbre FFT en Tiempo Real

Este documento define la arquitectura, formulación matemática y diseño del módulo de laboratorio acústico y análisis de timbre de **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ACOUSTIC-LAB-2026-001`
- **Título Oficial:** Espectrograma de Armónicos, Centroide Espectral y Distorsión Armónica Total (THD)
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** `Fase 6 (Avanzada)`
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

El módulo de **Espectrograma de Armónicos y Análisis de Timbre** proporciona al estudiante y al pedagogo musical un laboratorio de análisis espectral de grado conservatorio. A partir del tono fundamental $f_0$ detectado por el estimador MPM y la transformada espectral de la señal acústica, el sistema aísla y cuantifica la serie armónica ($f_0$ a $8f_0$), calcula el centroide espectral (brillo acústico) y la tasa de distorsión armónica total (THD), permitiendo evaluar la pureza de emisión sonora, resonancia y estabilidad tímbrica de cualquier instrumento o voz en tiempo real y de forma 100% offline.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Los afinadores convencionales se limitan a indicar si una nota está alta o baja en cents, ignorando la cualidad más importante del sonido de un músico: el **timbre y la calidad de proyección sonora**. Un ejecutante de flauta, trompeta o violín necesita saber no solo si su nota es un La4 a 440 Hz, sino si el sonido es rico en armónicos o si está produciendo un tono "apagado", "sucio" o con exceso de ruido de aire.

### 2.2 Fundamento Teórico / Físico / Acústico

1. **Serie Armónica de Fourier:**
   Toda vibración periódica compleja producida por una columna de aire o cuerda tensa se descompone en múltiplos enteros de la frecuencia fundamental:
   $$f_k = k \cdot f_0 \quad (k \in \{1, 2, 3, 4, 5, 6, 7, 8\})$$

2. **Centroide Espectral (Spectral Centroid - Brillo Tímbrico):**
   Mide el "centro de gravedad" de la distribución energética del espectro sonoro, correlacionado directamente con la percepción psicoacústica de brillo o calidez:
   $$\text{Centroide} = \frac{\sum_{k=1}^N f_k \cdot A_k}{\sum_{k=1}^N A_k}$$

3. **Distorsión Armónica Total (THD - Total Harmonic Distortion):**
   Relación cuadrática entre la energía contenida en los sobretonos armónicos y la energía de la fundamental:
   $$\text{THD} = \frac{\sqrt{\sum_{k=2}^N A_k^2}}{A_1}$$
   - Un tono senoidal puro posee $\text{THD} \approx 0.0$.
   - Una flauta en registro medio posee $\text{THD} \approx 0.15 - 0.35$.
   - Un violín o instrumento de caña posee $\text{THD} > 0.60$.

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos
- **REQ-HARM-01:** Identificación inmediata de los primeros 8 armónicos de la nota detectada.
- **REQ-HARM-02:** Cálculo continuo en tiempo real de amplitudes normalizadas ($0.0$ a $1.0$) y decibelios relativos ($\text{dBFS}$).
- **REQ-HARM-03:** Representación visual gráfica en barras vectoriales de alta resolución.
- **REQ-HARM-04:** Clasificación automática de la cualidad del timbre (Cálido / Redondo / Brillante / Penetrante).

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/features/acoustic_lab/domain/`)
* **`HarmonicSeriesAnalyzer`:** Algoritmo puro en Dart. Descompone los picos espectrales a frecuencias $k \cdot f_0$.
* **`HarmonicBarEntity`:** Estructura inmutable con índice armónico, frecuencia exacta, amplitud relativa y etiqueta musical.
* **`TimbreAnalysisResult`:** Modelo de dominio con serie armónica, centroide espectral, THD y diagnóstico timbral pedagógico.

### 4.2 Capa de Presentación (`lib/features/acoustic_lab/presentation/`)
* **`HarmonicSpectrogramModal`:** Vista modal con CustomPainter vectorial de barras de armónicos animados y métricas de brillo y pureza acústica.
