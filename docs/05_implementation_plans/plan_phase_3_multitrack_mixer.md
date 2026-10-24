# Implementation Plan: Phase 3 Multitrack Accompaniment Mixer & Independent Metronome Volume Control

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-MULTITRACK-MIXER-2026-009`
- **Título de la Implementación:** `Consola Mezcladora Multicanal de Stems (Voz, Piano, Guitarras) y Volumen Independiente de Metrónomo`
- **Fase del Proyecto:** `Fase 3`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `N/A`
- **Documento Funcional Base:** `docs/02_use_cases/07_uc_multitrack_stem_mixer.md` y `docs/02_use_cases/02_uc_high_res_audio_clock.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar la arquitectura de dominio e interfaz gráfica para la **Consola Mezcladora Multicanal (MultiTrack Stem Mixer)** de Tunner. Permite a cualquier músico ajustar individualmente:
1. El volumen del **Metrónomo** de forma independiente.
2. El volumen de las distintas **Pistas de Acompañamiento / Stems** de la canción (Voz, Piano, Guitarras / Vientos, etc.).
3. Funcionalidades profesionales de canal: controles individuales de **Mute (M)** y **Solo (S)**.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio puras `lib/domain/mixer_track_entity.dart` con modelo inmutable de pistas, ganancia, mute y solo.
  - Generación de clics audibles de metrónomo PCM en `ToneGeneratorService` con acento en pulso 1 y ganancia desacoplada.
  - Integración en `TunerViewModel`: canal maestro de metrónomo y catálogo de stems reactivo.
  - Consola gráfica en `TunerScreen` (botón de consola mezcladora y panel modal deslizante con faders verticales/horizontales premium estilo estudio analógico).
  - Pruebas unitarias completas de la lógica del mezclador de dominio.
- **Excluido (Out-of-Scope):**
  - Red neuronal en tiempo real de demuxing Spleeter/Demucs local sobre archivos MP3 arbitrarios del usuario (reservado para Fase 4 con FFI).

---

## 2. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Entidad de Mezclador y Pistas)
- [x] Crear `lib/domain/mixer_track_entity.dart` con `AudioTrack` y `MixerConsoleEntity`.
- [x] Soporte de volumen ($0.0 \dots 1.0$), `isMuted`, `isSoloed` y cálculo de ganancia efectiva.
- [x] Pruebas unitarias de dominio en `test/domain/mixer_track_test.dart`.

### Paso 2: Capa de Datos / Infraestructura (Síntesis de Clic de Metrónomo)
- [x] Extender `ToneGeneratorService` para generar buffers PCM de clic de metrónomo con acento agudo (1600 Hz) en el pulso 1 y clics normales (800 Hz) en los pulsos secundarios, escalados por el volumen específico del metrónomo.

### Paso 3: Capa de Presentación (ViewModel & Consola Gráfica en UI)
- [x] En `TunerViewModel`: exponer `mixerConsole`, métodos para `setMetronomeVolume`, `setTrackVolume`, `toggleMute`, `toggleSolo`.
- [x] En `TunerScreen`: botón de consola mezcladora en la barra de herramientas y panel modal deslizante con faders y botones M/S con diseño premium.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecutar `flutter test` y `flutter analyze`.

---

## 3. Criterios de Aceptación (Definition of Done)

- [x] Metrónomo con volumen 100% independiente de las pistas de la canción.
- [x] Pistas de la canción (Voz, Piano, Instrumento) con controles independientes de volumen, mute y solo.
- [x] 100% de pruebas unitarias pasando.
