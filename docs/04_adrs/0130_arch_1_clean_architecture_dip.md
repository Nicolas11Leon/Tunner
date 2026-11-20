# ADR-0130: Pureza de Capas Clean Architecture e Inversión de Dependencias Estricta (ARCH-1)

- **Estado:** Aceptado
- **Fecha:** 2026-11-20
- **Issue Relacionado:** #108
- **Caso de Uso Base:** `docs/02_use_cases/141_uc_arch_1_clean_architecture_dip.md`

## Contexto
La auditoría arquitectónica `PLAN-PRE-V1-ARCH-SOLID-2026-01` identificó violaciones directas a las reglas no negociables de `AGENTS.md` (§3.2):
1. Tres archivos en `lib/core/*/domain/` importaban `package:flutter/foundation.dart` por usar `Listenable`/`ChangeNotifier`.
2. Tres módulos de `lib/core/` (`tunner_os_kernel.dart`, `local_disk_studio_file_system_repository.dart`, `studio_theme_switcher.dart`) importaban código de `lib/features/`, invirtiendo la dirección de dependencia del núcleo.
3. `TunerViewModel` importaba 15 clases concretas de `data/` e `infrastructure/` como valores por defecto en su constructor, y 5 archivos adicionales de `presentation/` importaban e instanciaban directamente `UniversalMediaIoService` o `PlatformFileGateway`.

## Decisión
Se adopta la inversión de dependencias estricta (DIP) en toda la frontera de `core`, `domain`, `data` y `presentation`:
1. **Dominio Dart Puro:** Se introduce `StudioChangeNotifierMixin` / `IStudioListenable` en `lib/core/domain/` (o `List<VoidCallback>` puro) sin importar `package:flutter/foundation.dart` dentro de `/domain/`. Las implementaciones reactivas concretas (`ChangeNotifier`) residen en `data/` o `presentation/`.
2. **Desacoplamiento `core -> features` mediante Puertos y Adaptadores:**
   - `StudioThemeSwitcher` solo interactúa con `StudioThemeController`; la sincronización con `TunerViewModel` se realiza desde `MainAppShell`.
   - `LocalDiskStudioFileSystemRepository` recibe un callback o puerto `IWorkspaceSeedProvider` opcional en su constructor; el sembrado con sintetizadores se conecta en `StudioCompositionRoot`.
   - `TunnerOsKernel` recibe puertos abstractos de dominio (`ITerminalFeaturePort` / puertos existentes) inyectados desde `StudioCompositionRoot`.
3. **Desacoplamiento `presentation -> data`:**
   - Se define `IUniversalMediaIoService` en `lib/features/media_vault/domain/` y `NoOp` fallbacks puros de dominio para los servicios de `TunerViewModel`, `MediaVaultViewModel` y modales que consumen `IPlatformFileGateway`.
   - `StudioCompositionRoot` pasa a ser el único lugar donde se instancian las implementaciones concretas de `data/` y se inyectan completamente en `TunerViewModel`, `MediaVaultViewModel` y `TunnerOsKernel`.

## Consecuencias
### Positivas
- Cumplimiento verificable por `grep` del 100% de las reglas de Clean Architecture de `AGENTS.md §3.2`.
- Eliminación total de efectos secundarios de plataforma al instanciar ViewModels en pruebas unitarias aisladas.
- Posibilidad de validar la capa de dominio compilándola como Dart puro independiente de Flutter.

### Negativas / Riesgos Mitigados
- Las pruebas que instanciaban `TunerViewModel()` esperando que creara servicios reales por defecto (si alguna dependía de `PracticeEvaluatorService` o `InstrumentTranspositionService` puros) deben mantener dichos servicios puros en `domain/` o recibirlos en pruebas; se verificará ejecutando la suite completa de 1,205+ tests tras cada cambio.
