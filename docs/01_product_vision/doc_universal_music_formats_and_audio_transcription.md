# Especificación Técnica: Ecosistema Universal de Formatos Musicales & Transcripción de Audio a Partitura

Este documento define la arquitectura integral, especificaciones funcionales y fundamentos algorítmicos para la ingesta, exportación y transcripción bidireccional entre audio digital y partituras en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-FORMATS-TRANSCRIPTION-2026-001`
- **Título Oficial:** Ecosistema Universal de Formatos Musicales, Ingesta Multi-Códec y Transcripción Offline de Audio a Partitura
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-27
- **Fase Asociada:** `Fase 8 (Ecosistema Universal de Formatos & Transcripción)`
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

Tunner evoluciona para convertirse en un centro neurálgico musical integral con capacidad para importar, exportar y transformar música en cualquier dirección:
1. **Lectura y Escritura Universal de Partituras:** Decodificación nativa de Compressed MusicXML (`.mxl`), XML plano (`.musicxml`, `.xml`), MIDI Estándar (`.mid`, `.midi`), y notación compacta ABC (`.abc`), junto con exportadores simétricos a MusicXML, MIDI y ABC.
2. **Transcripción Offline de Audio a Partitura (Audio-to-Score):** Ingesta de archivos de audio digital (WAV, PCM), extracción de muestras temporales, segmentación espectral mediante el McLeod Pitch Method (MPM) con ventana deslizante, y cuantización rítmica determinista para generar partituras vectoriales SMuFL editables y reproducibles.
3. **Centro de Producción de Acompañamiento:** Carga de pistas externas de audio en el mezclador multicanal para sincronización con metrónomo y práctica con stems.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 El Desafío de la Fragmentación de Formatos Musicales
Los músicos y educadores se enfrentan a silos incompatibles:
- Archivos descargados de repositorios como IMSLP suelen estar empaquetados como `.mxl` (contenedores ZIP con compresión Deflate conteniendo el manifiesto `META-INF/container.xml`).
- Repertorios pedagógicos y folclóricos utilizan ampliamente la sintaxis de texto plano ABC Notation (`.abc`).
- Las grabaciones de audio en crudo carecen de representación simbólica, obligando al usuario a realizar transcripciones manuales lentas.

### 2.2 Fundamento Teórico de la Transcripción de Audio a Partitura
La transformación de una señal continua $x[n]$ en una secuencia discreta de eventos de partitura $\mathcal{S} = \{(N_k, \tau_k, d_k)\}$ requiere:
1. **Ventaneo y Análisis Temporal:**
   Se divide la señal en marcos de longitud $W = 2048$ muestras con un salto (*hop size*) $H = 512$ muestras. A $f_s = 44100\text{ Hz}$, cada salto equivale a $\Delta t \approx 11.61\text{ ms}$.
2. **Estimación de Tono Monoaural de Alta Resolución:**
   Para cada marco $m$, se evalúa la función de diferencia cuadrada normalizada (NSDF) del McLeod Pitch Method:
   $$r_t(\tau) = \frac{2 \sum_{j} x_j x_{j+\tau}}{\sum_j x_j^2 + \sum_j x_{j+\tau}^2}$$
   Se extrae la frecuencia fundamental $f_0[m]$ si la claridad $r_t(\tau_{\text{peak}}) \ge 0.65$ y el nivel RMS supera el umbral de ruido.
3. **Segmentación y Continuidad de Notas:**
   Dos marcos contiguos pertenecen a la misma nota si su distancia interválica en cents es menor al umbral de tolerancia:
   $$|\Delta \text{cents}| = \left|1200 \cdot \log_2\left(\frac{f_0[m]}{f_0[m-1]}\right)\right| \le 40\text{ cents}$$
4. **Cuantización Rítmica Determinista:**
   La duración en milisegundos de cada segmento $D_{\text{ms}}$ se proyecta a la figura métrica más cercana (redonda, blanca, negra, corchea, semicorchea o silencios) con base en el BPM base de transcripción.

---

## 3. Especificación Funcional

### 3.1 Módulos Cardinales

1. **`CompressedMusicXmlParser` (`.mxl`):**
   - Descomprime el archivo ZIP en memoria.
   - Parsea `META-INF/container.xml` para ubicar la ruta del archivo `.xml` raíz.
   - Delega el XML extraído al `MusicXmlScoreParser` canónico.
2. **`AbcScoreParser` (`.abc`):**
   - Parsea cabeceras: `X:` (índice), `T:` (título), `M:` (compás), `L:` (longitud de nota por defecto), `Q:` (tempo BPM), `K:` (armadura de clave).
   - Transforma secuencias de notas (`C D E F G A B c d e f g a b`), alteraciones (`^`, `_`, `=`), duraciones numéricas relativas y barras de compás `|` en un `HierarchicalScore`.
3. **`CanonicalAbcExporter`:**
   - Convierte cualquier `HierarchicalScore` a un documento ABC notation formateado.
4. **`AudioToScoreTranscriptionEngine`:**
   - Decodifica archivos WAV/PCM 16-bit estéreo o mono.
   - Ejecuta ventana deslizante con MPM.
   - Segmenta eventos de nota y silencio.
   - Cuantiza métricamente y entrega un `HierarchicalScore`.
5. **`UniversalScoreImporterService` Unificado:**
   - Orquesta la detección y ruteo automático entre MusicXML plano, Compressed MusicXML, MIDI y ABC Notation.

---

## 4. Criterios de Aceptación (Definition of Done)

- 100% de pruebas unitarias y de integración pasando.
- Cero advertencias en `flutter analyze`.
- Cero dependencias externas propietarias o servicios en la nube (100% offline).
- Cero emojis en código fuente, comentarios o commits.
