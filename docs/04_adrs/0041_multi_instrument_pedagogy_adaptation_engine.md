# ADR 0041: Motor de Adaptación Pedagógica Multi-Instrumento en Dominio Puro

## Estado
Aceptado

## Contexto
Originalmente, el sistema de lecciones guiadas de **Tunner** (`curated_guided_lessons.dart`) y las piezas de muestra del descompositor de canciones (`SongDecomposerService`) fueron diseñados con parámetros predeterminados centrados en instrumentos agudos de viento (especialmente Flauta Traversa en octavas 4 y 5, y consejos orientados a boquilla y columna de aire).

Al expandir el afinador a guitarras acústicas y eléctricas, bajos, instrumentos de cuerda frotada (violín, violonchelo, contrabajo), metales (trompeta en Si♭, corno en Fa, trombón, tuba) y voces, se evidenció que los estudiantes de otros instrumentos experimentaban:
1. **Frecuencias Meta Inalcanzables:** Notas en octavas 4 y 5 incompatibles con el registro grave de un bajo eléctrico, contrabajo o cello.
2. **Confusión en Instrumentos Transpositores:** Un trompetista en Si♭ o saxofonista en Mi♭ lee partituras en un tono diferente al de concierto, provocando discrepancias visuales-auditivas.
3. **Instrucciones Biomecánicas Inadecuadas:** Consejos de "embocadura de boquilla" o "columna de aire" presentados a un guitarrista o chelista.

## Decisión
Se decide implementar un motor pedagógico en la capa de dominio puro (`lib/features/guided_lessons/domain/instrument_pedagogy_adapter_engine.dart`), sin dependencias de plugins ni de Flutter UI:
1. **Octave-Shifting Adaptativo:** Algoritmo que transpone las notas en saltos de octava ($\pm 12$ semitonos) hasta ubicarlas en la zona central ergonómica de la tesitura del instrumento (`[minFrequencyHz, maxFrequencyHz]`), preservando las relaciones interválicas.
2. **Cálculo de Notación Escrita vs Concierto:** Para instrumentos transpositores, calcula automáticamente la nota escrita que el músico debe leer en su instrumento (`writtenNoteName`) basándose en `InstrumentProfileEntity.transpositionSemitones`, mientras mantiene la frecuencia de detección acústica en el tono de concierto correspondiente.
3. **Inyección de Consejos Biomecánicos por Familia:** Mapeo de feedback pedagógico adaptativo según `InstrumentFamily`:
   - `strings` (Guitarras/Bajos): Consejos sobre digitación en trastes, ángulo de pulsación, postura de la mano izquierda y evitar micro-bendings involuntarios.
   - `strings` (Cuerdas Frotadas): Peso del arco, velocidad de cerdas, punto de contacto y afinación sin trastes.
   - `brass`: Vibración labial (*buzzing*), soporte abdominal y relajación muscular.
   - `woodwinds`: Presión sobre boquilla/caña, soporte diafragmático y velocidad del aire.
   - `vocals`: Relajación laringea, apoyo costodiafragmático y resonancia en la máscara facial.

## Consecuencias

### Positivas
- Democratización total del aprendizaje musical: cualquier estudiante puede aprender y realizar rutinas de afinación con su instrumento predilecto.
- Coherencia visual y pedagógica para instrumentos transpositores.
- Cero impacto en rendimiento (cálculos en $O(1)$ ejecutados en el dominio antes del inicio de la lección).

### Negativas / Mitigaciones
- Mayor variedad de notas meta evaluadas simultáneamente en el evaluador. Se mitiga mediante pruebas unitarias exhaustivas con toda la biblioteca de 21 instrumentos estándar.
