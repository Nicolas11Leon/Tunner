# Dynamic Just Intonation and Adaptive Harmonic Tuning Tutor

Documento de visión de producto y arquitectura técnica para el sistema de entonación armónica pura adaptativa y tutor de afinación justa de **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-067`
- **Título Oficial:** Tutor de Afinación Justa Dinámica, Rol Armónico en Tiempo Real y Cancelación de Batimientos Acústicos
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-13`
- **Última Modificación:** `2026-11-13`
- **Fase Asociada:** `Fase 2 (Suites Sinergéticas y Multitarea Profesional)`
- **Autor / Revisor Principal:** `Nicolás León / Tunner Architecture Team`

---

## 1. Resumen Ejecutivo (Executive Summary)

El **Tutor de Afinación Justa Dinámica** (*Dynamic Just Intonation & Adaptive Harmonic Tuning Tutor*) es una herramienta de pedagogía auditiva y acústica de conservatorio diseñada para resolver una de las mayores deficiencias del software musical contemporáneo: la fijación ciega en el temperamento igual de 12 tonos (12-TET).

Aunque el 12-TET es el compromiso universal para instrumentos de afinación fija (pianos, sintetizadores), en ensambles corales, cuartetos de cuerdas, secciones de metales y orquestas sinfónicas los músicos ajustan microtonalmente su afinación en función de su rol armónico respecto a la fundamental activa del acorde. En 12-TET, las terceras mayores son ásperas por estar $+13.69\text{ cents}$ altas respecto al ratio puro $5/4$, las terceras menores están $-15.64\text{ cents}$ bajas respecto al ratio $6/5$, y las séptimas dominantes están $+31.17\text{ cents}$ altas frente a la séptima armónica pura $7/4$.

Este módulo calcula en tiempo real el rol armónico de la nota captada por el micrófono respecto a un acorde o fundamental guía, deriva la frecuencia diana de afinación justa ($f_{\text{JI}}$), computa la desviación exacta en cents ($\Delta c_{\text{JI}}$), cuantifica la frecuencia de batimiento acústico ($f_{\text{beat}}$) y guía visual y auditivamente al músico para anular las fricciones de fase ($f_{\text{beat}} \to 0\text{ Hz}$) alcanzando una consonancia acústica perfecta.

---

## 2. Contexto del Problema y Fundamento Acústico

### 2.1 Limitaciones del Temperamento Igual en Ensambles
En la música de cámara y vocal, un acorde mayor ejecutado según afinador 12-TET estándar produce una sensación de aspereza e inestabilidad debido a la colisión de los armónicos superiores:
- El 5to armónico de la fundamental ($5 \cdot f_0$) no coincide con el 4to armónico de la tercera mayor temperada ($4 \cdot f_{\text{3ra}}$).
- Esta diferencia genera un fenómeno de modulación de amplitud conocido como **batimiento acústico** (*acoustic beat*):
  $$f_{\text{beat}} = |4 \cdot f_{\text{3ra}} - 5 \cdot f_0|$$
- En una tríada de Do Mayor ($C_4 = 261.63\text{ Hz}$), la tercera temperada $E_4$ vibra a $329.63\text{ Hz}$. La colisión armónica ocurre a:
  $$|4 \cdot 329.63 - 5 \cdot 261.63| = |1318.52 - 1308.15| \approx 10.37\text{ Hz}$$
- Este batimiento de $\approx 10.4\text{ Hz}$ es percibido por el oído humano como una vibración desagradable y disonante.

### 2.2 Formulación de Afinación Justa de Límite 5 y Límite 7
Para anular el batimiento, la tercera mayor debe ejecutarse a la frecuencia pura:
$$f_{\text{JI}} = \frac{5}{4} f_0 = 1.25 \cdot 261.63\text{ Hz} = 327.0375\text{ Hz}$$
La desviación respecto al temperamento igual es:
$$\Delta c = 1200 \cdot \log_2\left(\frac{5/4}{2^{4/12}}\right) = 1200 \cdot \log_2\left(\frac{1.25}{1.259921}\right) \approx -13.686\text{ cents}$$

### 2.3 Matriz Canónica de Ratios y Desviaciones Armónicas

| Intervalo / Rol Armónico | Semitonos 12-TET | Ratio Justo ($p/q$) | Cents Justos | Offset respecto a 12-TET | Batimiento Primario ($p \cdot f_0 - q \cdot f$) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Fundamental (Root)** | 0 | $1/1$ | $0.00\text{ c}$ | $0.00\text{ c}$ | $0\text{ Hz}$ |
| **Segunda Menor** | 1 | $16/15$ | $111.73\text{ c}$ | $+11.73\text{ c}$ | $\|16 f_0 - 15 f\|$ |
| **Segunda Mayor** | 2 | $9/8$ | $203.91\text{ c}$ | $+3.91\text{ c}$ | $\|9 f_0 - 8 f\|$ |
| **Tercera Menor** | 3 | $6/5$ | $315.64\text{ c}$ | $+15.64\text{ c}$ | $\|6 f_0 - 5 f\|$ |
| **Tercera Mayor** | 4 | $5/4$ | $386.31\text{ c}$ | $-13.69\text{ c}$ | $\|5 f_0 - 4 f\|$ |
| **Cuarta Justa** | 5 | $4/3$ | $498.04\text{ c}$ | $-1.96\text{ c}$ | $\|4 f_0 - 3 f\|$ |
| **Tritono (Sub-séptima)** | 6 | $7/5$ | $582.51\text{ c}$ | $-17.49\text{ c}$ | $\|7 f_0 - 5 f\|$ |
| **Quinta Justa** | 7 | $3/2$ | $701.96\text{ c}$ | $+1.96\text{ c}$ | $\|3 f_0 - 2 f\|$ |
| **Sexta Menor** | 8 | $8/5$ | $813.69\text{ c}$ | $+13.69\text{ c}$ | $\|8 f_0 - 5 f\|$ |
| **Sexta Mayor** | 9 | $5/3$ | $884.36\text{ c}$ | $-15.64\text{ c}$ | $\|5 f_0 - 3 f\|$ |
| **Séptima Armónica (7ma Dominante)** | 10 | $7/4$ | $968.83\text{ c}$ | $-31.17\text{ c}$ | $\|7 f_0 - 4 f\|$ |
| **Séptima Menor Justa (5-Limit)** | 10 | $9/5$ | $1017.60\text{ c}$ | $+17.60\text{ c}$ | $\|9 f_0 - 5 f\|$ |
| **Séptima Mayor** | 11 | $15/8$ | $1088.27\text{ c}$ | $-11.73\text{ c}$ | $\|15 f_0 - 8 f\|$ |

---

## 3. Especificación Funcional

### 3.1 Identificación Dinámica del Rol Armónico
- El usuario selecciona una fundamental o un acorde activo (e.g. Do Mayor, Sol Dominante, La menor) o el sistema lo sincroniza desde la partitura activa o el analizador polifónico.
- Al captar la nota del usuario ($f_{\text{user}}$), el motor calcula su distancia interválica en semitonos modulares $\Delta s = (M_{\text{user}} - M_{\text{root}}) \pmod{12}$.
- Determina el rol funcional dentro del contexto tonal (e.g. "Tercera Mayor de Do Mayor").

### 3.2 Cuantificación del Error Microtonal y Tasa de Batimiento
- Calcula la frecuencia objetivo pura $f_{\text{target\_JI}} = f_{\text{root}} \cdot 2^k \cdot \text{ratio}(\Delta s)$.
- Calcula la desviación $\Delta c_{\text{JI}} = 1200 \cdot \log_2(f_{\text{user}} / f_{\text{target\_JI}})$.
- Calcula la tasa de batimiento acústico instantánea $f_{\text{beat}}$ en Hertz.
- Clasifica el estado acústico en 3 bandas:
  1. **Lock Armónico Puro:** $|\Delta c_{\text{JI}}| \le 3.0\text{ cents}$ ($f_{\text{beat}} < 0.5\text{ Hz}$). Consonancia estricta de conservatorio.
  2. **Zona de Ajuste:** $3.0 < |\Delta c_{\text{JI}}| \le 12.0\text{ cents}$. Batimiento audible moderado.
  3. **Fricción / Disonancia:** $|\Delta c_{\text{JI}}| > 12.0\text{ cents}$. Batimiento rápido o fuera de entonación armónica.

### 3.3 Generador de Ensamble de Referencia Acústica (Drone Armónico Puro)
- Permite sintetizar de fondo la fundamental pura y la quinta (o la tríada completa) con generador de ondas senoidales multicapa puro sin aliasing.
- Al cantar o tocar sobre el drone, el estudiante escucha físicamente cómo el batimiento disminuye de velocidad hasta desaparecer por completo cuando ajusta su entonación a la diana justa.

---

## 4. Arquitectura de Software y Capas

1. **Capa de Dominio (`lib/features/harmonic_tutor/domain/`):**
   - `harmonic_role_entity.dart`: Tipificación inmutable de los 12 roles armónicos con sus ratios fraccionarios enteros irreducibles $(p/q)$ y desviaciones canónicas.
   - `just_intonation_calculator.dart`: Funciones puras para cómputo de cents, frecuencia pura y tasa de batimiento.
   - `harmonic_tutor_session_entity.dart`: Estado reactivo de la sesión de afinación armónica (fundamental, acorde, rol detectado, batimiento, score de consonancia).
2. **Capa de Infraestructura / Datos (`lib/features/harmonic_tutor/data/`):**
   - `harmonic_reference_synth.dart`: Síntesis local determinista en memoria de acordes de referencia con osciladores puros y rampa anti-pop.
3. **Capa de Presentación (`lib/features/harmonic_tutor/presentation/`):**
   - `harmonic_tutor_view_model.dart`: Orquestador reactivo con `ChangeNotifier`.
   - `harmonic_tutor_modal.dart`: Diálogo modal de práctica con indicador visual de batimiento, medidor de rol armónico y selector de acorde guía.
   - `harmonic_beat_gauge.dart`: Widget CustomPainter con aguja y animación reactiva que desacelera cuando el batimiento tiende a cero.

---

## 5. Criterios de Calidad y Rendimiento

- **Tiempo de Respuesta:** Cómputo matemático en $\le 0.1\text{ ms}$ por muestra analizada.
- **Cero Bucles Busy-Waiting:** El oscilador y el renderizado se sincronizan con los ticks de audio y frames de Flutter.
- **Aislamiento Total:** Dominio 100% puro en Dart sin dependencias de UI.
- **Cero Emojis:** Cumplimiento total de la regla de redacción técnica formal de Tunner.
