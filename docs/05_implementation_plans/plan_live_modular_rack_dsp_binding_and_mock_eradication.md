# Implementation Plan: Enlace Real de DSP y Erradicación Total de Mocks en el Rack Modular

Este documento define la arquitectura y el plan de implementación para eliminar de raíz todos los componentes simulados, textos en duro y handlers vacíos (`onPressed: () {}`) dentro de las tarjetas del Rack Modular de Estudio (`RackUnitCard`), conectando cada uno de los 10 módulos de producción y análisis con los motores acústicos en vivo de `TunerViewModel`.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-RACK-2026-0080`
- **Título de la Implementación:** Enlace Real de DSP y Erradicación Total de Mocks en el Rack Modular
- **Fase del Proyecto:** `Fase 3` (Consolidación de Arquitectura de Audio y Estación de Trabajo Desktop)
- **Estado:** `Aprobado`
- **ADR Relacionado:** [0070_live_modular_rack_dsp_binding_and_mock_eradication.md](../04_adrs/0070_live_modular_rack_dsp_binding_and_mock_eradication.md)
- **Documento Funcional Base:** [80_uc_live_modular_rack_dsp_binding_and_mock_eradication.md](../02_use_cases/80_uc_live_modular_rack_dsp_binding_and_mock_eradication.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Vincular cada uno de los 10 módulos del Rack Modular con el estado real acústico, temporal y musical de `TunerViewModel`:
1. **Afinador Estroboscópico (`strobeTuner`):** Reemplazar el texto fijo `+0.2 ¢` y frecuencia fija por la nota detectada real en vivo (`noteName`), desviación centesimal exacta (`cents`) y frecuencia fundamental en Hertz (`fundamentalFrequency`).
2. **Metrónomo Determinista (`metronome`):** Reemplazar el slider y botones muertos por controles reales vinculados a `tunerViewModel.bpm`, `toggleMetronome()`, `setBpm(val)`, `tapTempo()` y compás real.
3. **Pentagrama en Vivo (`scoreNotation`):** Mostrar el estado real de la partitura cargada (`currentSongPackage`), compás actual y botones operativos para abrir el editor o importar archivos.
4. **Grabador de Audio (`practiceRecorder`):** Conectar el estado de grabación en vivo (`isRecording`), cronómetro en tiempo real, guardado de tomas y reproducción de archivos WAV capturados.
5. **Autotune DSP (`vocalAutoTune`):** Enlazar con calibración base A4 y temperamento activo, proveyendo acceso directo al modal de afinación vocal.
6. **Dron Armónico (`harmonicDrone`):** Visualizar el tono de referencia activo y alternar síntesis continua de audio real.
7. **Espectrograma FFT (`spectrogram`):** Reemplazar barras aleatorias fijas por visualización reactiva de energía espectral y nivel acústico en decibelios (`soundLevelDb`).
8. **Analizador Polifónico (`chordAnalyzer`):** Mostrar el acorde real detectado (`detectedChord`) o el estado de espera acústica.
9. **Tutor de Lecciones (`guidedLessons`):** Vincular con la rutina didáctica seleccionada y evaluación de rushing/dragging.
10. **Entrenador Auditivo (`earTrainer`):** Conectar con el motor de discriminación interválica a ciegas.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Refactorización integral de `lib/features/modular_rack/presentation/rack_unit_card.dart`.
  - Integración de `context.watch<TunerViewModel>()` dentro del ciclo de renderizado de cada tarjeta de unidad.
  - Sincronización del transporte maestro en `MultitaskMasterConsoleWidget` con `TunerViewModel`.
  - Pruebas unitarias y de widgets que validen la reactividad real de los 10 módulos.
- **Excluido (Out-of-Scope):**
  - Modificación de la API de plugins de audio VST3 externos (reservado para fases nativas).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Documentación Canónica
- [x] Plan de Implementación formal.
- [x] Caso de Uso 80 con diagramas Mermaid de caso de uso y secuencia.
- [x] ADR 0070 documentando la erradicación de mocks del rack.

### Paso 2: Implementación en Capa de Presentación
- [x] Actualizar `RackUnitCard` para consumir `TunerViewModel` de forma reactiva.
- [x] Implementar widgets funcionales para cada uno de los 10 tipos de módulo, eliminando todos los `onPressed: () {}` y constantes estáticas falsas.
- [x] Conectar los controles de transporte maestro de `MultitaskMasterConsoleWidget` con `tunerViewModel.toggleMetronome()` y `tunerViewModel.startPracticeRecording()`.

### Paso 3: Validación y Pruebas
- [x] Ejecutar `flutter analyze lib/ test/` con 0 advertencias.
- [x] Ejecutar suite de pruebas de widgets verificando el enlace reactivo.
- [x] Compilar y relanzar aplicación en pantalla `DISPLAY=:0`.
- [x] Git commit y push a la rama de trabajo.
