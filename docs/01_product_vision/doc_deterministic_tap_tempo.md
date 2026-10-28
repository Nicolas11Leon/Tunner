# Documentación Técnica: Motor de Tap Tempo Determinista y Diagnóstico de Precisión Métrica

Este documento define la especificación técnica, fundamentos matemáticos y diseño de arquitectura del sistema de calibración manual de tempo y análisis de jitter de **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-TAPTEMPO-2026-001`
- **Título Oficial:** Motor de Tap Tempo Determinista con Filtrado de Jitter y Diagnóstico de Precisión Métrica
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** Fase 7.5 (Vanguardia Acústica y Conservatorio)
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity

---

## 1. Resumen Ejecutivo (Executive Summary)

El motor de Tap Tempo Determinista proporciona una herramienta de alta precisión para el ajuste instantáneo de la velocidad métrica del metrónomo acústico mediante pulsaciones manuales del usuario. 

A diferencia de implementaciones elementales de media aritmética, incorpora un algoritmo de promedio ponderado lineal (Weighted Moving Average) sobre los últimos intervalos temporales registrados, rechazo atómico de valores atípicos y reinicio automático tras periodos de inactividad superiores a $2.5\text{ segundos}$. Además, cuantifica matemáticamente el jitter motriz del músico en milisegundos mediante la desviación estándar muestral, transformando una simple utilidad de control en un instrumento de evaluación pedagógica del sentido rítmico.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Cuando un músico o director marca un pulso rítmico con los dedos sobre una pantalla táctil, se producen variaciones fisiológicas naturales en los intervalos inter-pulsación (Inter-Onset Intervals, IOI). A velocidades elevadas ($> 140\text{ BPM}$), una discrepancia de apenas $20\text{ ms}$ puede desplazar el cálculo en más de $10\text{ BPM}$. El sistema requiere un suavizado adaptativo que responda con rapidez a los cambios intencionales de tempo pero filtre el temblor involuntario.

### 2.2 Formulación Matemática
Sean $t_0, t_1, \dots, t_N$ los instantes de tiempo en milisegundos de las pulsaciones registradas. Los intervalos consecutivos se definen como:
$$\Delta t_k = t_k - t_{k-1}, \quad \text{para } k = 1, \dots, M$$
Donde $M \le 8$ representa el número de intervalos en la ventana activa.

El promedio ponderado temporal $\overline{\Delta t}$ se calcula como:
$$\overline{\Delta t} = \frac{\sum_{k=1}^M k \cdot \Delta t_k}{\sum_{k=1}^M k}$$

La velocidad métrica resultante en pulsos por minuto (BPM) se obtiene mediante:
$$\text{BPM} = \text{clamp}\left(\text{round}\left(\frac{60000}{\overline{\Delta t}}\right), 30, 300\right)$$

### 2.3 Cálculo de Jitter y Calificación de Estabilidad
Para $M \ge 2$, la varianza muestral $s^2$ y la desviación estándar $\sigma$ (jitter absoluto en ms) se calculan como:
$$\sigma = \sqrt{\frac{1}{M-1} \sum_{k=1}^M (\Delta t_k - \overline{\Delta t})^2}$$

El porcentaje relativo de jitter respecto al pulso medio:
$$\text{Jitter}\% = \left(\frac{\sigma}{\overline{\Delta t}}\right) \cdot 100\%$$

---

## 3. Especificación Funcional

### 3.1 Requerimientos Funcionales
- **REQ-TAP-01:** Rango de detección de 30 a 300 BPM con truncamiento seguro.
- **REQ-TAP-02:** Reinicio automático del acumulador tras $2500\text{ ms}$ de inactividad entre toques sucesivos.
- **REQ-TAP-03:** Sincronización atómica inmediata con `IMetronomeService.updateTempo` a partir del segundo toque.
- **REQ-TAP-04:** Estimación y reporte cuantitativo del jitter ($\pm \sigma\text{ ms}$) y clasificación cualitativa.
- **REQ-TAP-05:** Asociación automática con la marca italiana de tempo correspondiente (`TempoMark.fromBpm`).

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/features/metronome/domain/`)
- `TapTempoResult`: Value object inmutable con bpm, jitterMs, jitterPercentage, stabilityDescription y tempoMark.
- `TapTempoEngine`: Clase pura en Dart sin dependencias de Flutter, determinista y testeable de forma aislada.

### 4.2 Capa de Presentación (`lib/features/metronome/presentation/`)
- `TapTempoWidget`: Componente táctil interactivo con animación de onda expansiva al pulsar.
- `TapTempoModal`: Modal interactivo que muestra el BPM, marca de tempo y diagnóstico de regularidad rítmica en tiempo real.

---

## 5. Criterios de Rendimiento

- **Tiempo de Cómputo:** $\le 0.1\text{ ms}$ por pulsación (complejidad temporal $\mathcal{O}(M)$ con $M \le 8$).
- **Uso de Memoria:** Determinista, búfer circular en memoria fija sin recolección de basura notable.
