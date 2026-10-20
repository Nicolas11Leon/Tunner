# Implementation Plan: Fase 1 Core Audio Engine & Metronome Optimization

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-AUDIO-ENGINE-2026-001`
- **Título de la Implementación:** `Optimización No Bloqueante del Reloj de Audio y Expansión Universal de Detección de Frecuencias`
- **Fase del Proyecto:** `Fase 1`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `docs/04_adrs/0001_in_process_isolate_clock_and_dsp_pipeline.md`
- **Documento Funcional Base:** `docs/02_use_cases/01_uc_acoustic_pitch_detection.md` y `docs/02_use_cases/02_uc_high_res_audio_clock.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Resolver la deuda técnica crítica de rendimiento en el metrónomo eliminando el bucle de espera activa (*busy-waiting loop*) para reducir el consumo parásito de CPU del 100% a $\le 1\%$, y expandir el motor de afinación eliminando el filtro rígido (200-3000 Hz) para dar cobertura universal a todos los registros vocales humanos ($E_2$ a $C_6$, ~80 Hz a 1100 Hz) e instrumentales ($A_0$ a $C_8$, 27.5 Hz a 4186 Hz) con cálculo de energía acústica mínima (Noise Gate RMS).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Refactorización de `lib/data/metronome_service.dart`: Reemplazo del `while (true)` con `Stopwatch` activo por un despachador no bloqueante basado en temporizador con *sleep* compensado o `Timer.periodic`.
  - Refactorización de `lib/data/pitch_detector_service.dart`: Incorporación de filtro de potencia RMS para rechazo de ruido de fondo y soporte de perfiles acústicos (Voz, Bajo/Guitarra, Vientos, Universal).
  - Robustecimiento de `lib/domain/note_entity.dart`: Documentación matemática formal de la escala temperada a 440 Hz y pruebas unitarias completas.
  - Creación del primer ADR formal en `docs/04_adrs/`.
- **Excluido (Out-of-Scope):**
  - Renderizado SMuFL de partituras (reservado para la Fase 2).
  - Síntesis de sonido SoundFont (reservado para la Fase 3).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.5` (Estable).
  - Flutter SDK: Canal estable oficial.
  - `record: ^6.2.1`: Stream de audio PCM directo.
  - `pitch_detector_dart: ^0.0.7`: Algoritmo base de autocorrelación.
  - `provider: ^6.1.5+1`: Inyección de dependencias y estado reactivo.
- **Riesgo Tecnológico:**
  - **Riesgo Bajo.** No requiere dependencias de terceros nuevas; se optimiza la utilización de la biblioteca estándar de Dart (`dart:isolate`, `dart:math`, `dart:async`).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Pure Dart)
- [ ] Documentar y afinar `NoteEntity.fromFrequency(double freq)` para manejar correctamente cualquier frecuencia entre 20 Hz y 5000 Hz sin artefactos de división ni notas fantasma.
- [ ] Crear la suite de pruebas unitarias en `test/domain/note_entity_test.dart` verificando frecuencias estándar ($A_4 = 440.0\text{ Hz} \rightarrow \text{La4}, 0\text{ cents}$, $C_4 = 261.63\text{ Hz}$, $E_2 = 82.41\text{ Hz}$, etc.).

### Paso 2: Capa de Infraestructura / Datos (Servicios de Audio y Reloj)
- [ ] **Reloj de Audio:** Refactorizar `MetronomeService` para que el `Isolate` use temporización no bloqueante que rinda ciclos al SO, asegurando consumo casi nulo de batería.
- [ ] **Procesador de Tono:** Refactorizar `PitchDetectorService` calculando el valor cuadrático medio (RMS) del buffer PCM16:
  $$\text{RMS} = \sqrt{\frac{1}{N}\sum_{i=1}^{N} x_i^2}$$
  Descartar buffers con $\text{RMS} < \text{umbral}$ para que el afinador no salte con el susurro del aire.
- [ ] Ampliar el rango permitido de frecuencias a $27.5\text{ Hz} \le f \le 4186\text{ Hz}$.

### Paso 3: Capa de Presentación (ViewModel y Feedback Visual)
- [ ] Conectar los nuevos rangos y el control optimizado del metrónomo en `TunerViewModel`.
- [ ] Validar que la interfaz responde fluidamente sin caídas de cuadros (*frame drops*).

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecutar `flutter analyze` y asegurar 0 errores de linter.
- [ ] Ejecutar `flutter test` garantizando 100% de tests pasando.
- [ ] Redactar el ADR `0001_in_process_isolate_clock_and_dsp_pipeline.md`.
- [ ] Commit y sincronización con GitHub.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- Si la precisión temporal del nuevo temporizador presenta fluctuaciones (*jitter*) audibles, se conservará la lógica desacoplada bajo una interfaz de estrategia para ajustar el mecanismo de sleep sin alterar la UI ni el ViewModel.
- Punto de restauración Git: `cadd9c1` (Commit actual de la rama `main`).

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Cero busy-waiting loops verificados en código.
- [ ] Soporte probado para el registro vocal grave y agudo.
- [ ] Pruebas unitarias de dominio pasando con éxito.
- [ ] ADR documentado en `docs/04_adrs/`.
- [ ] Sincronizado en la rama `main` de GitHub.
