# Implementation Plan: Phase 2 Professional High-Precision Metronome & Italian Tempo Scales

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-PRO-METRONOME-2026-007`
- **Título de la Implementación:** `Metrónomo Profesional de Alta Precisión con Escalas Italianas y Rango 20-300 BPM`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `N/A`
- **Documento Funcional Base:** `docs/01_product_vision/doc_audio_high_res_pro_metronome.md` y `docs/02_use_cases/02_uc_high_res_audio_clock.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Extender las capacidades de temporización rítmica de **Tunner** incorporando una entidad de dominio pura para marcas de tempo italianas (`TempoMark`), ampliando el rango dinámico de trabajo de 20 a 300 BPM, y optimizando el `MetronomeService` y `TunerViewModel` para admitir ajustes de precisión milimétrica ($\pm 1$ BPM) con respuesta visual y cero desincronización de reloj.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio pura `lib/domain/tempo_entity.dart` con resolución de términos italianos estándar (*Larghissimo* a *Prestissimo*).
  - Pruebas unitarias de dominio completas en `test/domain/tempo_entity_test.dart`.
  - Actualización de rango en `TunerViewModel` ($20 \le \text{BPM} \le 300$) y métodos de ajuste incremental fino.
  - Actualización del slider y controles de tempo en `TunerScreen` mostrando el término italiano reactivo y botones de ajuste fino.
- **Excluido (Out-of-Scope):**
  - Clics de audio con muestras SF2 de percusión orquestal múltiple (reservado para Fase 3).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`.
- **Flutter Framework:** UI reactiva vía `ChangeNotifier` y `CustomPainter`.
- **Riesgo Tecnológico:** **Nulo**. Lógica matemática pura y widgets estándar sin nuevas dependencias externas.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Entidad Pura de Tempo y Escalas Italianas)
- [x] Crear `lib/domain/tempo_entity.dart` con la clase `TempoMark` y el resolvedor canónico `TempoMark.fromBpm(int bpm)`.
- [x] Crear pruebas unitarias exhaustivas en `test/domain/tempo_entity_test.dart`.

### Paso 2: Capa de Infraestructura / ViewModel
- [x] Ampliar el clamping de BPM en `TunerViewModel` de `[40, 200]` a `[20, 300]`.
- [x] Agregar métodos de ajuste fino `incrementBpm()` y `decrementBpm()`.
- [x] Exponer `currentTempoMark` derivado de forma reactiva.

### Paso 3: Capa de Presentación (UI de Metrónomo Pro en `TunerScreen`)
- [x] Desplegar el nombre italiano (*Andante*, *Allegro*, etc.) estilizado con tipografía elegante.
- [x] Agregar botones de paso fino ($\pm 1$) al lado del selector de tempo.
- [x] Ajustar el `Slider` para el rango 20 a 300 con feedback háptico/visual.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecutar `flutter test` verificando que todos los tests pasen.
- [x] Ejecutar `flutter analyze` confirmando 0 advertencias o errores.

---

## 4. Estrategia de Rollback

- Revertir al commit `6ebcdd6` en caso de anomalías en el reloj o renderizado.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Rango completo de 20 a 300 BPM operativo sin fallos.
- [x] Términos italianos desplegados exactamente según la escala internacional.
- [x] 100% de tests unitarios pasando.
