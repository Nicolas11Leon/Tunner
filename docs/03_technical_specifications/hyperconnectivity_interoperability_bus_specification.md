# Especificacion Tecnica del Bus de Hiperconectividad e Interoperabilidad Pro-Studio (Ola 6: US-HC-01 a US-HC-08)

Este documento define la especificacion tecnica, los fundamentos matematicos y la arquitectura de software para la Ola 6 de Hiperconectividad Pro-Studio del proyecto **Tunner**, enfocada en eliminar los silos remanentes entre herramientas de analisis, composicion, practica adaptativa, grabacion, consola DJ y boveda multimedia dentro de un monolito modular 100% local (Offline-First).

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-0195`
- **Titulo Oficial:** `Especificacion Tecnica del Bus de Hiperconectividad, Enrutamiento Full-Duplex y Puentes Pedagogicos Pro-Studio (US-HC-01 a US-HC-08)`
- **Estado:** `Draft`
- **Fecha de Creacion:** `2026-11-26`
- **Ultima Modificacion:** `2026-11-26`
- **Fase Asociada:** `Fase 2 / Ola 6 Hiperconectividad Pro-Studio`
- **Autor / Revisor Principal:** `Nicolas Leon`

---

## 1. Resumen Ejecutivo (Executive Summary)

Tras consolidar la ergonomia de estacion de trabajo en la Ola 5 (`US-UX-05` a `US-UX-10`), una auditoria integral de conectividad en **Tunner** identifico ocho desconexiones operativas entre subsistemas que ya contaban con motores internos robustos pero carecian de enlaces bidireccionales o puentes de transferencia directa. Entre ellas destacan: el slot `rightInspectorContent` sin poblar en `MainAppShell` y el enrutamiento rigido de `MediaSynergyTarget.mixerChannel` hacia DJ Deck A (`US-HC-01`); la vinculacion parcial de las macro-perillas de `StudioSmartControlsMacroBar` con el `SignalBus` y `TunerViewModel` (`US-HC-02`); la omision del rango de bucle A-B en el secuenciador principal de `TunerViewModel` y el anclaje fijo al Canal A en la exportacion al Patchbay (`US-HC-03`); la imposibilidad de inyectar partituras activas de `workspaceScores` directamente en la Consola DJ o enviar mezclas grabadas a la Boveda Multimedia (`US-HC-04`); el aislamiento entre `ChordAnalyzerModal` y los motores de Dron Armonico y Tutor de Entonacion Justa (`US-HC-05`); la falta de generacion automatica de ejercicios remediales desde `criticalNotes` en `PracticeReportModal` (`US-HC-06`); la desconexion entre el selector aleatorio de `BlindEarTrainerModal` y la cola priorizada por retencion de `EbbinghausSpacedRepetitionEngine` (`US-HC-07`); y la ausencia de puentes en 1 clic desde las tomas de `PracticeRecorderDock` hacia `SongDecomposerModal`, `MediaVaultViewModel` y `DjConsoleViewModel` (`US-HC-08`).

Esta especificacion formaliza el bus unificado de hiperconectividad sobre Clean Architecture, garantizando latencias de sincronizacion sub-5 ms, cero bucles `busy-waiting`, ejecucion determinista en memoria local y trazabilidad completa hacia los ADRs `0195` a `0202` y los Casos de Uso `UC-203` a `UC-210`.

---

## 2. Contexto del Problema y Justificacion Teorica

### 2.1 Planteamiento del Problema
Aunque **Tunner** dispone de infraestructura de comunicacion inter-herramientas (`SignalBus`, `StudioPatchbayRoutingService`, `MediaVaultViewModel`, `EbbinghausSpacedRepetitionEngine`, `ScorePlaybackCoordinator` y `AlgorithmicExerciseGenerator`), la integracion efectiva presentaba ocho brechas concretas:

1. **Inspector Derecho Incompleto y Despacho de Boveda Sin Canalizacion (`US-HC-01`):** `StudioDesktopAppShell` expone `rightInspectorContent`, pero `MainAppShell` no inyecta vistas contextuales segun la pestana activa. Asimismo, `MediaVaultViewModel.onDispatchToTool` redirige `MediaSynergyTarget.mixerChannel` de forma fija a `_djConsoleViewModel.loadTrackWithBeatTracking('A', ...)` en lugar de publicar en `StudioPatchbayRoutingService`.
2. **Macro-Controles Parcialmente Conectados (`US-HC-02`):** En `StudioSmartControlsMacroBar`, solo `A4 PITCH` y `MASTER TEMPO` se propagan hacia `TunerViewModel` y `ModularRackViewModel`, mientras que `NOISE GATE`, `DRONE MIX`, `RETUNE SPEED` y `ROOM REVERB` permanecen como estado local de widget sin enlace bidireccional al bus DSP.
3. **Desacoplamiento del Bucle A-B y Canal Fijo en Partituras (`US-HC-03`):** `CompositionNotationWorkspaceView` configura `scorePlaybackCoordinator.setMeasureLoopRange(...)`, pero el ticker de `TunerViewModel` avanza compases con `(_currentMeasureIndex + 1) % maxMeasures`, ignorando `[M_A, M_B]`, y `_sendActiveScoreToPatchbayChannelA` publica unicamente en `'canal_a'`.
4. **Aislamiento entre Repertorio Activo, Consola DJ y Boveda (`US-HC-04`):** `DjTrackLoaderModal` solo consulta `studioLibrary`, `SongDecomposerService.getCuratedLibrary()` y rutas de archivo locales, omitiendo `TunerViewModel.workspaceScores` y los activos de `MediaVaultViewModel`, asi como la exportacion directa de grabaciones DJ hacia la boveda.
5. **Ruptura del Ciclo Analisis Armonico -> Referencia Justa (`US-HC-05`):** Tras detectar un acorde polifonico en `ChordAnalyzerModal`, el musico debe configurar manualmente la fundamental y calidad de acorde al abrir `HarmonicDroneModal` o `HarmonicTutorModal`.
6. **Brecha entre Evaluacion y Practica Remedial (`US-HC-06`):** `PracticeReportModal` calcula y muestra `report.criticalNotes`, pero no permite invocar `AlgorithmicExerciseGenerator` para generar al instante un ejercicio correctivo enfocado en dichas notas.
7. **Subutilizacion de la Curva de Olvido en Entrenamiento Auditivo (`US-HC-07`):** `BlindEarTrainerModal` instancia `BlindEarTrainerEngine()` con todos los intervalos cromaticos equiprobables, sin consultar `TunerViewModel.ebbinghausEngine.getDueItems()` para priorizar los intervalos con menor retencion cognitiva.
8. **Tomas Grabadas Confinadas al Reproductor (`US-HC-08`):** Desde `PracticeRecordingPlayerModal` o `PracticeRecorderDock`, una toma capturada solo puede convertirse a partitura mediante `convert_take_to_score_button`, careciendo de envio directo a `SongDecomposerModal`, `MediaVaultViewModel` o los decks de la consola DJ.

### 2.2 Fundamento Teorico / Fisico / Musical

1. **Propagacion Reactiva en Bus Full-Duplex (`US-HC-01`, `US-HC-02`, `US-HC-03`):**
   La sincronizacion de parametros normalizados $u_k \in [0, 1]$ entre la barra macro y los motores DSP sigue la transformacion afin acotada:
   $$x_k = x_{k,\min} + u_k \cdot (x_{k,\max} - x_{k,\min}), \quad u_k = \frac{\text{clamp}(x_k, x_{k,\min}, x_{k,\max}) - x_{k,\min}}{x_{k,\max} - x_{k,\min}}$$
   El umbral de puerta de ruido en decibelios $L_{\text{dBFS}} \in [-70, -10]$ se convierte a amplitud lineal PCM mediante:
   $$A_{\text{gate}} = 10^{L_{\text{dBFS}} / 20}$$

2. **Aritmetica Modular de Bucle A-B Unificada (`US-HC-03`):**
   Dado un puntaje con $N_{\text{measures}} \ge 1$ compases y un rango activo $[M_A, M_B]$ en base cero ($0 \le M_A \le M_B < N_{\text{measures}}$), la transicion determinista de compas al completar el sub-tick final del compas $m$ es:
   $$m_{\text{next}} = \begin{cases} M_A & \text{si } \text{isMeasureLoopActive} \land (m \ge M_B \lor m < M_A) \\ (m + 1) \bmod N_{\text{measures}} & \text{en caso contrario} \end{cases}$$

3. **Mapeo de Entonacion Justa desde Acordes Detectados (`US-HC-05`):**
   Dado un acorde reconocido con indice cromatico fundamental $r \in \{0, \dots, 11\}$, octava $o \in [1, 6]$ y referencia $f_{A4}$ (por defecto $440.0\text{ Hz}$), la frecuencia fundamental temperada de referencia es:
   $$f_{\text{root}} = f_{A4} \cdot 2^{\frac{((o + 1) \cdot 12 + r) - 69}{12}}$$
   Sobre $f_{\text{root}}$, `JustIntonationCalculator` evalua la desviacion en cents respecto a las razones puras canonicas ($1/1$ fundamental, $5/4$ tercera mayor $+386.31\text{ cents}$ frente a $400\text{ cents}$, $6/5$ tercera menor $+315.64\text{ cents}$, $3/2$ quinta justa $+701.96\text{ cents}$, $7/4$ septima armonica $+968.83\text{ cents}$).

4. **Priorizacion Cognitiva de Ebbinghaus (`US-HC-07`):**
   Para cada intervalo $i$ en `EbbinghausSpacedRepetitionEngine`, la retencion instantanea en el instante $t$ (dias transcurridos $\Delta t_i$ desde `lastReviewDate` con estabilidad $S_i$) sigue:
   $$R_i(t) = \exp\left(-\frac{\Delta t_i}{S_i}\right)$$
   Los items vencidos ($R_i(t) \le \tau_{\text{ret}}$ con $\tau_{\text{ret}} = 0.90$, o $t > \text{nextReviewDate}$) se ordenan por retencion creciente $R_i(t)$ para maximizar la eficiencia de consolidacion sin repetir material ya dominado.

5. **Ponderacion Remedial por Precision de Nota (`US-HC-06`):**
   Sea $C = \{n_1, \dots, n_k\}$ el conjunto de `criticalNotes` ordenado de menor a mayor precision $p(n_j) \in [0, 100]$. Cada nota critica genera una secuencia pedagogica de nota larga y borde vecinal ($\pm 1$ o $\pm 2$ semitonos segun escala activa) a un tempo inicial conservador $\text{BPM}_{\text{drill}} = \text{clamp}(\text{BPM}_{\text{base}} \cdot 0.75, 50, 96)$.

---

## 3. Especificacion Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos

- **REQ-01 (`US-HC-01` - Inspector Contextual Vivo y Ruteo de Boveda por Canal):**
  - `MainAppShell` construye e inyecta `rightInspectorContent` en `StudioDesktopAppShell` de acuerdo con la pestana activa (`_currentIndex`), exponiendo propiedades en vivo, estado de canales del Patchbay y accesos directos no bloqueantes (`Key('live_contextual_inspector_content')`, `Key('inspector_quick_route_patchbay_btn')`).
  - `MediaVaultViewModel` y `MainAppShell` permiten despachar activos de audio o partitura hacia canales explicitos de `StudioPatchbayRoutingService` (`canal_a`, `canal_b`, `canal_c`, `canal_d` o canales personalizados) mediante `Key('vault_channel_routing_selector')`, publicando metadatos (`title`, `bpm`, `key`, `isPlaying`) y flujo PCM en tiempo real.

- **REQ-02 (`US-HC-02` - Macro-Controles Bidireccionales DSP y Enlace al SignalBus):**
  - Las 6 macro-perillas de `StudioSmartControlsMacroBar` (`A4 PITCH`, `MASTER TEMPO`, `NOISE GATE`, `DRONE MIX`, `RETUNE SPEED`, `ROOM REVERB`) operan bidireccionalmente con `TunerViewModel` y `ModularRackViewModel.signalBus`.
  - Los cambios originados desde la UI o desde eventos atomicos del `SignalBus` actualizan de manera consistente el estado DSP y las vistas sin crear bucles infinitos de notificacion (`_isSyncingFromBus` guard).

- **REQ-03 (`US-HC-03` - Coordinador Unificado de Bucle A-B y Puente de Exportacion Patchbay):**
  - El ticker de reproduccion y practica en `TunerViewModel` respeta `scorePlaybackCoordinator.isMeasureLoopActive`, `loopStartMeasureIndex` y `loopEndMeasureIndex` al avanzar de compas.
  - `CompositionNotationWorkspaceView` permite seleccionar el canal destino del Patchbay (`Key('btn_score_patchbay_channel_selector')`) al publicar la partitura y exportar en 1 clic el segmento `[M_A, M_B]` hacia `AudioMidiExportModal` o `MediaVaultViewModel`.

- **REQ-04 (`US-HC-04` - Inyeccion en Vivo de SongPackage en Consola DJ y Retorno a Boveda):**
  - `DjConsoleViewModel` incorpora `injectSongPackageToDeck(String deckId, SongPackage package)` para sintetizar y analizar beat-tracking/Camelot de cualquier partitura viva del usuario.
  - `DjTrackLoaderModal` expone pestanas para `TunerViewModel.workspaceScores` (`Key('dj_loader_workspace_scores_tab')`) y `MediaVaultViewModel` (`Key('dj_loader_media_vault_tab')`), y `DjStudioWorkstationView` incorpora `Key('dj_export_mix_to_vault_btn')` para enviar la mezcla grabada a la Boveda Multimedia.

- **REQ-05 (`US-HC-05` - Puente Acordes -> Dron Armonico y Tutor de Entonacion Justa):**
  - `ChordAnalyzerModal` expone dos puentes de 1 clic sobre la tarjeta de acorde reconocido (`chord.isRecognized`):
    1. `Key('chord_to_harmonic_drone_btn')`: configura `HarmonicDroneConfig` con la fundamental y octava del acorde detectado y abre/activa `HarmonicDroneModal`.
    2. `Key('chord_to_ji_tutor_btn')`: configura `HarmonicTutorViewModel` con `rootNoteName`, `rootFrequency` y `HarmonicChordType` equivalentes y abre `HarmonicTutorModal`.

- **REQ-06 (`US-HC-06` - Generacion de Ejercicios Remediales desde Reporte de Practica):**
  - `AlgorithmicExerciseGenerator` provee `generateRemedialDrillFromCriticalNotes(...)` en Pure Dart, construyendo un `SongPackage` enfocado en las notas criticas de `PracticeReportEntity`.
  - `PracticeReportModal` muestra `Key('report_generate_remedial_drill_btn')` cuando `report.criticalNotes.isNotEmpty`, cargando el ejercicio remedial en `TunerViewModel` y abriendo la practica en 1 clic.

- **REQ-07 (`US-HC-07` - Puente Adaptativo Ebbinghaus -> Entrenador Auditivo):**
  - `BlindEarTrainerModal` consulta `TunerViewModel.ebbinghausEngine.getDueItems()` para construir la configuracion adaptativa de intervalos vencidos, mostrando el indicador `Key('ear_trainer_due_count_badge')` y el conmutador `Key('ear_trainer_ebbinghaus_adaptive_toggle')`.
  - Cada respuesta evaluada actualiza simultaneamente `BlindEarTrainerEngine` y `EbbinghausSpacedRepetitionEngine`, recalculando la cola de pendientes.

- **REQ-08 (`US-HC-08` - Puentes de Grabadora en 1 Clic e Ingestion de Tomas en Descompositor):**
  - `PracticeRecordingPlayerModal` y `PracticeRecorderDock` exponen acciones directas sobre `activeRecording` hacia `SongDecomposerModal` (`Key('recorder_send_to_decomposer_btn')`), `MediaVaultViewModel` (`Key('recorder_send_to_media_vault_btn')`) y `DjConsoleViewModel` (`Key('recorder_send_to_dj_deck_btn')`).
  - `SongDecomposerModal` incorpora `Key('decomposer_ingest_active_take_btn')` para ingerir la toma activa (`OfflinePracticeTakeAnalyzer` / PCM WAV), extraer su contorno y generar un `SongPackage` editable con pistas.

### 3.2 Casos de Borde y Condiciones de Error
- **Cola Ebbinghaus Vacia (Sin Intervalos Vencidos):** Si `getDueItems()` retorna vacio porque todos los intervalos superan el umbral de retencion, el adaptador selecciona los 3 intervalos con menor `retentionAt(now)` o activa el modo de repaso libre sin lanzar `StateError`.
- **Lista `criticalNotes` Vacia o Nombres Enarmonicos Mixtos:** Si `report.criticalNotes` esta vacia, `report_generate_remedial_drill_btn` permanece oculto. Los nombres enarmonicos (`Mib4`, `D#4`, `Sol4`) se normalizan mediante `CanonicalPitchNotationCodec.parseOrDefault`.
- **Acorde Reconocido No Estandar en Puente a Tutor Justo:** Si el acorde detectado (`ChordEntity`) tiene una calidad no mapeada directamente en `HarmonicChordType` (por ejemplo, cluster o acorde suspendido complejo), el mapeador realiza un respaldo determinista hacia `HarmonicChordType.majorTriad` o `minorTriad` segun la presencia de tercera mayor/menor en `chord.notes`, preservando siempre la fundamental exacta.
- **Toma de Grabacion Nula o Silenciosa en Ingestion:** Si `activeRecording` es nula o su duracion util es inferior a $250\text{ ms}$, los puentes hacia Descompositor, Boveda y DJ muestran un estado informativo no destructivo y omiten la creacion de activos vacios.
- **Anti-Reentrancia en Buses Bidireccionales:** Tanto `StudioPatchbayRoutingService` como `ModularRackViewModel` y `StudioSmartControlsMacroBar` emplean guardas de origen (`sourceId != ownPlugId` y banderas `_isSyncingFromBus`) para impedir ciclos de retroalimentacion infinitos.

---

## 4. Diseño Tecnico y Arquitectura de la Solucion

### 4.1 Capa de Dominio (Domain Layer)
Todos los algoritmos de mapeo, adaptacion y transformacion viven en **Pure Dart** sin dependencias de Flutter UI:
- `ChordHarmonicBridgeMapper` (`lib/features/chord_analyzer/domain/`): traduce `ChordEntity` a `HarmonicDroneConfig` y parametros de `HarmonicTutorSessionEntity`.
- `AlgorithmicExerciseGenerator.generateRemedialDrillFromCriticalNotes` (`lib/features/exercise_generator/domain/algorithmic_exercise_generator.dart`): construye `SongPackage` remedial a partir de `criticalNotes` y `noteAccuracyMap`.
- `EbbinghausEarTrainerBridge` (`lib/features/ear_training/domain/`): proyecta `List<EarTrainingItemEntity>` vencidos desde `EbbinghausSpacedRepetitionEngine` hacia `List<MusicalInterval>` y pesos de seleccion.
- `SmartControlDspBindingSpec` (`lib/features/modular_rack/domain/`): encapsula ecuaciones de normalizacion/desnormalizacion y mapeo hacia `AtomicSignalEvent` en `SignalBus`.
- Extensiones de `MediaSynergyTarget` (`lib/features/media_vault/domain/media_synergy_target.dart`) para enrutamiento por canal de Patchbay (`patchbayChannel`).

### 4.2 Capa de Infraestructura / Datos (Data Layer)
- `StudioPatchbayRoutingService` (`lib/core/channels/domain/studio_patchbay_routing_service.dart`): actua como bus central full-duplex para canales troncales (`canal_a`..`canal_d`) y personalizados, transportando titulo, BPM, tonalidad Camelot, estado de transporte y buffers PCM.
- `StudioAudioDeviceMatrixService` y `MediaVaultViewModel`: operan 100% en memoria y almacenamiento local (`StudioFileSystemRepository`), convirtiendo tomas `PracticeRecordingEntity` y mezclas DJ WAV a `MediaAssetEntity` sin acceso a red.

### 4.3 Capa de Presentacion (Presentation Layer)
- `MainAppShell` y `StudioLiveInspectorBuilder`: ensamblan `rightInspectorContent` reactivo por pestana y conectan `MediaVaultViewModel.onDispatchToTool` con `StudioPatchbayRoutingService`.
- `StudioSmartControlsMacroBar`: enlaza las 6 perillas rotatorias `StudioRotaryKnob` con `TunerViewModel` y `ModularRackViewModel` de forma bidireccional.
- `CompositionNotationWorkspaceView`, `DjTrackLoaderModal`, `DjStudioWorkstationView`, `ChordAnalyzerModal`, `PracticeReportModal`, `BlindEarTrainerModal`, `PracticeRecordingPlayerModal`, `PracticeRecorderDock` y `SongDecomposerModal`: exponen exclusivamente controles en 1 clic con `Key` verificables, delegando toda logica matematica a dominio/ViewModels.

---

## 5. Criterios de Rendimiento y Benchmarking

- **Latencia de Propagacion de Bus:** $\le 5\text{ ms}$ entre la modificacion de un parametro macro o publicacion en Patchbay y la actualizacion de los suscriptores conectados.
- **Fluidez de Lienzo:** $60/120\text{ FPS}$ ($\le 8.3\text{ ms}$ por frame) durante la reproduccion con bucle A-B en `RealSheetMusicPainter` y ajuste de `StudioRotaryKnob`.
- **Consumo de CPU y Memoria:** Cero bucles `busy-waiting`; los timers de secuenciacion en `ScorePlaybackCoordinator` utilizan calculo de deadline con `Stopwatch` y compensacion de `Timer`, y las colas de eventos usan buffers acotados sin fugas de suscripciones (`dispose()` determinista).

---

## 6. Plan de Pruebas y Validacion (QA)

- [ ] `test/core/navigation/us_hc_01_live_contextual_inspector_and_vault_routing_test.dart`: Validacion de `rightInspectorContent` por pestana y despacho de activos de Boveda a canales de `StudioPatchbayRoutingService`.
- [ ] `test/features/modular_rack/us_hc_02_bidirectional_smart_controls_dsp_binding_test.dart`: Validacion de sincronizacion bidireccional de las 6 perillas macro con `TunerViewModel` y `SignalBus`.
- [ ] `test/features/workspaces/us_hc_03_score_ab_loop_coordinator_and_patchbay_bridge_test.dart`: Validacion de bucle A-B en `TunerViewModel` + `ScorePlaybackCoordinator` y seleccion de canal en Patchbay.
- [ ] `test/features/dj_console/us_hc_04_dj_live_score_injection_and_vault_export_test.dart`: Validacion de inyeccion de `workspaceScores` en Decks A/B y exportacion de mezclas a `MediaVaultViewModel`.
- [ ] `test/features/chord_analyzer/us_hc_05_chord_to_harmonic_drone_and_ji_tutor_bridge_test.dart`: Validacion de mapeo de `ChordEntity` hacia `HarmonicDroneModal` y `HarmonicTutorViewModel`.
- [ ] `test/features/practice_evaluator/us_hc_06_remedial_drill_from_critical_notes_test.dart`: Validacion de generacion determinista de ejercicios remediales desde `PracticeReportModal`.
- [ ] `test/features/ear_training/us_hc_07_ebbinghaus_adaptive_ear_trainer_bridge_test.dart`: Validacion de seleccion prioritaria de intervalos vencidos y actualizacion reciproca de retencion.
- [ ] `test/features/practice_recorder/us_hc_08_recorder_bridges_and_decomposer_ingestion_test.dart`: Validacion de envio de tomas grabadas hacia Descompositor, Boveda y DJ.
- [ ] Verificacion estatica global: `flutter analyze --no-fatal-infos` con `0 issues`.

---

## 7. Referencias Tecnicas y Bibliografia

1. *Constitucion de Ingenieria del Proyecto Tunner (`AGENTS.md`): Clean Architecture, Offline-First y Cero Microservicios.*
2. *Especificacion HCI Pro-Workstation Ola 5 (`docs/03_technical_specifications/pro_workstation_ux_hci_specification.md`).*
3. *W3C Music Notation Community Group - Standard Music Font Layout (SMuFL) Specification.*
4. *Ebbinghaus, H. (1885) & Wozniak, P. A. (SM-2 Spaced Repetition Model).*
5. *Plomp, R. & Levelt, W. J. M. (1965) - Tonal Consonance and Critical Bandwidth (Just Intonation Reference).*
