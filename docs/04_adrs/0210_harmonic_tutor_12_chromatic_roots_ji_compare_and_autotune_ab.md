# ADR 0210: 12 Tonicas Cromaticas en Tutor Armonico, Comparacion JI vs 12-TET y Bypass A/B en AutoTune

- **Estado:** Propuesto
- **Fecha:** 2026-11-26
- **Autor:** Nicolas Leon
- **Caso de Uso Relacionado:** [UC-218](../02_use_cases/218_uc_harmonic_tutor_12_chromatic_roots_ji_compare_and_autotune_ab.md)

---

## 1. Contexto

En `HarmonicTutorModal` (`lib/features/harmonic_tutor/presentation/harmonic_tutor_modal.dart`), la lista `_standardRoots` solo expone las 7 notas naturales (`Do`, `Re`, `Mi`, `Fa`, `Sol`, `La`, `Si`), omitiendo las 5 tonicas cromaticas con sostenido/bemol (`Do#/Reb`, `Re#/Mib`, `Fa#/Solb`, `Sol#/Lab`, `La#/Sib`), lo que restringe la practica de Entonacion Justa frente a tonalidades reales de orquesta y jazz. Asimismo, aunque `JustIntonationCalculator` (`lib/features/harmonic_tutor/domain/just_intonation_calculator.dart`) calcula `centsOffsetFromJi` y `centsOffsetFrom12Tet`, el usuario no dispone de un comparador explicito **JI vs 12-TET** para contrastar la diferencia en cents y audicionar ambas referencias. Por ultimo, `VocalAutoTuneModal` (`lib/features/vocal_autotune/presentation/vocal_autotune_modal.dart`) permite encender o apagar el motor (`autotune_master_toggle`), pero carece de un boton dedicado de **Comparacion A/B (Bypass Temporal)** que permita contrastar audio seco (A) frente a correccion tonal (B) sin alterar el estado de configuracion.

---

## 2. Decision

1. **Cobertura Cromatica Completa de 12 Tonicas en `HarmonicTutorModal`:**
   - Ampliar `_standardRoots` a los 12 grados cromaticos (`C4` a `B4`) calculados por $f_m = 440 \cdot 2^{(m-69)/12}$ con identificadores `Key('harmonic_tutor_root_chip_0')` .. `Key('harmonic_tutor_root_chip_11')`.
2. **Comparador Directo JI vs 12-TET en `HarmonicTutorViewModel` y Modal:**
   - Incorporar modo de comparacion en `HarmonicTutorViewModel` (`isComparing12Tet`, `toggleReferenceComparisonMode()`) y la tarjeta `Key('harmonic_tutor_comparison_card')` con conmutador `Key('harmonic_tutor_ji_vs_12tet_toggle')` que muestra $f_{\text{JI}}$, $f_{\text{12-TET}}$ y el desplazamiento $\Delta_{\text{JI}-\text{12TET}}$ en cents, ajustando la sintesis de referencia cuando esta activa la audicion comparativa.
3. **Conmutador A/B Bypass en `VocalAutoTuneModal`:**
   - Anadir `isBypassed` en `AutoTuneConfigEntity` / `TunerViewModel` y el boton `Key('autotune_ab_compare_btn')` en `VocalAutoTuneModal` para alternar instantaneamente entre `A: Original (Bypass)` y `B: AutoTune Procesado` tanto en monitoreo en vivo como en reproduccion de tomas multitrack.

---

## 3. Consecuencias

### 3.1 Positivas
- **Cumplimiento Pedagogico y Acustico (Regla 4.1):** Cobertura de las 12 tonalidades cromaticas sin exclusiones arbitrarias.
- **Audicion Critica A/B:** Cantantes e instrumentistas perciben con claridad tanto la pureza de la tercera/septima justa frente al 12-TET como el impacto exacto de la correccion vocal.

### 3.2 Compromisos y Mitigaciones
- **Claridad entre Apagado Global y Bypass A/B:** Cuando el interruptor maestro `autotune_master_toggle` esta en `false`, `autotune_ab_compare_btn` indica estado inactivo o habilita la comparacion de referencia sin perder `retuneSpeedMs` ni la escala elegida.

---

## 4. Verificacion

- Suite automatizada planificada: `test/features/harmonic_tutor/us_ux_18_chromatic_roots_ji_compare_and_autotune_ab_test.dart`.
- Analisis estatico objetivo: `flutter analyze --no-fatal-infos` con `0 issues`.
