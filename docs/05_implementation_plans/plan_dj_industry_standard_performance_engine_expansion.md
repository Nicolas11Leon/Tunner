# Plan de Implementación: Expansión de Consola DJ al Estándar de la Industria

Este documento define la estructura y el cronograma de ejecución para elevar la Consola DJ y la estación de trabajo de audio al estándar de la industria (grado Pioneer Rekordbox, Serato DJ y Traktor Pro) con ejecución acústica real no simulada.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-DJ-EXPANSION-2026-092`
- **Título de la Implementación:** Expansión del Motor de Rendimiento DJ al Estándar de la Industria
- **Fase del Proyecto:** Fase 1 (Sinceramiento y Emisión Acústica Real)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0082: docs/04_adrs/0082_dj_industry_standard_performance_engine_expansion.md](docs/04_adrs/0082_dj_industry_standard_performance_engine_expansion.md)
- **Documento Funcional Base:** [Caso de Uso 92: docs/02_use_cases/92_uc_dj_industry_standard_performance_engine_expansion.md](docs/02_use_cases/92_uc_dj_industry_standard_performance_engine_expansion.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar las funciones interactivas de la Consola DJ de Tunner en un motor acústico real, sincronizado y no simulado:
1. Salto y reproducción acústica inmediata al presionar Hot Cues 1 a 4/8 en Deck A y Deck B.
2. Emisión audible de audio PCM real para el banco de 8 Performance Pads del Sampler (Airhorn, Siren, Kick, Snare, Laser, Drop, Vox, Clap).
3. Modulación de velocidad de reproducción y scrubbing audible proporcional al movimiento angular del Jog Wheel en modo vinilo.
4. Sincronización continua de Auto-Loops (reproducción circular sin saltos de fase) y Beat Jump bidireccional cuantizado en el motor de audio físico.
5. Ingesta y enrutamiento inter-herramientas mediante la Matriz de Canales Universales del Estudio para cargar pistas directas desde el Editor de Partituras o sintetizador hacia los decks.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `DjConsoleViewModel`: Vinculación de `triggerHotCue`, `triggerSamplerPad`, `scratchDeck`, `beatJump`, `halveLoop`, `doubleLoop` con `IDjDeckAudioPlayer` e `IAudioSynthesizerService`.
  - Inyección de `IAudioSynthesizerService` en `DjConsoleViewModel` para reproducir búferes de sampler en tiempo real.
  - Sincronización en el bucle de 30 Hz para bucles automáticos cerrados (`wrapLoopPosition` reflejado en `seekDeck`).
  - Extensión del listener de canales en `DjStudioWorkstationView` para recibir buffers de audio y archivos locales reales desde el Patchbay.
  - Pruebas unitarias de integración para cada capacidad del estándar industrial.
- **Excluido (Out-of-Scope):**
  - Protocolos de streaming de red WebRTC / MIDI sobre red (mantiene el principio Offline First y Modular Monolith).
  - Modificación de las estructuras de persistencia de archivos del sistema operativo completadas en Fase 2.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal oficial estable.
  - `audioplayers`: `^6.1.1` (emisión de audio nativa multiplataforma con baja latencia).
- **Riesgo Tecnológico:**
  - Sin dependencias de red o servicios remotos (100% Offline First).
  - La síntesis de sampler de transición se ejecuta en memoria y se transfiere a PCM WAV sin pausas en el hilo de renderizado.
  - Tolerancia para pruebas herméticas mediante `MemoryDjDeckAudioPlayer` y `MemoryAudioSynthesizerService`.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Contratos)
- [x] Verificar contratos de `IDjDeckAudioPlayer` e `IAudioSynthesizerService`.
- [x] Validar fórmulas matemáticas de scratch:
  $$\Delta t_{\text{scrub}} = \Delta \theta \cdot k_{\text{scrub}}$$
  $$\text{rate}_{\text{vinyl}} = 1.0 + \frac{\Delta \theta}{\Delta t \cdot \omega_0}$$
- [x] Validar fórmula de salto de compás cuantizado:
  $$\Delta t_{\text{jump}} = \text{beats} \cdot \left(\frac{60000}{\text{BPM}_{\text{eff}}}\right)$$

### Paso 2: Capa de Infraestructura / Datos
- [x] Asegurar que `DjDeckAudioService` responda a comandos rápidos de `seekDeck` sin bloquear la interfaz.
- [x] Conectar `DjTransitionSfxSynthesizer` y `ProceduralInstrumentSynthesizer` con `IAudioSynthesizerService.playPcmWav`.

### Paso 3: Capa de Presentación (ViewModels y Workstation)
- [x] Conectar `triggerHotCue` en `DjConsoleViewModel` para buscar la posición en milisegundos y reproducir audio real si el deck está activo o en modo audición CDJ.
- [x] Conectar `triggerSamplerPad` para sintetizar el float buffer y despachar `playPcmWav` audible.
- [x] Conectar `scratchDeck` para modular el playback rate durante la rotación física del plato y restituir el pitch original al soltarlo.
- [x] Conectar `beatJump` y auto-loops en el `_playbackTicker` para realizar `seekDeck` al inicio del bucle cuando la posición alcance o supere `loopEndMs`.
- [x] Conectar la Matriz de Canales en `DjStudioWorkstationView` para recibir streams PCM/WAV reales.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Desarrollar suite de pruebas exhaustivas en `test/features/dj_console/dj_industry_standard_performance_engine_test.dart`.
- [x] Ejecutar `flutter analyze` verificando cero advertencias.
- [x] Ejecutar `flutter test` asegurando 100% de éxito.
- [x] Compilar binario nativo Linux: `flutter build linux`.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Estado limpio verificado en branch `feature/multimedia-vault-timeline-universal-io`.
- **Mitigación Inmediata:** Los servicios continúan desacoplados mediante interfaces `IDjDeckAudioPlayer` e `IAudioSynthesizerService`; si algún controlador de audio falla, el fallback a `MemoryDjDeckAudioPlayer` asegura estabilidad sin degradación del sistema.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Cero emojis en código, comentarios y documentación.
- [x] Hot cues buscan y emiten audio físico en milisegundos exactos.
- [x] Los 8 sampler pads emiten sonido audible inmediato.
- [x] El jog wheel modula velocidad acústica durante el giro en modo vinilo.
- [x] Los bucles automáticos y beat jumps mantienen sincronía perfecta de audio.
- [x] Cero regresiones en la suite general de pruebas (775 pruebas pasando).
