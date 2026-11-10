# Especificación Canónica: Afinador Inteligente por Reconocimiento Tímbrico y Adaptación Acústica

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-059`
- **Título Oficial:** Arquitectura del Afinador Inteligente: Reconocimiento Tímbrico Multivariado, Adaptación Dinámica de Filtros Acústicos y Síntesis de Referencia Real
- **Estado:** Approved
- **Fecha de Creación:** 2026-11-09
- **Última Modificación:** 2026-11-09
- **Fase Asociada:** Fase 5 (Modular Studio & Hiper-Sinergia)
- **Autor / Revisor Principal:** DeepMind Agentic Pair Programmer & Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo (Executive Summary)

El presente documento define la arquitectura formal del **Afinador Inteligente por Reconocimiento de Instrumento** en **Tunner**. A diferencia de los afinadores tradicionales que aplican un filtro genérico unidimensional a cualquier sonido entrante, Tunner utiliza un motor de análisis tímbrico multivariado (`SmartInstrumentDetector`) que evalúa en tiempo real el rango fundamental ($f_0$), la distribución armónica de sobretonos ($H_1-H_8$) y el centroide espectral.

Al identificar el instrumento que está sonando (ej. flauta traversa, trompeta en Si bemol, violonchelo, clarinete o guitarra), el sistema:
1. Adapta dinámicamente la compuerta de ruido (*Noise Gate*) y los filtros pasa-altos/pasa-bajos del micrófono para aislar la tesitura exacta.
2. Bloquea la histéresis estroboscópica en las cuerdas o registros típicos del instrumento activo.
3. Conmuta el generador de tonos de diapasón para emitir frecuencias de referencia sintetizadas con el **timbre y envolvente ADSR real** del instrumento, facilitando la afinación por simpatía tímbrica.

---

## 2. Fundamentos Acústicos y Matemáticos

### 2.1 Firma Acústica Multivariada (`AcousticSignature`)
Una firma acústica capturada en un frame temporal se modela mediante el vector $\mathbf{s}$:
$$\mathbf{s} = \begin{bmatrix} f_0 \\ C_{\text{spectral}} \\ R_{\text{odd/even}} \\ \mathbf{h} \end{bmatrix}$$
Donde:
- $f_0$ es la frecuencia fundamental en Hz ($20\text{ Hz} \le f_0 \le 5000\text{ Hz}$).
- $C_{\text{spectral}}$ es el centroide espectral en Hz, indicativo del brillo acústico:
  $$C_{\text{spectral}} = \frac{\sum_{k=1}^N f_k \cdot |X(k)|}{\sum_{k=1}^N |X(k)|}$$
- $\mathbf{h} = [h_1, h_2, \dots, h_8]$ son las amplitudes relativas normalizadas de los primeros 8 armónicos.
- $R_{\text{odd/even}}$ es la razón de energía entre armónicos impares y pares:
  $$R_{\text{odd/even}} = \frac{h_1 + h_3 + h_5 + h_7}{h_2 + h_4 + h_6 + h_8 + \epsilon}$$
  *Ejemplo:* El clarinete posee una columna de aire cilíndrica cerrada en un extremo, produciendo predominantemente armónicos impares ($R_{\text{odd/even}} \gg 1.5$), mientras que el saxofón (cónico) y la flauta (abierta) presentan espectros armónicos pares balanceados.

### 2.2 Puntuación de Confianza de Coincidencia ($\text{Confidence}$)
Para cada instrumento $I$ en la base de datos de Tunner:
$$\text{Score}(I) = w_{\text{range}} \cdot S_{\text{range}}(f_0, I) + w_{\text{overtones}} \cdot \text{CosineSimilarity}(\mathbf{h}, \mathbf{h}_I) + w_{\text{ratio}} \cdot S_{\text{ratio}}(R, R_I)$$
Si $\text{Score}(I) \ge \theta_{\text{threshold}}$ (por defecto $0.75$), el sistema reconoce el instrumento con alta certeza.

---

## 3. Especificación Funcional

### 3.1 Comportamiento del Sistema (Requerimientos)
- **REQ-SMART-01:** El detector analiza firmas acústicas en memoria en $< 2\text{ ms}$ sin interferir con el hilo de renderizado visual a 120 FPS.
- **REQ-SMART-02:** En modo automático (`autoSwitch = true`), al alcanzar $\ge 0.85$ de confianza durante 3 frames consecutivos, el afinador actualiza `activeInstrument` y reconfigura los filtros acústicos del micrófono.
- **REQ-SMART-03:** En modo asistido (`autoSwitch = false`), se presenta un badge no intrusivo en pantalla que permite al usuario aceptar la adaptación con un solo toque.
- **REQ-SMART-04:** La emisión del diapasón o tono de prueba se conmuta al patch SoundFont SF2 correspondiente al instrumento detectado.
