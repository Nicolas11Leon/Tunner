# ADR-0132: Decomposición de Vistas Monolíticas y Unificación de Dominio DJ (ARCH-3)

- **Estado:** Aceptado
- **Fecha:** 2026-11-20
- **Issue Relacionado:** #110
- **Caso de Uso Base:** `docs/02_use_cases/143_uc_arch_3_monolithic_views_and_dj_unification.md`

## Contexto
La auditoría `PLAN-PRE-V1-ARCH-SOLID-2026-01` identificó:
1. `MainAppShell` (1,731 LOC) contenía un método `_openCommandPalette` masivo (>200 LOC) que mezclaba orquestación de shell con la definición de los 25 comandos.
2. `DjConsoleModal` y `DjStudioWorkstationView` duplicaban el renderizado de la grilla de 4 Hot Cues y controles de deck.
3. `TunerScreen` (1,598 LOC) incluía inline la vista completa del Modo Esencial.
4. `DjConsoleViewModel.activeLitActions` contenía expresiones booleanas complejas para tolerar simultáneamente ranuras `0..3` y `1..4`.

## Decisión
1. **Extracción de `StudioCommandCatalogBuilder`:** Se mueve la definición de los `CommandItem` a `lib/features/navigation/presentation/studio_command_catalog_builder.dart`.
2. **Sub-widgets Compartidos DJ y Tuner:** Se extraen `DjHotCuePadGrid` en `lib/features/dj_console/presentation/widgets/dj_hot_cue_pad_grid.dart` y `EssentialTunerPanel` en `lib/features/tuner/presentation/widgets/essential_tuner_panel.dart`.
3. **Helper Canónico de Hot Cues:** Se encapsula `isHotCueSlotActive(Map<int, int> hotCues, int slotIndexZeroBased)` en `DjConsoleViewModel` para eliminar duplicación de lógica booleana entre Deck A y Deck B.

## Consecuencias
### Positivas
- Reducción significativa de líneas y complejidad ciclomática en `MainAppShell`, `TunerScreen` y vistas DJ.
- Eliminación de código duplicado en grillas de Hot Cues y lógica de LEDs.

### Negativas / Riesgos Mitigados
- Todos los `Key` de widgets usados por pruebas automatizadas se preservan exactamente iguales en los sub-widgets extraídos.
