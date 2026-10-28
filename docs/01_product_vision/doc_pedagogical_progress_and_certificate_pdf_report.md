# Especificación Técnica: Generador de Reportes y Certificados de Progreso Pedagógico en PDF

Este documento define la arquitectura, formulación matemática y diseño del motor de exportación de informes pedagógicos y certificados de aprovechamiento acústico en formato PDF vectorial estándar internacional (ISO 32000-1) para la plataforma **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-PEDAGOGY-2026-033`
- **Título Oficial:** Generador de Reportes y Certificados de Progreso Pedagógico en PDF Vectorial (ISO 32000-1)
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-28
- **Última Modificación:** 2026-10-28
- **Fase Asociada:** Fase 13 (Analítica Pedagógica y Certificación Formal)
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

El Generador de Reportes y Certificados Pedagógicos en PDF dota a Tunner de un canal de salida formal, imprimible y compartible que consolida la evidencia acústica obtenida en sesiones de práctica musical. Mediante un motor de renderizado vectorial nativo en Dart puro, el sistema compila curvas de micro-entonación en centésimas de semitono (cents), análisis de distribución armónica (FFT), variabilidad temporal del pulso (jitter de metrónomo/tap tempo en milisegundos) y recomendaciones pedagógicas formativas en un documento PDF de alta resolución gráfica.

Asimismo, el módulo incorpora la emisión de Certificados de Logro Acústico de Conservatorio, provistos de un marco ornamental vectorial geométrico, código criptográfico de autenticación local e indicadores cuantitativos de competencia técnica musical, cerrando el ciclo pedagógico entre la práctica deliberada y la acreditación académica.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
1. **Falta de Trazabilidad e Intangibilidad del Progreso:** Los estudiantes de música y profesores carecen de un mecanismo estructurado para archivar la evolución de la afinación a lo largo de semanas de práctica sin depender de plataformas en la nube o suscripciones privativas.
2. **Dependencias Nativas Pesadas:** La mayoría de las soluciones de exportación a PDF en aplicaciones móviles o de escritorio dependen de motores de renderizado web (Chromium/WebKit headless) o bibliotecas nativas de C que elevan el consumo de memoria a más de 100 MB y agregan puntos de falla multiplataforma.
3. **Ausencia de Visualización Acústica Formal:** Los informes escolares convencionales se limitan a calificaciones cualitativas o porcentuales subjetivas, omitiendo la evidencia física del sonido (curvas continuas de cents, bandas de tolerancia de conservatorio y centroide espectral).

### 2.2 Fundamento Teórico y Acústico

#### Precisión de Entonación y Tolerancia en Cents
La afinación de cada nota interpretada respecto a su tono teórico $f_{\text{ref}}$ en la escala temperada o temperamento histórico seleccionado se define mediante la ecuación logarítmica canónica:
$$\Delta c = 1200 \cdot \log_2\left(\frac{f_{\text{medida}}}{f_{\text{teorica}}}\right)$$

El reporte categoriza la entonación en tres bandas de conservatorio:
- **Afinación Pura (Conservatorio):** $|\Delta c| \le 5.0\text{ cents}$.
- **Tolerancia Aceptable (Ensamble):** $5.0\text{ cents} < |\Delta c| \le 15.0\text{ cents}$.
- **Desviación Crítica:** $|\Delta c| > 15.0\text{ cents}$.

#### Calidad Tímbrica: Centroide Espectral y THD
El brillo del timbre y la pureza armónica se determinan analizando las amplitudes de los primeros 8 armónicos $\{A_1, A_2, \dots, A_8\}$:
- **Centroide Espectral ($SC$):**
  $$SC = \frac{\sum_{k=1}^{8} f_k \cdot A_k}{\sum_{k=1}^{8} A_k}$$
- **Distorsión Armónica Total ($THD\%$):**
  $$THD = \frac{\sqrt{\sum_{k=2}^{8} A_k^2}}{A_1} \times 100\%$$

#### Estabilidad Rítmica y Jitter Temporal
La regularidad motriz se evalúa mediante la desviación estándar de los intervalos inter-golpe ($\Delta t_i$ en ms):
$$\sigma = \sqrt{\frac{1}{N-1} \sum_{i=1}^{N} (\Delta t_i - \bar{\Delta t})^2}$$
Un valor de $\sigma \le 15.0\text{ ms}$ refleja un pulso de nivel profesional de concierto.

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos
- **REQ-01 (Compilación Vectorial ISO 32000-1):** El motor debe generar un flujo binario PDF 1.4 estricto en memoria, con tablas de referencias cruzadas (xref) y catálogo de páginas, sin dependencias de plugins externos ni conexión de red.
- **REQ-02 (Página 1 - Reporte Analítico):**
  - Encabezado con datos del estudiante, instrumento, calibración de concierto ($A_4$), tonalidad y fecha.
  - 4 Tarjetas de Métricas Clave (Afinación $\le 5$ cents, Desviación Media, Brillo Tímbrico y Jitter Rítmico).
  - Lienzo Vectorial de Micro-Entonación con eje cero central, bandas de tolerancia coloreadas y curva continua interpolada.
  - Histograma de Barras Vectoriales para los 8 armónicos principales.
  - Sección de Diagnóstico Pedagógico y Pautas Técnicas de Estudio.
- **REQ-03 (Página 2 - Certificado de Aprovechamiento):**
  - Marco ornamental vectorial con orlas de doble trazo en coordenadas exactas de página.
  - Nombre del estudiante en tipografía formal destacada.
  - Enunciado del logro con nivel alcanzado (Iniciación, Intermedio, Avanzado, Virtuoso).
  - Sello acústico geométrico con hash de verificación hexadecimal y firma pedagógica.
- **REQ-04 (Configuración Flexible):** El usuario puede activar o desactivar secciones (gráfico de entonación, radar de armónicos, certificado) y editar el nombre del alumno e institución antes de la compilación.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (Domain Layer)
- `PedagogicalReportConfig`: Objeto de valor inmutable con metadatos de configuración y banderas de inclusión.
- `PedagogicalSessionData`: Entidad pura que encapsula todas las métricas de la sesión evaluada (cents, armónicos, jitter, muestras temporales).
- `PedagogicalReportPdfGenerator`: Servicio de compilación de bajo nivel que genera las secuencias de operadores PDF (`q`, `Q`, `m`, `l`, `c`, `re`, `w`, `RG`, `rg`, `S`, `f`, `BT`, `ET`, `Tf`, `Tm`, `Tj`).

### 4.2 Capa de Presentación (Presentation Layer)
- `PedagogicalReportModal`: Modal interactivo que presenta la vista previa de datos, formulario de personalización de estudiante y disparador de exportación.
- Integración en `TunerViewModel`: Orquestación y extracción de métricas de la sesión viva para poblar `PedagogicalSessionData`.

---

## 5. Criterios de Rendimiento y Benchmarking

- **Tiempo de Generación:** $\le 50\text{ ms}$ para un documento de 2 páginas con cientos de nodos vectoriales.
- **Tamaño del Archivo:** Documento optimizado de entre $15\text{ KB}$ y $45\text{ KB}$, ideal para impresión física inmediata o archivo digital.
- **Consumo de Memoria:** Operación atómica sobre `StringBuffer` y `Uint8List` con recolección de basura inmediata.

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] Pruebas unitarias de generación PDF: Verificación de cabecera `%PDF-1.4`, objetos `/Catalog`, `/Pages`, `/Page`, tablas `/xref` y marca de fin de archivo `%%EOF`.
- [ ] Pruebas de cálculo de métricas y formateo de diagnósticos pedagógicos.
- [ ] Pruebas de integración de UI: Apertura del modal, personalización de campos de texto y generación del documento en memoria.

---

## 7. Referencias Técnicas y Bibliografía

1. *ISO 32000-1:2008 - Document management - Portable document format - Part 1: PDF 1.4.*
2. *Adobe Systems Incorporated. PDF Reference, Sixth Edition, version 1.7 (2006).*
3. *Sundberg, J. (1987). The Science of the Musical Voice. Northern Illinois University Press.*
