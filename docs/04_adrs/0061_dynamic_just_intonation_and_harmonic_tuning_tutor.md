# ADR 0061: Tutor de Afinación Justa Dinámica, Rol Armónico y Cancelación de Batimientos

## Estado
Aprobado (Approved) - 2026-11-13

## Contexto
El afinador cromático convencional de Tunner opera bajo la escala temperada igual de doce tonos (12-TET). Sin embargo, en el ámbito de la interpretación orquestal, ensambles de cámara (cuartetos de cuerdas, quintetos de metales) y coro, el temperamento igual genera fricciones acústicas y batimientos armónicos perceptibles (ej. tercera mayor $+13.69\text{ cents}$ alta, tercera menor $-15.64\text{ cents}$ baja, séptima armónica $-31.17\text{ cents}$ baja).

Los músicos de conservatorio aprenden a entonar de manera adaptativa según el rol armónico de su nota dentro del acorde que suena en el ensamble (entonación justa o Just Intonation de límite 5 y límite 7). No existía en la plataforma una herramienta pedagógica interactiva que:
1. Detectara automáticamente el rol funcional de la nota captada respecto a una fundamental o acorde guía.
2. Derivara la frecuencia pura diana ($f_{\text{JI}}$) y su desviación microtonal ($\Delta c_{\text{JI}}$).
3. Calculara y visualizara la velocidad física del batimiento acústico ($f_{\text{beat}}$) para guiar el ajuste de la embocadura o posición en el diapasón.
4. Generara drones de referencia armónica pura para entrenamiento auditivo sin batimientos.

## Decisión
1. **Capa de Dominio (`lib/features/harmonic_tutor/domain/`):**
   - **`HarmonicRoleEntity`:** Enumeración y entidad inmutable de los 12 roles interválicos modulares con sus ratios enteros irreducibles ($p/q$), fórmula de batimiento primario y desviación canónica en cents respecto a 12-TET.
   - **`JustIntonationCalculator`:** Motor de cálculo acústico puro en Dart que determina el rol armónico $\Delta s = (M_{\text{user}} - M_{\text{root}}) \pmod{12}$, la diana $f_{\text{target}} = f_{\text{root}} \cdot 2^k \cdot (p/q)$, la desviación en cents $\Delta c_{\text{JI}} = 1200 \cdot \log_2(f_{\text{user}} / f_{\text{target}})$ y la tasa de batimiento $f_{\text{beat}} = |p \cdot f_{\text{root}} - q \cdot f_{\text{user}}|$.
   - **`HarmonicTutorSessionEntity`:** Estado reactivo de la sesión de afinación (fundamental seleccionada, tipo de acorde, nota detectada, rol armónico deducido, estado de consonancia y tasa de batimiento).
2. **Capa de Datos e Infraestructura (`lib/features/harmonic_tutor/data/`):**
   - **`HarmonicReferenceSynth`:** Sintetizador procedural en memoria para acordes de referencia pura (fundamental + quinta justa $3/2$ + tercera opcional) utilizando osciladores senoidales sin aliasing y envolvente suave de atenuación para evitar clics acústicos.
3. **Capa de Presentación (`lib/features/harmonic_tutor/presentation/`):**
   - **`HarmonicTutorViewModel`:** ViewModel con `ChangeNotifier` que conecta el flujo continuo del detector de tono con el calculador de afinación justa y el sintetizador de referencia.
   - **`HarmonicBeatGauge`:** Widget gráfico con `CustomPainter` que renderiza una aguja dinámica cuya oscilación física replica la tasa de batimiento real $f_{\text{beat}}$, tornándose verde y estática cuando se alcanza la consonancia perfecta ($\le 3.0\text{ cents}$).
   - **`HarmonicTutorModal`:** Modal de conservatorio para entrenamiento interactivo con selectores de fundamental, cualidad de acorde y botón de activación de drone armónico.

## Consecuencias

### Positivas
- **Avance Pedagógico de Grado Conservatorio:** Dota a estudiantes y profesionales de una herramienta única para entrenar el oído y la técnica de entonación pura de cámara.
- **Rigor Matemático y Físico Absoluto:** Todo el cálculo se basa en las relaciones armónicas de Pitágoras, Zarlino y Euler sin números mágicos arbitrarios.
- **Rendimiento de Ultra Baja Latencia:** Algoritmo en Dart puro con tiempo de cómputo $< 0.1\text{ ms}$, compatible con el objetivo de latencia sub-10ms.

### Negativas / Mitigaciones
- **Complejidad Conceptual para Principiantes:** Conceptos como "afinar una tercera mayor 14 cents más baja que el afinador" pueden confundir a usuarios novatos.
  *Mitigación:* Se implementa un panel de ayuda contextual y descripciones claras de rol armónico ("Tercera Mayor: Tocar más bajo para eliminar batimiento").
