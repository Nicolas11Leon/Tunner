# Tunner Suite 1.0 (Conservatory & Studio Release Notes)

**Fecha de Lanzamiento:** 2026-11-09  
**Versión:** 1.0.0  
**Licencia:** GNU AGPLv3  
**Cobertura Arquitectónica:** 55 Casos de Uso | 49 ADRs | 0 Errores de Linter | 480+ Pruebas Automatizadas (100% Passing)

---

## 1. Resumen Ejecutivo de la Versión 1.0

La versión 1.0.0 de **Tunner** marca la culminación de la fase de desarrollo fundacional, consolidando a la plataforma como la primera suite de código abierto y grado conservatorio capaz de competir y superar a las alternativas comerciales propietarias (como iStrobosoft, Peterson StroboPlus, EarMaster y MuseScore) en un único ejecutable local 100% Offline-First.

Esta entrega incorpora la **Tríada de Hyper-Sinergia**:
1. **Visualizador Polifónico de Acordes y Armónicos H1 a H8:** Descomposición simultánea de notas con funciones armónicas (tónica, 3ª, 5ª, 7ª, tensiones) y visualización gráfica del espectro armónico continuo.
2. **Entrenador Auditivo a Ciegas (Conservatory Ear Trainer):** Modo de entrenamiento de oído puro ("Blind Mode") con atajos rápidos de selección (`1-4`), repetición (`Espacio`), avance (`Enter`) y evaluación milimétrica de afinación en cents y latencia.
3. **Suite Completa de Documentación 1.0 y Memoria Muscular DAW:** Manual de usuario formal de grado conservatorio, catálogo de atajos universales (Ableton, Logic, Pro Tools y Photoshop) y botones de ayuda contextual `?` en cada herramienta.

---

## 2. Novedades Destacadas en Tunner 1.0

### 2.1 Pilar 1: Visualizador Polifónico Armónico en Tiempo Real
- **Componente:** `PolyphonicLiveVoicingWidget` y `PolyphonicLiveVoicingModal`.
- **Análisis Armónico Multivocal:** Detección de fundamentales concurrentes en piano, guitarra y arreglos vocales mediante análisis cromático (`ChromaVectorCalculator`) y discriminación de armónicos.
- **Serie Armónica Teórica ($H_1 \dots H_8$):** Representación gráfica de los armónicos enteros ($H_n = n \cdot f_0$) comparados contra la energía espectral capturada.
- **Atajo Directo:** `Shift + C` o desde la paleta de comandos Spotlight.

### 2.2 Pilar 2: Entrenador Auditivo a Ciegas (Blind Ear Pitch Trainer)
- **Dominio Puro Dart:** Modelos matemáticos inmutables (`MusicalInterval`, `EarTrainingQuestion`, `BlindEarTrainerEngine`) con ratios de afinación temperada (12-EDO) y afinación justa (Just Intonation).
- **Modo Oído Puro ("Blind Mode"):** El lienzo oculta visualmente el nombre del intervalo para enfocar al 100% la percepción auditiva del estudiante.
- **Atajos Ergonómicos:** Teclas `1`, `2`, `3`, `4` para respuesta inmediata; `Espacio` para re-escucha; `Enter` para siguiente ejercicio.
- **Gamificación y Grado de Conservatorio:** Sistema de puntuación con multiplicador de racha (*streaks*) y calificación S/A/B/C/F.
- **Atajo Directo:** `Shift + E` o mediante Command Palette.

### 2.3 Pilar 3: Control de Transporte Global y Memoria Muscular
- **Convenciones Universales de DAW:**
  - `Espacio`: Play / Stop universal.
  - `Enter / Return`: Rebobinado inmediato al compás 1 (estándar Pro Tools / Logic).
  - `C`: Conmutar modo ciclo / bucle de práctica (estándar Logic / Ableton).
  - `,` y `.`: Nudge de compás (retroceder o avanzar 1 compás/pulso).
  - `R`: Armar / Detener grabación de práctica.
  - `B` / `T`: Tap Tempo interactivo.
  - `]` / `[`: Incremento y decremento fino ($\pm 1$ BPM) y grueso ($\pm 5$ BPM con Shift).
- **Herramientas Directas (Photoshop Single-Key):**
  - `A`: Afinador Estroboscópico.
  - `M`: Metrónomo Determinista en Isolate.
  - `S`: Pentagrama SMuFL y Partituras.
  - `L`: Tutor de Lecciones.
  - `0`: Silencio de Pánico (*Panic Mute*).
  - `Cmd/Ctrl + K` (o `F`): Command Palette Spotlight.
  - `Cmd/Ctrl + I`: Selector Universal de Instrumentos (60+).
  - `?`: Cheat Sheet completo de atajos.

---

## 3. Resumen de la Suite (55 Casos de Uso Implementados)

| Rango de Casos | Categoría Funcional | Tecnologías y Algoritmos |
|---|---|---|
| **UC 01 - 05** | Afinación de Precisión y Reloj | McLeod Pitch Method (MPM/NSDF), Reloj en Isolate, Strobe Tuner $\pm 0.1$ cents, Diapasón A4 |
| **UC 06 - 10** | Notación SMuFL y Descomposición | Motor vectorial SMuFL, Stems mixer, Transposición orquestal, Métricas 4D |
| **UC 11 - 15** | Personalización y Calibración | 8 Paletas estéticas, Grabador loopback, Calibrador 415-466 Hz, Importador MusicXML/MIDI |
| **UC 16 - 20** | Algoritmos DSP y Espectro | McLeod Pitch Method (YIN/MPM), Playback dinámico, Editor Memento, Transcriptor live, FFT H1-H8 |
| **UC 21 - 25** | Generación y Drones | Generador algorítmico, Modo Dual (Essential/Pro), Temperamentos históricos, Dron armónico, Acordes |
| **UC 26 - 30** | Audio Avanzado y OMR | Tap Tempo, Transcripción multiformato, OMR PDF, Supresión de bleed, Exportador canónico PDF |
| **UC 31 - 35** | Taxonomía y Workspaces | Transposición de instrumentos, Comparador espectral, Certificados PDF, Perfiles de aprendizaje, Hub de Workspaces |
| **UC 36 - 40** | Síntesis y SoundFonts | Stems export, Detección multitonos polifónicos, Lecciones guiadas, Autotune vocal, SoundFont SF2 |
| **UC 41 - 45** | Calibración y Aislamiento | Calibración de micrófono, Síntesis de guitarras/bajos, Rechazo de habla y ruidos, Presets acústicos, Adaptación curricular |
| **UC 46 - 50** | Consola y Sinergia de Bus | Dashboard universal, Consola de rack modular, Afinación microtonal, SignalBus atómico, Quick Action Dock |
| **UC 51 - 55** | Memoria Muscular y Release 1.0 | Atajos estilo Photoshop, Atajos universales DAW, Visualizador Polifónico armónico, Entrenador a Ciegas, Suite 1.0 |

---

## 4. Métricas de Calidad de Código y Estabilidad

- **Linter (`flutter analyze`):** 0 errores, 0 advertencias.
- **Suite de Pruebas Automatizadas:** 480 pruebas unitarias y de widgets pasando al 100%.
- **Gestión de Memoria:** Determinista, sin fugas en buffers circulares de audio ni bucles de espera activa.
- **Arquitectura:** Clean Architecture modular y monolítica (cero dependencias de microservicios externos).

---

## 5. Instrucciones de Instalación y Ejecución

```bash
# Clonar repositorio
git clone https://github.com/nicomania11/tunner.git
cd tunner

# Verificar entorno y dependencias
flutter doctor
flutter pub get

# Ejecutar suite de pruebas de regresión
flutter test

# Compilar y ejecutar en modo local (Linux, macOS, Windows, Android, iOS o Web)
flutter run -d linux
```
