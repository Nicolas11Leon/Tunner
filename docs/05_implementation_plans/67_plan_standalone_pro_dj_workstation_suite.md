# Plan de Implementación: Estación de Trabajo DJ Profesional Autónoma para PC (Standalone Pro DJ Workstation)

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-DJ-WORKSTATION-2026-067`
- **Título de la Implementación:** `Suite DJ Profesional Autónoma: 4-Stems DSP en Tiempo Real, Mezcla Armónica Camelot, Ondas Espectrales Paralelas RGB, Auto-Loops Cuantizados con Slip Mode, Sampler de 8 Pads, Automix con Bass-Swap y Monitoreo Split-Cue`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Propuesto`
- **ADR Relacionado:** `[ADR 0063](../04_adrs/0063_standalone_pro_dj_workstation_dsp_and_stems_architecture.md)`
- **Documento Funcional Base:** `[DOC-DJ-2026-069](../01_product_vision/doc_standalone_pro_dj_workstation_architecture.md)`
- **Caso de Uso Asociado:** `[UC-69](../02_use_cases/69_uc_standalone_pro_dj_workstation_suite.md)`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Consolidar el módulo `dj_console` de **Tunner** como una estación de trabajo DJ profesional todo-en-uno (*Standalone Pro DJ Workstation*) que permita a cualquier persona realizar sesiones completas en vivo utilizando únicamente un computador personal (PC/Laptop), su teclado y/o un mando de videojuegos, igualando las capacidades operativas de *Rekordbox*, *Serato DJ Pro*, *Traktor Pro 4* y *VirtualDJ*.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  1. **Capa de Dominio (`lib/features/dj_console/domain/`):**
     - `dj_stem_isolation_entity.dart`: Modelo inmutable para control de los 4 Stems por canal (`vocals`, `drums`, `bass`, `melody`) con estados *mute/solo*, ganancias individuales y presets rápidos (*Acapella Instantánea*, *Instrumental Instantáneo*, *Drum & Bass Tool*).
     - `dj_harmonic_camelot_engine.dart`: Motor matemático de la Rueda de Camelot (`1A`–`12A` menor, `1B`–`12B` mayor), detector cromático de tonalidad desde muestras de audio, evaluador de compatibilidad armónica (`perfectMatch`, `adjacentStep`, `relativeSwitch`, `energyBoost`, `clash`) y calculador de semitonos óptimos para `Key-Sync`.
     - `dj_loop_and_slip_engine.dart`: Lógica cuantizada para Auto-Loops ($1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8, 16$ beats), división/multiplicación (`halveLoop`, `doubleLoop`), `Beat Jump` ($\pm 1, \pm 4, \pm 8, \pm 16$ beats) y línea de tiempo dual para `Slip Mode`.
     - `dj_sampler_bank_entity.dart`: Entidad de 8 pads de efectos de performance y transiciones con cuantización opcional y control de volumen máster del sampler.
     - `dj_smart_automix_engine.dart`: Motor de transiciones automáticas entre Deck A y Deck B con curvas configurables e intercambio gradual de bajos (*Bass-Swap*) en el punto de cruce.
     - `dj_cue_monitor_entity.dart`: Estado de pre-escucha PFL por canal (`cueDeckA`, `cueDeckB`), balance `Cue/Master` y modo `Split-Cue Mono` (Master en L, Cue en R).
     - Expansión de `dj_action.dart`, `dj_deck_entity.dart`, `dj_controller_profile_entity.dart` y `dj_performance_orchestrator.dart` para integrar todas las nuevas acciones de Stems, Loops, Key-Sync, Sampler y Split-Cue.
  2. **Capa de Infraestructura / Datos (`lib/features/dj_console/data/`):**
     - Expansión de `dj_audio_processor.dart`: Filtros de aislamiento de 4 Stems en tiempo real (Mid/Side + Crossover Linkwitz-Riley + Detector de Transitorios) y matriz de salida `Split-Cue`.
     - `dj_transition_sfx_synthesizer.dart`: Generador procedural 100% *offline* de los 8 efectos del Sampler (*Airhorn*, *White Noise Riser*, *Sub-Bass Drop*, *Laser Dub Siren*, *Vinyl Brake*, *Backspin*, *Impact Hit*, *Vocal Chop Stutter*) y generador de perfiles espectrales RGB (`low`, `mid`, `high`) para visualización de ondas.
  3. **Capa de Presentación (`lib/features/dj_console/presentation/`):**
     - `dj_parallel_waveform_painter.dart`: `CustomPainter` de alta velocidad ($60/120\text{ FPS}$) que dibuja las dos formas de onda espectrales RGB apiladas horizontalmente, el *Beatgrid* sincronizado, las regiones de bucle activas, el puntero fantasma de *Slip Mode* y el medidor central de fase (*Phase Meter*).
     - `dj_pro_workstation_panel.dart`: Panel modular compacto para la estación DJ con controles táctiles/clicables de **4-Stems**, **Camelot Key & Key-Sync**, **Auto-Loops & Slip Mode**, **Sampler de 8 Pads**, **Smart Automix (Bass-Swap)** y **Split-Cue Monitor**.
     - Integración fluida en `dj_console_view_model.dart` y `dj_console_modal.dart`.
  4. **Suite de Pruebas (`test/features/dj_console/`):**
     - Pruebas unitarias exhaustivas de dominio, DSP y widgets verificando el 100% de los nuevos motores sin romper las 634 pruebas existentes.
- **Excluido (Out-of-Scope):**
  - Integración con servicios de streaming en la nube con DRM (Spotify, Apple Music, Tidal) por mandato de privacidad y arquitectura 100% *Offline-First* de `AGENTS.md`.
  - Descarga de modelos neuronales externos de varios gigabytes.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (Estable).
  - Flutter SDK: Canal oficial estable.
  - Dependencias externas adicionales: **Ninguna (Zero External Dependencies)**. Todo el procesamiento DSP (Mid/Side, filtros biquad/RC, envolvente de transitorios, síntesis FM/ruido para el Sampler y análisis cromático de Camelot) se implementa en Dart puro optimizado con `Float32List`.
- **Riesgo Tecnológico:**
  - **Introduce dependencias nativas o FFI:** No en esta iteración (compatible con todas las plataformas: Linux, Windows, macOS, Web, Android, iOS).
  - **Impacto en el hilo principal de Flutter:** Nulo. Los cálculos de ondas espectrales se pre-computan al cargar la pista y el renderizador `CustomPainter` opera únicamente sobre ventanas visibles en $O(W)$ donde $W$ es el número de barras visibles en pantalla ($\le 120$ segmentos).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio — Motores Matemáticos y Entidades Puras (`lib/features/dj_console/domain/`)
- [ ] **1.1 `dj_stem_isolation_entity.dart`:**
  - Definir `enum DjStemType { vocals, drums, bass, melody }`.
  - Crear `DjStemIsolationEntity` con ganancias `[0.0, 1.0]` y flags `isMuted` para cada stem, más métodos de preset rápido: `isolateAcapella()` (solo voz), `isolateInstrumental()` (silencia voz), `isolateRhythm()` (solo batería y bajo) y `resetAll()`.
- [ ] **1.2 `dj_harmonic_camelot_engine.dart`:**
  - Definir las 24 claves de la Rueda de Camelot (`1A` a `12A` y `1B` a `12B`) con su nombre musical estándar (ej. `8A = A minor`, `8B = C major`).
  - Implementar `analyzeCompatibility(String keyA, String keyB)` devolviendo `CamelotCompatibility` (`perfectUnison`, `harmonicStep`, `relativeMajorMinor`, `energyBoost`, `harmonicClash`).
  - Implementar `calculateOptimalSemitoneShift(String sourceKey, String targetKey)` que halla el desplazamiento mínimo en semitonos $\Delta s \in [-6, +6]$ para que la tonalidad de origen coincida armónicamente con la de destino.
  - Implementar `estimateCamelotKeyFromSamples(Float32List samples, int sampleRate)` mediante correlación cromática de perfiles tonales.
- [ ] **1.3 `dj_loop_and_slip_engine.dart`:**
  - Implementar cuantización de bucles para fracciones $b \in \{0.03125, 0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0\}$ beats.
  - Implementar `halveLoop()`, `doubleLoop()`, `computeBeatJumpMs()` y actualización de doble puntero $(t_{\text{audible}}, t_{\text{slip}})$ para `Slip Mode`.
- [ ] **1.4 `dj_sampler_bank_entity.dart`:**
  - Definir los 8 pads canónicos de club (`airhorn`, `whiteNoiseRiser`, `subBassDrop`, `laserSiren`, `vinylBrake`, `backspin`, `impactHit`, `vocalChop`) con estado activo, contador de disparos y volumen del banco.
- [ ] **1.5 `dj_smart_automix_engine.dart` y `dj_cue_monitor_entity.dart`:**
  - Implementar cálculo de interpolación de crossfader asistido y curva de intercambio automático de graves (*Bass-Swap* sin colisión de fase).
  - Implementar modelo de monitoreo PFL y configuración `Split-Cue Mono`.
- [ ] **1.6 Actualización de `dj_action.dart`, `dj_deck_entity.dart`, `dj_controller_profile_entity.dart` y `dj_performance_orchestrator.dart`:**
  - Añadir acciones para Stems (`deckAToggleVocalStem`, `deckAToggleDrumsStem`, `deckAToggleBassStem`, `deckAToggleMelodyStem`, equivalentes en Deck B), Loops (`deckALoopToggle`, `deckALoopHalve`, `deckALoopDouble`, `deckABeatJumpForward`, `deckABeatJumpBack`), Armonía (`deckAKeySync`, `deckBKeySync`, `deckAToggleSlip`, `deckBToggleSlip`), Sampler (`triggerSamplerPad1`..`4`), Automix (`startSmartAutomix`) y Pre-escucha (`toggleSplitCue`).

### Paso 2: Capa de Infraestructura / Datos — DSP Multibanda y Síntesis (`lib/features/dj_console/data/`)
- [ ] **2.1 Expansión de `dj_audio_processor.dart`:**
  - Implementar `applyStemIsolation(Float32List input, DjStemIsolationEntity stems)` usando descomposición espectral de 3 bandas + detector diferencial de transitorios para percusión y extracción de banda formántica vocal ($280\text{ Hz} - 3800\text{ Hz}$).
  - Implementar `encodeSplitCueStereo(Float32List masterMono, Float32List cueMono)` que entrelaza el bus Master en el canal Izquierdo ($L$) y el bus Cue en el canal Derecho ($R$).
- [ ] **2.2 Creación de `dj_transition_sfx_synthesizer.dart`:**
  - Implementar síntesis matemática determinista para los 8 pads del Sampler (barridos de ruido blanco filtrado para *Risers*, caída exponencial de seno $90\text{ Hz} \to 28\text{ Hz}$ para *Sub Drop*, oscilador FM para *Laser Siren*, acorde de quinta desafinada para *Airhorn*, etc.).
  - Implementar `computeSpectralWaveformSummary(Float32List samples, int buckets)` para extraer las envolventes RGB (`lowEnergy`, `midEnergy`, `highEnergy`) de la pista.

### Paso 3: Capa de Presentación — Ondas Paralelas RGB y Paneles Pro (`lib/features/dj_console/presentation/`)
- [ ] **3.1 `dj_parallel_waveform_painter.dart`:**
  - Construir el lienzo vectorial de doble onda paralela RGB con líneas de *Beatgrid* (rojas para el *Downbeat* 1, blancas para tiempos 2–4), sombreado de región de `Auto-Loop`, marcador de `Slip Mode` y barra central `Phase Alignment Meter`.
- [ ] **3.2 `dj_pro_workstation_panel.dart`:**
  - Construir la interfaz ergonómica de controles avanzados:
    - Sección **4-Stems Isolation** (botones `VOCAL`, `DRUMS`, `BASS`, `MELODY` + atajos `ACAPELLA` e `INSTRUMENTAL`).
    - Sección **Harmonic Camelot & Key-Sync** (insignia Camelot coloreada, estado de compatibilidad armónica, semitonos $\pm$ y botón `KEY SYNC`).
    - Sección **Quantized Loops, Slip & Beat Jump** (botones `1/4`, `1/2`, `1`, `2`, `4`, `8`, `1/2x`, `2x`, `SLIP`, `< JUMP`, `JUMP >`).
    - Sección **8-Pad Club Sampler & Smart Automix (Bass-Swap)** + **Split-Cue Headphone Monitor**.
- [ ] **3.3 Integración en `dj_console_view_model.dart` y `dj_console_modal.dart`:**
  - Conectar el ticker de reproducción para avanzar el reloj de `Slip Mode`, ejecutar transiciones suaves de `Smart Automix` con *Bass-Swap* y actualizar las ondas paralelas RGB a $60/120\text{ FPS}$.

### Paso 4: Pruebas Exhaustivas, Análisis Estático y Pull Request
- [ ] **4.1 Pruebas Unitarias de Dominio y Datos:**
  - `test/features/dj_console/domain/dj_pro_workstation_domain_test.dart`: Pruebas de `DjStemIsolationEntity`, `DjHarmonicCamelotEngine`, `DjLoopAndSlipEngine`, `DjSmartAutomixEngine`, `DjSamplerBankEntity` y `DjCueMonitorEntity`.
  - `test/features/dj_console/data/dj_pro_workstation_dsp_test.dart`: Pruebas de aislamiento de Stems en `DjAudioProcessor`, matriz `Split-Cue` y síntesis de los 8 efectos en `DjTransitionSfxSynthesizer`.
- [ ] **4.2 Pruebas de Widgets e Integración UI:**
  - `test/features/dj_console/presentation/dj_pro_workstation_ui_test.dart`: Verificación del renderizado de ondas paralelas RGB, botones de 4-Stems, `Key-Sync`, `Auto-Loops`, `Slip Mode`, disparo de pads del Sampler, `Automix` y `Split-Cue`.
- [ ] **4.3 Verificación de Calidad (Quality Gate):**
  - Ejecutar `flutter analyze` (0 advertencias, 0 errores).
  - Ejecutar `flutter test` verificando que el 100% de la suite (más de 660 pruebas) pase en verde.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit `73a2f1e` en la rama `main` (posterior al merge del PR #27).
- **Mitigación Inmediata:** Todos los nuevos subsistemas están encapsulados en entidades inmutables dentro de `lib/features/dj_console/`; si algún efecto o vista requiere ajuste, puede conmutarse sin afectar los reproductores base ni el resto de la plataforma **Tunner**.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Cumplimiento estricto de las directrices de [AGENTS.md](../../AGENTS.md) (100% Offline-First, Clean Architecture atomizada, cero *busy-waiting*, cero emojis).
- [ ] Latencia de procesamiento de bloque de audio $\le 4\text{ ms}$.
- [ ] Cobertura de pruebas unitarias y de widgets al $100\%$ en los nuevos módulos.
- [ ] Documentación canónica completa (`DOC-DJ-2026-069`, `UC-69`, `ADR-0063`, `PLAN-67`).
- [ ] Pull Request creado, verificado por CI y SonarCloud en verde.
