# Plan de Implementacion: US-4.5 Post-Produccion WAV, Preservacion de Formantes y Silencios en Vocal AutoTune

## Metadatos del Plan
- **ID del Plan:** `PLAN-FASE4-VOCAL-AUTOTUNE-2026-045`
- **Titulo de la Implementacion:** Procesamiento Real WAV (`processWavBytesAsync`), Preservacion de Formantes TD-PSOLA e Insercion de Silencios Cuantizados
- **Fase del Proyecto:** Fase 4
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0154](docs/04_adrs/0154_vocal_autotune_wav_formants_rests.md)
- **Documento Funcional Base:** [Caso de Uso 162](docs/02_use_cases/162_uc_vocal_autotune_wav_formants_rests.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Completar el procesamiento real de archivos WAV en post-produccion dentro de `VocalPedagogyController`, dotar a `TdPsolaPitchShifter` de preservacion real de formantes y soporte completo `27.5..4186.0 Hz`, y habilitar la insercion de silencios cuantizados `HierarchicalNote.rest` en `VocalScoreConverter`.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Nuevo puerto de dominio `lib/features/vocal_autotune/domain/i_vocal_take_file_gateway.dart` (`IVocalTakeFileGateway`, `NoOpVocalTakeFileGateway`).
  - Nuevo adaptador de infraestructura `lib/features/vocal_autotune/data/local_vocal_take_file_gateway.dart` (`LocalVocalTakeFileGateway`).
  - Refactor asincrono de `applyAutoTuneToRecordingTake` en `lib/features/vocal_autotune/presentation/vocal_pedagogy_controller.dart`, `lib/features/tuner/presentation/tuner_viewmodel.dart`, `lib/features/vocal_autotune/presentation/vocal_autotune_modal.dart` e inyeccion en `lib/app/studio_composition_root.dart`.
  - Preservacion de envolvente espectral/formantes (liftering cepstral STFT), re-muestreo directo de grano (`preserveFormants == false`) y rango `27.5..4186.0 Hz` en `lib/features/vocal_autotune/domain/td_psola_pitch_shifter.dart`.
  - Insercion de silencios cuantizados `HierarchicalNote.rest` en `lib/features/vocal_autotune/domain/vocal_score_converter.dart`.
  - Pruebas unitarias en `test/features/vocal_autotune/us_4_5_vocal_autotune_wav_test.dart` y ajuste de asercion legacy en `test/features/vocal_autotune/vocal_score_converter_test.dart`.
- **Excluido (Out-of-Scope):**
  - Cambios en los motores de transcripcion general (`AudioToScoreTranscriptionEngine`) o parsers externos (cubiertos en US-4.2 y US-4.4).
  - Enlaces FFI nativos C/Rust adicionales para PSOLA en esta iteracion.

---

## 2. Analisis de Dependencias y Tecnologias
- **SDK:** Dart/Flutter LTS configurado en el entorno local.
- **Dependencias nuevas:** Ninguna dependencia externa en `pubspec.yaml`; todo el DSP espectral (FFT Radix-2, cepstrum real, interpolacion lineal) se implementa en Dart puro dentro de `domain/`.
- **Riesgo Tecnologico:** Bajo. El procesamiento WAV se delega a `Isolate.run` mediante `processWavBytesAsync` sin bloquear el hilo de renderizado Flutter.

---

## 3. Plan Paso a Paso de Ejecucion

### Paso 1: Capa de Dominio (Pure Dart)
- [ ] Crear `lib/features/vocal_autotune/domain/i_vocal_take_file_gateway.dart` con `IVocalTakeFileGateway` y `NoOpVocalTakeFileGateway`.
- [ ] Actualizar `TdPsolaPitchShifter.shiftPitch` en `lib/features/vocal_autotune/domain/td_psola_pitch_shifter.dart` con rango `27.5..4186.0 Hz`, re-muestreo directo de grano (`preserveFormants == false`) y preservacion cepstral de envolvente espectral (`preserveFormants == true`).
- [ ] Actualizar `VocalScoreConverter.convertTrackToScore` en `lib/features/vocal_autotune/domain/vocal_score_converter.dart` para insertar silencios `HierarchicalNote.rest` por cada brecha `seg.startMs - lastEndMs >= msPerTick`.

### Paso 2: Capa de Infraestructura / Datos
- [ ] Crear `lib/features/vocal_autotune/data/local_vocal_take_file_gateway.dart` implementando lectura de WAV y persistencia segura como `*_autotuned.wav`.
- [ ] Inyectar `LocalVocalTakeFileGateway` en `StudioCompositionRoot.createTunerViewModel`.

### Paso 3: Capa de Presentacion
- [ ] Inyectar `IVocalTakeFileGateway` e `IStudioLogger` en `VocalPedagogyController` y `TunerViewModel` (con fallbacks `NoOp`).
- [ ] Convertir `applyAutoTuneToRecordingTake` a `Future<...>` leyendo bytes WAV, ejecutando `await _autoTuneProcessor.processWavBytesAsync(...)`, guardando `*_autotuned.wav` y asignando `tunedTake.filePath`.
- [ ] Actualizar el callback de `VocalAutoTuneModal` para esperar la operacion asincrona protegiendo `context.mounted`.

### Paso 4: Pruebas, Verificacion y Limpieza
- [ ] Escribir pruebas exhaustivas en `test/features/vocal_autotune/us_4_5_vocal_autotune_wav_test.dart`.
- [ ] Ejecutar `/home/nicomania11/desarrollo/flutter/bin/flutter analyze --no-fatal-infos` verificando 0 issues.
- [ ] Ejecutar `/home/nicomania11/desarrollo/flutter/bin/flutter test test/features/vocal_autotune/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` verificando 100% pass.

---

## 4. Estrategia de Rollback
- **Punto de Restauracion Git:** Commit base de `origin/qa` (`e946b95`).
- **Mitigacion Inmediata:** Reversion atomica de la rama `feature/us-4.5-vocal-autotune-wav-formants-rests` antes de merge a `qa`.

---

## 5. Criterios de Aceptacion (Definition of Done)
- [ ] Cero emojis en codigo, comentarios, commits, PR y documentacion.
- [ ] Cero violaciones de capas Clean Architecture en `arch_1_clean_architecture_boundaries_test.dart`.
- [ ] `flutter analyze --no-fatal-infos` con 0 issues.
- [ ] 100% de pruebas pasando en `test/features/vocal_autotune/` y `arch_1`.
