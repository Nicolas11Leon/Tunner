# Plan de Implementación: Atajos de Grado Photoshop y Ayuda Contextual Universal ("?")

- **ID del Plan:** `PLAN-2026-051`
- **Fase:** Fase 4 & Global
- **Fecha:** 2026-11-07
- **Estado:** Ready for Execution

---

## 1. Objetivos

1. Crear el componente reutilizable `ContextualHelpBadge` y el modal `ContextualHelpSheet`.
2. Crear la base de datos de conocimiento contextual de herramientas (`ToolHelpCatalog`) con explicaciones acústicas y atajos de cada herramienta.
3. Ampliar el sistema de atajos de teclado en `MainAppShell` para soportar la matriz completa estilo Photoshop (`A`, `M`, `S`, `R`, `D`, `V`, `F`, `C`, `L`, `K`, `[`, `]`, `Shift+[`, `Shift+]`, `0`, `Alt+Up/Down`, etc.).
4. Añadir el botón `?` a los módulos del rack (`RackUnitCard`) y a la consola multitarea.
5. Actualizar el modal de atajos (`KeyboardShortcutsCheatSheetModal`) con la nueva matriz expandida.
6. Crear pruebas automatizadas que verifiquen los nuevos atajos y la ayuda contextual.

---

## 2. Tareas de Implementación

- [ ] **Tarea 1 (Presentación):** Implementar `contextual_help_sheet.dart` con `ContextualHelpBadge` y catálogo de ayuda enriquecido.
- [ ] **Tarea 2 (Presentación / Shell):** Expandir `MainAppShell` con las intenciones y acciones completas de grado Photoshop.
- [ ] **Tarea 3 (Presentación / Rack):** Integrar `ContextualHelpBadge` en `RackUnitCard` para que cada módulo del rack tenga su botón `?`.
- [ ] **Tarea 4 (Presentación / Modal):** Actualizar `KeyboardShortcutsCheatSheetModal` para reflejar todas las secciones y teclas.
- [ ] **Tarea 5 (Pruebas Unitarias):** Crear `test/features/navigation/photoshop_shortcuts_and_help_test.dart` validando activación de atajos y apertura de ayuda.
- [ ] **Tarea 6 (Verificación & DoD):** Ejecutar `flutter analyze` y `flutter test` verificando 0 errores.
