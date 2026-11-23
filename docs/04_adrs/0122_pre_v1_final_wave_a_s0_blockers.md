# ADR 0122: Remediación de Bloqueantes S0 de Seguridad, Integridad de Datos, Audio y UI (Ola Final A)

## Estado
Aceptado

## Contexto
La auditoría forense directa sobre la rama `qa` (`c67078d`) reveló defectos bloqueantes S0 que impiden lanzar `v1.0.0` de forma segura:
1. `LocalDiskStudioFileSystemRepository` permitía leer/escribir rutas absolutas externas arbitrarias y borrar recursivamente la raíz mediante `'./'`.
2. `TunnerPackageCodecService`, `CompressedMusicXmlParser`, `PdfScoreParser` y `TunnerBinaryProjectCodec` presentaban brechas en validación SHA-256 1:1 y límites reales de descompresión.
3. `AppUserSettingsEntity.toMap()` recortaba el final de `recordingHistory` mientras las nuevas grabaciones se insertan al inicio (`index 0`).
4. `StudioCompositionRoot` dejaba repositorios `NoOp` en DJ/Rack y ruta temporal en `StemExportPersistenceService`.
5. `DjAudioProcessor._softLimit` y `HarmonicReferenceSynth._softLimit` colapsaban valores $>1.0$ hacia $0.0$.
6. La grabación DJ en vivo etiquetaba muestras mono como estéreo (2x velocidad), `StemAudioSynthesizer` buscaba IDs fijos `"voice"`/`"piano"`, y `TdPsolaPitchShifter` lanzaba `ArgumentError` bajo 48 muestras.
7. Existían 6 crashes UI reproducibles (`StudioThemeSwitcher`, `StudioCommandPromptBar`, `StudioDesktopAppShell`, `TunnerOsTerminalDrawer`, `StudioSettingsModal`, `StudioAudioChannel` cross-dispose) y secuestro de atajos sobre campos de texto.

## Decisión
1. **Confinamiento Estricto del Sandbox:** Reemplazar todas las ramas `isAbsolute`/`startsWith` en `LocalDiskStudioFileSystemRepository` por `_resolveSafePath` con validación por segmentos y `resolveSymbolicLinksSync()`.
2. **Integridad Criptográfica y Anti-Zip-Bomb:** Exigir biyección exacta entre entradas del ZIP (excepto `manifest.json`) y `fileHashes`, y contar bytes reales descomprimidos con tope en todos los parsers comprimidos.
3. **Retención y DI Real:** Usar `take(50)` para `recordingHistory` y cablear repositorios reales + `documentsDirectoryProvider` en `StudioCompositionRoot`.
4. **Estabilidad Matemática y Audio:** Sustituir `_softLimit` por limitador $C^1$-continuo basado en `tanh`; unificar `numChannels: 1` en grabación DJ con caché fuera del ticker; resolver dinámicamente las pistas de `StemAudioSynthesizer`.
5. **Blindaje UI/Teclado/Lifecycle:** Proteger `DropdownButton`, `didUpdateWidget`, `.clamp()`, `FocusNode` persistente con `mounted`, `Slider.clamp`, `Action.isEnabled` y `stop()` seguro en servicios con canales compartidos.

## Consecuencias
- Cero pérdidas de datos en grabaciones, mezclas DJ, keymaps y proyectos del Rack.
- Cero crashes en flujos críticos de escritorio/móvil al editar temas, usar la barra de comandos o escribir texto.
- Seguridad real offline-first ante archivos `.tunner`, `.mxl` y `.pdf` corruptos o maliciosos.
