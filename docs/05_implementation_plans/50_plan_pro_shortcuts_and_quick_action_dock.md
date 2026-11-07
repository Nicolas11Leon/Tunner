# Plan de Implementación: Quick Actions Dock, Command Palette y Atajos Globales

- **ID del Plan:** `PLAN-2026-050`
- **Fase:** Fase 4 & Global
- **Fecha:** 2026-11-07
- **Estado:** Ready for Execution

---

## 1. Objetivos

1. Crear el componente modal `ProCommandPaletteModal` para búsqueda universal instantánea y ejecución de acciones rápidas.
2. Crear el componente `QuickActionDockWidget` flotante ergonómico con controles de transporte, grabación, tap tempo y acceso rápido.
3. Crear el componente modal `KeyboardShortcutsCheatSheetModal` para guiar visualmente al usuario sobre todos los atajos disponibles.
4. Integrar `GlobalAppShortcutsWrapper` en `MainAppShell` para enlazar teclas de hardware (`Space`, `R`, `T`, `A`, `1-5`, `Cmd/Ctrl+K`, `?`).
5. Desarrollar suites de pruebas unitarias y de widgets exhaustivas con 100% de éxito.

---

## 2. Tareas de Implementación

- [ ] **Tarea 1 (Presentación):** Implementar `pro_command_palette_modal.dart` con indexación dinámica de comandos, herramientas e instrumentos universales.
- [ ] **Tarea 2 (Presentación):** Implementar `keyboard_shortcuts_modal.dart` con la ficha visual de atajos de teclado y controles.
- [ ] **Tarea 3 (Presentación):** Implementar `quick_action_dock_widget.dart` con botones ergonómicos, estado reactivo, animaciones y opción de colapso.
- [ ] **Tarea 4 (Presentación / Shell):** Actualizar `main_app_shell.dart` para alojar los atajos globales de teclado y el Dock flotante.
- [ ] **Tarea 5 (Pruebas Automatizadas):** Crear `test/features/navigation/pro_shortcuts_and_dock_test.dart` cubriendo la activación de comandos, teclado y dock.
- [ ] **Tarea 6 (Verificación & DoD):** Ejecutar `flutter analyze` y `flutter test` verificando 0 errores y confirmación del 100% de la suite.
