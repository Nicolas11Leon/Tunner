# ADR 0200: Generacion de Ejercicios Remediales desde Notas Criticas del Reporte de Practica

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-208](../02_use_cases/208_uc_remedial_drill_generation_from_practice_report_critical_notes.md)

---

## 1. Contexto

`PracticeReportModal` (`lib/features/practice_evaluator/presentation/practice_report_modal.dart`) presenta el analisis multidimensional de `PracticeReportEntity` (`lib/features/practice_evaluator/domain/practice_report_entity.dart`), destacando explicitamente `report.criticalNotes` y su porcentaje de acierto en `report.noteAccuracyMap`. Por otro lado, `AlgorithmicExerciseGenerator` (`lib/features/exercise_generator/domain/algorithmic_exercise_generator.dart`) genera paquetes `SongPackage` de escalas, arpegios y notas largas de forma aislada, sin aprovechar los datos de diagnostico de `PracticeReportEntity` para prescribir practica correctiva automatica.

---

## 2. Decision

1. **Generador Remedial Determinista en Pure Dart:** Extender `AlgorithmicExerciseGenerator` con `generateRemedialDrillFromCriticalNotes({required List<String> criticalNotes, Map<String, double>? noteAccuracyMap, int bpm = 72})`, el cual:
   - Ordena `criticalNotes` por menor porcentaje de precision en `noteAccuracyMap` (preservando el orden de entrada en empates).
   - Normaliza cada nota mediante `CanonicalPitchNotationCodec.parseOrDefault`.
   - Construye compases en $4/4$ (`TimeSignature.commonTime44`, 16 ticks por compas) alternando la nota critica en blanca sostenida con notas vecinas de aproximacion cromatica/diatonica para estabilizar embocadura y digitacion, retornando un `SongPackage` completo.
2. **Disparador en 1 Clic desde `PracticeReportModal`:** Cuando `report.criticalNotes.isNotEmpty`, renderizar el boton `Key('report_generate_remedial_drill_btn')` junto a los chips de notas criticas para generar el `SongPackage` remedial, cargarlo en `TunerViewModel.loadSongPackage(...)` y cerrar el modal listo para practicar.

---

## 3. Consecuencias

### 3.1 Positivas
- **Retroalimentacion Pedagogica Accionable:** Convierte un reporte pasivo de errores en un plan de correccion inmediato en menos de 1 segundo, sin configuracion manual.
- **Determinismo Matematico:** La misma lista de `criticalNotes` y `noteAccuracyMap` produce siempre exactamente el mismo `HierarchicalScore`.

### 3.2 Compromisos y Mitigaciones
- **Modal Desacoplado de `Provider`:** `PracticeReportModal` recibe opcionalmente un callback `onGenerateRemedialDrill` (o lee `TunerViewModel` de forma segura) para mantener compatibilidad con pruebas unitarias aisladas de `PracticeReportModal`.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/practice_evaluator/us_hc_06_remedial_drill_from_critical_notes_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
