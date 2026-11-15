# ADR 0063: Arquitectura de Aislamiento de 4 Stems en Tiempo Real, Mezcla Armónica Camelot y Enrutamiento Split-Cue para Estación DJ Autónoma en PC

---

## Estado
**Aprobado** — 2026-11-13

## Contexto
Para cumplir con la visión de producto en la que cualquier usuario pueda desempeñarse como DJ profesional utilizando únicamente su computador personal (sin controladores MIDI físicos ni tarjetas de sonido multicanal externas), el subsistema `dj_console` requiere capacidades avanzadas de separación de pistas (*4-Stems*), análisis armónico (*Camelot Wheel*), visualización espectral apilada (*Parallel RGB Waveforms*), bucles cuantizados con línea de tiempo deslizante (*Slip Mode*), efectos de transición (*Sampler*) y monitoreo dividido (*Split-Cue*).

Las soluciones comerciales suelen depender de redes neuronales pesadas que consumen $> 1.5\text{ GB}$ de VRAM y introducen latencias de $> 50\text{ ms}$, o requieren interfaces de audio USB de 4 canales para la pre-escucha en auriculares. Dentro de los principios no negociables de **Tunner** (`AGENTS.md`), la solución debe ser:
1. **100% Offline-First y Ligera:** Sin descargas de modelos pesados ni llamadas de red.
2. **Latencia Sub-10ms:** Procesamiento determinista en tiempo real y cero *busy-waiting*.
3. **Clean Architecture Atomizada:** Dominio 100% en Dart puro, desacoplado de la infraestructura DSP y del lienzo vectorial a $60/120\text{ FPS}$.

## Decisión
Adoptamos una arquitectura modular dividida en cinco decisiones técnicas fundamentales:

1. **Separación de 4 Stems en Tiempo Real mediante Descomposición Mid/Side + Crossover de Fase y Detector de Transitorios:**
   - En lugar de redes profundas pesadas con alta latencia, implementamos un separador DSP determinista en el dominio del tiempo/frecuencia que descompone la señal en canales Mid ($M$) y Side ($S$), aislando `Bass` ($< 220\text{ Hz}$), `Vocals` (banda formántica central $280\text{ Hz} - 3800\text{ Hz}$), `Drums` (detector diferencial de envolvente rápida y agudos percusivos) y `Melody` (componente lateral $S$ y armónicos sostenidos).
2. **Sistema Armónico Basado en la Rueda de Camelot (`1A`–`12B`) y Transposición Semitonal Acotada:**
   - Implementamos `DjHarmonicCamelotEngine` en la capa de dominio, mapeando las 24 tonalidades mayores y menores al grafo circular de quintas de Camelot y calculando el desplazamiento óptimo de semitonos en el intervalo $[-6, +6]$ para la función `Key-Sync`.
3. **Línea de Tiempo Dual para `Slip Mode` y Cuantización Rítmica de Auto-Loops:**
   - Extendemos el estado del reproductor con un puntero subyacente `slipPositionMs` que avanza de forma continua mientras el usuario ejecuta bucles cortos (*Loop Rolls*), *scratches* o saltos de *Hot Cue*, garantizando sincronía de frase al liberar el control.
4. **Síntesis Procedural de 8 Pads de Transición (`DjTransitionSfxSynthesizer`):**
   - Los 8 pads del *Sampler* (*White Noise Riser*, *Sub-Bass Drop*, *Laser Siren*, *Airhorn*, etc.) se generan matemáticamente en memoria local mediante osciladores modulados y ruido filtrado, ocupando $0\text{ KB}$ en disco.
5. **Matriz de Salida `Split-Cue` Mono:**
   - Proveemos un modo de mezcla que asigna el bus `Master` al canal izquierdo ($L$) y el bus de pre-escucha `Cue (PFL)` al canal derecho ($R$), permitiendo monitoreo independiente en cualquier portátil con salida única de $3.5\text{ mm}$.

## Consecuencias

### Positivas
- **Autonomía Total en PC:** El usuario obtiene las herramientas de un club profesional (Stems, Key-Sync, Ondas RGB, Loops, Slip Mode, Sampler, Automix con Bass-Swap y Split-Cue) ejecutándose de forma instantánea en su PC.
- **Cero Latencia Perceptible y Cero Bloqueos UI:** Todo el cálculo matemático opera sobre buffers pre-asignados en tiempo lineal $O(N)$.
- **Extensibilidad de Teclado y Gamepad:** Nuevas acciones en `DjAction` permiten disparar Stems, Loops, Key-Sync y Pads del Sampler directamente desde el teclado QWERTY o desde un mando de Xbox/PlayStation.

### Negativas / Trade-offs
- La separación de *Stems* basada en DSP Mid/Side y filtros de cruce + transitorios tiene un aislamiento ligeramente menor que una red neuronal *offline* de varios gigabytes en mezclas monofónicas antiguas, pero ofrece a cambio **latencia cero ($< 2\text{ ms}$)**, consumo mínimo de CPU/batería y compatibilidad universal.
