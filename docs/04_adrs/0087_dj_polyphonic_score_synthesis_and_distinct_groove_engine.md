# ADR 0087: Síntesis Acústica Real de Partituras Curadas y Motor de Grooves Diferenciados en Consola DJ

## Estado
Aprobado

## Contexto
En versiones previas de la Consola DJ Pro Studio de Tunner, la carga de canciones del repertorio canónico (como "Para Elisa", "Canon en Re Mayor", "Himno a la Alegría") o de presets de club ejecutaba internamente una función de prueba monofónica invariable (`generateDemoGroove` a 55 Hz). Esto causaba que cualquier selección de canción reprodujera exactamente el mismo audio de demostración plano, impidiendo que el usuario escuchara las obras musicales reales ni practicara la mezcla armónica con temas reconocibles.

## Decisión
1. **Síntesis Polifónica de Partituras en `DjAudioProcessor`:**
   Implementar en `DjAudioProcessor` la capacidad de sintetizar dinámicamente cualquier `SongPackage` o `HierarchicalScore`. El algoritmo recorre los compases y notas de la partitura, convierte los nombres de nota a frecuencias fundamentales exactas ($A_4 = 440\text{ Hz}$), aplica síntesis aditiva y envolventes de piano/cuerda, y añade una base rítmica de club sincronizada con el BPM de la obra para permitir el beatmatching y el filtrado por 4-stems.
2. **Presets de Club Acústicamente Diferenciados:**
   Implementar motores de síntesis especializados para cada preset electrónico:
   - *Midnight Cyber Synthwave* (128 BPM, arpegios en Fa menor y bombo analógico 80s).
   - *Deep Techno Underground* (132 BPM, sub-bajo continuo en Re menor y percusión industrial).
   - *Liquid Drum & Bass* (174 BPM, síncopas rápidas y acordes Rhodes).
   - *Vocal House Anthem* (124 BPM, acordes de piano house en Do mayor y bombo 909).
   - *Afro House Sunset* (122 BPM, polirritmia con marimba en Sol menor).
3. **Despacho Transparente en UI e Infraestructura:**
   Actualizar `DjTrackLoaderModal`, `DjStudioWorkstationView` y `DjDeckAudioService` para inyectar estas muestras en `loadTrackWithBeatTracking`, garantizando que tanto el motor de audio como las formas de onda visuales RGB reflejen fielmente el contenido musical seleccionado.

## Consecuencias
- **Positivas:**
  - El usuario escucha de inmediato las notas icónicas de "Para Elisa" o "Canon en Re Mayor" al reproducir el deck.
  - El aislamiento por stems (mudos de Bajo, Batería, Voz/Solista y Melodía) funciona acústicamente como una remezcla en vivo de la obra clásica.
  - Cada preset de club posee una firma sónica inconfundible y apropiada para su género.
  - Cero dependencias externas y cero latencia de red (100% Offline-First en Pure Dart).
- **Negativas / Mitigaciones:**
  - Ligero cómputo al cargar la pista (menos de 15 ms para generar 15-20 segundos de audio PCM en RAM), completamente imperceptible en la experiencia de usuario.
