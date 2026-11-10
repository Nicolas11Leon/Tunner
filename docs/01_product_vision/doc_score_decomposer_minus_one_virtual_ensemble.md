# Documento Tecnico: Descomponedor de Partituras, Ensamble Virtual "Minus-One" y Mezclador de Stems

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-061`
- **Título Oficial:** Arquitectura del Ensamble Virtual Minus-One, Descomposición de Partituras Multitrack y Evaluación Acústica en Vivo
- **Estado:** Approved
- **Fecha de Creación:** 2026-11-10
- **Última Modificación:** 2026-11-10
- **Fase Asociada:** Fase 2 (Suites Sinérgicas Multi-Herramienta)
- **Autor / Revisor Principal:** Nicolas Leon / Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo (Executive Summary)

Este documento especifica la arquitectura del Ecosistema 3 de Tunner: la integración sinérgica entre la biblioteca de canciones descompuestas (`song_library` / `song_decomposer`), la consola de mezcla multicanal (`mixer`), el sintetizador de tablas de ondas SoundFont SF2 (`audio_synthesizer`) y el evaluador pedagógico multidimensional (`practice_evaluator`).

El sistema permite descomponer una obra polifónica en stems individuales, silenciar automáticamente la pista correspondiente al instrumento activo del músico (concepto pedagógico canónico de "Minus-One" o Music Minus One), sintetizar el acompañamiento orquestal/camarístico restante con timbres SoundFont de alta fidelidad, captar la ejecución en vivo mediante micrófono con el detector McLeod Pitch Method (MPM), evaluar la afinación y el timing métrico (rushing vs dragging) contra la partitura silenciada, y permitir el balance de la mezcla final resultante.

---

## 2. Contexto del Problema y Justificacion Teorica

### 2.1 Planteamiento del Problema
En la pedagogía musical tradicional de conservatorio, la práctica individual carece del contexto polifónico y rítmico que proporciona un ensamble real o un pianista acompañante. Tocar sobre una pista de audio pregrabada rígida presenta limitaciones severas:
1. El estudiante no puede aislar, silenciar o modificar el volumen de voces intermedias críticas (e.g. bajo continuo, violonchelo, segunda voz).
2. Si el instrumento solista está pregrabado en la pista, el estudiante tiende a mimetizarlo pasivamente sin desarrollar afinación intencional ni tempo interno.
3. No existe correlación algorítmica entre la partitura vectorial leída y la señal captada por el micrófono durante el acompañamiento.

### 2.2 Fundamento Acustico y Pedagogico
El concepto "Music Minus One" (MMO) resuelve este desafío al proveer una orquestación completa donde se extirpa exactamente la voz que el estudiante interpreta:

1. **Aislamiento de la Voz de Estudio ($V_{\text{target}}$):**
   Dada una obra polifónica compuesta por un conjunto de pistas discretas $T = \{t_1, t_2, \dots, t_N\}$, el sistema define el subconjunto de acompañamiento audible $T_{\text{acc}}$ mediante la exclusión de la pista objetivo:
   $$T_{\text{acc}} = T \setminus \{t_{\text{user}}\}$$
   donde la ganancia efectiva del canal silenciado es $\text{gain}(t_{\text{user}}) = 0.0$.

2. **Sincronización Rítmica y Sub-Ticks Deterministas:**
   El motor de metrónomo genera pulsos maestros a $B\text{ BPM}$ con una resolución temporal de 16 sub-ticks por compás en compases cuaternarios ($4/4$):
   $$\Delta t_{\text{tick}} = \frac{60\,000}{B \cdot 4}\text{ ms}$$
   Cada nota de acompañamiento se despacha al sintetizador SoundFont con latencia determinista $\le 5\text{ ms}$, garantizando la sincronía vertical de los acordes de fondo.

3. **Evaluación Acústica Concurrente:**
   La fundamental detectada en el micrófono ($f_{\text{det}}$) se compara en cents contra la frecuencia nominal esperada ($f_{\text{expected}}$) de la nota presente en la pista $t_{\text{user}}$ en el sub-tick actual:
   $$\Delta \text{cents} = 1200 \cdot \log_2\left(\frac{f_{\text{det}}}{f_{\text{expected}}}\right)$$
   El desfase métrico $\Delta t = t_{\text{onset}} - t_{\text{grid}}$ clasifica el ataque rítmico en tres estados: Rushing ($\Delta t < -15\text{ ms}$), In-Pocket ($|\Delta t| \le 15\text{ ms}$) o Dragging ($\Delta t > +15\text{ ms}$).

---

## 3. Especificacion Funcional Detallada

### 3.1 Requerimientos del Sistema
- **REQ-01 (Detección y Asignación de Pista Objetivo):** El sistema debe identificar automáticamente la pista del `SongPackage` cuyo identificador de instrumento coincide con el instrumento activo seleccionado en el afinador, o permitir la selección manual por el usuario.
- **REQ-02 (Silenciamiento Automático Minus-One):** Al activar el modo Minus-One, la consola de mezcla (`MixerConsoleEntity`) debe poner en mute (`isMuted: true`) la pista del usuario y mantener activos los stems de acompañamiento y el metrónomo.
- **REQ-03 (Síntesis de Acompañamiento):** Las pistas restantes deben ser renderizadas en tiempo real mediante el sintetizador procedural / SoundFont SF2 según los patches General MIDI correspondientes.
- **REQ-04 (Evaluación Concurrente de Interpretación):** La señal del micrófono debe ser evaluada nota por nota contra las notas del pentagrama de la pista silenciada, registrando precisión tonal ($\pm\text{cents}$) y desvío rítmico ($\text{ms}$).
- **REQ-05 (Consola de Balance y Post-Escucha):** Al finalizar la sesión, el usuario debe poder reproducir la toma grabada junto con los stems de acompañamiento ajustando libremente los faders de volumen.

### 3.2 Casos de Borde y Condiciones de Error
- **Obra con Pista Única:** Si el paquete solo contiene una pista melódica, el sistema debe advertir que el modo Minus-One se ejecutará con acompañamiento exclusivo de metrónomo.
- **Transposición de Instrumento:** Si el instrumento del usuario es transpositor (e.g. Clarinete en Si bemol, Trompeta en Si bemol, Corno en Fa), la nota esperada para la evaluación acústica debe considerar la transposición de concierto automáticamente.
- **Filtrado de Sangrado Acústico (Acoustic Bleed):** Cuando los stems de acompañamiento suenan por los altavoces del dispositivo, el supresor de eco acústico (`AcousticEchoSuppressor`) debe atenuar la correlación de la señal de salida para evitar que los acordes de fondo falseen la detección MPM de la voz del usuario.

---

## 4. Diseno Tecnico y Arquitectura de la Solucion

### 4.1 Capa de Dominio (Domain Layer)
- **`MinusOneSessionEntity`:** Entidad inmutable que encapsula el estado de la sesión Minus-One:
  - `String songId`: Identificador de la obra.
  - `String userTrackId`: Pista del instrumento asignada al usuario.
  - `bool isMinusOneActive`: Estado de activación.
  - `bool isMutedUserTrack`: Silenciamiento de la pista de usuario.
  - `List<NoteEvaluationEntity> evaluations`: Evaluaciones registradas en vivo.
- **`MinusOneOrchestrator`:** Servicio puro de dominio que contiene la lógica matemática para:
  - Configurar consolas de mezcla en modo Minus-One.
  - Resolver el mapeo de transposición entre la partitura y la frecuencia acústica real.
  - Compilar el reporte de desempeño final de la sesión.

### 4.2 Capa de Presentacion (Presentation Layer)
- **Controles en `SongDecomposerModal`:**
  - Selector de pista de usuario ("Tu Instrumento").
  - Interruptor maestro de "Modo Minus-One".
  - Faders individuales de volumen para cada stem y el metrónomo.
  - Botón de transporte para iniciar la sesión de práctica evaluada.
- **Integración en `TunerViewModel`:**
  - Métodos reactivos: `toggleMinusOneMode()`, `setUserTrackForMinusOne(String trackId)`, `startMinusOneEvaluation()`, `stopMinusOneEvaluation()`.

---

## 5. Criterios de Aceptacion y Verificacion

1. **Pruebas Unitarias:**
   - Creación y mutación inmutable de `MinusOneSessionEntity`.
   - Lógica de silenciamiento selectivo de la pista del usuario en `MixerConsoleEntity`.
   - Evaluación precisa de notas acústicas en presencia de transposición.
2. **Pruebas de Widgets e Integración:**
   - Renderizado del interruptor Minus-One en el modal del descomponedor.
   - Verificación de que la pista seleccionada queda muteada visual y funcionalmente en la consola de mezcla.
   - Ejecución de la suite completa con 100% de pruebas aprobadas y 0 lints en `flutter analyze`.
