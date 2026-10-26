# Roadmap and Phases: The Phase-Gate Architecture

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ROADMAP-2026-002`
- **Título Oficial:** `Hoja de Ruta por Fases y Criterios de Aceptación (DoD): Tunner`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-10-19`
- **Última Modificación:** `2026-10-19`
- **Fase Asociada:** `Global`
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Resumen Ejecutivo (Executive Summary)

Este documento define la estructura de entrega secuencial del proyecto **Tunner** bajo el modelo de compuertas de fase (*Phase-Gate Model*). Con el fin de evitar la acumulación de deuda técnica y garantizar una base acústica y de software inquebrantable, ninguna fase podrá considerarse iniciada hasta que la fase predecesora haya satisfecho formalmente su respectiva *Definition of Done (DoD)*.

---

## 2. Definición del Modelo de Compuertas (Phase-Gate Policy)

```mermaid
graph LR
    P1["Fase 1: Núcleo Acústico & Audio Clock"] -->|DoD 1 Aprobada| P2["Fase 2: Motor de Partituras Dinámicas"]
    P2 -->|DoD 2 Aprobada| P3["Fase 3: Síntesis & Entrenamiento Auditivo"]
    P3 -->|DoD 3 Aprobada| P4["Fase 4: Descomposición & Universalidad"]
```

### Reglas de Compuerta
1. **Inmutabilidad de la Compuerta:** No se escribirán líneas de código funcional de una fase posterior mientras la fase actual presente pruebas fallidas, documentación desactualizada o deuda de rendimiento.
2. **Registro de Decisiones (ADRs):** Cada fase debe incorporar sus ADRs en `docs/04_adrs/` antes de realizar merge a la rama principal `main`.

---

## 3. Desglose Detallado de las Fases

### Fase 1: El Núcleo Acústico y Temporal (Core Acoustic & Temporal Engine)
*El corazón del sistema. Sin estabilidad matemática temporal y afinación precisa, ningún componente visual o pedagógico superior es viable.*

- **Componente 1.1: Audio Clock de Alta Resolución (Metrónomo No Bloqueante)**
  - Sustitución total del bucle de espera activa (*busy-waiting loop*) por un despachador de eventos basado en `Timer.periodic` o *compensated sleep* en microsegundos dentro de un `Isolate`.
  - Precisión de sub-milisegundo con consumo de CPU residual ($\le 1\%$).
  - Soporte de subdivisiones rítmicas configurables (negras, corcheas, semicorcheas, tresillos).
- **Componente 1.2: Motor de Estimación de Tono ($F_0$) de Amplio Espectro**
  - Cobertura universal de $27.5\text{ Hz}$ ($A_0$) a $4186\text{ Hz}$ ($C_8$).
  - Perfiles acústicos seleccionables: *Voz / Canto*, *Cuerdas Graves (Guitarra/Bajo)*, *Vientos/Flauta/Violín*, y *Cromático Universal*.
  - Implementación de filtro de potencia acústica (Noise Gate RMS en dBFS) para rechazar ruido de sala.
  - Filtro de mediana móvil o amortiguador de segundo orden para estabilización de vibrato en cantantes.
- **Componente 1.3: UI de Estudio (Afinador Estroboscópico & Centésimas)**
  - Pantalla de afinación estroboscópica virtual fluida (60/120 FPS).
  - Indicador numérico de desviación exacta en cents ($\pm 50.0\text{ cents}$) con tolerancias de conservatorio ($\pm 3\text{ cents}$).

**Definition of Done (DoD) Fase 1:**
- [ ] Cero uso parásito de CPU por bucles infinitos en Isolates.
- [ ] Detección verificada en todo el rango vocal humano y escalas de instrumentos.
- [ ] ADRs documentados para la arquitectura del reloj y el pipeline DSP.
- [ ] Pruebas unitarias para fórmulas matemáticas de frecuencia, notas y cents superando el 95% de cobertura.

---

### Fase 2: Motor de Partituras Dinámicas y Renderizado Vectorial
*Transformación de la notación musical en una herramienta visual interactiva que reacciona a la voz y al instrumento del usuario.*

- **Componente 2.1: Modelo de Notación Estándar (Score Tree Domain)**
  - Árbol de dominio desacoplado de Flutter: `Score` $\rightarrow$ `Part` $\rightarrow$ `Measure` $\rightarrow$ `Voice` $\rightarrow$ `Note/Rest/Chord`.
  - Soporte para cualquier compás métrico: simples ($2/4, 3/4, 4/4$) y compuestos ($6/8, 9/8, 12/8$).
  - Soporte de armaduras de clave (tonalidades mayores y menores con alteraciones reales) y líneas adicionales superiores/inferiores dinámicas.
- **Componente 2.2: Renderizado SMuFL (Standard Music Font Layout)**
  - Renderizado vectorial en `CustomPainter` basado en glifos tipográficos SMuFL estándar (fuente Bravura o Leland).
  - Espaciado horizontal proporcional al valor temporal de cada figura.
- **Componente 2.3: Cursor Interactivo (Playhead) y Evaluación en Tiempo Real**
  - Seguimiento visual sincronizado con el Audio Clock de la Fase 1.
  - Superposición gráfica inmediata del sonido emitido: coloración dinámica (Verde: afinado $\le 10\text{ cents}$, Amarillo: desvío moderado, Rojo: nota errónea).
  - Registro de precisión rítmica temporal (*Early / On-Time / Late*).

**Definition of Done (DoD) Fase 2:**
- [ ] Renderizado fluido a 60/120 FPS sin tirones durante el scroll de partitura.
- [ ] Correcta tipografía musical conforme a estándares de la industria.
- [ ] Pruebas unitarias de parsing y posicionamiento del árbol de notas.

---

### Fase 3: Síntesis Sonora y Entrenamiento Auditivo (Ear Training)
*Permitir que el estudiante escuche con claridad lo que debe reproducir.*

- **Componente 3.1: Generador Sintetizado de Tono de Referencia (Pure Tone & SoundFont)**
  - Síntesis senoidal pura de baja distorsión armónica integrada en el monolito (0 dependencias de servidores remotos).
  - Motor SoundFont (SF2) ultraligero para timbres instrumentales realistas (piano, flauta, violonchelo).
  - Clic de metrónomo audible con acento de alta definición en el pulso 1 del compás.
- **Componente 3.2: Modo de Práctica "Escuchar y Repetir" (Call & Response)**
  - Flujo pedagógico: Reproducción del tono/compás de muestra $\rightarrow$ Pausa para emisión del estudiante $\rightarrow$ Comparación espectral cuantitativa.
- **Componente 3.3: Modo Espera Inteligente (Smart Wait Mode)**
  - La partitura no avanza de compás si el alumno no consigue afinar y emitir la nota correspondiente, evitando la frustración de perder el compás.

**Definition of Done (DoD) Fase 3:**
- [ ] Síntesis de audio con cero latencia perceptible ($< 5\text{ ms}$).
- [ ] Sin interferencia entre el audio emitido por el altavoz y la captura del micrófono (cancelación básica o separación de canales).

---

### Fase 4: Descomposición Musical Avanzada e Ingesta Universal
*Apertura a todo el repertorio del mundo.*

- **Componente 4.1: Importador Universal MusicXML y MIDI**
  - Parser local en Dart para decodificar partituras estándares exportadas desde MuseScore, Sibelius o Finale.
- **Componente 4.2: Algoritmo de Deconstrucción Pedagógica**
  - Descomposición automática en capas:
    1. *Capa Rítmica pura:* La partitura se transforma en percusión en un solo tono para memorizar el pulso.
    2. *Capa Interválica pura:* Estudio a tempo libre de los saltos de notas sin presión de velocidad.
    3. *Capa Integrada:* Ensamblaje progresivo con incremento automático de BPM al alcanzar $\ge 90\%$ de precisión.

**Definition of Done (DoD) Fase 4:**
- [ ] Carga exitosa de partituras MusicXML complejas del mundo real.
- [ ] Modularidad 100% probada y suite completa de regresión pasando en CI.

---

## 4. Matriz de Trazabilidad y Estado Actual

| Fase | Título | Estado | % Completado | Componentes Principales Entregados |
| :--- | :--- | :--- | :--- | :--- |
| **Fase 1** | Núcleo Acústico y Reloj de Audio | **Completado** | 100% | YIN Isolate Worker, Strobe Tuner Widget, Reloj sin busy-waiting, Síntesis senoidal |
| **Fase 2** | Motor de Partituras Dinámicas & Estética | **Completado** | 100% | Score Tree Domain, RealSheetMusicPainter modular, 7 Estéticas Maestras, Theme Customization Studio interactivo, Importación/Exportación JSON |
| **Fase 3** | Síntesis y Mezcla Multicanal (Stems) | **En progreso** | 80% | Consola mezcladora multicanal, Ganancia/Mute/Solo, Clics de metrónomo acentuados |
| **Fase 4** | Ingesta Universal, Grabación y Repertorio | **En progreso** | 80% | Monolito Modular Feature-First, Paquetes de canciones descompuestas, Grabadora de Práctica Local & Loopback con Scrubber Waveform interactivo |
