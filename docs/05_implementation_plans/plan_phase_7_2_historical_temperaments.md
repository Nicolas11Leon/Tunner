# Plan de Implementación: Fase 7.2 - Motor de Temperamentos Históricos y Microtonales

Este plan define las tareas secuenciales para implementar el soporte completo de afinaciones históricas y microtonales en **Tunner**.

---

## 1. Objetivos

1. Proveer 8 sistemas canónicos de temperamento musical de conservatorio.
2. Permitir selección de la nota fundamental / tónica con modulación circular de semitonos.
3. Calcular con precisión matemática la frecuencia objetivo y el error en cents.
4. Integrar en `TunerViewModel`, persistencia atómica local y modal visual de selección.

---

## 2. Tareas por Capa Arquitectónica

### Capa 1: Dominio Puro (Pure Dart)
- [ ] Crear `lib/features/tuner/domain/temperament_engine.dart`:
  - Modelo `MusicalTemperament` con ID, nombre descriptivo, autor/año y lista de 12 offsets en cents.
  - Clase `TemperamentEngine` con presets matemáticos:
    - `equal` (12-EDO)
    - `pythagorean`
    - `justIntonation`
    - `meantoneQuarterComma`
    - `werckmeisterIII`
    - `kirnbergerIII`
    - `vallotti`
    - `youngII`
  - Métodos: `getOffsetInCents(noteIndex, rootIndex)`, `getTargetFrequency(noteIndex, octave, a4Ref, temperament, rootIndex)`, `calculateCentsDeviation(detectedHz, targetHz)`.
- [ ] Crear suite de pruebas de dominio: `test/features/tuner/temperament_engine_test.dart`.

### Capa 2: Persistencia & Aplicación
- [ ] Actualizar `AppUserSettingsEntity` en `lib/features/persistence/domain/app_user_settings_entity.dart`:
  - Campos: `selectedTemperamentId` (default: `'equal'`) y `temperamentRootKey` (default: `0` / Do).
  - Métodos `copyWith`, `toMap` y `fromMap`.
- [ ] Actualizar `TunerViewModel`:
  - Getters `selectedTemperament`, `temperamentRootKey`, `availableTemperaments`.
  - Métodos `setTemperament(String id)`, `setTemperamentRoot(int rootKey)`.
  - Actualizar `_pitchService.onPitchDetected` para computar `_cents` contra la frecuencia objetivo del temperamento histórico activo.

### Capa 3: Presentación (Flutter UI)
- [ ] Crear `TemperamentSelectorModal` en `lib/features/tuner/presentation/temperament_selector_modal.dart`.
- [ ] Añadir chip interactivo de temperamento en AppBar de `TunerScreen`.
- [ ] Crear pruebas de widget: `test/features/tuner/temperament_selector_ui_test.dart`.

---

## 3. Criterios de Aceptación (DoD)
- 100% de pruebas unitarias y de widget pasando.
- Cero advertencias en `flutter analyze`.
- Cero emojis en código, comentarios y commits.
- Pull request formal y merge a `main`.
