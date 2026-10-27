# Documentación Técnica: Transcripción de Micrófono a Partitura en Tiempo Real (Live Mic-to-Score Transcription)

Este documento define la arquitectura, formulación matemática y diseño del motor de transcripción acústica monofónica en tiempo real de **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-TRANSCRIPTION-2026-001`
- **Título Oficial:** Motor de Transcripción Acústica en Tiempo Real y Cuantización Rítmica Determinista
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** `Fase 6 (Avanzada)`
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

El motor de transcripción en tiempo real (*Mic-to-Score Live Ingestion*) convierte la ejecución acústica física del usuario (vocal o instrumental) capturada por el micrófono en notación musical canónica estandarizada (SMuFL) renderizada en el pentagrama instantáneamente. Mediante la articulación entre el estimador de tono McLeod (MPM) y un cuantizador rítmico determinista acoplado a la rejilla de sub-ticks del metrónomo, el sistema clasifica ataques de nota (*onsets*), duración sostenida y silencios, transcribiendo la interpretación en compases y figuras rítmicas formales sin latencia perceptible y de forma 100% offline.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Tradicionalmente, escribir música requiere introducir notas manualmente mediante teclados virtuales o ratón en editores complejos de escritorio. Los programas que ofrecen transcripción por micrófono suelen depender de servidores pesados en la nube, generan latencia inaceptable para el estudio instrumental, o sufren de inestabilidad acústica (ruido ambiental, transitorios de ataque percusivos y armónicos que generan fragmentación en notas falsas de semicorchea o silencios espurios).

### 2.2 Fundamento Teórico / Físico / Musical

1. **Detección de Ataque y Estabilidad (Onset & Pitch Stability):**
   Para distinguir una nota intencional de un transitorio de respiración o ruido de dedos en llaves/trastes, se evalúa la función de claridad de la NSDF:
   $$\text{Claridad}(\tau) \ge k_{\text{transcription}} \quad (k_{\text{transcription}} = 0.88)$$
   y se exige una histéresis temporal mínima de estabilidad:
   $$N_{\text{frames}} \ge N_{\text{min}} \quad (N_{\text{min}} = 2 \text{ frames } \approx 40\text{ ms})$$
   donde el tono estimado debe permanecer dentro de una tolerancia microtonal:
   $$|\Delta \text{cents}| \le 50.0 \text{ cents (semitono temperado)}$$

2. **Cuantización Rítmica Determinista a la Rejilla de Sub-Ticks:**
   La métrica de Tunner divide cada compás de $4/4$ en 16 sub-ticks (cada tick representa una semicorchea de duración):
   $$\text{Ticks}_{\text{semicorchea}} = 1, \quad \text{Ticks}_{\text{corchea}} = 2, \quad \text{Ticks}_{\text{negra}} = 4, \quad \text{Ticks}_{\text{blanca}} = 8, \quad \text{Ticks}_{\text{redonda}} = 16$$
   La duración acústica continua $t_{\text{sustain}}$ medida en ticks del metrónomo se redondea al múltiplo canónico más cercano mediante la función de cuantización:
   $$Q(t) = \operatorname{argmin}_{d \in \{1, 2, 4, 8, 16\}} |t - d|$$

3. **Manejo de Silencios y Ruido:**
   Si la amplitud RMS cae por debajo del umbral del noise gate ($\text{RMS} < 0.015$) o la claridad decae bruscamente por debajo de $0.70$, el motor declara el cierre de la nota activa (*note-off*), emite la entidad `HierarchicalNote` y espera el siguiente ataque o rellena con silencios canónicos.

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos
- **REQ-TRANS-01:** Activación / desactivación mediante un botón de alternancia (*toggle*) en la interfaz principal.
- **REQ-TRANS-02:** Clasificación continua de ataques (*onsets*), sostenimiento y liberación (*offsets*) en tiempo real sin congelamiento de UI.
- **REQ-TRANS-03:** Inserción automática de las notas detectadas en el compás activo de la partitura y avance automático a compases subsiguientes cuando se supera la capacidad métrica (ej. 16 ticks en $4/4$).
- **REQ-TRANS-04:** Registro en el historial Memento para permitir deshacer o rehacer cualquier compás transcrito.

### 3.2 Casos de Borde y Condiciones de Error
- **Trémolos y Vibratos Amplios:** El filtro de histéresis promedia la frecuencia fundamental evitando dividir notas con vibrato natural en notas múltiples separadas.
- **Transitorios de Ataque:** Rechazo de ruidos de consonantes o aire sin periodicidad armónica clara.
- **Compases Llenos:** Al completarse los ticks de un compás, el motor crea automáticamente un nuevo `MeasureEntity` de forma fluida.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/features/transcription/domain/`)
* **`LiveTranscriptionEngine`:** Pure Dart. Máquina de estados determinista (`idle`, `detecting_onset`, `sustaining_note`, `note_closed`).
* **`TranscriptionCandidate`:** Objeto inmutable que almacena la nota base, octava, frecuencia promedio, tick de inicio y ticks acumulados.
* **`RhythmicQuantizer`:** Algoritmo puro de redondeo a figuras canónicas de notación musical.

### 4.2 Capa de Infraestructura / Datos
* Consumo directo del flujo de estimaciones del [McLeodPitchMethod](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/lib/features/tuner/domain/mcleod_pitch_method.dart) sin recrear buffers ni generar contención de memoria.

### 4.3 Capa de Presentación
* Integración reactiva en [TunerViewModel](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/lib/features/tuner_viewmodel.dart) y visualización en tiempo real en [TunerScreen](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/lib/features/tuner_screen.dart).

---

## 5. Criterios de Rendimiento

- **Latencia:** $\le 30\text{ ms}$ desde el cese de una nota hasta su aparición gráfica en el pentagrama.
- **CPU:** Overhead residual inferior al $2\%$ adicional en el hilo principal.
- **Memoria:** Operación sin asignaciones masivas de memoria dinámica en bucles de audio.

---

## 6. Plan de Pruebas y Validación (QA)

- [x] Pruebas unitarias de cuantización rítmica.
- [x] Pruebas de histéresis y filtrado de ruido.
- [x] Pruebas de integración con la partitura y el pintor SMuFL.
