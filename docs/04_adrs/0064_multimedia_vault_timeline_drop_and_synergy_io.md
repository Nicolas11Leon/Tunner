# ADR 0064: Bóveda Multimedia Centralizada, Línea de Tiempo Drag & Drop y Motor Universal de I/O

- **Estado:** Aceptado
- **Fecha:** 2026-11-14
- **Contexto Relacionado:** [DOC-MEDIA-2026-070](../01_product_vision/doc_multimedia_vault_and_universal_io_sync.md), [UC-70](../02_use_cases/70_uc_multimedia_vault_timeline_drag_drop_and_universal_io.md)

---

## 1. Contexto

Tunner dispone de múltiples herramientas especializadas (`dj_console`, `universal_importer`, `song_library`, `mixer`, `practice_recorder`, `score_editor`), cada una con sus propios formatos de entrada/salida. El usuario requiere:
1. Un repositorio visual único (**Media Vault**) donde guardar y organizar canciones, stems, partituras, archivos MIDI y grabaciones.
2. Un espacio de **Línea de Tiempo Multi-Pista** con soporte nativo de **Drag & Drop** para organizar y sincronizar activos en el tiempo.
3. Un motor unificado de **Importación y Exportación** lo más completo posible, 100% offline y bajo Clean Architecture estricta.

## 2. Decisión Arquitectónica

1. **Feature Independiente `lib/features/media_vault/`:**
   Se crea un módulo autónomo con separación estricta en `domain/`, `data/` y `presentation/`, sin dependencias circulares hacia otras features.
2. **Integración por Contratos e Inyección de Despacho (`MediaSynergyTarget`):**
   `MediaVaultViewModel` no instancia ni importa otros ViewModels directamente; en su lugar, expone un contrato `MediaToolDispatcher` que la capa de integración superior (`App` / `DjConsoleModal`) conecta para cargar pistas en `Deck A/B`, pads del Sampler, `Mixer` o `Score Editor`.
3. **Codec RIFF/WAV PCM Puro en Dart (`WavPcmCodec`):**
   Para garantizar exportación e importación de audio sin pérdida 100% offline y multiplataforma sin añadir dependencias nativas frágiles en esta fase, se implementa un codificador/decodificador RIFF/WAV PCM en `data/wav_pcm_codec.dart`.
4. **Reutilización de Exportadores/Importadores Canónicos Existentes:**
   El servicio `UniversalMediaIoService` reutiliza `UniversalScoreImporterService` y los exportadores canónicos de `universal_importer` (`MIDI`, `MusicXML`, `ABC`, `PDF`), evitando duplicar parsers y manteniendo una única fuente de verdad.

## 3. Consecuencias

### Positivas
- Cero acoplamiento entre `media_vault` y el resto de módulos de UI.
- Exportación de audio WAV real, hojas `.cue` para sets DJ, paquetes `.tunner.json` y partituras sin conexión a internet.
- Entidades de dominio de la línea de tiempo (cuantización, colisiones, ordenamiento) 100% testeables en Dart puro.

### Negativas / Compromisos
- Formatos comprimidos propietarios con patente (ej. MP3/AAC) requieren decodificador nativo FFI en plataforma en iteraciones futuras; por ahora, el pipeline de audio soporta PCM/WAV nativo y partituras/MIDI/JSON de forma universal.
