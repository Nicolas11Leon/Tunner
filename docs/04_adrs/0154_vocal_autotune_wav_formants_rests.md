# ADR 0154: Post-Produccion Real WAV, Preservacion de Formantes y Silencios en Vocal Suite

- **Estado:** Aprobado
- **Fecha:** 2026-11-22
- **Issue Relacionado:** `#152`
- **Caso de Uso Base:** `docs/02_use_cases/162_uc_vocal_autotune_wav_formants_rests.md`

## Contexto
La auditoria de US-4.5 detecto tres brechas funcionales y de fidelidad acustica en `lib/features/vocal_autotune/`:
1. `VocalPedagogyController.applyAutoTuneToRecordingTake` era sincrono y se limitaba a invocar `processPracticeTake`, dejando el audio fisico WAV sin procesar y conservando la ruta original en `tunedTake.filePath`, pese a que `VocalAutoTuneProcessor.processWavBytesAsync` ya existia en dominio.
2. `TdPsolaPitchShifter.shiftPitch` acotaba `detectedPitchHz` a `50.0..1500.0 Hz` (incumpliendo el rango instrumental completo `27.5..4186.0 Hz` exigido por `AGENTS.md`) y declaraba el parametro `preserveFormants` sin utilizarlo en absoluto.
3. `VocalScoreConverter.convertTrackToScore` ignoraba la posicion temporal inicial y las pausas entre segmentos vocales, empaquetando todas las notas de forma contigua sin insertar `HierarchicalNote.rest`.

Adicionalmente, las reglas de Clean Architecture y DIP verificadas por `arch_1_clean_architecture_boundaries_test.dart` prohiben importar `dart:io` en `domain/` o importar implementaciones de `data/` en `presentation/` y `TunerViewModel`.

## Decision
1. **Puerto de Dominio para I/O de Tomas Vocales (`IVocalTakeFileGateway`):**
   - Definir `IVocalTakeFileGateway` y `NoOpVocalTakeFileGateway` en `lib/features/vocal_autotune/domain/i_vocal_take_file_gateway.dart` (Pure Dart, sin `dart:io`).
   - Implementar `LocalVocalTakeFileGateway` en `lib/features/vocal_autotune/data/local_vocal_take_file_gateway.dart` para leer bytes WAV desde `originalTake.filePath` y persistir archivos `*_autotuned.wav` en disco (con respaldo al directorio de documentos via `IPlatformFileGateway` o directorio temporal del sistema).
   - Inyectar `IVocalTakeFileGateway` y `IStudioLogger` en `VocalPedagogyController` y `TunerViewModel` (con fallback `NoOp` por defecto para pruebas aisladas) y conectar `LocalVocalTakeFileGateway` desde `StudioCompositionRoot`.
   - Convertir `applyAutoTuneToRecordingTake` a `Future<...>` tanto en `VocalPedagogyController` como en `TunerViewModel`, actualizando el manejador asincrono en `VocalAutoTuneModal` con verificacion `context.mounted`.

2. **Bifurcacion Real de Formantes y Rango `27.5..4186.0 Hz` en `TdPsolaPitchShifter`:**
   - Ampliar el clamping de frecuencia fundamental a `27.5..4186.0 Hz` (A0 a C8) y ajustar los limites minimos del periodo `p0` (>= 4 muestras) y `ps` (>= 3 muestras) para no deformar notas agudas cercanas a 4186 Hz ni cortar notas graves de 27.5 Hz.
   - Cuando `preserveFormants == false`: aplicar re-muestreo directo en dominio temporal sobre cada grano alrededor de la marca de analisis (`srcPos = nearestAnalysis + i * clampedRatio` con interpolacion lineal y ventana de sintesis `2 * ps`), desplazando tanto el tono fundamental como los formantes.
   - Cuando `preserveFormants == true`: ejecutar sintesis TD-PSOLA con escala temporal de grano 1:1 y aplicar preservacion explicita de envolvente espectral mediante liftering cepstral en bloques STFT con ventana de Hann (FFT Radix-2 en Dart puro), transfiriendo la envolvente suave original sobre la senal afinada con preservacion de energia RMS.

3. **Insercion Determinista de Silencios Cuantizados en `VocalScoreConverter`:**
   - Mantener un cursor temporal `lastEndMs` inicializado en `0`.
   - Antes de ubicar cada segmento vocal valido, calcular `gapMs = seg.startMs - lastEndMs`. Si `gapMs >= msPerTick`, cuantizar `restTicks = (gapMs / msPerTick).round()` e insertar bloques `HierarchicalNote.rest` divididos limpiamente en fronteras de compas (`ticksPerMeasure`) antes de colocar la nota y actualizar `lastEndMs = seg.endMs`.

## Consecuencias
- **Positivas:**
  - Las tomas afinadas en post-produccion generan audio WAV real reproducible en `*_autotuned.wav` sin bloquear el hilo de UI gracias a `Isolate.run`.
  - Cumplimiento estricto de Clean Architecture y `AGENTS.md`: cero `dart:io` en `domain/` y cero acoplamiento `presentation -> data`.
  - Diferencia acustica medible y verificable entre preservacion de formantes y re-muestreo directo de grano en todo el espectro `27.5..4186.0 Hz`.
  - Transcripcion vocal a partitura rítmicamente fiel con silencios cuantizados y compases validos.
- **Negativas / Trade-offs:**
  - `applyAutoTuneToRecordingTake` pasa de firma sincrona a `Future`, exigiendo `await` en los invocadores (`VocalAutoTuneModal` y pruebas).
  - La preservacion cepstral STFT agrega costo computacional acotado en bloques con `preserveFormants == true`; mitigado en post-produccion al ejecutarse dentro de `Isolate.run` y con tamanos de FFT acotados en Dart puro.
