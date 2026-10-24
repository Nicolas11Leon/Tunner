# ADR 0003: Arquitectura Híbrida de Ingesta Musical: Biblioteca Pre-descompuesta y Parser Universal MIDI / MusicXML

---

- **Estado:** `Approved`
- **Fecha:** `2026-10-24`
- **Autores:** `Tunner Engineering & Nicolas Leon`
- **Decisores:** `Nicolas Leon (Creador), Antigravity AI`
- **Fase del Proyecto:** `Fase 4` (Preparación e Infraestructura de Dominio)

---

## 1. Contexto

La visión de **Tunner** exige que cualquier usuario o estudiante pueda disponer de canciones con acompañamiento instrumental descompuesto por capas (Voz, Piano, Bajo, Metrónomo, etc.) para silenciar su propio instrumento (*minus-one*) y practicar con retroalimentación visual en tiempo real.

Existen dos caminos técnicos habituales en la industria:
1. **Separación espectral de audio puro (MP3/WAV) vía redes neuronales (Demucs / Spleeter):** Requiere modelos de IA de cientos de megabytes, alto consumo de GPU/NPU, y genera pistas de audio en onda con artefactos de fase (*bleeding*), pero **no** extrae las notas musicales exactas para pintar el pentagrama ni para evaluar la afinación del usuario.
2. **Archivos de Notación Simbólica y Multi-Pista (MIDI y MusicXML):** Son estándares universales de la industria (exportables desde MuseScore, Sibelius, Finale, Guitar Pro y repositorios abiertos). Contienen de forma nativa e instantánea:
   - Las notas musicales exactas por pista/instrumento (pitch, compás, armadura, duración).
   - Canales y pistas independientes (*tracks*) ya separados de forma 100% matemática y limpia sin artefactos.
   - Ocupan menos de $50\text{ KB}$ por canción y se procesan en milisegundos en Dart puro sin dependencias externas ni consumo de red.

---

## 2. Decisión Arquitectónica

Adoptamos una **Estrategia Híbrida basada en Notación Simbólica Multi-Pista y Biblioteca Curada**:

1. **Biblioteca Canónica Precargada (Offline First):** Una suite de canciones y estudios pedagógicos curados incorporados en la aplicación, clasificados por género, dificultad e instrumentos, con pistas de acompañamiento separadas listas para tocar de inmediato.
2. **Lector / Parser Universal Local (MIDI / MusicXML):** Un motor de decodificación en memoria en Dart puro capaz de:
   - Leer cualquier archivo `.mid` o `.musicxml` cargado por el usuario desde su dispositivo.
   - Extraer automáticamente cada pista instrumental como un `AudioTrack` (`stem`) independiente en la consola de mezcla (`MixerConsoleEntity`).
   - Mapear las notas melódicas principales directamente al pentagrama interactivo (`HierarchicalScore` / `MeasureEntity`) para que el usuario pueda practicar y ser evaluado en vivo.

---

## 3. Consecuencias

### Consecuencias Positivas
- **Velocidad y Cero Latencia:** El usuario sube un archivo y en menos de $10\text{ ms}$ la partitura está renderizada en pantalla con todos sus stems separados en el mezclador.
- **100% Offline:** Cumple con la regla cardinal de cero dependencia de servidores o APIs de terceros en la nube.
- **Acceso Infinito a Repertorio:** Existen millones de archivos MIDI y MusicXML gratuitos en la web de cualquier género musical (clásica, jazz, pop, rock).
- **Consumo de Memoria Mínimo:** Cero sobrecarga de GPU/batería en comparación con modelos neuronales pesados.

### Consecuencias Negativas / Mitigaciones
- No separa directamente un archivo MP3 grabado en un solo archivo de audio estéreo: los usuarios que deseen importar su repertorio deben utilizar archivos MIDI o MusicXML, o bien canciones de la biblioteca curada de Tunner. Para archivos de audio crudo, se planificará una extensión FFI en una fase futura.
