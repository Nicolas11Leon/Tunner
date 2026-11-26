# ADR 0199: Puente de Analizador de Acordes hacia Dron Armonico y Tutor de Entonacion Justa

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-207](../02_use_cases/207_uc_chord_analyzer_to_harmonic_drone_and_ji_tutor_bridge.md)

---

## 1. Contexto

`ChordAnalyzerModal` (`lib/features/chord_analyzer/presentation/chord_analyzer_modal.dart`) reconoce acordes polifonicos en tiempo real mediante `PolyphonicChordRecognizer` (`ChordEntity` en `viewModel.recognizedChord`) y exhibe su simbolo, formula, notas constitutivas y radar cromatico. Sin embargo, para estudiar o afinar ese mismo acorde contra una referencia pura, el musico debe cerrar el modal, abrir manualmente `HarmonicDroneModal` (`lib/features/drone/presentation/harmonic_drone_modal.dart`) o `HarmonicTutorModal` (`lib/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart`) y volver a seleccionar la fundamental y la calidad armonica en `HarmonicTutorViewModel`.

---

## 2. Decision

1. **Mapeador Puro en Dominio (`ChordHarmonicBridgeMapper`):** Crear en `lib/features/chord_analyzer/domain/` un traductor Pure Dart que convierta una instancia reconocida de `ChordEntity` (junto con `a4ReferenceHz`) en:
   - Un `HarmonicDroneConfig` (`lib/features/drone/domain/harmonic_drone_config.dart`) con `rootNoteIndex` en $[0, 11]$ y octava calculada.
   - Una configuracion de contexto para `HarmonicTutorViewModel` (`rootNoteName`, `rootFrequency` mediante $f = f_{A4} \cdot 2^{(m - 69)/12}$ y `HarmonicChordType` equivalente en `lib/features/harmonic_tutor/domain/harmonic_role_entity.dart`).
2. **Acciones Puente en `ChordAnalyzerModal`:** Mostrar en la tarjeta de acorde activo (`_buildActiveChordCard`, cuando `chord.isRecognized == true`) dos botones en 1 clic:
   - `Key('chord_to_harmonic_drone_btn')`: aplica la configuracion al dron de `TunerViewModel` y abre `HarmonicDroneModal`.
   - `Key('chord_to_ji_tutor_btn')`: inicializa `HarmonicTutorViewModel.setRootNote(...)` y `setChordType(...)` y abre `HarmonicTutorModal`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Flujo Pedagogico Continuo:** El ensamble o instrumentista detecta un acorde en vivo y en 1 clic pasa a afinar sus terceras (`5:4` / `6:5`) y quintas (`3:2`) en Entonacion Justa sin batimientos.
- **Pureza de Dominio:** Las reglas de equivalencia enarmonica y calidad de acorde residen en Pure Dart y son verificables mediante pruebas unitarias sin UI.

### 3.2 Compromisos y Mitigaciones
- **Acordes Extendidos o No Canonicos:** Cuando `ChordEntity` representa una sonoridad compleja sin correspondencia directa en `HarmonicChordType`, el mapeador proyecta deterministicamente la triada base (mayor o menor segun sus intervalos constitutivos) conservando la fundamental exacta.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/chord_analyzer/us_hc_05_chord_to_harmonic_drone_and_ji_tutor_bridge_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
