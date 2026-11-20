# Plan de Implementación: Ola Final A — Remediación de Bloqueantes S0 Pre-v1.0.0

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-PRE-V1-FINAL-WAVE-A-2026-092`
- **Título de la Implementación:** `Remediación de Bloqueantes S0 (Seguridad FS, Integridad de Datos, Audio, Teclado y Crashes UI)`
- **Fase del Proyecto:** `Pre-Release Gate v1.0.0 — Ola Final A`
- **Estado:** `En Progreso`
- **Issue Relacionado:** `#92`
- **ADR Relacionado:** [ADR-0122](../04_adrs/0122_pre_v1_final_wave_a_s0_blockers.md)
- **Documento Funcional Base:** [UC-133](../02_use_cases/133_uc_pre_v1_final_wave_a_s0_blockers.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Resolver la totalidad de bloqueantes de severidad S0 detectados en la auditoría forense sobre `qa`, asegurando seguridad de archivos, persistencia fiable sin `NoOp` silenciosos, integridad matemática de audio y cero crashes UI.

### 1.2 Límites del Alcance
- **Incluido:** Hallazgos `S0-01` a `S0-12` (seguridad FS, `.tunner`/`.mxl`/`.pdf`/`TUNP`, `AppUserSettingsEntity`, `StudioCompositionRoot`, `_softLimit`, DJ recording, `StemAudioSynthesizer`, `TdPsolaPitchShifter`, atajos de teclado, crashes UI y `dispose()` de canales compartidos).
- **Excluido:** Olas B, C y D (motor SF2/MPM/Temperamentos, Parsers/PDF, Clean Architecture y Web/iOS/Android packaging).

---

## 2. Plan Paso a Paso

- [ ] **Paso 1:** Blindar `LocalDiskStudioFileSystemRepository` (`_resolveSafePath` con canonicalización de symlinks y rechazo de `.` / `..` / rutas absolutas).
- [ ] **Paso 2:** Endurecer `TunnerPackageCodecService`, `CompressedMusicXmlParser`, `PdfScoreParser` y `TunnerBinaryProjectCodec` (biyección SHA-256 1:1 y topes reales de descompresión).
- [ ] **Paso 3:** Corregir `AppUserSettingsEntity.toMap()` (`recordingHistory.take(50)`), cablear repositorios reales + `documentsDirectoryProvider` en `StudioCompositionRoot` y `StemExportPersistenceService`.
- [ ] **Paso 4:** Corregir `_softLimit` ($C^1$ `tanh`) en `DjAudioProcessor` y `HarmonicReferenceSynth`; corregir `numChannels: 1` y caché PCM en `DjConsoleViewModel`; resolver dinámicamente stems en `StemAudioSynthesizer`; guardar `len < 48` en `TdPsolaPitchShifter`.
- [ ] **Paso 5:** Blindar atajos de teclado en `MainAppShell` (`Action.isEnabled`) y `DjConsoleViewModel` (eliminar doble handler global); corregir crashes en `StudioThemeSwitcher`, `StudioCommandPromptBar`, `StudioDesktopAppShell`, `TunnerOsTerminalDrawer`, `StudioDslTerminalPanelWidget`, `StudioSettingsModal` y `dispose()` de canales compartidos.
- [ ] **Paso 6:** Añadir pruebas de regresión específicas de Ola A, ejecutar `flutter analyze --no-fatal-infos` y `flutter test` al 100%, y fusionar PR hacia `qa`.

---

## 3. Criterios de Aceptación (DoD)
- [ ] Pruebas de regresión de Ola A pasando al 100%.
- [ ] Suite completa `flutter test` pasando al 100%.
- [ ] `flutter analyze --no-fatal-infos` con 0 issues.
