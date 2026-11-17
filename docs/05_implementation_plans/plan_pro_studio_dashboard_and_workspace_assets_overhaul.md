# Plan de Implementación: Rediseño Pro del Dashboard de Inicio y Activos de Espacio de Trabajo

Este documento define la planificación técnica para elevar la estética, ergonomía e interactividad del Dashboard Principal de Tunner (`HomeDashboardScreen`) y eliminar los indicadores vacíos `(0)` en la barra lateral del explorador, incorporando la tarjeta de la Consola DJ Pro, un diseño de rejilla responsiva de estudio y sembrado de proyectos canónicos en el ViewModel.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-UI-DASHBOARD-WORKSPACE-OVERHAUL-2026-095`
- **Título de la Implementación:** Rediseño Pro del Dashboard de Inicio, Incorporación de Consola DJ y Población de Activos
- **Fase del Proyecto:** Fase 1 / Consolidación de Experiencia y Estética de Estudio
- **Estado:** Propuesto
- **ADR Relacionado:** [ADR 0085: docs/04_adrs/0085_pro_studio_dashboard_and_workspace_assets_overhaul.md](docs/04_adrs/0085_pro_studio_dashboard_and_workspace_assets_overhaul.md)
- **Documento Funcional Base:** [Caso de Uso 95: docs/02_use_cases/95_uc_pro_studio_dashboard_and_workspace_assets_overhaul.md](docs/02_use_cases/95_uc_pro_studio_dashboard_and_workspace_assets_overhaul.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar la pantalla principal (`HomeDashboardScreen`) y el árbol de documentos del proyecto en una estación de trabajo de grado profesional (Ableton/Logic/Rekordbox):
1. **Incorporación de la Consola DJ Pro:** Agregar la tarjeta de gran formato para la Consola DJ en los módulos principales, permitiendo el salto directo a la estación de mezcla de 2 decks.
2. **Rejilla Responsiva de Escritorio:** En pantallas de escritorio ($\ge 900\text{px}$), presentar los módulos de trabajo en una cuadrícula moderna de 2 o 3 columnas con profundidad, micro-bordes y gradientes sutiles, eliminando el vacío horizontal plano.
3. **Población Canónica de Activos en Sidebar:** Sembrar en `TunerViewModel` partituras de repertorio curado, tomas de audio WAV de estudio y presets de afinación histórica por defecto, de modo que `Documentos del Proyecto` muestre activos reales (`(3)`, `(2)`, `(2)`) y no carpetas vacías `(0)`.
4. **Interactividad Sonora en Dashboard:** Botón para escuchar el tono de referencia del diapasón directamente en la tarjeta de instrumento activo.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `lib/features/navigation/presentation/home_dashboard_screen.dart`: Rejilla responsiva, tarjeta de Consola DJ Pro, gradientes sutiles y micro-métricas en vivo.
  - `lib/features/tuner_viewmodel.dart`: Inicialización con partituras de estudio, tomas WAV y presets de afinación por defecto.
  - `lib/features/navigation/presentation/main_app_shell.dart`: Integración fluida de navegación para los nuevos activos.
- **Excluido (Out-of-Scope):**
  - Modificación de los algoritmos de detección de tono o códecs de audio.

---

## 2. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Estado y Datos (TunerViewModel)
- [ ] Enriquecer `_initDefaultWorkspaceAssets()` en `TunerViewModel` para cargar las 3 partituras maestras de la biblioteca curada en `_workspaceScores`.
- [ ] Inicializar tomas de audio de referencia (`Toma Acústica A4 - 440 Hz`, `Groove Estudio 124 BPM`) en `_recordingHistory`.
- [ ] Inicializar presets de afinación orquestal (442 Hz y Barroco 415 Hz) en `_customTuningPresets`.

### Paso 2: Capa de Presentación (HomeDashboardScreen)
- [ ] Diseñar la tarjeta de gran formato para **Consola DJ Pro Workstation** (Navegación al tab 5).
- [ ] Implementar el diseño de cuadrícula responsiva (`Wrap` / `LayoutBuilder`) para pantallas de escritorio.
- [ ] Incorporar el botón interactivo de audición de diapasón en el banner del instrumento activo.

### Paso 3: Pruebas, Verificación y Control de Calidad
- [ ] Ejecutar `flutter analyze` verificando cero advertencias.
- [ ] Ejecutar `flutter test` asegurando que todos los tests pasen al 100%.
- [ ] Recompilar binario de producción Linux.

---

## 3. Criterios de Aceptación (Definition of Done)

- [ ] Cero emojis en código, comentarios y documentación técnica.
- [ ] La Consola DJ Pro se encuentra visible y accesible con un clic desde el dashboard principal.
- [ ] La barra lateral muestra activos poblados (`(3)`, `(2)`, `(2)`) con navegación directa a cada uno.
- [ ] El diseño en escritorio distribuye el espacio en cuadrícula profesional sin vacíos visuales.
- [ ] Cero regresiones en la suite de pruebas.
