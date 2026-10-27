# Plan de Implementación: Transcripción de Micrófono a Partitura en Tiempo Real

Este documento define el plan estructurado para la implementación del motor de transcripción acústica en tiempo real en **Tunner**, cumpliendo estrictamente con [AGENTS.md](AGENTS.md).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE6-TRANSCRIPTION-2026-001`
- **Título de la Implementación:** Motor de Transcripción Acústica en Vivo y Cuantización Rítmica
- **Fase del Proyecto:** Fase 6 (Vanguardia Open Source)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR-0015](../04_adrs/0015_live_mic_to_score_transcription.md)
- **Documento Funcional Base:** [DOC-TRANSCRIPTION-2026-001](../01_product_vision/doc_live_mic_to_score_transcription.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Permitir a los músicos transcribir frases melódicas tocadas en su instrumento acústico en notas vectoriales sobre el pentagrama SMuFL en tiempo real, cuantizando alturas y duraciones métricamente.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido:**
  - Capa de dominio: `LiveTranscriptionEngine`, `RhythmicQuantizer`, `TranscriptionCandidate`.
  - Integración en `TunerViewModel`: `toggleLiveTranscription()`, `isLiveTranscriptionActive`.
  - Integración en `TunerScreen`: Botón interactivo de grabación/transcripción con indicador de escucha.
  - Pruebas unitarias de dominio y de widgets UI.
- **Excluido:**
  - Transcripción polifónica de acordes simultáneos (reservado para fase posterior).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio Pura (Dart Puro)
- [ ] Implementar `RhythmicQuantizer` con cuantización canónica a $1, 2, 4, 8, 16\text{ ticks}$.
- [ ] Implementar `LiveTranscriptionEngine` con máquina de estados y filtro de histéresis.
- [ ] Crear suite de pruebas unitarias en `test/features/transcription/live_transcription_engine_test.dart`.

### Paso 2: Integración en Capa de Presentación / ViewModel
- [ ] Conectar `TunerViewModel` con `LiveTranscriptionEngine`.
- [ ] Sincronizar el flujo del detector de tono cuando la transcripción esté activa.
- [ ] Integrar el control en la interfaz de `TunerScreen`.

### Paso 3: Pruebas, Verificación y Limpieza
- [ ] Ejecutar `flutter analyze` y asegurar 0 issues.
- [ ] Ejecutar `flutter test` y asegurar que todas las pruebas pasen al 100%.
- [ ] Verificar que no existan emojis en código ni documentación.
- [ ] Commit y push a `origin/main`.
