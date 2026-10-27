# Plan de Implementación: Espectrograma de Armónicos y Análisis de Timbre

Este documento define el plan para implementar el laboratorio acústico de armónicos y timbre en **Tunner**, cumpliendo con [AGENTS.md](AGENTS.md).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE6-HARMONICS-2026-002`
- **Título:** Laboratorio de Armónicos, Centroide Espectral y Calidad Tímbrica
- **Fase del Proyecto:** Fase 6 (Vanguardia Open Source)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR-0016](../04_adrs/0016_fft_harmonic_spectrogram.md)
- **Documento Funcional Base:** [DOC-ACOUSTIC-LAB-2026-001](../01_product_vision/doc_fft_harmonic_spectrogram.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Proveer a los músicos un visualizador y analizador en vivo de los primeros 8 armónicos de su sonido, con métricas de brillo (centroide espectral) y distorsión armónica total (THD).

### 1.2 Límites del Alcance
- **Incluido:**
  - `HarmonicBarEntity` y `TimbreAnalysisResult`.
  - `HarmonicSeriesAnalyzer` (Dart puro en `lib/features/acoustic_lab/domain/`).
  - `HarmonicSpectrogramModal` en `lib/features/acoustic_lab/presentation/`.
  - Pruebas unitarias de dominio y widgets.

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Dart Puro)
- [ ] Implementar `HarmonicBarEntity`, `TimbreAnalysisResult` y `HarmonicSeriesAnalyzer`.
- [ ] Crear pruebas unitarias en `test/features/acoustic_lab/harmonic_series_analyzer_test.dart`.

### Paso 2: Capa de Presentación
- [ ] Implementar `HarmonicSpectrogramModal` con diseño estético de conservatorio.
- [ ] Integrar botón de acceso en `TunerScreen`.
- [ ] Crear pruebas de widget en `test/features/acoustic_lab/harmonic_spectrogram_ui_test.dart`.

### Paso 3: Verificación
- [ ] `flutter analyze` (0 issues).
- [ ] `flutter test` (100% pasando).
