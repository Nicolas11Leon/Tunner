# Especificación Técnica: Motor de Transposición Tonal, Instrumentos Transpositores y Claves Musicales

Este documento define la arquitectura integral, especificaciones funcionales y fundamentos matemáticos para el soporte de instrumentos transpositores, conmutación dinámica de claves (Clave de Sol y Clave de Fa) y transposición interválica de partituras en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-TRANSPOSITION-2026-001`
- **Título Oficial:** Motor Universal de Transposición Acústica, Instrumentos Transpositores y Claves de Notación
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-28
- **Fase Asociada:** `Fase 11 (Instrumentos Transpositores y Claves)`
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

En la práctica orquestal y de conservatorio, numerosos instrumentos de viento (maderas y metales) no leen en tono de concierto (Concert Pitch en Do), sino que utilizan notación transpuesta: cuando un trompetista o clarinetista lee y toca un Do escrito en su partitura, el sonido acústico emitido físicamente es un Si bemol real. De igual manera, los instrumentos graves (violonchelo, contrabajo, trombón, fagot) leen en Clave de Fa en 4ta línea.

Este módulo formaliza el **Motor de Transposición e Instrumentos Transpositores** de Tunner. Permite:
1. **Doble Lectura en el Afinador:** Visualización simultánea de la nota escrita (*Written Note*) y la nota acústica sonando (*Sounding / Concert Note*), eliminando la carga cognitiva de transposición mental para instrumentistas de viento.
2. **Soporte de Claves Musicales:** Conmutación automática o manual entre Clave de Sol (Treble Clef) y Clave de Fa (Bass Clef) en el renderizador vectorial `RealSheetMusicPainter` y en el exportador PDF.
3. **Catálogo Orquestal Extendido:** Perfiles acústicos con rangos en Hz, claves de afinación ($B\flat, E\flat, F, G, A$, octavas graves/agudas) y claves de lectura.
4. **Transposición Atómica de Partituras:** Utilidad para transponer obras completas por semitonos o adaptar partituras de concierto a la tonalidad escrita de cualquier instrumento en 1 toque.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 La Realidad Acústica de los Instrumentos Transpositores
Históricamente, los instrumentos de viento adoptaron longitudes físicas de tubo que facilitaban ciertas series armónicas naturales. Para permitir a un intérprete alternar entre instrumentos de la misma familia (e.g. saxofón alto en Mi♭ y saxofón tenor en Si♭) con idéntica digitación, las partituras se escriben transpuestas:
- **Instrumentos en Si♭ ($B\flat$, transposición $-2$ semitonos sonando / $+2$ semitonos escritos):**
  - Al leer un Do4 escrito ($261.63\text{ Hz}$), emiten físicamente un Si♭3 ($233.08\text{ Hz}$).
  - Al leer notas escritas $N_{\text{escrita}}$, el sonido emitido es:
    $$f_{\text{sonido}} = f(N_{\text{escrita}}) \cdot 2^{-2/12}$$
  - Si el micrófono capta una nota afinada $N_{\text{sonando}}$, la nota que el músico está leyendo en sus dedos es:
    $$N_{\text{escrita}} = N_{\text{sonando}} + 2\text{ semitonos}$$
- **Instrumentos en Mi♭ ($E\flat$, transposición $-9$ semitonos / $+9$ semitonos escritos):**
  - Saxofón Alto, Clarinete Alto. Al leer Do4 escrito, suena Mi♭3.
- **Instrumentos en Fa ($F$, transposición $-7$ semitonos / $+7$ semitonos escritos):**
  - Corno Francés, Corno Inglés. Al leer Do4 escrito, suena Fa3.
- **Instrumentos en La ($A$, transposición $-3$ semitonos / $+3$ semitonos escritos):**
  - Clarinete en La de orquesta.
- **Instrumentos en Sol ($G$, transposición $-5$ semitonos / $+5$ semitonos escritos):**
  - Flauta Alto en Sol.

### 2.2 Notación en Clave de Fa (Bass Clef)
La Clave de Fa fija el Fa3 en la cuarta línea del pentagrama:
- Línea 1 (inferior): Sol2 ($G_2$).
- Línea 2: Si2 ($B_2$).
- Línea 3: Re3 ($D_3$).
- Línea 4: Fa3 ($F_3$) (línea guía de los dos puntos de la clave).
- Línea 5 (superior): La3 ($A_3$).
- Do central (Do4): Primera línea adicional superior.

---

## 3. Especificación Funcional

### 3.1 Requerimientos del Sistema
- **REQ-TRANS-01:** El afinador principal debe mostrar la nota escrita del instrumento activo en tipografía heroica destacada, y un indicador secundario de la nota de concierto sonando (e.g. `Escrita: Do4` | `Sonando: Si♭3`).
- **REQ-TRANS-02:** Si el instrumento seleccionado es de concierto ($C$, transposición 0), se muestra la nota unificada con la indicación de concierto.
- **REQ-TRANS-03:** `RealSheetMusicPainter` debe renderizar la Clave de Fa ("𝄢") y calcular las alturas diatónicas relativas a Sol2 cuando el instrumento activo o la partitura especifique Clave de Fa.
- **REQ-TRANS-04:** `InstrumentProfileEntity` debe incluir el campo `InstrumentClef clef` (treble, bass).
- **REQ-TRANS-05:** Ampliar el catálogo canónico de instrumentos a 16 instrumentos principales de conservatorio (incluyendo Piccolo, Clarinete en La, Flauta Alto en Sol, Corno Francés en Fa, Saxofón Soprano, Saxofón Alto, Saxofón Tenor, Saxofón Barítono, Fagot, Trombón, Tuba, Violonchelo, Contrabajo).
- **REQ-TRANS-06:** Proveer en `TunerViewModel` el método `transposeScoreForInstrument(InstrumentProfileEntity targetInstrument)` y transposición interválica rápida.

---

## 4. Diseño Técnico y Arquitectura

### 4.1 Capa de Dominio (`lib/features/instrument/domain/`)
- `InstrumentClef`: Enum `{ treble, bass }`.
- `InstrumentKey`: Añadir `aKey(-3)`, `gKey(-5)`, `highOctaveC(+12)`.
- `InstrumentProfileEntity`: Incorporar `clef` y nuevos perfiles canónicos.
- `InstrumentTranspositionService`: Funciones puras de mapeo bidireccional armónico entre notas sonando y escritas con preservación estricta de nombres con enarmonía musical.

### 4.2 Capa de Presentación
- `RealSheetMusicPainter`: Soporte de dibujo de Clave de Fa y proyección vertical $y$ según clave activa.
- `TunerScreen`: Indicador heroico dual de afinación con insignia de instrumento transponedor.
- `InstrumentSelectorModal`: Modal rediseñado con filtros por familia y selector de clave.

---

## 5. Criterios de Aceptación (Definition of Done)

- 100% de pruebas unitarias y de widgets pasando.
- Cobertura matemática de todos los intervalos de transposición (Si♭, Mi♭, Fa, La, Sol, octavas).
- Renderizado visual sin jank (60/120 FPS).
- Cero emojis en código, comentarios y commits.
