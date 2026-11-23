# ADR-0173: Identificadores con Ámbito de Instancia en el Patchbay DJ y Contratos DIP de Dominio

- **Estado:** Accepted
- **Fecha:** 2026-11-23
- **Issues:** #190 (US-11.2), #181 (US-8.2)
- **Alcance:** `features/dj_console`, `core/audio`, `features/harmonic_tutor`, `features/ear_training`, `features/guided_lessons`, `features/exercise_generator`, `features/pedagogy_profiles`, `features/project_format`

---

## Contexto

1. **Colisión global de plugs y duplicación en Consola DJ:** Tanto `DjConsoleModal` como `DjStudioWorkstationView` duplicaban ~120 líneas de registro de plugs, listeners de recepción y publicación de parámetros hacia `StudioPatchbayRoutingService` utilizando IDs globales fijos (`'plug_dj_deck_a_in'`, `'plug_dj_deck_b_in'`). Si ambas vistas coexistían o se desmontaba una mientras la otra seguía activa, `unregisterSinkListener` dejaba sorda a la instancia viva.
2. **Acoplamiento de telemetría y targets de Media Vault:** `DjConsoleViewModel` no exponía un canal de telemetría de alta frecuencia aislado para vúmetros y fase (`vuA`, `vuB`, `phaseA`, `phaseB`), y `DjConsoleModal` redirigía `MediaSynergyTarget.djSamplerPad` a un pad fijo sin usar el buffer del activo y `MediaSynergyTarget.mixerChannel` al Deck A directamente.
3. **Detección de entorno de pruebas en producción:** `DjDeckAudioService` inspeccionaba `Platform.environment.containsKey('FLUTTER_TEST')` para intercambiar `StudioAudioEngine` por `MemoryStudioAudioEngine`, violando el principio de Inversión de Dependencias y contaminando la capa de datos con lógica exclusiva de testing.
4. **Brechas de contratos DIP en dominio:** Ocho servicios y motores clave (`StudioMasterClockService`, `StudioAudioDeviceMatrixService`, `HarmonicReferenceSynth`, `BlindEarTrainerEngine`, `TaskCatalogIndex`, `AlgorithmicExerciseGenerator`, `AdaptiveScaffoldingEngine`, `TunnerBinaryProjectCodec`) carecían de interfaces puras dedicadas en sus respectivas capas `domain/`.

---

## Decisión

1. **Bridge reutilizable con IDs con scope de instancia:** Se crea `DjDeckPatchbayBridge` en `lib/features/dj_console/presentation/dj_deck_patchbay_bridge.dart`, parametrizado con `scopePrefix` único por instancia. Sus plugs se identifican como `'${scopePrefix}_plug_dj_deck_a_in'`, `'${scopePrefix}_plug_dj_deck_b_in'` y opcionalmente `'${scopePrefix}_plug_dj_master_out'`. Tanto `DjConsoleModal` como `DjStudioWorkstationView` delegan su ciclo de vida de patchbay a este puente.
2. **Telemetría desacoplada por `ValueNotifier`:** Se añade `telemetryNotifier` (`ValueNotifier<({double vuA, double vuB, double phaseA, double phaseB})>`) en `DjConsoleViewModel`, actualizado por el ticker de 30 Hz y liberado en `dispose()`.
3. **Cableado real de Media Vault:** Se añade `triggerSamplerBuffer` en `DjConsoleViewModel` para reproducir el buffer PCM del activo en `MediaSynergyTarget.djSamplerPad`, y `publishMixerChannelAsset` en `DjDeckPatchbayBridge` para enrutar `MediaSynergyTarget.mixerChannel` al bus de mezclador (`canal_c`) del patchbay.
4. **Eliminación de `FLUTTER_TEST` en `DjDeckAudioService`:** Se elimina `_isTestEnvironment` y el import de `MemoryStudioAudioEngine` en producción; el constructor resuelve `audioEngine ?? StudioAudioEngine()`, permitiendo inyectar `MemoryStudioAudioEngine` explícitamente en pruebas.
5. **Creación de 8 interfaces puras de dominio:**
   - `IStudioMasterClockService` (`lib/core/audio/domain/i_studio_master_clock_service.dart`)
   - `IStudioAudioDeviceMatrixService` (`lib/core/audio/domain/i_studio_audio_device_matrix_service.dart`)
   - `IHarmonicReferenceSynth` (`lib/features/harmonic_tutor/domain/i_harmonic_reference_synth.dart`), inyectada en `HarmonicTutorViewModel`
   - `IEarTrainerEngine` (`lib/features/ear_training/domain/i_ear_trainer_engine.dart`)
   - `ITaskCatalogIndex` (`lib/features/guided_lessons/domain/i_task_catalog_index.dart`)
   - `IExerciseGenerator` (`lib/features/exercise_generator/domain/i_exercise_generator.dart`)
   - `IAdaptiveScaffoldingEngine` (`lib/features/pedagogy_profiles/domain/i_adaptive_scaffolding_engine.dart`)
   - `ITunnerBinaryCodec` (`lib/features/project_format/domain/i_tunner_binary_codec.dart`)

---

## Consecuencias

### Positivas
- Dos o más instancias de vistas DJ pueden montarse, operar y desmontarse de manera independiente sobre `StudioPatchbayRoutingService` sin colisión de IDs ni pérdida de listeners.
- Reducción significativa de código duplicado entre `DjConsoleModal` y `DjStudioWorkstationView`.
- Los consumidores de telemetría (vúmetros y fase) pueden escuchar `telemetryNotifier` de forma granular.
- `DjDeckAudioService` es 100% determinista por inyección de dependencias y compatible con entornos donde `dart:io` no es deseable.
- La capa de dominio expone contratos completos en Pure Dart para pruebas unitarias con dobles de prueba y evolución futura hacia enlaces nativos `dart:ffi`.

### Negativas / Trade-offs
- Las pruebas unitarias que instanciaban `DjDeckAudioService()` sin argumentos requieren inyectar explícitamente `audioEngine: MemoryStudioAudioEngine()`.
- Los plugs registrados en la matriz muestran identificadores con prefijo de ámbito, lo cual requiere que las pruebas de integración consulten los IDs expuestos por `DjDeckPatchbayBridge`.
