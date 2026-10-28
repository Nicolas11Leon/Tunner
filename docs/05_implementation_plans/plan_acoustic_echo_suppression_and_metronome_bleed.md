# Plan de Implementación: Supresión de Eco Acústico y Aislamiento de Metrónomo

## Metadatos del Plan
- **ID del Plan:** `PLAN-AUDIO-2026-AES-01`
- **Título de la Implementación:** Supresión de Eco Acústico, Filtrado de Sangrado y Clic Percusivo de Metrónomo
- **Fase del Proyecto:** Fase 10 (Acoustic Hardening)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0025](../04_adrs/0025_acoustic_echo_suppression_and_percussive_metronome_click.md)
- **Documento Funcional Base:** [doc_acoustic_echo_suppression_and_metronome_bleed.md](../01_product_vision/doc_acoustic_echo_suppression_and_metronome_bleed.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Evitar que el micrófono del dispositivo capture los clics del metrónomo emitidos por los altavoces y los interprete erróneamente como notas musicales en el afinador, el evaluador de práctica o el transcriptor en tiempo real.

### 1.2 Límites del Alcance
- **Incluido:**
  - Rediseño de la síntesis de clic en `PcmWavSynthesizer` para generar transitorios aperiódicos (madera/woodblock) sin tonos senoidales puros.
  - Creación del componente puro `AcousticEchoSuppressor` en la capa de dominio (`lib/features/tuner/domain/acoustic_echo_suppressor.dart`).
  - Integración en `TunerViewModel` para notificar disparos de clic y suprimir frames de tono espurios durante la ventana de supresión de eco.
  - Creación de pruebas unitarias exhaustivas para `AcousticEchoSuppressor`, síntesis de clic y comportamiento en `TunerViewModel`.
- **Excluido:**
  - Modificación del algoritmo MPM interno (que ya opera correctamente según la señal de entrada).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Entidad Pura de Supresión de Eco)
- [x] Crear `lib/features/tuner/domain/acoustic_echo_suppressor.dart`:
  - Registro de marcas de tiempo de clics (`notifyClickEmitted`).
  - Ventana de inmunidad temporal $\Delta t \approx 65\text{ ms}$.
  - Detección de continuidad de tono para preservar notas sostenidas del instrumentista.
  - Función de evaluación `shouldSuppressPitch(double pitchHz, {int? timestampMs})`.
- [x] Pruebas unitarias de dominio en `test/features/tuner/acoustic_echo_suppressor_test.dart`.

### Paso 2: Capa de Dominio / Síntesis (Rediseño de Clic Aperiódico)
- [x] Modificar `PcmWavSynthesizer.generateMetronomeClickWav`:
  - Implementar síntesis de impulso con barrido de frecuencia rápido descendente y decaimiento exponencial ultra-corto ($< 10\text{ ms}$).
  - Garantizar que la autocorrelación de la señal del clic no genere picos periódicos en MPM.
- [x] Pruebas de síntesis en `test/features/audio_synthesizer/pcm_wav_synthesizer_test.dart`.

### Paso 3: Capa de Presentación / Orquestación (ViewModel)
- [x] Integrar `AcousticEchoSuppressor` en `TunerViewModel`:
  - Notificar a `_echoSuppressor.notifyClickEmitted()` al reproducir el clic del metrónomo.
  - Filtrar en `_pitchService.onPitchDetected` cuando el supresor indique que el frame corresponde a sangrado acústico.
- [x] Pruebas de integración en `test/features/tuner/tuner_metronome_bleed_suppression_test.dart`.

### Paso 4: Verificación y Aprobación
- [x] 100% de pruebas del repositorio pasando (258/258 pruebas superadas con éxito).
- [x] Verificación de tipos, compilación y linter completadas sin advertencias.
- [x] Cero emojis en código, comentarios y commits.
