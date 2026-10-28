# ADR 0027: Motor de Transposición Tonal, Instrumentos Transpositores y Claves Musicales

---

## Estado
Aprobado

## Contexto
En la educación musical y en la interpretación instrumental profesional, la notación transpuesta y la diversidad de claves son estándares universales:
- Los instrumentistas de viento en Si♭ (Trompeta, Clarinete, Saxofón Tenor) leen una nota escrita que difiere en 2 o 14 semitonos de la nota real emitida.
- Los instrumentistas de Mi♭ (Saxofón Alto, Barítono) difieren en 9 o 21 semitonos.
- Los instrumentistas en Fa (Corno Francés, Corno Inglés) difieren en 7 semitonos.
- Los instrumentistas graves (Violonchelo, Fagot, Trombón, Tuba) leen en Clave de Fa (Bass Clef) en lugar de Clave de Sol (Treble Clef).

Previamente en Tunner:
- `InstrumentTranspositionService` solo se utilizaba de forma secundaria en la evaluación pedagógica.
- La pantalla del afinador mostraba exclusivamente la nota sonora de concierto, obligando al músico a realizar cálculo mental inverso.
- El pentagrama visual (`RealSheetMusicPainter`) solo admitía Clave de Sol.

## Decisión
Se decide implementar una arquitectura integral de transposición y claves en el dominio puro:
1. **Atributo `InstrumentClef` en `InstrumentProfileEntity`:**
   - Define explícitamente si el instrumento lee en `treble` (Sol) o `bass` (Fa).
2. **Ampliación del Catálogo de Instrumentos a 16 Perfiles Canónicos:**
   - Inclusión de Flautín/Piccolo, Flauta Alto en Sol, Clarinete en La, Corno Inglés, Trombón, Fagot, Tuba, Saxofón Soprano y Saxofón Barítono.
3. **Afinación Dual Reactiva en ViewModel y Pantallas:**
   - Exponer `writtenNoteName` en `TunerViewModel`.
   - Mostrar la nota escrita destacada con insignia de transposición cuando el offset sea distinto de cero.
4. **Soporte de Clave de Fa en `RealSheetMusicPainter`:**
   - Renderizado del glifo de Clave de Fa ("𝄢") y cálculo de coordenadas verticales diatónicas relativas a Sol2 (línea 1 del pentagrama de Fa).
5. **Transposición Atómica de Partituras por Instrumento:**
   - Método `transposeScoreForInstrument` en `TunerViewModel` para adaptar cualquier partitura en Do a la tonalidad del instrumento activo.

## Consecuencias
- **Positivas:**
  - Experiencia de usuario natural y profesional para cualquier músico de conservatorio o banda sin fricción mental.
  - Soporte completo para repertorio grave en Clave de Fa.
  - Arquitectura limpia en Pure Dart sin dependencias externas.
- **Negativas / Mitigaciones:**
  - El dibujo de líneas adicionales para notas en clave de Fa requiere calibración de signo inverso respecto a clave de Sol, lo cual queda cubierto mediante pruebas unitarias de proyección diatónica.
