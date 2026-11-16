# Implementation Plan: Erradicación Integral de Mocks, Persistencia de Estado de Rack y Menús Desktop Profesionales

Este documento define la estructura técnica y el plan de trabajo para eliminar de raíz cualquier comportamiento simulado o cableado en duro en la estación de trabajo de **Tunner**, habilitando menús desktop interactivos completos, paleta omnibox funcional con autocompletado y ayuda, y persistencia de estado del rack modular.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-WORKSTATION-2026-0078`
- **Título de la Implementación:** Erradicación Integral de Mocks, Persistencia de Estado de Rack y Menús Desktop Profesionales
- **Fase del Proyecto:** `Fase 3` (Consolidación de Arquitectura de Audio y Estación de Trabajo Desktop)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [0068_eliminate_remaining_workstation_mocks.md](../04_adrs/0068_eliminate_remaining_workstation_mocks.md)
- **Documento Funcional Base:** [78_uc_eliminate_remaining_workstation_mocks.md](../02_use_cases/78_uc_eliminate_remaining_workstation_mocks.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la estación de trabajo desktop en un entorno 100% operativo y profesional donde:
1. La barra de menús superior (`Tunner`, `Workspace`, `View`, `Window`) despliegue menús nativos funcionales de escritorio con acciones reales de archivo, visualización, calibración y navegación.
2. Los accesos rápidos de la barra lateral (`Automations`, `Customizations`, `Settings`) abran modales y herramientas dedicadas reales en lugar de atajos desalineados o closures vacíos.
3. La barra de comandos omnibox (`StudioCommandPromptBar`) cuente con un catálogo expandido de autocompletado para acciones (`/afinar`, `/metro`, `/bpm`, `/calibrar`, `/grabar`, `/help`, etc.) y módulos (`@afinador`, `@metronomo`, `@partitura`, `@grabador`, `@rack`, `@espectrograma`, `@acordes`), garantizando ejecución atómica inmediata.
4. El estado del rack modular (`ModularRackViewModel`) se preserve de manera continua a nivel de aplicación, evitando el reinicio de módulos y conexiones al navegar entre pestañas.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Componente de menú contextual de escritorio (`StudioMenuBarItem`) integrado en `StudioDesktopAppShell`.
  - Modales dedicados para `Automations` (rutinas de práctica y calentamiento acústico) y `Customizations` (ajustes de motor DSP, latencia y apariencia del lienzo).
  - Modal de `Settings` general con calibración de referencia A4, temperamentos y preferencias de audio.
  - Elevación del ciclo de vida de `ModularRackViewModel` en `MainAppShell` para persistir módulos agregados y cables virtuales.
  - Sincronización bidireccional de instrumento activo entre `TunerViewModel` y `ModularRackViewModel`.
  - Sustitución de colores en duro en modales de rack por `StudioDesignTokens`.
  - Pruebas unitarias y de widgets para todas las nuevas interacciones.
- **Excluido (Out-of-Scope):**
  - Procesamiento en la nube o sincronización remota (100% offline-first).
  - Implementación de síntesis MIDI externa por hardware no USB.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `>=3.0.0 <4.0.0`
  - Flutter SDK: Canal estable oficial para Linux/macOS/Windows.
  - Provider: `^6.1.1`
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI? No, reutiliza la infraestructura limpia existente sin romper contratos de dominio.
  - ¿Afecta el rendimiento del bucle principal de Flutter? No, desacopla el estado modular y optimiza el árbol de renderizado a 60/120 FPS.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Verificar inmutabilidad de entidades de rack (`RackModuleEntity`, `PortId`, `SignalType`).
- [x] Garantizar que no existan emojis ni dependencias de Flutter en `lib/features/modular_rack/domain/`.

### Paso 2: Capa de Infraestructura y Gestión de Estado (ViewModels)
- [x] Integrar `ModularRackViewModel` como estado persistente en `_MainAppShellState` o a través del árbol de proveedores.
- [x] Conectar la sincronización de instrumentos entre `TunerViewModel` y `ModularRackViewModel`.

### Paso 3: Capa de Presentación (Átomos, Moléculas y Organismos de UI)
- [x] Desarrollar menús desplegables desktop (`PopupMenuButton`) en la barra superior de `StudioDesktopAppShell`:
  - `Tunner`: Acerca de Tunner, Guía de Atajos, Preferencias, Salir.
  - `Workspace`: Nuevo Proyecto, Nueva Partitura, Importar Archivo, Guardar Espacio.
  - `View`: Alternar Barra Lateral, Alternar Rack Modular, Modos de Contraste.
  - `Window`: Afinador Estroboscópico, Metrónomo, Espectrograma FFT, Grabador Multipista.
- [x] Conectar los callbacks `onOpenAutomations`, `onOpenCustomizations` y `onOpenSettings` con sus respectivos modales especializados.
- [x] Enriquecer el catálogo de `PromptSuggestion` en `MainAppShell` para soportar módulos `@` y acciones `/` completas.
- [x] Ajustar `ModularStudioRackView` para consumir el ViewModel existente sin reinstanciarlo.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Redacción de tests unitarios y de widgets para menús, modales de utilidades y persistencia de rack.
- [x] Ejecución de `flutter analyze lib/ test/` con cero advertencias.
- [x] Ejecución de `flutter test` verificando 100% de éxito.
- [x] Compilación y ejecución nativa en Linux Desktop.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit `7678ca8` (`feat(ui): strictly separate project documents from technical tool suite in workstation sidebar`).
- **Mitigación Inmediata:** Si surge una regresión en el árbol de renderizado o en el estado de Provider, revertir cambios vía `git reset --hard 7678ca8`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Cero menús con `onTap: () {}` en la barra superior.
- [x] El modal de `Settings` no abre el selector de instrumentos, sino el panel de configuración del estudio.
- [x] Al cambiar de pestaña y regresar a la vista de Rack Modular, los módulos agregados y cables se mantienen intactos.
- [x] El autocompletado del omnibox funciona para comandos de acción (`/`) y módulos (`@`) con navegación por teclado y ejecución limpia.
- [x] Pruebas automatizadas pasando sin errores.
