# Implementation Plan: Virtual DJ Performance Console & Universal QWERTY Keyboard Mapping Engine

Este documento define el plan paso a paso y los criterios de aceptación para la construcción e integración de la Consola de DJ Virtual de doble reproductor y el motor de mapeo universal de teclado QWERTY en **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-DJ-CONSOLE-2026-063`
- **Título de la Implementación:** Construcción de la Consola de DJ Virtual con Decks Duales, Pitch Shifting, Crossfader Curvilíneo, Jog Wheels Vectoriales y Mapeador QWERTY Universal
- **Fase del Proyecto:** Fase 3 (Herramientas Creativas Avanzadas) & Fase 4 (Hardware & Periféricos)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR 0059](../04_adrs/0059_virtual_dj_console_and_keyboard_mapping.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-065](../01_product_vision/doc_virtual_dj_console_and_keyboard_mapping.md), [UC-65](../02_use_cases/65_uc_virtual_dj_console_and_keyboard_mapping.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Crear un subsistema modular de consola de DJ virtual con dos decks (Deck A y Deck B), crossfader acústico con 3 curvas conmutables, ecualizadores de 3 bandas con cortes aisladores, control de pitch con sync de BPM, jog wheels vectoriales y un motor universal de mapeo de teclado QWERTY/MIDI que permita ejecutar mezclas completas con respuesta inferior a 10 milisegundos.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras: `DjDeckEntity`, `DjCrossfaderEntity`, `DjKeymapProfileEntity`, `DjPerformanceOrchestrator`, `DjAction`.
  - Servicio de persistencia de mapeos en JSON local.
  - Procesador de audio de mezcla y ecualización de decks.
  - Presentación: `DjConsoleModal`, `DjDeckView`, `VectorJogWheel`, `DjKeymapEditorModal`, y `DjConsoleViewModel`.
  - Integración en el catálogo universal de herramientas de Tunner (`AppToolCatalog`).
  - Suite de pruebas unitarias de dominio y pruebas de widgets.
- **Excluido (Out-of-Scope):**
  - Separación de stems en tiempo real basada en redes neuronales (Denoise/Demucs), la cual se alimenta de stems pre-generados por el sintetizador de Tunner o archivos WAV cargados.

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.0` (o versión estable activa en el proyecto).
- **Flutter SDK:** Canal estable oficial.
- **Dependencias Externas:** Ninguna dependencia adicional requerida; utiliza las capacidades nativas de `services` (para `KeyEvent` / `HardwareKeyboard`) y `custom_painter` de Flutter.
- **Riesgo Tecnológico:** Cero riesgo de busy-waiting loops. El refresco de jog wheels utiliza `SingleTickerProviderStateMixin` / `AnimationController` estándar atado a la tasa de refresco del display (vsync).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Crear `lib/features/dj_console/domain/dj_action.dart`: Definición de acciones canónicas de transporte, ecualización, crossfader y cues.
- [ ] Crear `lib/features/dj_console/domain/dj_crossfader_entity.dart`: Cálculo estricto de ganancias para curvas de Potencia Constante, Lineal y Fast Cut.
- [ ] Crear `lib/features/dj_console/domain/dj_deck_entity.dart`: Estado de transporte, pitch, BPM, hot cues y ganancias de ecualización.
- [ ] Crear `lib/features/dj_console/domain/dj_keymap_profile_entity.dart`: Mapeo de teclas a acciones con serialización y deserialización JSON.
- [ ] Crear `lib/features/dj_console/domain/dj_performance_orchestrator.dart`: Coordinación de eventos y despacho de acciones hacia los decks.
- [ ] Crear `test/features/dj_console/domain/dj_domain_test.dart`: Cobertura del 100% de la lógica matemática y de transporte.

### Paso 2: Capa de Infraestructura / Datos
- [ ] Crear `lib/features/dj_console/data/dj_audio_processor.dart`: Manejo de mezcla, ganancia de volumen y corte de frecuencias.
- [ ] Crear `lib/features/dj_console/data/dj_keymap_persistence_service.dart`: Almacenamiento y carga de perfiles de usuario.

### Paso 3: Capa de Presentación
- [ ] Crear `lib/features/dj_console/presentation/dj_console_view_model.dart`: Estado reactivo y enlace de teclado.
- [ ] Crear `lib/features/dj_console/presentation/vector_jog_wheel.dart`: CustomPainter optimizado para plato vinílico.
- [ ] Crear `lib/features/dj_console/presentation/dj_keymap_editor_modal.dart`: Editor interactivo para personalizar teclas.
- [ ] Crear `lib/features/dj_console/presentation/dj_console_modal.dart`: Vista principal de la consola con Deck A, Deck B, EQ y Crossfader.
- [ ] Integrar la herramienta en `AppToolCatalog` y atajos de teclado globales.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Crear `test/features/dj_console/presentation/dj_console_ui_test.dart`: Pruebas de widgets, interacción de botones y pulsaciones de teclas.
- [ ] Ejecutar `flutter analyze` asegurando cero advertencias.
- [ ] Ejecutar `flutter test` asegurando 100% de pruebas pasando.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Rama `main` o commit base de inicio.
- **Mitigación Inmediata:** Desactivación de la herramienta en `AppToolCatalog` y reversión aislada del directorio `lib/features/dj_console/`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero busy-waiting loops.
- [ ] Cero emojis en código fuente, comentarios, documentación y mensajes de commit.
- [ ] Pruebas unitarias de dominio y UI pasando al 100%.
- [ ] Documentación técnica (`DOC-ARCH-2026-065`), caso de uso (`UC-65`) y ADR (`ADR 0059`) completados.