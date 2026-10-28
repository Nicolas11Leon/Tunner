# Plan de Implementación: Fase 7.4 - Reconocimiento Polifónico de Acordes (Pitch Class Profile & Chroma Vectors)

Este plan formaliza la descomposición técnica y pasos de ejecución para construir el motor de reconocimiento polifónico de acordes en tiempo real en **Tunner**.

---

## 1. Objetivos

1. Implementar en el dominio puro (`lib/features/chord_analyzer/domain/`) el cálculo del vector de cromagrama (Chroma Vector de 12 clases de tono / Pitch Class Profile) a partir de muestras de audio PCM o espectro armónico.
2. Construir plantillas armónicas formales para 9 tipos de acordes canónicos (Mayor, Menor, Disminuido, Aumentado, Séptima de Dominante, Séptima Mayor, Séptima Menor, Suspendido 4, Suspendido 2) y sus 12 transposiciones cromáticas (108 combinaciones).
3. Desarrollar el clasificador de máxima verosimilitud por similitud de coseno con umbral adaptativo y filtro de histéresis temporal para evitar parpadeos visuales.
4. Integrar el motor en `TunerViewModel`, procesando los búferes de audio del micrófono y actualizando el acorde reconocido en tiempo real.
5. Diseñar la interfaz de usuario con visualizador circular de cromagrama (Chroma Radar de 12 clases de tono) y tarjeta de visualización de acorde activo en `TunerScreen`.

---

## 2. Tareas por Capa Arquitectónica

### Capa 1: Dominio Puro (Pure Dart)
- [x] Crear `lib/features/chord_analyzer/domain/chord_entity.dart`:
  - Enum `ChordQuality`: `major`, `minor`, `diminished`, `augmented`, `dominant7`, `major7`, `minor7`, `sus4`, `sus2`.
  - Entidad inmutable `ChordEntity`:
    - `rootMidiNote` (0 a 11, correspondiente a C a B).
    - `quality` (ChordQuality).
    - `confidence` (0.0 a 1.0).
    - `chromaVector` (List<double> de 12 elementos).
    - `chordNotes` (List<String> con los nombres en notación internacional y silábica: Do, Mi, Sol).
    - Propiedades de visualización (`displayName`, `symbol`, `formula`).
    - Objeto estático `ChordEntity.none`.
- [x] Crear `lib/features/chord_analyzer/domain/chroma_vector_calculator.dart`:
  - Transformada discreta de Fourier dirigida / Filter Bank acumulativo en las 12 clases cromáticas ($C \dots B$) a lo largo de las octavas de relevancia musical (65 Hz a 2000 Hz, $C_2$ a $C_6$).
  - Normalización Euclídea $L_2$ del vector de 12 clases cromáticas.
- [x] Crear `lib/features/chord_analyzer/domain/polyphonic_chord_recognizer.dart`:
  - Banco de plantillas de acordes normalizadas unitarias.
  - Cálculo de similitud de coseno entre vector Chroma y plantillas.
  - Clasificación probabilística y selección del acorde con mayor correspondencia.
  - Filtro de rechazo por umbral de ruido / silencio y suavizado de ventana temporal.
- [x] Crear suite de pruebas de dominio: `test/features/chord_analyzer/polyphonic_chord_recognizer_test.dart`:
  - Detección precisa de tríadas y cuatriadas sintéticas generadas matemáticamente.
  - Rechazo de silencio y ruido estocástico blanco.
  - Tolerancia a armónicos y variaciones de octava.

### Capa 2: Infraestructura y Aplicación
- [x] Integrar el analizador en `TunerViewModel`:
  - Mantener instancia de `PolyphonicChordRecognizer`.
  - Propiedades reactivas: `ChordEntity recognizedChord`, `bool isChordRecognitionActive`, `List<double> activeChromaVector`.
  - Métodos `toggleChordRecognition()`, `resetChordRecognition()`.
  - Invocación periódica en el pipeline de análisis de audio de micrófono.

### Capa 3: Presentación (Flutter UI)
- [x] Crear `ChordRadarWidget` en `lib/features/chord_analyzer/presentation/chord_radar_widget.dart`:
  - `CustomPainter` de alta fidelidad que renderiza el círculo cromático de 12 notas con radios proporcionales a la energía de cada semitono y resaltado de las notas pertenecientes al acorde detectado.
- [x] Crear `ChordAnalyzerModal` en `lib/features/chord_analyzer/presentation/chord_analyzer_modal.dart`:
  - Indicador visual monumental del acorde reconocido (ej: Do Mayor / C Maj).
  - Componentes del acorde (fundamental, tercera, quinta, séptima).
  - Barra de confianza / certidumbre del reconocimiento (%).
  - Historial de acordes detectados recientemente.
  - Radar cromático en tiempo real.
- [x] Integrar chip / botón del Reconocedor de Acordes en el AppBar de `TunerScreen` en Modo Conservatorio Pro y Modo Esencial.
- [x] Crear suite de pruebas de interfaz: `test/features/chord_analyzer/chord_analyzer_ui_test.dart`.

---

## 3. Criterios de Aceptación (DoD)
- 100% de pruebas unitarias y de widgets pasando.
- Cero issues en `flutter analyze`.
- Cero emojis en código, comentarios y commits.
