# ADR 0039: Aislamiento Acústico por Tesitura Instrumental y Rechazo de Habla Humana (Speech Rejection & Tone Lock)

---

## Estado
Aprobado (Approved)

---

## Contexto
En situaciones cotidianas de ensayo, conservatorio o práctica doméstica, los músicos hablan, comentan compases o respiran frente al dispositivo mientras afinan. Dado que la laringe humana genera oscilaciones cuasi-periódicas al emitir vocales, los detectores de tono monofónicos generales (MPM / YIN / Autocorrelación) capturan estos formantes vocálicos como notas musicales espurias (saltos desordenados entre octavas y notas intermedias), degradando severamente la experiencia de afinación.

Asimismo, cuando el usuario ha seleccionado un instrumento específico (ej. Guitarra con registro de $82\text{ Hz}$ a $1175\text{ Hz}$ o Bajo con registro de $30\text{ Hz}$ a $392\text{ Hz}$), permitir que el detector procese frecuencias en cualquier rango arbitrario hasta $4200\text{ Hz}$ aumenta innecesariamente la vulnerabilidad a ruidos del entorno.

---

## Decisión
Se decide implementar un módulo de dominio de Pure Dart denominado `InstrumentAcousticFilter` con:
1. **Confinamiento de Tesitura Dinámico:** Sincronizado atómicamente con el `InstrumentProfileEntity` activo, restringiendo las frecuencias válidas al rango $[0.92 \cdot f_{\text{min}}, 1.08 \cdot f_{\text{max}}]$.
2. **Umbral Adaptativo de Claridad Armónica:** Exige $c \ge 0.82$ para instrumentos musicales (la voz hablada no musical oscila típicamente por debajo de $0.75$).
3. **Enganche de Tono con Histéresis (Tone Lock Tracker):** Filtra fluctuaciones bruscas de prosodia lingüística ($> 30\text{ cents}$) exigiendo al menos 2 frames consecutivos estables antes de confirmar la presencia de una nota musical genuina.

Todo el procesamiento ocurre en memoria dentro del worker Isolate de `PitchDetectorService` sin añadir latencia perceptible ($< 0.1\text{ ms}$ de overhead matemático).

---

## Consecuencias

### Positivas:
- **Inmunidad al habla casual:** El músico puede hablar, dictar indicaciones o toser sin que el afinador muestre notas falsas ni mueva la aguja.
- **Mayor precisión y confianza:** La aguja solo responde a notas reales y sostenidas del instrumento seleccionado.
- **Flexibilidad total:** Al seleccionar "Voz / Canto Universal", el filtro conmuta a modo vocal entonado permitiendo afinar la voz humana con naturalidad.

### Neutras / Mitigaciones:
- Un ejecutante tocando notas extremadamente staccato de duración menor a $35\text{ ms}$ podría no activar el afinador si el umbral fuera muy estricto; el parámetro de frames requeridos se calibra en 2 ventanas (~40 ms) para asegurar perfecta respuesta a notas normales y rápidas.
