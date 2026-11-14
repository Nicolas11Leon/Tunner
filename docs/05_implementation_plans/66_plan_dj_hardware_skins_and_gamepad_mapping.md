# Implementation Plan: DJ Console Visual Hardware Skins and Universal Controller Mapping

Este documento define el plan de trabajo detallado y los criterios de aceptación para la construcción del emulador visual de consolas físicas reales y el sistema universal de mapeo de controles (PC y Gamepads) en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-DJ-SKINS-2026-066`
- **Título de la Implementación:** Construcción del Emulador de Skins de Hardware DJ Industrial y Mapeo Universal de Teclado / Mandos de Videojuegos
- **Fase del Proyecto:** Fase 3 (Herramientas Creativas Avanzadas) & Fase 4 (Estudio de Producción)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR 0062](../04_adrs/0062_dj_hardware_skins_and_universal_gamepad_mapping.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-068](../01_product_vision/doc_dj_hardware_skins_and_gamepad_mapping.md), [UC-68](../02_use_cases/68_uc_dj_hardware_skins_and_gamepad_mapping.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Permitir al usuario emular visualmente las consolas DJ más famosas de la industria (Pioneer DDJ-FLX4, Pioneer CDJ-3000 y Traktor Kontrol S4 MK3) mediante skins vectoriales ultraligeros, y asignar de forma interactiva ("Learn Mode") cualquier botón o potenciómetro físico a teclas del computador o botones de un control de videojuegos (Xbox, PlayStation o gamepad USB).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio en Dart puro: `DjHardwareSkinEntity`, `DjSkinZoneEntity`, `DjControllerProfileEntity`.
  - Catálogo de hardware `DjHardwareCatalog` con las 3 consolas industriales más icónicas.
  - Servicio de entrada normalizado `DjGamepadInputService` para teclado y controles de consola.
  - Motor de renderizado vectorial `DjHardwareConsolePainter` con retroalimentación LED reactiva a 60/120 FPS.
  - Modo visual interactivo "Learn Mode" (`DjVisualMappingOverlay`) con asignación por clic y pulsación física.
  - Integración en `DjConsoleModal` con selector de consola y vista de hardware.
  - Pruebas unitarias de dominio, pruebas de datos y pruebas de widgets.
- **Excluido (Out-of-Scope):**
  - Descarga de texturas raster pesadas (PNG/JPG) para no engrosar el binario offline.

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** Canal estable oficial.
- **Flutter SDK:** Canal estable oficial (`CustomPainter`, `HardwareKeyboard`).
- **Dependencias Externas:** Ninguna librería externa adicional requerida.
- **Riesgo Tecnológico:** Cero busy-waiting loops. El dibujo vectorial corre sobre el canvas optimizado de Flutter.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Crear `lib/features/dj_console/domain/dj_skin_zone_entity.dart`: Zonas interactivas con coordenadas normalizadas `(x, y, w, h)`, tipo de control (`button`, `knob`, `fader`, `jogWheel`), acción `DjAction` y etiqueta visual.
- [ ] Crear `lib/features/dj_console/domain/dj_hardware_skin_entity.dart`: Definición de consola física con dimensiones de aspecto, fabricante, modelo y lista de zonas.
- [ ] Crear `lib/features/dj_console/domain/dj_controller_profile_entity.dart`: Mapeo unificado de periféricos (teclado + gamepad) con persistencia JSON.
- [ ] Pruebas unitarias: `test/features/dj_console/domain/dj_hardware_skin_test.dart`.

### Paso 2: Capa de Datos e Infraestructura
- [ ] Crear `lib/features/dj_console/data/dj_hardware_catalog.dart`: Layouts vectoriales precisos de Pioneer DDJ-FLX4, Pioneer CDJ-3000 + DJM-900NXS2 y Traktor Kontrol S4 MK3.
- [ ] Crear `lib/features/dj_console/data/dj_gamepad_input_service.dart`: Mapeo y normalización de eventos de mando de juego (Xbox / PlayStation) hacia `DjAction`.

### Paso 3: Capa de Presentación
- [ ] Crear `lib/features/dj_console/presentation/dj_hardware_console_painter.dart`: CustomPainter con estética industrial de chasis, aro lumínico reactivo de jog wheels, faders graduados y pads RGB.
- [ ] Crear `lib/features/dj_console/presentation/dj_visual_mapping_overlay.dart`: Capa táctil con modo Learn para asignación por clic y tecla/gamepad.
- [ ] Actualizar `lib/features/dj_console/presentation/dj_console_view_model.dart`: Gestión de consola física activa, estado LED de botones y modo Learn.
- [ ] Actualizar `lib/features/dj_console/presentation/dj_console_modal.dart`: Selector de consola física y conmutador de vista de hardware.
- [ ] Pruebas de widgets: `test/features/dj_console/presentation/dj_hardware_console_ui_test.dart`.

### Paso 4: Verificación, Quality Gate y Pull Request
- [ ] Ejecutar `flutter analyze` asegurando cero advertencias.
- [ ] Ejecutar la suite completa de pruebas unitarias y de widgets (`flutter test`).
- [ ] Realizar commit respetando la política de cero emojis y conventional commits.
- [ ] Enviar rama y abrir Pull Request con `gh pr create`.
- [ ] Verificar que GitHub Actions y SonarCloud pasen 100% en verde.

---

## 4. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero busy-waiting loops.
- [ ] Cero emojis en código fuente, comentarios, documentación y mensajes de commit.
- [ ] Todas las pruebas unitarias y de widgets pasando al 100%.
- [ ] Documentación técnica (`DOC-ARCH-2026-068`), caso de uso (`UC-68`) y ADR (`ADR 0062`) aprobados.
