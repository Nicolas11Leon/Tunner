# Documentación Técnica: Reconocimiento Polifónico de Acordes en Tiempo Real (Polyphonic Chord Recognizer)

Este documento define la especificación técnica, fundamentos acústico-matemáticos y diseño de arquitectura del motor de clasificación armónica polifónica de **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-CHORD-2026-001`
- **Título Oficial:** Reconocimiento Polifónico de Acordes mediante Vectores de Cromagrama (Chroma Vectors & Pitch Class Profile)
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** Fase 7.4 (Vanguardia Acústica y Conservatorio)
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity

---

## 1. Resumen Ejecutivo (Executive Summary)

El Reconocimiento Polifónico de Acordes en Tiempo Real amplía las capacidades analíticas de **Tunner** más allá de la detección monofónica, permitiendo a instrumentistas polifónicos (pianistas, guitarristas, arpistas, ensambles de cámara y directores corales) identificar instantáneamente la armonía ejecutada en el ambiente sonoro.

El motor implementa la técnica de extracción de características musicales de vanguardia conocida como **Chroma Vectors / Pitch Class Profile (PCP)** en Dart puro. Agrupa la energía espectral de la señal acústica en 12 dimensiones correspondientes a las clases de tono de la escala cromática ($C, C\sharp, D, D\sharp, E, F, F\sharp, G, G\sharp, A, A\sharp, B$) y clasifica el acorde resultante contra un banco de 108 plantillas canónicas mediante similitud de coseno, entregando nombre formal, cifrado, notas constitutivas y porcentaje de certidumbre en menos de $4\text{ ms}$ de cómputo.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
A diferencia de una nota solista que posee un único armónico fundamental $f_0$ predominante, una señal polifónica (como un acorde de Do Mayor tocado en guitarra o piano: $C_3, G_3, C_4, E_4, G_4$) consiste en la superposición lineal de múltiples fundamentales y sus respectivas series armónicas. Un detector monofónico (como YIN o MPM) oscilaría erráticamente o saltaría de octava entre las componentes.

### 2.2 Fundamento Teórico: Pitch Class Profile (PCP) y Similitud de Coseno
Para cada muestra de audio en el tiempo discreto dentro de un búfer de análisis $x[0 \dots N-1]$, se evalúa la presencia energética en cada nota MIDI $m \in [36, 84]$ (cubriendo desde $C_2 \approx 65.4\text{ Hz}$ hasta $C_6 \approx 1046.5\text{ Hz}$):

$$f(m) = f_{\text{A4}} \cdot 2^{\frac{m - 69}{12}}$$

Para cada frecuencia objetivo $f(m)$, la energía espectral se obtiene por correlación trigonométrica dirigida:
$$\text{Re}(m) = \sum_{n=0}^{N-1} x[n] \cos\left(\frac{2\pi f(m) n}{f_s}\right), \quad \text{Im}(m) = \sum_{n=0}^{N-1} x[n] \sin\left(\frac{2\pi f(m) n}{f_s}\right)$$
$$E(m) = \sqrt{\text{Re}(m)^2 + \text{Im}(m)^2}$$

La acumulación en el vector de cromagrama de 12 clases $\mathbf{V} = [v_0, v_1, \dots, v_{11}]$ se calcula colapsando todas las octavas:
$$v_c = \sum_{m \pmod{12} = c} E(m)$$

Posteriormente, el vector $\mathbf{V}$ se normaliza a longitud unitaria:
$$\hat{\mathbf{V}} = \frac{\mathbf{V}}{\|\mathbf{V}\|_2} = \frac{\mathbf{V}}{\sqrt{\sum_{k=0}^{11} v_k^2}}$$

### 2.3 Clasificación por Similitud de Coseno
Para cada una de las 108 plantillas de acordes normalizadas $\hat{\mathbf{T}}_i$ (donde $i$ varía sobre las 12 notas raíz y los 9 tipos de acordes):
$$\text{Similitud}(\hat{\mathbf{V}}, \hat{\mathbf{T}}_i) = \hat{\mathbf{V}} \cdot \hat{\mathbf{T}}_i = \sum_{k=0}^{11} \hat{v}_k \cdot \hat{t}_{i, k}$$

El clasificador elige la plantilla óptima:
$$i^* = \arg\max_i \text{Similitud}(\hat{\mathbf{V}}, \hat{\mathbf{T}}_i)$$

Si $\text{Similitud}(\hat{\mathbf{V}}, \hat{\mathbf{T}}_{i^*}) \ge \gamma_{\text{umbral}}$ (donde $\gamma_{\text{umbral}} \approx 0.60$) y la energía RMS supera el umbral de ruido de fondo, se declara el acorde correspondiente.

---

## 3. Especificación Funcional

### 3.1 Familias de Acordes Reconocidos
1. **Tríadas Mayores:** Raíz, 3ra Mayor (+4 st), 5ta Justa (+7 st).
2. **Tríadas Menores:** Raíz, 3ra Menor (+3 st), 5ta Justa (+7 st).
3. **Tríadas Disminuidas:** Raíz, 3ra Menor (+3 st), 5ta Disminuida (+6 st).
4. **Tríadas Aumentadas:** Raíz, 3ra Mayor (+4 st), 5ta Aumentada (+8 st).
5. **Acordes de Séptima de Dominante:** Raíz, 3ra Mayor, 5ta Justa, 7ma Menor (+10 st).
6. **Acordes de Séptima Mayor:** Raíz, 3ra Mayor, 5ta Justa, 7ma Mayor (+11 st).
7. **Acordes de Séptima Menor:** Raíz, 3ra Menor, 5ta Justa, 7ma Menor (+10 st).
8. **Acordes Suspendidos de Cuarta (Sus4):** Raíz, 4ta Justa (+5 st), 5ta Justa (+7 st).
9. **Acordes Suspendidos de Segunda (Sus2):** Raíz, 2da Mayor (+2 st), 5ta Justa (+7 st).

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/features/chord_analyzer/domain/`)
- `ChordQuality`: Enumeración con nombres técnicos y símbolos musicales.
- `ChordEntity`: Entidad inmutable con raíz, calidad, notas, confianza y vector de cromagrama.
- `ChromaVectorCalculator`: Algoritmo matemático puro en Dart para la generación del vector de 12 clases de tono.
- `PolyphonicChordRecognizer`: Clasificador formal por plantillas y similitud de coseno con filtro de histéresis temporal.

### 4.2 Capa de Presentación (`lib/features/chord_analyzer/presentation/`)
- `ChordRadarWidget`: Canvas vectorial que visualiza las 12 alturas cromáticas dispuestas circularmente, destacando los semitonos activados y la energía armónica de la señal en tiempo real.
- `ChordAnalyzerModal`: Panel de estudio interactivo con acorde monumental, porcentaje de confianza, desglose de notas constitutivas e historial de acordes.

---

## 5. Criterios de Rendimiento

- **Tiempo de Ejecución:** $\le 3.5\text{ ms}$ por cuadro de análisis en CPU de dispositivo móvil estándar.
- **Consumo de Memoria:** Determinista, sin asignación masiva de objetos efímeros en cada cuadro de audio.
- **Tasa de Refresco:** 60 FPS garantizados en la interfaz de usuario.
