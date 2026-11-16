# ADR 0068: Erradicación Integral de Mocks, Persistencia de Estado de Rack y Menús Desktop Profesionales

## Estado
Aprobado

## Fecha
2026-11-16

## Contexto
Durante la auditoría visual y funcional de la estación de trabajo desktop estilo Adobe Spectrum / IDE, se identificaron varios puntos donde la interfaz presentaba comportamientos simulados o desconectados:
1. Los menús de la barra superior (`Tunner`, `Workspace`, `View`, `Window`) tenían controladores vacíos (`onTap: () {}`).
2. Los enlaces de utilidades en la barra lateral (`Automations`, `Customizations`, `Settings`) invocaban atajos incorrectos (por ejemplo, `Settings` y `Customizations` abrían el selector de instrumentos musicales en lugar de sus paneles respectivos, y `Automations` activaba el metrónomo).
3. `ModularStudioRackView` recreaba su instancia de `ModularRackViewModel` en cada llamada a `build()`, provocando que al cambiar de pestaña el usuario perdiera todos los módulos agregados y cables parcheados.
4. El autocompletado de la barra omnibox interactiva (`StudioCommandPromptBar`) requería soporte directo para comandos de módulo con prefijo `@` y ayuda contextual `/help`.

## Decisión
1. **Menús de Cabecera Nativos:** Implementar `PopupMenuButton` estilizados con el sistema atómico `StudioDesignTokens` en la barra superior de `StudioDesktopAppShell`, proporcionando acciones reales de gestión de proyecto, vistas, herramientas y configuración.
2. **Paneles de Utilidades Dedicados:** Crear componentes modales independientes para:
   - `Automations`: Rutinas de práctica acústica, calentamiento guiado y captura automática.
   - `Customizations`: Ajustes de renderizado de lienzo, motor DSP seleccionado y visualización centesimal.
   - `Settings`: Calibración de frecuencia base A4, temperamento armónico y sensibilidad de entrada.
3. **Persistencia del Rack Modular:** Elevar la instancia de `ModularRackViewModel` a nivel del estado principal (`_MainAppShellState`), reutilizándola en todas las navegaciones y asegurando la sincronización de instrumentos entre módulos y el afinador maestro.
4. **Catálogo Integral de Comandos en Omnibox:** Proveer sugerencias automáticas para acciones con `/` y módulos con `@`, ejecutando navegación o cambios de estado atómicamente.

## Consecuencias
- **Positivas:**
  - La interfaz de usuario es 100% interactiva, profesional y libre de comportamientos falsos.
  - El usuario puede estructurar su rack de trabajo sin temor a perder configuraciones al navegar entre pantallas.
  - La experiencia desktop emula de forma fidedigna herramientas profesionales de referencia como Antigravity IDE y estaciones de audio digital (DAWs).
- **Negativas / Desafíos:**
  - Mayor cantidad de listeners y contratos en el estado de la aplicación, mitigado mediante desacoplamiento estricto y pruebas automatizadas.
