# Template: Implementation Plan (Plantilla Plan de Implementación)

Este documento define la estructura obligatoria para la implementación del sistema jerárquico de escritorio estilo Antigravity IDE / Adobe Creative Suite en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-DESKTOP-IDE-TREEVIEW-2026-073`
- **Título de la Implementación:** `Implementación del Sistema Jerárquico de Escritorio estilo Antigravity IDE y Adobe Audition con Navegación por Carpetas, Sesiones y Consola de Estudio`
- **Fase del Proyecto:** `Fase 2 (Estudio de Grabación & Sistema de Diseño de Escritorio)`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0014_desktop_hierarchical_ide_workspace_architecture.md`
- **Documento Funcional Base:** `docs/02_use_cases/73_uc_antigravity_hierarchical_ide_workspace.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Evolucionar la interfaz gráfica de Tunner para escritorio para replicar con máxima fidelidad la estructura jerárquica y el flujo de trabajo de entornos de alta gama como **Antigravity IDE**, **VS Code** y **Adobe Creative Cloud** (específicamente Adobe Audition / Premiere):
1. **Barra Lateral Jerárquica Multivel:**
   - Acciones de nivel superior fijas: *Automatizaciones (Metrónomo Continuo)* y *Personalizaciones / Plugins DSP*.
   - Sección de Proyectos estructurada por carpetas colapsables con chevron animado, glifos de carpeta (`folder` / `folder_open`), nodos hijos sangrados con indicadores de estado en vivo (`dot` de actividad, badges numéricos de frecuencia/tempo), y timestamps técnicos (`1h ago`, `En vivo`).
   - Acceso inferior persistente a *Ajustes de Audio & Sistema* (`Settings`) y tarjeta de instrumento activo.
2. **Barra Superior Contextual (Breadcrumbs & Acciones de Ventana):**
   - Ruta completa: `tunner / [Proyecto] / [Sub-herramienta Activa]`.
   - Botón de opciones de panel (`⋮`), split view y alternador de sidebar.
3. **Consola Rápida Inferior de Comandos Musicales (Prompt / Command Bar):**
   - Input estilizado de comandos directos: `Buscar afinación, ejecutar atajo o configurar módulo (@ para módulos, / para acciones)`.
   - Selectores compactos de motor DSP y calibración (ej. `Tartini DSP`, `48 kHz`, `A4=440Hz`).
4. **Acoplamiento Atómico y Cero Regresiones Móviles:**
   - En pantallas pequeñas (`< 720px`) se mantiene el layout responsivo adaptable sin degradar la experiencia táctil.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación de modelo jerárquico multinivel en `StudioTreeView` (`StudioFolderNode`, `StudioTreeItem`, `StudioTreeSection`).
  - Refactorización de `StudioDesktopAppShell` para incluir la cabecera de proyectos con botones de filtro/creación, los accesos directos de Automations/Customizations y la barra fija de Settings.
  - Implementación de la consola inferior de comandos musicales estilo IDE.
  - Actualización de `MainAppShell` para proveer la estructura completa de carpetas musicales reales de la aplicación (Afinación, Audio Lab, Conservatorio, Estudio Modular, Partituras).
  - Pruebas unitarias de los nuevos componentes y navegación.
- **Excluido (Out-of-Scope):**
  - Modificación de los algoritmos de detección de tono FFI en C/Rust.
  - Reescritura del motor de audio de bajo nivel.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal estable Linux Desktop.
  - Dependencias: `provider` para inyección de dependencias reactiva de `TunerViewModel`.
- **Riesgo Tecnológico:**
  - Cero dependencias externas adicionales. Se utilizan widgets puros de Flutter y el sistema de tokens atómicos `StudioDesignTokens`.
  - Cero loops de busy-waiting; renderizado estrictamente guiado por eventos a 60/120 FPS.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Modelo Jerárquico y Molécula de Árbol Multinivel
- [x] Diseñar las entidades de datos inmutables: `StudioProjectFolder`, `StudioTreeItem`, `StudioFolderChild`.
- [x] Implementar la expansión/colapso con animaciones suaves de chevron y estado persistente en `StudioTreeView`.
- [x] Soporte para drag indicator, bullet dots de estatus y badges técnicos.

### Paso 2: Organismo `StudioDesktopAppShell` Estilo Antigravity
- [x] Incorporar los accesos de barra superior del sidebar: *Automatizaciones*, *Personalizaciones*.
- [x] Implementar cabecera de sección *Projects* con botones compactos de filtrado y creación.
- [x] Integrar pie inferior fijo con `Settings` y tarjeta de instrumento de precisión.
- [x] Añadir barra de comandos rápidos de estudio inferior (Command / Prompt Box).

### Paso 3: Conexión con `MainAppShell` y Mapeo de Vistas
- [x] Organizar las carpetas musicales de Tunner:
  - `tunner` (Afinador Estroboscópico de Precisión, Calibrador A4, Dron Armónico).
  - `Estudio & Grabación` (Rack Modular de Pedales, Bóveda Multimedia, Consola DJ).
  - `Laboratorio Acústico` (Espectrograma FFT, Analizador Polifónico).
  - `Conservatorio & Lecciones` (Tutor de Tempo & Rushing, Entrenador Auditivo a Ciegas).
  - `Biblioteca de Partituras` (Lector MusicXML, Editor de Compases).
- [x] Mapear los callbacks de navegación y los breadcrumbs reactivos.

### Paso 4: Pruebas, Verificación y Documentación
- [x] Crear suite de pruebas en `test/core/design_system/studio_hierarchical_tree_test.dart`.
- [x] Ejecutar `flutter analyze` y asegurar cero errores y cero advertencias.
- [x] Compilar el binario nativo de Linux y validar visualmente en pantalla completa.
- [x] Redactar ADR 0014 y Caso de Uso 73.
