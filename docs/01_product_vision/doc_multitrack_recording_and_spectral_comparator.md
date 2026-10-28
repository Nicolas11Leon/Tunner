# Documento de Especificación Técnica: Grabación Multi-Pista y Comparador Visual Espectral de Tomas de Ensayo

---

## Metadatos del Documento

- **ID del Documento:** `DOC-PRACTICE-2026-032`
- **Título Oficial:** Arquitectura de Grabación Multi-Pista, Multi-Toma y Comparador Visual Espectral para Práctica Instrumental de Conservatorio
- **Estado:** Approved
- **Fecha de Creación:** 2026-10-28
- **Última Modificación:** 2026-10-28
- **Fase Asociada:** Fase 12 (Multi-Track & Spectral Intonation Comparator)
- **Autor / Revisor Principal:** Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo (Executive Summary)

El aprendizaje y perfeccionamiento instrumental en conservatorios de alto rendimiento exige un proceso iterativo de autoescucha crítica y contrastación objetiva entre múltiples intentos ("tomas" o *takes*). Hasta el momento, el músico solo podía grabar una toma lineal aislada o consultar un espectrograma en tiempo real sin capacidad de contrastación diacrónica.

Esta especificación formaliza el motor de **Grabación Multi-Pista / Multi-Toma** y el **Comparador Visual Espectral**, permitiendo registrar múltiples tomas sobre la misma partitura u obra musical, conservar sus curvas de entonación (desviación microtonal en cents) y métricas de brillo timbral (centroide espectral en Hz y distorsión armónica THD), y contrastarlas superpuestas de manera sincronizada (A/B testing visual y auditivo).

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Cuando un estudiante de conservatorio practica un pasaje virtuosístico (por ejemplo, los compases 16 a 24 de una sonata):
1. Ejecuta una primera toma (Toma 1) donde ciertos intervalos agudos tienden a calarse (flat, $-18$ cents).
2. Ejecuta una segunda toma (Toma 2) intentando corregir el soporte diafragmático o la posición del arco.
3. Al escuchar secuencialmente las tomas sin soporte visual objetivo, la memoria auditiva a corto plazo distorsiona la percepción real de la mejora.
4. Se carece de una herramienta unificada en el dispositivo que superponga las curvas de afinación y el centroide espectral punto por punto para evidenciar objetivamente la estabilidad acústica alcanzada.

### 2.2 Fundamento Teórico y Matemático

#### 2.2.1 Desviación Microtonal de Afinación
Para cada instante de tiempo $t_i$, la desviación en cents respecto a la nota objetivo de la partitura $f_{\text{target}}$ se computa como:
$$\Delta c(t_i) = 1200 \cdot \log_2\left(\frac{f(t_i)}{f_{\text{target}}}\right)$$

#### 2.2.2 Delta de Estabilidad de Entonación entre Tomas
Dadas dos tomas $A$ y $B$ alineadas temporalmente con $N$ muestras válidas de tono:
$$\bar{\epsilon}_A = \frac{1}{N} \sum_{i=1}^N |\Delta c_A(t_i)|, \quad \bar{\epsilon}_B = \frac{1}{N} \sum_{i=1}^N |\Delta c_B(t_i)|$$
$$\Delta_{\text{estabilidad}} = \bar{\epsilon}_A - \bar{\epsilon}_B$$
Si $\Delta_{\text{estabilidad}} > 0$, la Toma $B$ demuestra una afinación promedio estadísticamente más precisa que la Toma $A$.

#### 2.2.3 Centroide Espectral (Brillo Timbral)
El centroide espectral $SC(t_i)$ describe el centro de gravedad de la distribución de energía frecuencial:
$$SC(t_i) = \frac{\sum_{k=1}^K f_k \cdot |X(k)|}{\sum_{k=1}^K |X(k)|}$$
Una toma con mayor soporte acústico y proyección de armónicos superiores mostrará un incremento controlado en $SC$ sin exceder los umbrales de estridencia acústica.

---

## 3. Especificación Funcional Detallada

### 3.1 Requerimientos Funcionales
- **REQ-01 (Multi-Toma):** El sistema debe permitir registrar múltiples tomas de práctica vinculadas a la sesión actual, almacenando metadatos temporales, peaks de amplitud, curva de entonación en cents y centroide espectral.
- **REQ-02 (Controles de Pista):** Cada toma debe poder silenciarse (Mute), reproducirse en solitario (Solo) y ajustar su nivel de ganancia relativa (0.0 a 1.0).
- **REQ-03 (Comparador Superpuesto):** El lienzo gráfico debe permitir seleccionar dos tomas (Toma A y Toma B) y renderizar sus curvas de afinación superpuestas con colores contrastantes y un eje de referencia en 0 cents.
- **REQ-04 (Métricas de Mejora Acústica):** El comparador debe computar y mostrar la diferencia de afinación promedio, la convergencia rítmica en milisegundos y la variación de brillo tímbrico entre tomas.
- **REQ-05 (Audición Conmutada A/B):** La interfaz debe proporcionar botones de conmutación rápida para alternar instantáneamente la escucha auditiva entre la Toma A y la Toma B durante la reproducción.

### 3.2 Casos de Borde y Tolerancias
- Si una toma es más corta que la otra, el comparador ajusta la escala temporal al mínimo común o normaliza los compases coincidentes.
- Los silencios o caídas por debajo del umbral de ruido (Noise Gate RMS $\le 0.015$) se renderizan como huecos en la curva de entonación para no generar artefactos espurios.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (Domain Layer)
- `MultiTrackSessionEntity`: Representa la sesión completa de ensayo con su lista de tomas `PracticeTakeEntity`, BPM base y título.
- `PracticeTakeEntity`: Entidad pura que almacena ID, nombre, timestamp, duración, ruta de audio, picos de forma de onda, `List<TimedPitchSample>` y `List<TimedSpectralSample>`.
- `SpectralComparatorService`: Servicio puro de dominio que computa métricas diferenciales, correlación de entonación y deltas armónicos entre pares de tomas.

### 4.2 Capa de Presentación (Presentation Layer)
- `SpectralComparatorModal`: Modal modal de análisis comparativo de conservatorio.
- `SpectralComparatorPainter`: `CustomPainter` vectorial de alto rendimiento que traza las curvas continuas de entonación (Bézier o polilíneas suavizadas), zonas de afinación perfecta ($\pm 5$ cents) y envolventes de brillo tímbrico.
- Integración en `TunerViewModel`: Métodos para gestionar tomas en sesión activa, alternar tomas de comparación y notificar cambios reactivos.

---

## 5. Criterios de Rendimiento

- **Tiempo de Cómputo Comparativo:** $\le 5\text{ ms}$ para analizar 1,000 puntos temporales en memoria.
- **Tasa de Refresco de Pintura:** 60 FPS estables sin recreación de objetos pesados en el método `paint`.
- **Almacenamiento Local:** Persistencia compacta en JSON local sin dependencias en la nube ni microservicios externos.

---

## 6. Plan de Pruebas y Validación

- [x] Pruebas unitarias de dominio para cálculo de deltas de estabilidad y centroide.
- [x] Pruebas de serialización/deserialización de `MultiTrackSessionEntity` y `PracticeTakeEntity`.
- [x] Pruebas de renderizado en `SpectralComparatorPainter`.
- [x] Pruebas de integración UI en `spectral_comparator_ui_test.dart`.
