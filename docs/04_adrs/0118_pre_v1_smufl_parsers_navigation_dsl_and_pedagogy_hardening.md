# ADR 0118: Endurecimiento de Notación SMuFL, Parsers/Exporters, Navegación de Estudio, Terminal DSL y Pedagogía

## Estado
Aceptado

## Contexto
El subsistema de partituras e importación/exportación universal de Tunner procesa archivos de múltiples formatos (PDF vectorial, MusicXML, MIDI SMF Formato 0/1 y ABC). Asimismo, el motor de renderizado vectorial SMuFL y el coordinador de reproducción (`ScorePlaybackCoordinator`) deben garantizar una correspondencia exacta entre las notas visuales y la síntesis acústica, evitando desincronizaciones de NoteOff o saltos en notas con bemoles (`Si`/`Sib`). En la capa de presentación, los atajos de teclado globales no deben secuestrar las teclas de espacio o letras cuando el foco de entrada se encuentra en un campo de texto editable. Finalmente, el intérprete DSL y el motor de andamiaje pedagógico deben ser completamente deterministas.

## Decisión
1. **Parsers y Exporters Universales:**
   - En `PdfScoreVectorRenderer`: Renderizar correctamente cabezas de notas huecas para blancas y redondas, así como accidentales de bemol y sostenido en nomenclatura internacional y solfeo (`Sib`, `Eb`).
   - En `CompressedMusicXmlParser` y `MusicXmlParser`: Garantizar el orden correcto de compases y sistemas, soportando archivos comprimidos `.mxl` sin desbordamiento de memoria.
   - En `MidiFileParser` y `AbcScoreParser`: Incluir guardas matemáticas contra división por cero en tempos extremos y bucles no terminados.
2. **Coordinación de Reproducción y SMuFL:**
   - En `ScorePlaybackCoordinator`: Procesar correctamente todos los nombres de notas en español e inglés (`Si`, `Sib`, `Mib`) mapeándolos a números MIDI canónicos y emitiendo los correspondientes `noteOff` sincronizados.
   - En `SmuflGlyphPathEngine`: Ajustar los contornos vectoriales para cabezas de notas negras, blancas y redondas bajo la especificación estándar SMuFL.
3. **Atajos de Teclado y Foco:**
   - Incorporar verificación de foco activo en los listeners de teclado (`FocusManager.instance.primaryFocus`) para evitar que atajos globales como espacio (Play/Pause) o letras interfieran con la escritura del usuario.
4. **Intérprete DSL y Suite Pedagógica:**
   - Sincronizar la cola de comandos temporales en el intérprete DSL y blindar el cálculo de tolerancia de andamiaje en `AdaptiveScaffoldingEngine`.

## Consecuencias
- Cero interrupciones de foco durante la edición de texto o búsqueda de módulos.
- Notación y audición musical precisa y sin saltos de afinación en todas las tonalidades.
- Robustez ante partituras importadas de terceros con formatos anómalos o incompletos.
