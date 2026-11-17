# Implementation Plan: Authentic Hardware Console Skins & Interactive QWERTY Keymapper Suite

Este documento define la planificación técnica formal para la implementación de consolas de hardware DJ hiper-realistas y el sistema de mapeo interactivo de teclado QWERTY en **Tunner**, cumpliendo con la Constitución del Proyecto (`AGENTS.md`), Clean Architecture y el ciclo canónico de ingeniería.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-DJ-HARDWARE-KEYMAPPER-2026-0074`
- **Título de la Implementación:** Visualización Fiel de Modelos de Consolas de Hardware DJ y Suite de Mapeo Interactivo de Teclado QWERTY
- **Fase del Proyecto:** Fase 2 (Instrumentos Virtuales y Motores de Mezcla DSP)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0074: Authentic Hardware Console Skins & Interactive QWERTY Keymapper Suite](../04_adrs/0074_authentic_hardware_console_skins_and_interactive_keymapper.md)
- **Documento Funcional Base:** [Caso de Uso 84: Visualización Fiel de Consolas Hardware y Mapeo Interactivo de Teclado](../02_use_cases/84_uc_authentic_hardware_console_skins_and_interactive_keymapper.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la experiencia de la Consola DJ en un entorno de hardware virtual fidedigno e hiper-ergonómico donde:
1. El usuario pueda seleccionar e interactuar visualmente con consolas y módulos de hardware reales de la industria (Pioneer DDJ-FLX4, Pioneer CDJ-3000 + DJM-900NXS2, Traktor Kontrol S4 MK3, Denon DJ Prime 4+, Numark Mixtrack Pro FX) con acabados industriales vectoriales (metal cepillado, jogs de vinilo con estrías microscópicas y display central de aguja/BPM, botones circulares luminiscentes con serigrafía de club, faders de carbono y VU-meters integrados).
2. El usuario pueda mapear cualquier tecla de su teclado físico QWERTY de manera directa e intuitiva sobre cada control de la consola (Click en control $\rightarrow$ Presionar tecla $\rightarrow$ Asignación instantánea guardada con badge visible sobre el control), además de un visualizador interactivo de teclado QWERTY con presets de la industria (VirtualDJ, Traktor Pro, Serato DJ).
3. Se garantice la captura global de pulsaciones de teclado mediante `KeyboardListener` y `FocusNode` en la vista de estación de trabajo `DjStudioWorkstationView` con latencia sub-10ms.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Catálogo ampliado de modelos de hardware con especificaciones industriales (`denonPrime4`, `mixtrackProFx`, mejoras a `ddjFlx4`, `cdj3000`, `traktorKontrolS4`).
  - Renderizado vectorial de alta definición en `DjHardwareConsolePainter` con insignias de atajo de teclado (`keyBadges`), serigrafías de chasis, texturizado de vinilo, graduación de potenciómetros e iluminación LED reactiva.
  - Intercepción global de teclado en `DjStudioWorkstationView` y `DjConsoleModal` con captura de eventos `KeyEvent` y soporte de modificadores (Shift, Ctrl, Alt).
  - Modal interactivo de visualización de teclado QWERTY (`DjInteractiveKeymapVisualizerModal`) con iluminación de teclas según función y presets estándar de la industria.
  - Alternador de vistas en `DjStudioWorkstationView`: Modo Hardware Completo, Modo Split-Screen (Formas de onda + Consola Hardware) y Modo Modular DAW.
  - Persistencia de perfiles de mapeo en disco mediante `DjKeymapPersistenceService`.
  - Cobertura de pruebas unitarias y de widgets para todas las nuevas capacidades.
- **Excluido (Out-of-Scope):**
  - Controladores físicos MIDI USB por protocolo SysEx exclusivo (se mantiene la capa genérica HID/Gamepad ya soportada).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK & Flutter:** Flutter Estable en Linux Desktop (`dart:math`, `package:flutter/services.dart` para `RawKeyDownEvent`/`KeyDownEvent` y `LogicalKeyboardKey`).
- **Arquitectura:** Clean Architecture.
  - Dominio: Entidades inmutables (`DjHardwareSkinEntity`, `DjSkinZoneEntity`, `DjKeymapProfileEntity`, `DjAction`).
  - Infraestructura: `DjHardwareCatalog`, `DjKeymapPersistenceService`.
  - Presentación: `DjHardwareConsolePainter`, `DjVisualMappingOverlay`, `DjInteractiveKeymapVisualizerModal`, `DjStudioWorkstationView`, `DjConsoleViewModel`.
- **Riesgo Tecnológico:** Cero dependencias nativas externas requeridas. Renderizado vectorial puro por `Canvas` manteniendo 60/120 FPS fluidos.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio y Catálogo de Modelos Fidedignos
- [ ] Ampliar `DjHardwareCatalog` con nuevos modelos icónicos: `denonPrime4` y `mixtrackProFx`.
- [ ] Incorporar soporte para insignias de teclas en `DjSkinZoneEntity` y resolución reactiva de atajos a partir de `DjKeymapProfileEntity`.
- [ ] Crear presets canónicos de la industria en `DjKeymapProfileEntity` (`virtualDjStandard`, `traktorProStandard`, `seratoDjStandard`).

### Paso 2: Renderizador Vectorial Industrial y Badges de Teclado
- [ ] Actualizar `DjHardwareConsolePainter` con estética industrial de placa metálica, marcadores de aguja, serigrafía de marcas, ranuras de fader, indicadores luminosos de corte y visualización de insignias de teclas asociadas (`[SPACE]`, `[Q]`, `[W]`, etc.).
- [ ] Implementar animación de foco/halo dorado para controles seleccionados en modo asignación.

### Paso 3: Componentes de Mapeo Interactivo y Visualizador QWERTY
- [ ] Crear `DjInteractiveKeymapVisualizerModal` con renderizado de teclado QWERTY físico, coloreado por decks/funciones, asignación visual de un clic y selector de presets.
- [ ] Actualizar `DjVisualMappingOverlay` con soporte para alternar visualización de atajos (`Ver Teclas`), selector rápido de modelo de hardware y modo Learn asistido por teclado.

### Paso 4: Integración en la Estación de Trabajo `DjStudioWorkstationView`
- [ ] Integrar `FocusNode` y `KeyboardListener` en `DjStudioWorkstationView` para captura de atajos con foco automático.
- [ ] Agregar selector de modo de vista (Hardware Fiel, Split-Screen con Formas de Onda RGB, y Modular Pro).
- [ ] Integrar botón de acceso directo a la visualización de consola y mapeo en el encabezado.

### Paso 5: Pruebas, Verificación y Control de Calidad
- [ ] Redactar pruebas unitarias de hardware catalog y mapeo de teclado en `test/features/dj_console/`.
- [ ] Ejecutar `flutter analyze` asegurando cero advertencias.
- [ ] Ejecutar suite completa de tests de la Consola DJ.
- [ ] Compilar y desplegar en `DISPLAY=:0`.
- [ ] Documentar y subir cambios a Git.
