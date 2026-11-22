# ADR-0158: Sintesis Mixdown en Vivo y Persistencia JSON del Catalogo en MediaVault

- **Estado:** Aceptado
- **Fecha:** 2026-11-22
- **Historia de Usuario:** US-5.3 (EPIC-05)
- **Issue:** #159

## Contexto

`MediaVaultViewModel.togglePlayback()` solo avanzaba `_playheadMs` con un `Timer.periodic` de 33 ms sin emitir audio, `toggleTrackMute`/`toggleTrackSolo` no afectaban ningun flujo sonoro, los activos semilla de partitura y MIDI tenian `rawBytes: null` y `pcmSamples: null`, y el catalogo de la boveda se perdia al cerrar la aplicacion.

## Decision

1. **Mixdown unificado reutilizando `IMediaIoService` y `WavPcmCodec`:** Inyectar `IStudioAudioEngine?` y `IAudioSynthesizerService?` en `MediaVaultViewModel` (provistos por `StudioCompositionRoot.createMediaVaultViewModel()`). Al iniciar reproduccion o cambiar Mute/Solo en vivo, generar el mixdown WAV respetando `isMuted`, `isSolo`, `track.volume * clip.gain` y `clip.startMs`, recortar la ventana desde `_playheadMs` y enviarlo a `playPcmWav`.
2. **Semillas musicales binarias reales:** Poblar `rawBytes` con WAV 16-bit reales para pistas/stems, un MusicXML 3.1 valido para `estudio_la_menor.musicxml` y un archivo SMF MIDI Type 0 binario para `sub_bassline_01.mid`, ademas de `pcmSamples` sintetizados para previsualizacion acustica de todos los activos semilla.
3. **Persistencia offline en `StudioFileSystemRepository`:** Serializar `MediaAssetEntity` (`toJson`/`fromJson` con `base64` para `rawBytes` y `waveformPeaks`) en `media_vault/catalog_v1.json`, restaurando `pcmSamples` desde `rawBytes` WAV al recargar para mantener el archivo compacto.

## Consecuencias

- **Positivas:**
  - Reproduccion acustica sincronizada y respuesta instantanea de Mute/Solo sin duplicar logica DSP.
  - Cero `rawBytes: null` o `pcmSamples: null` en activos semilla.
  - Persistencia 100% offline respetando Clean Architecture.
- **Negativas / Compensaciones:**
  - Cambiar Mute/Solo durante reproduccion regenera el mixdown desde `_playheadMs`, lo cual introduce una recomputacion breve O(N) en memoria proporcional a la duracion restante del timeline.
