# Architecture & Technical Specification: Virtual DJ Performance Console & Universal QWERTY Keyboard Mapping Engine

Este documento define la arquitectura técnica, fundamentos acústicos, modelos matemáticos y contratos del sistema de Consola de DJ Virtual de Doble Deck con Mapeo Universal de Teclado QWERTY y Controladores MIDI en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-065`
- **Título Oficial:** Arquitectura de Consola de DJ Virtual con Decks Duales, Pitch Shifting, Crossfader Curvilíneo y Mapeo Universal de Teclado QWERTY / MIDI
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-11-13
- **Última Modificación:** 2026-11-13
- **Fase Asociada:** Fase 3 & Fase 4
- **Autor / Revisor Principal:** Mantenedor de Arquitectura de Audio Digital Tunner

---

## 1. Resumen Ejecutivo (Executive Summary)

El sistema de Consola de DJ Virtual de Tunner democratiza la ejecución y mezcla de pistas musicales y stems en tiempo real sin requerir la adquisición de equipamiento de hardware DJ dedicado de alto costo (e.g. Pioneer CDJ/DDJ, Native Instruments Traktor Kontrol). La arquitectura introduce un motor de audio de baja latencia con dos reproductores virtuales independientes (Deck A y Deck B), un crossfader con respuesta configurable (lineal, logarítmica y sharp cut para scratch), ecualizador de 3 bandas con aislamiento por corte (Isolator 24 dB/oct), puntos de Hot Cue reactivos, jog wheels virtuales vectoriales con emulación de inercia vinílica y un motor desacoplado de mapeo universal de eventos de teclado físico QWERTY que traduce pulsaciones y combinaciones de teclas con respuesta determinista en menos de 10 milisegundos.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema

Los estudiantes de producción musical, arreglos y mezcla contemporánea frecuentemente se enfrentan a una barrera de entrada económica significativa: la necesidad de adquirir consolas controladoras físicas para practicar transiciones armónicas, mezclas en vivo, beatmatching y control de stems. Las soluciones de software comercial a menudo imponen latencias perceptibles en interfaces de escritorio no especializadas, carecen de esquemas de mapeo flexibles para teclados estándar de ordenador o comprometen la fidelidad acústica al reproducir cambios de tempo mediante algoritmos rudimentarios de remuestreo.

### 2.2 Fundamento Físico, Acústico y Matemático

#### 2.2.1 Curvas de Atenuación de Crossfader

El crossfader combina las señales estéreo de Deck A ($S_A$) y Deck B ($S_B$) en función de la posición normalizada del cursor $x \in [-1.0, 1.0]$, donde $-1.0$ representa Deck A al 100% y $+1.0$ representa Deck B al 100%.

Se definen tres funciones de transferencia acústica estándar de la industria:

1. **Curva de Potencia Constante (Equal-Power / Smooth Transition):**
   Garantiza que la suma de energía acústica cuadrática se mantenga invariable a lo largo de toda la transición, evitando caídas perceptibles de volumen en la posición central ($x = 0$):
   $$\theta = \frac{\pi}{4}(x + 1)$$
   $$g_A(x) = \cos(\theta), \quad g_B(x) = \sin(\theta)$$
   $$\text{Comprobación de conservación de energía: } g_A^2(x) + g_B^2(x) = \cos^2(\theta) + \sin^2(\theta) = 1.0$$

2. **Curva Lineal Estricta (Linear Fading):**
   $$g_A(x) = \max\left(0, \frac{1 - x}{2}\right), \quad g_B(x) = \max\left(0, \frac{1 + x}{2}\right)$$

3. **Curva de Corte Brusco (Fast Cut / Scratching):**
   Especializada para transiciones percusivas y cortes rítmicos inmediatos. Aplica una función sigmoidea hiperbólica o umbral rápido con zona muerta mínima:
   $$g_A(x) = \begin{cases} 1.0 & \text{si } x \le 0.05 \\ \max\left(0, 1 - \frac{x - 0.05}{0.95}\right) & \text{si } x > 0.05 \end{cases}$$
   $$g_B(x) = \begin{cases} 1.0 & \text{si } x \ge -0.05 \\ \max\left(0, 1 + \frac{x + 0.05}{0.95}\right) & \text{si } x < -0.05 \end{cases}$$

#### 2.2.2 Pitch Shifting y Remuestreo de Tempo (BPM Scaling)

La tasa de reproducción $r \in [0.5, 2.0]$ altera la velocidad de reproducción sin interpolaciones defectuosas:
$$\text{BPM}_{\text{actual}} = \text{BPM}_{\text{base}} \cdot r$$
El cambio de afinación en semitonos derivado de la alteración de velocidad (cuando se opera en modo Vinilo Clásico sin Timestretch) sigue la relación logarítmica temperada:
$$\Delta \text{semitonos} = 12 \cdot \log_2(r)$$
$$\Delta \text{cents} = 1200 \cdot \log_2(r)$$

Cuando se activa el modo Master Tempo / Key Lock, el motor conserva el tono fundamental original $f_0$ aplicando análisis en ventanas overlap-add de fase fija.

#### 2.2.3 Filtros de Ecualización de 3 Bandas (High, Mid, Low)

Cada deck cuenta con una etapa de filtrado biquad en cascada:
- **Low Shelf / Low Pass:** Frecuencia de corte $f_c = 250\text{ Hz}$.
- **Peaking Bandpass:** Frecuencia central $f_0 = 1200\text{ Hz}$, $Q = 1.0$.
- **High Shelf / High Pass:** Frecuencia de corte $f_c = 4000\text{ Hz}$.
- Rango de ganancia: $-\infty\text{ dB}$ (Kill switch / aislamiento total a corte de 24 dB/oct) hasta $+6\text{ dB}$.

---

## 3. Especificación Funcional Detallada

### 3.1 Requerimientos Funcionales del Sistema

- **REQ-01 (Dual Deck Architecture):** Dos instancias independientes de reproductor de audio con carga de archivos de audio locales (WAV, MP3, FLAC, OGG) y stems generados por el sintetizador de Tunner.
- **REQ-02 (Curvilinear Crossfader):** Control deslizante central que fusiona las salidas de Deck A y B con soporte de tres curvas conmutables: Potencia Constante, Lineal y Fast Cut.
- **REQ-03 (BPM & Tempo Pitch Slider):** Rango de pitch de $\pm 8\%$, $\pm 16\%$ y $\pm 50\%$, con botón de Sync de tempo para igualar el BPM de una pista con la pista maestra activa.
- **REQ-04 (Hot Cues & Loop Engine):** Cuatro bancos de Hot Cues por deck con memorización de marcas de tiempo en milisegundos y saltos instantáneos, además de loops automáticos cuantizados de 1, 2, 4, 8 y 16 tiempos.
- **REQ-05 (Universal QWERTY Keyboard Mapper):** Mapeador desacoplado configurable que asocia cualquier tecla física (alfanuméricas, espaciador, modificadores Shift/Control) a acciones DJ (Play/Pause, Cue, Nudge BPM, Crossfader Left/Right, Kill EQs, Trigger Hot Cue).
- **REQ-06 (Perfil de Mapeo por Defecto):** Distribución ergonómica inspirada en VirtualDJ / Traktor:
  - Deck A: Tecla `Q` (Cue), `W` (Play/Pause), `E` (Sync), `A` (Pitch Down), `S` (Pitch Up), `1-4` (Hot Cues 1-4).
  - Deck B: Tecla `U` (Cue), `I` (Play/Pause), `O` (Sync), `J` (Pitch Down), `K` (Pitch Up), `7-0` (Hot Cues 1-4).
  - Crossfader: Tecla `X` (Crossfader a izquierda), `C` (Crossfader al centro), `V` (Crossfader a derecha).
- **REQ-07 (Jog Wheel Vectorial & Scratching):** Renderizado en CustomPainter a 60/120 FPS con respuesta táctil/ratón que simula inercia angular, desaceleración por fricción y reproducción en reversa.

---

## 4. Diseño Técnico y Arquitectura de la Solución

```
+-------------------------------------------------------------------+
|                     Presentation Layer (UI)                       |
|   DjConsoleModal / DjDeckView / VectorJogWheel / DjKeymapEditor   |
+---------------------------------+---------------------------------+
                                  | Observa cambios de estado
                                  v
+-------------------------------------------------------------------+
|                     Presentation ViewModel                        |
|                        DjConsoleViewModel                         |
+---------------------------------+---------------------------------+
                                  | Invoca orquestación de dominio
                                  v
+-------------------------------------------------------------------+
|                          Domain Layer                             |
|  - DjDeckEntity (Puro Dart: estado, bpm, tempo, hotCues, loops)   |
|  - DjCrossfaderEntity (Puro Dart: posición x, curva de potencia)  |
|  - DjKeymapProfileEntity (Puro Dart: asociaciones tecla -> acción)|
|  - DjPerformanceOrchestrator (Lógica pura de mezcla y transporte) |
+---------------------------------+---------------------------------+
                                  | Implementa interfaces de datos
                                  v
+-------------------------------------------------------------------+
|                     Data / Infrastructure Layer                   |
|  - DjAudioEngineService (Canales de audio, buffer mix, filtros)  |
|  - JsonDjKeymapPersistenceService (Persistencia de perfiles JSON) |
+-------------------------------------------------------------------+
```

---

## 5. Criterios de Rendimiento y Benchmarking

- **Latencia de Respuesta de Teclado:** $\le 8\text{ ms}$ desde el evento de hardware `RawKeyEvent` / `KeyEvent` hasta la orden de reproducción en el motor.
- **Eficiencia de CPU:** Renderizado vectorial de jog wheels sin recomposiciones de árbol completo; aislamiento mediante `RepaintBoundary` y `CustomPainter`.
- **Memoria:** Consumo predecible con liberación inmediata de buffers al descargar o reemplazar pistas en los decks.

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] Pruebas unitarias de cálculo de ganancias de crossfader (Potencia Constante, Lineal, Scratch Cut).
- [ ] Pruebas unitarias de serialización y deserialización de perfiles de mapeo de teclado (`DjKeymapProfileEntity`).
- [ ] Pruebas unitarias de gestión de transporte, sincronización de BPM y saltos a Hot Cues.
- [ ] Pruebas de widgets e interfaz de usuario para interacción con decks, sliders de ecualización y asignador de atajos.

---

## 7. Referencias Técnicas

1. *Pohlmann, K. C. (2010). Principles of Digital Audio. McGraw-Hill.*
2. *Zölzer, U. (2011). DAFX: Digital Audio Effects. John Wiley & Sons.*
3. *W3C Audio Working Group: Web Audio API Specification - Equal Power Crossfade.*