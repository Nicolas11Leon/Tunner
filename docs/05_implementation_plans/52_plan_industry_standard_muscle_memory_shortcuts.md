# Plan de Implementación: Estándar Global de Memoria Muscular para Tunner

- **ID del Plan:** `PLAN-2026-052`
- **Fase:** Fase 4 & Global
- **Fecha:** 2026-11-07
- **Estado:** Ready for Execution

---

## 1. Objetivos

1. Implementar en `MainAppShell` los atajos universales de DAWs:
   - `Enter` / `Return`: Rebobinado al inicio de la partitura / compás 1.
   - `C`: Alternar modo ciclo / bucle de práctica.
   - `,` (Coma): Retroceder 1 compás en el playhead.
   - `.` (Punto): Avanzar 1 compás en el playhead.
   - `Cmd/Ctrl + F`: Búsqueda Spotlight (alias de `Cmd/Ctrl + K`).
2. Actualizar `TunerViewModel` si se requieren métodos de conveniencia para nudge de compás y ciclo de reproducción.
3. Actualizar `ToolHelpCatalog` y `KeyboardShortcutsCheatSheetModal` reflejando las convenciones de memoria muscular de la industria.
4. Crear pruebas unitarias y de widgets que validen la respuesta a `Enter`, `C`, `,`, `.`, y `Cmd+F`.
5. Ejecutar `flutter analyze` y `flutter test` verificando cero errores y alta cobertura.

---

## 2. Tareas de Implementación

- [ ] **Tarea 1 (ViewModel):** Verificar y asegurar soporte de rebobinado a inicio y ciclo en `TunerViewModel`.
- [ ] **Tarea 2 (Presentación):** Actualizar `MainAppShell` con las nuevas intenciones de transporte (`RewindToStartIntent`, `ToggleCycleLoopIntent`, `NudgeMeasureBackIntent`, `NudgeMeasureForwardIntent`).
- [ ] **Tarea 3 (Presentación / Modal):** Actualizar `KeyboardShortcutsCheatSheetModal` incorporando la tabla de convenciones DAW (Logic/Pro Tools/Ableton).
- [ ] **Tarea 4 (Pruebas Automatizadas):** Crear `test/features/navigation/industry_standard_shortcuts_test.dart`.
- [ ] **Tarea 5 (Verificación & DoD):** Ejecutar análisis estático y suites de pruebas completas.
