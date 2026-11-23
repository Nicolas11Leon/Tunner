# ADR-0177: Extracción de Modales de TunerScreen, Helper de Calibración/Dron y Afinaciones Derivadas de A4

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Contexto / Issue:** US-9.3 (#185)
- **Caso de Uso Asociado:** [UC-185](../02_use_cases/185_uc_tuner_screen_viewmodel_atomization_and_midi_tuning.md)

---

## 1. Contexto

El archivo `lib/features/tuner/presentation/tuner_screen.dart` había crecido hasta 1,380 líneas al contener tres hojas modales extensas embebidas (`_showLibraryModal`, `_showMixerModal` y `_showInstrumentModal`), además de chips repetidos entre los modos Esencial y Conservatorio Pro estilizados con colores legacy en lugar del sistema de tokens `StudioThemeScope` y el átomo `StudioIcon`.

En paralelo, `lib/features/tuner/presentation/tuner_viewmodel.dart` concentraba lógica directa de calibración de ruido ambiental (con `detectedDcOffset: 0.0` fijo y sin guarda de ciclo de vida tras `Future.delayed`), mapeo de intervalos hacia identificadores de repetición espaciada Ebbinghaus y refresco de síntesis del dron armónico.

Finalmente, `lib/features/instrument/domain/universal_instrument_definition.dart` exponía únicamente frecuencias estándar fijas para `A4 = 440.0 Hz`, dificultando el cálculo puro de frecuencias objetivo cuando el músico calibra un tono de concierto distinto (por ejemplo `442.0 Hz` o `432.0 Hz`).

---

## 2. Decisión

1. **Extracción de Modales a `lib/features/tuner/presentation/modals/`:**
   - `tuner_library_modal.dart` (`TunerLibraryModal`)
   - `tuner_mixer_modal.dart` (`TunerMixerModal`)
   - `tuner_instrument_modal.dart` (`TunerInstrumentModal`)
   Todos los modales y la barra superior de `TunerScreen` consumen `StudioThemeScope.of(context)` y renderizan iconografía semántica mediante `StudioIcon`, conservando intactas todas las `Key`s y tooltips existentes.

2. **Extracción de `TunerCalibrationAndDroneHelper` en `lib/features/tuner/presentation/controllers/tuner_calibration_and_drone_helper.dart`:**
   - Encapsula la calibración real de piso de ruido y medición aritmética de DC offset sobre las ventanas PCM capturadas (con respaldo sobre `latestAudioSamples`).
   - Protege la reanudación asíncrona mediante verificación explícita `isDisposed()` y restauración garantizada de callbacks en `finally`.
   - Encapsula el mapeo de `MusicalInterval` a claves Ebbinghaus y la generación/reproducción del bucle de dron armónico.
   - Mantiene intacta la API pública de `TunerViewModel` (sin `part`/`part of`, respetando Clean Architecture).

3. **Derivación Pura de Afinación A4 en `UniversalInstrumentDefinition`:**
   - Se añade el método puro `List<double> standardTuningFrequenciesFor({double referencePitchHz = 440.0})`, que escala cada frecuencia base mediante `freq * (referencePitchHz / 440.0)` y devuelve una lista inmutable.

---

## 3. Consecuencias

### Positivas
- Reducción de `tuner_screen.dart` en más de 600 líneas, mejorando legibilidad, mantenibilidad y cohesión visual con el sistema de tokens OLED Studio.
- Medición acústica real de DC offset en calibración de micrófono y eliminación de potenciales errores de estado tras `dispose()`.
- Soporte de dominio puro para calibración de concierto A4 en el catálogo universal de instrumentos sin mutar definiciones constantes.
- Cero regresiones en pruebas existentes al preservar todas las `Key`s, textos y contratos de `TunerViewModel`.

### Trade-offs
- `TunerScreen` mantiene el paso de `viewModel.currentPalette` únicamente hacia widgets hijos legacy aún no migrados (`EssentialTunerPanel`, vistas de workspace y `SmartInstrumentBadge`), aislando el alcance de esta iteración.

---

## 4. Verificación

- `flutter analyze --no-fatal-infos` sin errores ni advertencias críticas.
- Suite dedicada `test/features/tuner/us_9_3_tuner_atomization_and_midi_tuning_test.dart`.
- Regresión completa sobre `test/features/tuner/` y `test/features/instrument/`.
