# ADR 0032: Motor de Exportación de Stems de Audio Multicanal y Síntesis MIDI

## Estado
Aprobado

## Contexto
En el espacio de trabajo de **Componer** de **Tunner**, los usuarios visualizan partituras, transcriben audio melódico, ajustan volúmenes en el mezclador multicanal y graban tomas vocales o instrumentales. Sin embargo, no existía un mecanismo para materializar estas composiciones y mezclas en archivos de audio reproducibles fuera de la aplicación (DAWs, reproductores de audio, secuenciadores de hardware) ni para exportar stems de audio separados con los parámetros de mezcla aplicados.
Asimismo, la generación de archivos Standard MIDI File (SMF) requería integración formal en el flujo de composición para permitir exportación simultánea tanto de la partitura en MIDI como de las señales de audio en formato WAV PCM.

## Decisión
1. **Modelado en Capa de Dominio Puro (`lib/features/audio_synthesizer/domain/`):**
   - Crear entidades inmutables `StemExportConfig`, `ExportedStemFile` y `ExportBundleResult` sin dependencias de Flutter ni plugins de plataforma.
   - Implementar `StemAudioSynthesizer` en Pure Dart:
     - Síntesis de notas melódicas a PCM 16-bit 44.1 kHz con envolventes anti-pop y armónicos aditivos.
     - Síntesis de clic percusivo de metrónomo sincronizado por pulsos métricos.
     - Mezcla de canales (master mixdown) mediante acumuladores de punto flotante de 64 bits (`Float64List`), ganancia ponderada según el estado del mezclador (`MixerConsoleEntity`) y limitador suave analógico anti-clipping con tangente hiperbólica (`tanh`).
     - Generación de cabecera canónica RIFF/WAVE de 44 bytes para cada stem y para el máster.
2. **Exportación Estándar MIDI Multitrack:**
   - Integrar `CanonicalMidiExporter` para generar archivos Standard MIDI File (SMF Format 0 / Format 1) que preserven tempo (BPM), firmas métricas y secuencias de eventos NoteOn/NoteOff con resolución de 480 PPQN.
3. **Capa de Infraestructura / Persistencia (`lib/features/audio_synthesizer/data/`):**
   - Implementar `StemExportPersistenceService` con soporte para inyección de dependencias de rutas de almacenamiento local, permitiendo escribir los archivos binarios directamente a disco en una carpeta `exports/` local y offline.
4. **Capa de Presentación (`lib/features/audio_synthesizer/presentation/`):**
   - Crear `AudioMidiExportModal` accesible directamente desde la barra de herramientas de `CompositionNotationWorkspaceView`.
   - Permitir al usuario seleccionar pistas individuales (Master, Melodía, Acompañamiento, Metrónomo, Toma Micrófono) y formatos de salida (WAV PCM, MIDI).
   - Mostrar resumen en tiempo real de tamaño en KB/MB y botón de guardado y descarga local.

## Consecuencias
- **Positivas:**
  - Capacidad completa de exportación profesional sin requerir dependencias de red, servidores en la nube ni librerías pesadas nativas.
  - Fidelidad acústica y matemática determinista (16-bit 44.1 kHz PCM).
  - Cumplimiento estricto de Clean Architecture con 100% de aislamiento en la capa de dominio.
- **Negativas / Mitigaciones:**
  - La síntesis matemática en Dart de piezas extensas puede requerir cómputo intensivo; se estructura de manera vectorial y puede transferirse a un Isolate en segundo plano si la duración supera los 5 minutos.
