# Plan de Implementación: Suite de Notación Musical Vectorial SMuFL y Síntesis Polifónica Interactiva

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-SMUFL-NOTATION-POLY-SYNTH-2026-0094`
- **Título de la Implementación:** Suite de Notación Musical Vectorial SMuFL, Motor de Síntesis Polifónica Multi-Voz con Envolvente ADSR y Coordinador de Reproducción Sincronizada
- **Fase del Proyecto:** Fase 5 (Consolidación de Workstation Pro)
- **Estado:** Implementado
- **ADR Relacionado:** [ADR 0094](../04_adrs/0094_interactive_smufl_notation_and_polyphonic_synth_suite.md)
- **Documento Funcional Base:** [Caso de Uso 105](../02_use_cases/105_uc_interactive_smufl_notation_and_polyphonic_synth_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Integrar armónicamente lo mejor de la dimensión visual (Notación SMuFL) y la dimensión acústica (Síntesis Polifónica):
1. **Motor de Notación Tipográfica Vectorial SMuFL:** Sustituir caracteres Unicode ad-hoc por un motor de trazado geométrico en `Path` (`SmuflGlyphPathEngine`) que dibuje claves canónicas (Sol y Fa), cabezas de notas (redondas, blancas, negras), plicas proporcionales, silencios universales y alteraciones vectoriales nítidas en cualquier resolución.
2. **Motor de Síntesis Polifónica Pura (`PolyphonicVoicePool`):** Implementar un sintetizador determinista en Dart puro con 16 voces simultáneas, osciladores multi-forma de onda (seno, sierra, pulso/cuadrada con PWM, triángulo), generadores de envolvente ADSR de grado estudio y robo inteligente de voces (*voice stealing* con crossfade para evitar clicks).
3. **Coordinador de Reproducción y Audición Táctil (`ScorePlaybackCoordinator`):** Permitir la audición inmediata al hacer clic o tocar cualquier nota en el pentagrama (*tap-to-listen*), así como la reproducción orquestada a 60/120 FPS siguiendo el compás del reloj de transporte maestro (`StudioMasterClockService`).
4. **Integración en Consola y Espacio de Trabajo:** Conectar el flujo de audio del sintetizador de partitura a un canal dedicado de la matriz de audio (`score_synth`), permitiendo ecualización, compresión y grabación directa a WAV.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Motor de cálculo y trazado geométrico SMuFL (`SmuflGlyphPathEngine`) en `lib/features/sheet_music/presentation/smufl/`.
  - Integración del motor SMuFL en `RealSheetMusicPainter`.
  - Modelos matemáticos de osciladores, generadores ADSR y pool de 16 voces polifónicas en `lib/features/audio_synthesizer/domain/polyphonic/`.
  - Coordinador de reproducción `ScorePlaybackCoordinator` en `lib/features/sheet_music/domain/`.
  - Controles de parámetros de síntesis (forma de onda, Attack, Decay, Sustain, Release) en el espacio de trabajo de composición (`CompositionNotationWorkspaceView`).
  - Enrutamiento del canal `'score_synth'` hacia `StudioAudioDeviceMatrixService`.
  - Comandos de terminal `/synth waveform <type>`, `/synth adsr <a d s r>`, `/score play|stop` en `TunnerOsKernel`.
  - Pruebas unitarias de síntesis matemática, renderizado vectorial y widget tests interactivos.
- **Excluido (Out-of-Scope):**
  - Carga dinámica de archivos binarios `.sf2` de terceros por red (la síntesis es 100% matemática local y offline de acuerdo con [AGENTS.md](../../AGENTS.md)).
  - Notación de tablatura para instrumentos de cuerda (se mantiene en su módulo independiente).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (Canal estable oficial).
  - Flutter SDK: Canal estable oficial.
  - Cero dependencias externas adicionales: Todo el trazado SMuFL y los osciladores DSP se escriben en Dart puro con primitivas de `dart:math` y `dart:ui`.
- **Riesgo Tecnológico:**
  - Cero loops de espera activa (*zero busy-waiting*).
  - Máxima optimización de memoria: Las rutas `Path` comunes se calculan y escalan proporcionalmente al semiespacio del pentagrama ($sp$).
  - Latencia sub-10ms en respuesta al tacto.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Épica 1: Motor de Síntesis Polifónica Pura y Envolvente ADSR
- [x] Implementar `AdsrEnvelopeGenerator` con etapas de Ataque, Decaimiento, Sostenimiento y Liberación en tiempo lineal.
- [x] Implementar `PolyphonicSynthVoice` con osciladores matemáticos (seno, sierra, pulso con modulación PWM, triángulo).
- [x] Implementar `PolyphonicVoicePool` (16 voces con algoritmo de robo de voz suave).
- [x] Desarrollar suite de pruebas unitarias para verificación matemática y ausencia de saturación digital.

### Épica 2: Motor de Renderizado Vectorial SMuFL
- [x] Diseñar `SmuflGlyphPathEngine` con trazado paramétrico de glifos canónicos:
  - `gClef` (Clave de Sol) y `fClef` (Clave de Fa).
  - `noteheadWhole`, `noteheadHalf`, `noteheadBlack` con rotación estandarizada ($12^\circ$ a $15^\circ$).
  - Silencios vectoriales (redonda, blanca, negra, corchea, semicorchea).
  - Alteraciones vectoriales (sostenido, bemol, becuadro).
- [x] Actualizar `RealSheetMusicPainter` para consumir `SmuflGlyphPathEngine` en lugar de texto Unicode.
- [x] Añadir soporte para líneas adicionales (*ledger lines*) proporcionales.

### Épica 3: Coordinador de Reproducción y Audición Táctil Partitura-Audio
- [x] Implementar `ScorePlaybackCoordinator` para sincronizar `ScoreTree` con `PolyphonicVoicePool` y `StudioMasterClockService`.
- [x] Implementar audición instantánea al tocar o hacer clic sobre una nota en el pentagrama (*tap-to-listen*).
- [x] Añadir despacho de eventos `noteOn` y `noteOff` conforme el playhead avanza a 60/120 FPS.

### Épica 4: Integración en Consola Master, Workspace y Comandos CLI
- [x] Enrutar la salida de `PolyphonicVoicePool` como entrada `'score_synth'` en `StudioAudioDeviceMatrixService`.
- [x] Incorporar panel de control tímbrico y ADSR en `CompositionNotationWorkspaceView`.
- [x] Integrar comandos `/synth` y `/score` en `TunnerOsKernel` con soporte en el prompt bar.

### Épica 5: Verificación Integral, Cobertura de Pruebas y Pipeline CI
- [x] Crear pruebas unitarias para `PolyphonicVoicePool` y `AdsrEnvelopeGenerator`.
- [x] Crear pruebas de rendering y widgets para `RealSheetMusicPainter` con SMuFL.
- [x] Ejecutar análisis estático sin advertencias (`flutter analyze --no-fatal-infos`).
- [x] Ejecutar la suite completa de pruebas unitarias y verificar ejecución en CI.
