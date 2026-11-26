# ADR 0201: Puente Adaptativo de Intervalos Vencidos Ebbinghaus en Entrenador Auditivo

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-209](../02_use_cases/209_uc_ebbinghaus_adaptive_ear_trainer_due_intervals_bridge.md)

---

## 1. Contexto

`TunerViewModel` (`lib/features/tuner/presentation/tuner_viewmodel.dart`) mantiene la instancia persistida `ebbinghausEngine` (`EbbinghausSpacedRepetitionEngine` en `lib/features/pedagogy/domain/ebbinghaus_spaced_repetition_engine.dart`), y `BlindEarTrainerModal` (`lib/features/ear_training/presentation/blind_ear_trainer_modal.dart`) reporta cada respuesta a `widget.viewModel.recordEarTrainingAnswer(...)`. Sin embargo, la seleccion de preguntas dentro de `BlindEarTrainerModal` se realiza mediante una instancia local de `BlindEarTrainerEngine()` con configuracion uniforme sobre los 13 intervalos cromaticos, ignorando `ebbinghausEngine.getDueItems()` y la retencion calculada $R(t) = \exp(-t / S)$.

---

## 2. Decision

1. **Adaptador Puro de Priorizacion Ebbinghaus (`EbbinghausEarTrainerBridge`):** Implementar en `lib/features/ear_training/domain/` el mapeo bidireccional entre los identificadores de `EbbinghausSpacedRepetitionEngine` (`interval_P1`, `interval_m2`, ..., `interval_P8`) y `MusicalInterval`, seleccionando los intervalos activos en orden de urgencia cognitiva (`getDueItems(now: now)` ordenado por menor `retentionAt(now)`).
2. **Integracion en `BlindEarTrainerEngine` y `BlindEarTrainerModal`:**
   - Permitir inyectar el intervalo prioritario o lista ponderada de intervalos vencidos al generar preguntas en `BlindEarTrainerEngine`.
   - Agregar en `BlindEarTrainerModal` el conmutador `Key('ear_trainer_ebbinghaus_adaptive_toggle')` (activado por defecto en modo adaptativo) y la insignia `Key('ear_trainer_due_count_badge')` con el conteo en vivo de intervalos pendientes de repaso.
   - Al responder cada estimulo, refrescar dinamicamente la cola de pendientes desde `widget.viewModel.ebbinghausEngine`.

---

## 3. Consecuencias

### 3.1 Positivas
- **Entrenamiento Auditivo Realmente Adaptativo:** El estudiante practica prioritariamente los intervalos cercanos al umbral de olvido ($R(t) \le 0.90$) en lugar de repetir intervalos ya consolidados.
- **Trazabilidad Completa en Memoria Persistente:** El progreso sobrevivira entre sesiones a traves de `earTrainingItemsJson` en `AppUserSettingsEntity`.

### 3.2 Compromisos y Mitigaciones
- **Modo Libre de Conservatorio:** El usuario puede desactivar `ear_trainer_ebbinghaus_adaptive_toggle` en cualquier momento para practicar el catalogo completo de forma uniforme. Si la cola vencida queda en `0`, el modo adaptativo realiza respaldo determinista sobre los 3 intervalos de menor retencion actual.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/ear_training/us_hc_07_ebbinghaus_adaptive_ear_trainer_bridge_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
