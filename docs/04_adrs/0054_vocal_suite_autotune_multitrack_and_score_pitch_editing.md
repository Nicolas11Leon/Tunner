# ADR 0054: Arquitectura de la Suite Vocal con Auto-Tune en Tiempo Real, Grabación Multitrack y Edición Microtonal en Pentagrama

## Estado
Aprobado (Approved) - 2026-11-10

## Contexto
Actualmente, las funciones de Auto-Tune (`vocal_autotune`), Grabación Multipista (`practice_recorder`), Edición de Partituras (`score_editor`) y Síntesis SoundFont (`audio_synthesizer`) funcionan de forma aislada. Cuando un vocalista canta y graba, no dispone de un puente directo que traslade su toma grabada (con sus alturas reales y corregidas por el Auto-Tune) a un pentagrama interactivo tipo Melodyne para inspeccionar y corregir notas desafinadas, re-alinearlas a la escala modal y escucharlas de inmediato con síntesis de alta fidelidad.

## Decisión
1. **Extensión del Modelo de Muestras de Grabación (`MultiTrackSample`):**
   - Incorporar campos opcionales `correctedPitchHz`, `centsDeviation` y `isAutoTuned` sin romper la compatibilidad regresiva.
2. **Creación del Servicio de Dominio Puro `VocalScoreConverter`:**
   - Ubicado en `lib/features/vocal_autotune/domain/vocal_score_converter.dart`.
   - Transforma series temporales continuas de muestras vocales en notas discretas (`HierarchicalNote` estructuradas en compases `Measure`) con cuantización rítmica a semicorcheas y preservación de la desviación media en cents original.
3. **Orquestación en `TunerViewModel`:**
   - Método `convertActiveRecordingToScorePackage()` que toma la grabación activa de `practice_recorder` y genera un `SongPackage` vocal listo para inspección en el `ScoreEditor` o en la vista de partituras.
   - Acción directa de corrección y cuantización a la escala activa (`snapVocalNotesToScale()`).
   - Reproducción acústica directa mediante el patch vocal de SoundFont (GM Patch 54 "Voice Oohs" o sintetizador seleccionado).
4. **Componente de UI Atómico y Acción en Dock de Grabación:**
   - Botón `"Editar Afinación en Pentagrama"` en el reproductor de tomas grabadas (`PracticeRecordingPlayerModal`) y en el panel de Auto-Tune (`VocalAutoTuneModal`).

## Consecuencias

### Positivas
- **Flujo de Producción y Pedagogía Vocal Unificado:** Ofrece una experiencia al nivel de estaciones de trabajo de audio digital profesionales (Melodyne/AutoTune/Logic) 100% offline y gratuita.
- **Transparencia en el Aprendizaje Vocal:** Los cantantes ven con precisión científica dónde desafinaron y cómo la escala modal teórica resuelve la melodía.
- **Reutilización y Cero Duplicación:** Se aprovechan directamente las estructuras canónicas del `ScoreTree`, `ScoreEditor` y `SoundFontSynthesizerService`.

### Negativas / Mitigaciones
- **Fragmentación por Vibrato Natural:** Un vibrato vocal amplio puede fragmentarse en múltiples semitonos adyacentes. *Mitigación:* `VocalScoreConverter` aplica un filtro de histéresis temporal y suavizado de ventana móvil ($\approx 80\text{ ms}$) antes de emitir onsets de notas.
