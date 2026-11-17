# ADR 0086: DJ Complete Hardware Keys Routing & Universal Track Loading Architecture

- **Estado:** Aprobado
- **Fecha:** 2026-11-16
- **Contexto:** En la Consola DJ Pro Workstation, los atajos de teclado globales definidos en `MainAppShell` para el metrónomo, afinador y navegación capturaban teclas vitales de DJ (`W`, `A`, `S`, `C`, `B`, `M`, `1..5`, `Space`, etc.), impidiendo la interacción física con la consola. Asimismo, el reproductor `DjDeckAudioService` descartaba los buffers WAV cargados con `loadDeckTrack` al carecer de un puntero a `_loadedWavBytes` y sobrescribirlos con bucles de demo predeterminados. Además, el selector de pistas carecía de conexión directa con el repertorio curado de conservatorio (`SongPackage`) y las tomas de audio del proyecto local.
- **Decisión:**
  1. Condicionar los atajos en `MainAppShell`: cuando `_currentIndex == 5` (pestaña DJ activa), la jerarquía de atajos globales desactiva los disparadores de transporte y navegación de pantalla completa, cediendo todos los eventos de teclado al árbol de widgets de `DjStudioWorkstationView` y `DjConsoleViewModel`.
  2. Implementar resolución normalizada de teclas en `DjControllerProfileEntity.findAction`: permitir coincidencia estricta y difusa (`'w'`, `'W'`, `'Key W'`, `'Digit 1'`, etc.).
  3. Almacenar y reproducir `_loadedWavBytesA` y `_loadedWavBytesB` en `DjDeckAudioService` para que cualquier pista inyectada en memoria sea reproducida fielmente por el motor de audio en lugar de caer en el fallback por defecto.
  4. Rediseñar `DjTrackLoaderModal` para admitir cuatro fuentes canónicas de audio: Obras Curadas con Stems, Tomas WAV del Proyecto, Estilos Club Sintéticos e Importación de Archivos Locales.
  5. Añadir chips de carga rápida de un toque en las cabeceras de los Decks A y B en `DjStudioWorkstationView`.
- **Consecuencias:**
  - **Positivas:** Control de teclado instantáneo y predecible en la consola DJ sin fugas a otras pantallas; carga y reproducción audible real de cualquier obra o archivo; experiencia de usuario profesional conforme a los estándares de la industria del software para DJs.
  - **Negativas:** En la pestaña DJ, los atajos de salto directo con un solo dígito (`1..5`) deben ejecutarse con modificador `Alt+1..6` para permitir el uso de Hot Cues con los números `1..4` y `7..0`.
