# ADR 0073: Consola DJ Profesional con Mezclador de Grado Club y Carga Universal de Audio

- **Estado:** Aceptado
- **Fecha:** 2026-11-16
- **Contexto:**
  La implementación previa de la consola DJ presentaba controles genéricos horizontales tipo slider de baja fidelidad ("parece hecho de palitos") que distorsionaban la ergonomía de una mezcladora de DJ real y causaban problemas de maquetación en pantallas estándar. Asimismo, los botones de carga de pistas generaban tonos sintetizados de prueba en lugar de permitir cargar archivos de audio reales o pistas maestras de estudio, y la consola no contaba con una vista de pantalla completa nativa en el sistema de pestañas de espacio de trabajo.

- **Decisión:**
  1. Diseñar componentes atómicos y moleculares profesionales:
     - `StudioRotaryKnob`: Dial rotatorio vectorial de precisión para ecualización (-26dB a +6dB) y filtros, con arrastre vertical interactivo y muesca central de 0 dB.
     - `StudioStereoVuMeter`: Medidor de nivel estéreo por canal (verde, ámbar, rojo) con retención de picos de señal.
     - `DjVerticalChannelStrip`: Tira de canal vertical de estándar industrial con Trim, High/Mid/Low EQ, switches Kill con LEDs retroiluminados, y Faders de volumen de carrera suave.
  2. Implementar `DjTrackLoaderModal`:
     - Soporte para importar archivos reales del disco (WAV, MP3, FLAC, AIFF).
     - Biblioteca de pistas maestras de estudio con stems pregrabados (Synthwave, House, Funk, Jazz, Afrobeat) con BPM real y clave armónica Camelot.
  3. Crear `DjStudioWorkstationView` e integrarla como espacio de trabajo de primer nivel en `MainAppShell` (`F4`), permitiendo alternar entre el afinador, el rack modular, la notación musical y la consola DJ a pantalla completa sin necesidad de modales flotantes apretados.

- **Consecuencias:**
  - **Positivas:** Ergonomía 100% auténtica de estación DJ de club; erradicación total de controles rústicos y mocks de prueba; experiencia inmersiva fluida en pantalla completa; análisis acústico y de beat-tracking real.
  - **Negativas:** Mayor número de componentes gráficos CustomPainter en la capa de presentación (mitigado mediante caché y repintado condicional).
