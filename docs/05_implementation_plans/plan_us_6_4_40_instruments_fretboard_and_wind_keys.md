# Plan de Implementacion US-6.4: Catalogo de 40 Instrumentos y Superficies Tactiles

- **Issue:** #169
- **Caso de Uso:** `UC-171` (`docs/02_use_cases/171_uc_40_instruments_catalog_and_tactile_surfaces.md`)
- **ADR:** `ADR-0163` (`docs/04_adrs/0163_unified_40_instruments_profile_and_tactile_physics.md`)
- **Rama:** `feature/us-6.4-40-instruments-fretboard-and-wind-keys`
- **Base:** `qa`
- **Estado:** Completado

## 1. Objetivo

Unificar el catalogo de `InstrumentProfileEntity.standardInstruments` con los 40 instrumentos de `UniversalInstrumentDefinition.masterCatalog`, habilitar los trastes `1..totalFrets` en `FretboardTactileWidget`, y asignar frecuencias escalares reales a las llaves/pistones en `InstrumentEmulationSurfaceWidget`.

## 2. Archivos a Modificar

1. `lib/features/instrument/domain/instrument_profile_entity.dart`
   - Agregar los 19 instrumentos restantes de `UniversalInstrumentDefinition.masterCatalog` a `standardInstruments` (total >= 40, incluyendo Kora, Sitar, Shakuhachi, Charango, Cuatro).
2. `lib/features/instrument/presentation/fretboard_tactile_widget.dart`
   - Hacer interactivos los trastes `1..totalFrets` con $f = f_{\text{open}} \cdot 2^{\text{fret}/12}$ y `Key('fret_cell_${s}_$fret')`.
3. `lib/features/instrument/presentation/instrument_emulation_surface_widget.dart`
   - Reemplazar `(minFrequencyHz + maxFrequencyHz) / 2.0` en `_buildGenericAcousticSurface` por grados diatonicos/armonicos reales indexados por llave/piston.
4. Pruebas: `test/features/instrument/us_6_4_catalog_and_tactile_surfaces_test.dart`

## 3. Criterios de Verificacion

- `flutter analyze --no-fatal-infos` -> `No issues found!`
- `flutter test --no-pub test/features/instrument/ test/core/architecture/arch_1_clean_architecture_boundaries_test.dart` -> 100% aprobado.
