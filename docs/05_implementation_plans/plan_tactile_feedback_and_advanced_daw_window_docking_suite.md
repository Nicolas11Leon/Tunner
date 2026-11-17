# Plan de Implementación: Suite de Respuesta Táctil Ultra-Reactiva y Sistema Avanzado de Acoplamiento de Ventanas DAW

Este documento define la estructura y hoja de ruta para resolver de forma definitiva la retroalimentación de controles, la intuitividad operativa y el rendimiento fluido del sistema de acoplamiento de ventanas de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-TACTILE-DOCKING-2026-0086`
- **Título de la Implementación:** Optimización de Respuesta Táctil de Controles, LEDs Reactivos en Tiempo Real y Sistema de Ventanas DAW Fluido con Presets de Disposición
- **Fase del Proyecto:** Fase 2 (Instrumentación, Consola DJ y Estaciones de Trabajo)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0076: Suite de Respuesta Táctil Ultra-Reactiva y Sistema Avanzado de Acoplamiento de Ventanas DAW](../04_adrs/0076_ultra_responsive_tactile_feedback_and_advanced_daw_window_docking_suite.md)
- **Documento Funcional Base:** [Caso de Uso 86: Respuesta Táctil Ultra-Reactiva y Sistema Avanzado de Acoplamiento de Ventanas DAW](../02_use_cases/86_uc_ultra_responsive_tactile_feedback_and_advanced_daw_window_docking_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la experiencia de usuario de la estación DJ y el sistema de ventanas divididas en un entorno inmediato, intuitivo y con respuesta visual a 60/120 FPS:
1. **Sincronización de LEDs y Estados Táctiles:** Sincronizar dinámicamente el estado de los LEDs (`isLedLit`) de la consola física (`DjHardwareSkinEntity`) con el estado real del motor de audio (Play/Pause, Cue, Sync, Hot Cues, Loop, FX Kill) y añadir micro-animaciones táctiles instantáneas (pulso de neón, estado presionado transitorio).
2. **Intuitividad Inmediata y Presets de Disposición (1-Click DAW Layouts):** Incorporar una barra de disposiciones preconfiguradas que permita al usuario cambiar instantáneamente entre "Club Clásico", "Hardware Fiel", "Estudio Stems", "Monitor Espectral" y "Dividido DAW Completo" sin necesidad de arrastrar manualmente si no lo desea.
3. **Acciones Rápidas de Acoplamiento en Cabeceras:** Dotar a cada tarjeta de ventana (`StudioDockableWindowCard`) de botones directos de anclaje (Izquierda, Centro, Derecha, Inferior, Maximizar, Flotante) con tooltips claros para que acoplar ventanas sea trivial y no requiera adivinar cómo arrastrar.
4. **Optimización con `RepaintBoundary`:** Aislar las zonas de renderizado intensivo para garantizar cero jank y 60 FPS estables.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Sincronización continua de LEDs de hardware en `DjConsoleViewModel`.
  - Animación de pulsación táctil (press feedback) en `DjVisualMappingOverlay` y `DjHardwareConsolePainter`.
  - Barra de accesos directos de disposición en `StudioWorkspaceDockingContainer`.
  - Botones de acción directa en cabeceras de ventana (`StudioDockableWindowCard`).
  - Pruebas unitarias y de widgets actualizadas.
- **Excluido (Out-of-Scope):**
  - Plugins de terceros externos o dependencias que requieran conexión de red.

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK:** Versión estable.
- **Flutter SDK:** Canal oficial, renderizado vectorial puro en Canvas y CustomPainter.
- **Cero dependencias externas:** Todo el estado reactivo, cálculo de splits y sincronización de LEDs se realiza mediante arquitectura limpia in-memory offline-first.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio y ViewModel
- Implementar sincronización activa de LEDs en `DjConsoleViewModel`:
  - `_syncHardwareSkinLeds()`: Actualiza dinámicamente `isLedLit` para `deckAPlayPause`, `deckBPlayPause`, `deckACue`, `deckBCue`, `deckASync`, `deckBSync`, `deckAHotCue1-4`, etc.
  - Soporte de pulsación transitoria (`activePushedZoneId`) con auto-apagado temporizado (80 ms) para dar retroalimentación visual al hacer clic en controles momentáneos.

### Paso 2: Capa de Presentación de la Consola DJ
- Integrar retroalimentación visual inmediata en `DjVisualMappingOverlay` y `DjHardwareConsolePainter`:
  - Renderizar halo de pulsación activa sobre el botón o perilla presionado.
  - Asegurar que los botones CUE, PLAY y SYNC en la vista modular también tengan iluminación neón vibrante según su estado.

### Paso 3: Sistema de Acoplamiento de Ventanas (Docking DAW)
- Enriquecer `StudioWorkspaceDockingContainer`:
  - Barra de Presets Rápidos: "Club Clásico", "Consola Fiel", "Estudio Stems", "Dividido 3 Paneles", "Restablecer".
  - En `StudioDockableWindowCard`: Botones de anclaje rápido en la barra superior con iconos intuitivos (`dock_to_left`, `dock_to_right`, `dock_to_bottom`, `maximize`).
  - Envoltura con `RepaintBoundary` en cada panel para aislar el repintado de formas de onda y jogs.

### Paso 4: Batería de Pruebas y Verificación
- Pruebas unitarias de sincronización de LEDs en `DjConsoleViewModel`.
- Pruebas de widgets de la barra de presets y botones de cabecera en `StudioWorkspaceDockingContainer`.
- Ejecución completa de `flutter analyze` y suite de pruebas.
- Compilación nativa de Linux y verificación en `DISPLAY=:0`.

---

## 4. Criterios de Aceptación (Definition of Done)
1. Los botones PLAY, CUE, SYNC y Hot Cues cambian de color e iluminación LED de forma instantánea y visible tanto en la consola física como en el modo modular.
2. Cada ventana en modo docking cuenta con botones visibles e intuitivos para moverla a cualquier zona en un solo clic.
3. Existe una barra de presets de disposición (1-Click) para alternar entre flujos de trabajo sin esfuerzo.
4. Cero advertencias o errores en `flutter analyze`.
5. Pruebas automatizadas pasando al 100%.
