# Plan de Implementación: Suite Interactiva Universal de Alto Rendimiento

Este documento formaliza la planificación técnica previa para dotar a **Tunner** de la suite interactiva universal definitiva, integrando física acústica en tiempo real, HUD de comandos rápidos, generación y sembrado de archivos WAV audibles reales en disco, vúmetros reactivos de alta precisión y rutina automatizada de prueba (Showcase de 15 segundos).

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-UNIVERSAL-INTERACTIVE-SUITE-2026-093`
- **Título de la Implementación:** Suite Interactiva Universal, Física Rítmica y HUD de Comandos Rápidos
- **Fase del Proyecto:** Fase 1 / Consolidación Universal (Beta Ready)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0083: docs/04_adrs/0083_universal_high_performance_interactive_suite.md](docs/04_adrs/0083_universal_high_performance_interactive_suite.md)
- **Documento Funcional Base:** [Caso de Uso 93: docs/02_use_cases/93_uc_universal_high_performance_interactive_suite.md](docs/02_use_cases/93_uc_universal_high_performance_interactive_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Consolidar la aplicación en una experiencia interactiva completa, fluida y de máxima calidad táctil y acústica para pruebas manuales y producción:
1. **Vúmetros Analógicos Dinámicos:** Modelado de decaimiento rítmico exponencial en tiempo real sincronizado a la fase del BPM en canales A, B y Master.
2. **Archivos Físicos Reales en Disco:** Reemplazar datos semilla vacíos por archivos PCM WAV estereofónicos reales de alta fidelidad (`Toma_Acustica_440Hz.wav` y `Loop_Club_Groove_124BPM.wav`) generados proceduralmente en `~/Documents/TunnerProjects`.
3. **HUD Flotante de Atajos Rápidos:** Barra superior colapsable que documenta y guía la interacción por teclado físico para flujo de trabajo profesional.
4. **Selector Rápido de Pistas en Cabecera de Decks:** Menú directo para intercambiar instantáneamente entre 5 estilos de estudio sin pasos intermedios.
5. **Rutina de Demostración y Prueba Automática (Showcase 15s):** Secuencia coreografiada no bloqueante que activa y prueba todos los motores simultáneamente (reproducción, hot cues, loops, sampler, sincronización y crossfader).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/core/file_system/data/local_disk_studio_file_system_repository.dart`: Generación procedural de WAVs válidos de 16-bit PCM para el almacenamiento local.
  - `lib/features/dj_console/presentation/dj_vertical_channel_strip.dart`: Física de vúmetros con rebote exponencial sincronizado al compás.
  - `lib/features/dj_console/presentation/dj_studio_workstation_view.dart`: HUD de atajos rápidos, selector de géneros en Decks y botón de Showcase.
  - `lib/features/dj_console/presentation/dj_console_view_model.dart`: Orquestación asíncrona cancelable para la rutina de Showcase de 15 segundos.
- **Excluido (Out-of-Scope):**
  - Servidores remotos o dependencias externas de red (principio Offline First inmutable).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart / Flutter SDK:** Canal estable oficial.
- **Matemáticas de Decaimiento:**
  $$\text{beatPulse} = 0.40 + 0.60 \cdot e^{-3.5 \cdot \text{fase}}$$
- **Seguridad en Pruebas:**
  - Las rutinas de Showcase y temporizadores deben ser cancelables y limpiarse en `dispose()`.
  - Cero dependencias nativas bloqueantes en el hilo principal.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Infraestructura y Sistema de Archivos
- [x] Enriquecer `_seedDefaultWorkspaceStructure` en `LocalDiskStudioFileSystemRepository` para escribir bytes PCM WAV reales sintetizados proceduralmente.
- [x] Verificar que los archivos generados en disco contengan cabeceras RIFF/WAVE completas y datos audibles.

### Paso 2: Capa de Presentación (Física Rítmica en Vúmetros)
- [x] Implementar el cálculo de fase de pulso y decaimiento exponencial en `DjVerticalChannelStrip`.
- [x] Validar que el vúmetro oscile con dinámica de bombo y percusión durante la reproducción y vuelva a cero en pausa.

### Paso 3: Capa de Presentación (HUD, Carga Rápida y Showcase)
- [x] Incorporar el HUD colapsable de atajos en `DjStudioWorkstationView`.
- [x] Añadir menú de carga rápida en los paneles de Deck A y B.
- [x] Implementar `runShowcaseRoutine()` y `cancelShowcaseRoutine()` en `DjConsoleViewModel`.

### Paso 4: Pruebas, Verificación y Build
- [x] Escribir suite de pruebas en `test/features/dj_console/dj_universal_suite_interactive_test.dart`.
- [x] Ejecutar `flutter analyze` (0 advertencias).
- [x] Ejecutar `flutter test` asegurando 100% de éxito.
- [x] Compilar binario de producción Linux.

---

## 4. Criterios de Aceptación (Definition of Done)

- [x] Cero emojis en código, comentarios y documentación.
- [x] Vúmetros rebotan rítmicamente en tiempo real al BPM.
- [x] Archivos en disco son WAVs reales reproducibles por cualquier reproductor del sistema operativo.
- [x] HUD y botones de carga rápida responden instantáneamente al clic del usuario.
- [x] Showcase de 15 segundos ejecuta la coreografía acústica completa sin excepciones.
- [x] Todas las pruebas automatizadas pasando al 100%.
