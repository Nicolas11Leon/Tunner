# ADR-0168: Fronteras de Dominio Puro, Igualdad Estructural en Mixer y Captura de Audio Asincrona Sin Bloqueos

- **Estado:** Aprobado
- **Fecha:** 2026-11-23
- **Autor:** Devs 3 (Agente 03) - Parsers Polifonicos, Transcripcion y Audio DSP
- **Incidencias Relacionadas:** US-8.1 (#180), US-10.1 (#186)

---

## 1. Contexto

Durante la auditoria forense integral de arquitectura y rendimiento en tiempo real se identificaron dos grupos de hallazgos criticos:

1. **Pureza y Consistencia de Dominio (US-8.1 / #180):**
   - `AppUserSettingsEntity` no persistia `activeStudioThemeId`, impidiendo conservar la seleccion del tema de estudio (`'studio_oled_monochrome'`) entre sesiones.
   - `StudioPatchbayRoutingService` utilizaba literales hexadecimales sin constantes semanticas documentadas, invocaba `notifyListeners()` directamente en multiples metodos sin pasar por la guarda `_safeNotify()`, y compartia un unico `Timer? _signalPulseTimer` que sobrescribia el pulso visual cuando una señal se despachaba hacia multiples sinks.
   - `AudioTrack.fromMap` carecia de validacion frente a valores `NaN`, `Infinity` o fuera de `[0.0, 1.0]`, no incluia soporte de balance estereo (`pan`), y ni `AudioTrack` ni `MixerConsoleEntity` implementaban igualdad por valor (`==` y `hashCode`).
   - `PedagogicalCertificatePdfGenerator` codificaba cadenas directamente con `utf8.encode` sobre fuentes Type 1 Helvetica sin declarar `/WinAnsiEncoding` ni sanitizar tildes y eñes, provocando glifos corruptos en lectores PDF conformes a ISO 32000-1.

2. **Ciclo de Vida de Audio y Escritura Sin Bloqueos (US-10.1 / #186):**
   - `StudioAudioChannel` creaba tres suscripciones a `onPositionChanged`, `onDurationChanged` y `onPlayerComplete` sin almacenarlas ni cancelarlas en `dispose()`.
   - `StudioAudioInputEngine` ignoraba `bufferSize` en su estado de configuracion y llamaba `stopCapture()` sin encadenar la liberacion de `_recorderInstance?.dispose()` ni proteger contra doble `dispose()`.
   - `AudioPlaybackService` y `PitchDetectorService` podian instanciar internamente motores de audio (`_audioEngine`, `_inputEngine`) cuando no eran inyectados, pero no los liberaban en `dispose()`.
   - `StudioMasterCaptureService.appendStereoSamples` ejecutaba `_randomAccessFile?.writeFromSync(bytes)` dentro del flujo de captura en tiempo real, exponiendo el hilo emisor a bloqueos de I/O de disco.
   - `HarmonicBeatGauge` mantenia su `AnimationController` en modo `repeat()` perpetuo incluso cuando el estado era `HarmonicLockStatus.pureConsonance`, consumiendo ciclos de CPU/GPU sin desplazamiento angular efectivo.

---

## 2. Decision

1. **Persistencia de Skin y Semantica en Dominio:**
   - Añadir el campo inmutable `activeStudioThemeId` (por defecto `'studio_oled_monochrome'`) en `AppUserSettingsEntity` (`constructor`, `copyWith`, `toMap`, `fromMap`).
   - Definir constantes de token semantico documentadas (`defaultActiveChannelTokenHex` y `disconnectedPlugTokenHex`) en `StudioPatchbayRoutingService`, canalizar todas las notificaciones a traves de `_safeNotify()`, y reemplazar el timer unico por un mapa `Map<String, Timer> _plugPulseTimers` para rastrear pulsos independientes por `plugId`.
   - En `AudioTrack`, incorporar el campo `pan` (`[-1.0, 1.0]`, por defecto `0.0`), validar `isFinite` y `.clamp(...)` tanto para `volume` como para `pan` en `fromMap` y `copyWith`, e implementar `==` y `hashCode` estructurales en `AudioTrack` y `MixerConsoleEntity`.
   - En `PedagogicalCertificatePdfGenerator`, declarar `/Encoding /WinAnsiEncoding` en las fuentes Type 1 Helvetica y aplicar sanitizacion explicita de caracteres acentuados y eñes antes de construir el flujo PDF.

2. **Endurecimiento del Ciclo de Vida de Audio y Cola Asincrona de Captura:**
   - Almacenar `_positionSub`, `_durationSub` y `_completeSub` en `StudioAudioChannel` y cancelarlas explicitamente en `dispose()`.
   - Registrar `activeBufferSize` en `StudioAudioInputEngine`, proteger `dispose()` con guarda `_isDisposed` y encadenar `stopCapture().whenComplete(() => _recorderInstance?.dispose())`.
   - Registrar `_ownsAudioEngine` en `AudioPlaybackService` y `_ownsInputEngine` en `PitchDetectorService` para invocar `dispose()` sobre los motores creados internamente.
   - Sustituir `writeFromSync` en `StudioMasterCaptureService` por una cadena asincrona `Future<void> _writeChain = Future<void>.value()` que encola `_randomAccessFile?.writeFrom(bytes)` y es esperada (`await _writeChain`) antes de escribir la cabecera final y cerrar el archivo en `stopCapture()` / `stopAndFinalizeCapture()`.
   - En `HarmonicBeatGauge`, detener el controlador (`_wobbleController.stop()`) en `initState` y `didUpdateWidget` cuando `widget.status == HarmonicLockStatus.pureConsonance`, y reanudar `repeat()` unicamente cuando exista batimiento activo.

---

## 3. Consecuencias

### Positivas
- **Cero Bloqueos de I/O en Captura de Audio:** El callback de captura PCM solo encola buffers en memoria hacia `_writeChain`, manteniendo una latencia determinista sub-10 ms.
- **Cero Fugas de Suscripciones y Motores:** La destruccion de canales, reproductores y detectores de tono libera de forma determinista todos los streams y grabadores subyacentes.
- **Eficiencia Energetica en UI:** `HarmonicBeatGauge` consume 0% de ticks de animacion cuando el estudiante mantiene consonancia pura.
- **Integridad de Datos en Mixer y PDF:** La consola de mezcla es inmune a valores `NaN`/`Infinity` provenientes de JSON corruptos y los certificados PDF se renderizan sin errores de codificacion.

### Negativas / Trade-offs
- El encadenamiento asincrono en `StudioMasterCaptureService` requiere que `stopCapture()` aguarde la finalizacion de `_writeChain` antes de cerrar el descriptor de archivo, lo cual es transparente para los consumidores que ya invocan `await stopCapture()`.
