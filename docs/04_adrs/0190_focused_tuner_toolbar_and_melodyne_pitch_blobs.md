# ADR 0190: Reduccion de Entropia Visual en Afinador Pro y Tira de Contorno Tonal por Blobs estilo Melodyne

- **Estado:** Aprobado
- **Fecha:** 2026-11-25
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-198](../02_use_cases/198_uc_focused_tuner_toolbar_and_melodyne_pitch_blobs.md)

---

## 1. Contexto

La auditoria ergonomica de `TunerScreen` en modo `conservatoryPro` identifico dos puntos de friccion: (1) una barra superior con 19 acciones horizontales planas que incrementaba el tiempo de busqueda visual segun la Ley de Hick-Hyman ($RT = a + b \log_2(n + 1)$), y (2) la ausencia de una representacion visual temporal de las notas ejecutadas como objetos fisicos sobre una cuadricula tonal con deriva interna (*pitch drift* y vibrato) al estilo de **Celemony Melodyne 5**.

---

## 2. Decision

1. **Widget `PitchContourBlobStripWidget` (`lib/features/tuner/presentation/widgets/pitch_contour_blob_strip_widget.dart`):** Implementar un lienzo a 60 FPS (`Key('melodyne_pitch_contour_blob_strip')`) gobernado por `MelodynePitchBlobPainter` que renderiza:
   - Cuadricula tonal con centro ideal ($0	ext{ cents}$) y bandas de tolerancia ($\pm 15	ext{ cents}$, $\pm 50	ext{ cents}$).
   - Marco fantasma de intencion tonal (*Intended Note Target Frame*).
   - Historial deslizante de hasta 24 *Pitch Blobs* coloreados semanticamente (**Verde Esmeralda** $|\Delta c| \le 15$, **Ambar** $15 < |\Delta c| \le 35$, **Rojo Coral** $> 35$) con curva interna de micro-entonacion y boton `Key('btn_clear_pitch_blobs')`.
2. **Agrupacion Ergonomica en `TunerScreen` (`lib/features/tuner/presentation/tuner_screen.dart`):** Incorporar el conmutador `Key('tuner_toggle_melodyne_blobs_btn')` en la barra persistente Pro y el menu categorizado de baja entropia `Key('tuner_ergonomic_quick_tools_menu_btn')` (`Herramientas Rapidas DSP`), preservando todas las llaves existentes para retrocompatibilidad total.

---

## 3. Consecuencias

### 3.1 Positivas
- **Diagnostico Visual Instantaneo de Ataque y Fiato:** El estudiante observa no solo el valor instantaneo en Hz, sino la evolucion temporal de cada nota como un blob con su curva de deriva interna.
- **Reduccion de Tiempo de Busqueda Cognitiva:** El menu agrupador organiza las herramientas secundarias en categorias semanticas sin saturar la vista primaria.

### 3.2 Compromisos y Mitigaciones
- **Consumo de Memoria Determinista:** La cola de blobs esta acotada estrictamente a un maximo fijo de 24 muestras (`maxSamples = 24`), evitando crecimiento de memoria en sesiones prolongadas.

---

## 4. Verificacion

- Suite automatizada: `test/features/tuner/us_ux_06_focused_tuner_and_melodyne_blobs_test.dart`.
- Analisis estatico: `flutter analyze --no-fatal-infos` con `0 issues`.
