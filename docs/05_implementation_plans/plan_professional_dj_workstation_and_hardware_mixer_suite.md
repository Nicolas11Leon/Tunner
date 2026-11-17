# Plan de Implementación: Estación de Trabajo DJ Profesional, Mezclador de Grado Club y Carga Real de Pistas/Stems (Erradicación de Sliders Rudimentarios)

Este documento define la estructura obligatoria que debe redactarse y validarse antes de ejecutar cualquier cambio significativo en el código fuente de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-DJ-PRO-WORKSTATION-2026-083`
- **Título de la Implementación:** `Transformación Integral de la Consola DJ: Mezclador Vertical de Grado Club (EQs de Precisión, VU-Meters Estéreo y Faders), Carga Real de Audio/Stems, Integración como Espacio de Trabajo Nativo (F4) y Erradicación de Mocks`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `En Progreso`
- **ADR Relacionado:** [ADR 0073: Consola DJ Profesional con Mezclador de Grado Club y Carga Universal de Audio](../04_adrs/0073_professional_dj_workstation_and_hardware_mixer_suite.md)
- **Documento Funcional Base:** [Caso de Uso 83](../02_use_cases/83_uc_professional_dj_workstation_and_hardware_mixer_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Erradicar la apariencia rudimentaria ("hecha de palitos") de la Consola DJ reemplazando los sliders horizontales genéricos por un **Mezclador de Grado Club Pro (Estilo Pioneer DJM-900NXS2 / Allen & Heath Xone)** con tiras de canal verticales, perillas/diales giratorios de EQ de 3 bandas (High, Mid, Low) con corte Isolator (-26dB a +6dB y Kill con LEDs), medidores VU-Meter duales estéreo animados por canal, faders verticales de volumen, crossfader con curva seleccionable, y selector real de pistas/stems (WAV, MP3, FLAC y catálogo maestro de estudio) que carga audio real y analiza BPM y clave Camelot de forma determinista.

Asimismo, integrar la Consola DJ como un **Espacio de Trabajo de Primer Nivel en pantalla completa** accesible desde la pestaña `Consola DJ` (`F4`) del `StudioWorkspaceTabBar`, permitiendo su uso tanto como estación completa como modal.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Componente atómico [`StudioRotaryKnob`](lib/core/design_system/atoms/studio_rotary_knob.dart): dial giratorio vectorial de precisión con indicador de aguja, arrastre vertical para ajustar valor, y muesca central de 0 dB.
  - Componente molecular [`DjVerticalChannelStrip`](lib/features/dj_console/presentation/dj_vertical_channel_strip.dart): tira de canal profesional con perilla Trim/Gain, EQ de 3 bandas (High, Mid, Low) con botones KILL iluminados, medidor VU-Meter estéreo de 12 segmentos con picos, fader vertical de volumen de 100 mm y botón CUE con iluminación LED.
  - Diálogo de carga real de pistas [`DjTrackLoaderModal`](lib/features/dj_console/presentation/dj_track_loader_modal.dart): permite importar archivos de audio del disco (WAV, MP3, FLAC, AIFF) o seleccionar pistas maestras de estudio con stems reales (Synthwave, Deep House, Funk, Jazz, Afrobeat) con BPM y clave Camelot precalculados.
  - Vista completa de espacio de trabajo [`DjStudioWorkstationView`](lib/features/dj_console/presentation/dj_studio_workstation_view.dart) integrada en `MainAppShell` para navegación con `F4`.
  - Reemplazo y rediseño completo del mezclador en `DjConsoleModal` para garantizar consistencia visual y funcional impecable.
- **Excluido (Out-of-Scope):**
  - Controladores MIDI USB mediante controladores externos de terceros (se utiliza la capa FFI y web standards existente).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Flutter SDK: Canal estable.
  - CustomPaint vector graphics: Pintura nativa a 60/120 FPS sin bloqueos.
  - Motor de audio: `DjAudioProcessor` y `BpmBeatTrackerEngine` 100% locales y offline.
- **Riesgo Tecnológico:**
  - Rendimiento gráfico: Los VU-Meters y formas de onda RGB deben dibujarse con CustomPainter eficiente para mantener 60 FPS estables.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa Atómica y Componentes Visuales Profesionales
- [x] Crear átomo `StudioRotaryKnob`: Dial rotatorio industrial con renderizado vectorial, arrastre cinemático y retroalimentación de valor numérico.
- [x] Crear molécula `StudioStereoVuMeter`: Medidor de nivel acústico estéreo de doble barra (verde -24dB..0dB, amarillo +3dB, rojo CLIP) con retención de picos.
- [x] Crear molécula `DjVerticalChannelStrip`: Tira de canal de mezclador analógico/digital de alta fidelidad.

### Paso 2: Sistema de Carga Real de Audio y Stems
- [x] Implementar `DjTrackLoaderModal`: Selector interactivo de audio con navegación por catálogo maestro y selector de archivos del sistema.
- [x] Conectar la carga directa de audio con `BpmBeatTrackerEngine` y el análisis de compatibilidad armónica Camelot.

### Paso 3: Rediseño Integral de la Estación DJ
- [x] Crear `DjStudioWorkstationView`: Espacio de trabajo a pantalla completa con formas de onda RGB paralelas, Decks A y B con jog wheels vectoriales y controles táctiles, Mezclador Central Pro de 2 canales, 4-Stems Isolator y 8 Sampler Pads.
- [x] Actualizar `main_app_shell.dart` para enlazar la pestaña `Consola DJ` (`F4`) a `DjStudioWorkstationView`.
- [x] Actualizar `DjConsoleModal` para utilizar los nuevos componentes de canal vertical y selector de pistas.

### Paso 4: Pruebas, Verificación y Build
- [x] Pruebas unitarias y de widgets para `StudioRotaryKnob`, `DjVerticalChannelStrip` y `DjTrackLoaderModal`.
- [x] `flutter analyze` con cero errores.
- [x] Compilación y despliegue del binario nativo en pantalla.
