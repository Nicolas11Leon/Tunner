# Implementation Plan: DJ Hardware Keyboard Routing & Universal Track Loading Suite

Este documento define el plan de implementación formal para solucionar de raíz el conflicto de captura de teclado en la consola DJ y dotarla de un cargador universal de pistas (stems, repertorio curado, tomas WAV del usuario y archivos locales) 100% funcional.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-DJ-KEYS-TRACKLOADER-2026-096`
- **Título de la Implementación:** DJ Hardware Keyboard Routing & Universal Track Loading Suite
- **Fase del Proyecto:** Fase 1 (Consola DJ & Estándar de la Industria)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0086](../04_adrs/0086_dj_complete_hardware_keys_and_universal_track_loader.md)
- **Documento Funcional Base:** [Caso de Uso 96](../02_use_cases/96_uc_dj_complete_hardware_keys_and_universal_track_loader.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
1. Eliminar el secuestro de atajos de teclado provocado por el `Shortcuts` global de `MainAppShell`, permitiendo que al encontrarse en la pestaña de la Consola DJ (`_currentIndex == 5`), todas las teclas del mapa QWERTY / VirtualDJ / Serato / Traktor (`W`, `Q`, `E`, `A`, `S`, `D`, `Z`, `X`, `C`, `I`, `U`, `O`, `J`, `K`, `L`, `M`, `,`, `.`, `1..4`, `7..0`, `Space`, etc.) se enruten sin pérdidas ni interferencias al motor de DJ.
2. Normalizar la resolución de identificadores de teclado (`cleanKeyLabel`, `findAction`) para admitir indistintamente caracteres en minúscula, mayúscula y descriptores de plataforma (`'w'`, `'W'`, `'Key W'`, `'1'`, `'Digit 1'`, `' '`, `'Space'`).
3. Resolver el descarte de audio en `DjDeckAudioService` almacenando y reproduciendo `_loadedWavBytesA` y `_loadedWavBytesB`, eliminando el fallback forzado a bucles por defecto cuando se han inyectado pistas de usuario.
4. Integrar en `DjTrackLoaderModal` y en los Decks A y B acceso directo en un solo clic a:
   - Catálogo Curado Maestro (`Canon de Pachelbel`, `Bach`, `Mozart`, `Beethoven`, `Satie`) con stems reales.
   - Tomas de Audio & WAV del Proyecto (`Toma Acústica 440 Hz`, `Loop Club Groove 124 BPM`).
   - Estilos Club & Performance con síntesis espectral.
   - Importación de archivos locales con respaldo en caso de fallo de diálogo de sistema.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido:**
  - `MainAppShell`: Atajos condicionales que ceden el control al motor de DJ cuando `_currentIndex == 5`.
  - `DjControllerProfileEntity`: Normalización simétrica de tokens de entrada en `findAction`.
  - `DjDeckAudioService`: Persistencia y reproducción real de `wavBytes` cargados en memoria.
  - `DjConsoleViewModel`: No sobreescribir pistas válidas con `null` al llamar sincronizaciones de metadatos.
  - `DjTrackLoaderModal`: Soporte de navegación por pestañas (Curado, Tomas WAV, Club, Archivos).
  - `DjStudioWorkstationView`: Enfoque forzado al hacer clic en cualquier punto del espacio de trabajo y chips de carga rápida en los decks.
- **Excluido:**
  - Microservicios de streaming remoto (mantenimiento estricto de Offline-First).

---

## 2. Análisis de Dependencias y Tecnologías
- **Dart SDK & Flutter:** Flutter Stable en Linux Desktop.
- **HardwareKeyboard & Focus:** API oficial de Flutter sin paquetes externos para el manejo de teclado.
- **Riesgo:** 0 riesgo de regresión en las demás herramientas; los atajos globales de `MainAppShell` se mantienen intactos en las pestañas 0, 1, 2, 3 y 4.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Normalización de Entidades de Dominio
- Refactorizar `DjControllerProfileEntity.findAction` para resolver tokens canónicos con variantes de prefijos (`Key`, `Digit`, espacios y mayúsculas).

### Paso 2: Audio Engine & Reproducción Real
- Actualizar `DjDeckAudioService` con campos `_loadedWavBytesA` y `_loadedWavBytesB`.
- Garantizar que `playDeck` reproduzca `_loadedWavBytes` si existen antes del fallback por defecto.
- Evitar que `loadTrackSimple` borre pistas existentes en el reproductor.

### Paso 3: Aislamiento de Atajos en MainAppShell
- Condicionar `Shortcuts` en `MainAppShell` para que cuando `_currentIndex == 5`, solo operen atajos de nivel de aplicación (`Ctrl+K`, `Shift+?`, `Alt+1..6`) y todas las teclas alfanuméricas queden disponibles para el DJ.

### Paso 4: Modal de Carga Universal y Chips Rápidos
- Rediseñar `DjTrackLoaderModal` para incluir pestañas de Repertorio Maestro, Tomas WAV y presets de estudio.
- Añadir chips de carga inmediata de 1 clic en la cabecera de los Decks A y B.
