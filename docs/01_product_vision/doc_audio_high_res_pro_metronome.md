# DOC-AUDIO-2026-003: Metrónomo Profesional de Alta Precisión con Escalas Italianas y Compensación de Deriva

---

## Metadatos del Documento

- **ID del Documento:** `DOC-AUDIO-2026-003`
- **Título Oficial:** `Especificación Técnica del Metrónomo Profesional: Escala Extendida 20-300 BPM, Marcas de Tempo Italianas y Drift Zero`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-10-24`
- **Última Modificación:** `2026-10-24`
- **Fase Asociada:** `Fase 1` / `Fase 2`
- **Autor / Revisor Principal:** `Tunner Engineering & Nicolas Leon`

---

## 1. Resumen Ejecutivo (Executive Summary)

El presente documento formaliza la arquitectura matemática y técnica para el Metrónomo Profesional de **Tunner**. Resuelve la limitación de rangos rígidos (previamente restringidos de 40 a 200 BPM) ampliando la escala de trabajo al estándar profesional orquestal y de estudio ($20 \le \text{BPM} \le 300$). Incorpora la clasificación canónica de marcas de tempo italianas (*Larghissimo, Largo, Adagio, Andante, Moderato, Allegro, Presto, Prestissimo*) con granularidad en sub-ticks y reloj determinista en Isolate de Dart con compensación de deriva (*drift-free scheduling*), garantizando cero acumulación de retardo temporal a lo largo de sesiones prolongadas.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
En la práctica musical instrumental avanzada (particularmente flauta, instrumentos de viento y pasajes de virtuosismo contemporáneo o estudios ultra-lentos de respiración y afinación sostenida), un límite inferior de 40 BPM resulta insuficiente para la introspección rítmica y técnica. De forma análoga, el límite de 200 BPM excluye pasajes en *Presto* o subdivisiones rápidas. Además, la interacción requiere una correspondencia didáctica inmediata con la terminología musical italiana universal.

### 2.2 Fundamento Teórico y Escalas de Tempo Italianas
El cálculo del intervalo exacto por sub-tick de semicorchea en microsegundos responde a la siguiente formulación:

$$\Delta t_{\text{tick}} = \frac{60\,000\,000}{\text{BPM} \times S}\quad [\mu\text{s}]$$

Donde:
- $\text{BPM} \in [20, 300]$.
- $S$ es el número de subdivisiones por negra (por defecto $S = 4$ para semicorcheas en compás simple).

#### Clasificación Canónica de Marcas de Tempo Italianas
| Rango de BPM | Marca Canónica Italiana | Carácter Musical |
| :--- | :--- | :--- |
| **20 – 39** | *Larghissimo / Grave* | Extremadamente lento, solemne |
| **40 – 59** | *Largo / Lento* | Amplio, reposado |
| **60 – 75** | *Adagio* | Lento y majestuoso |
| **76 – 107** | *Andante / Andantino* | A paso de marcha natural, fluido |
| **108 – 119** | *Moderato* | Moderado, templado |
| **120 – 155** | *Allegro* | Rápido, animado, alegre |
| **156 – 199** | *Vivace / Presto* | Muy rápido, vivaz |
| **200 – 300** | *Prestissimo* | Velocidad extrema de virtuosismo |

---

## 3. Especificación Funcional Detallada

### 3.1 Requerimientos del Sistema
- **REQ-METRO-01 (Rango Profesional):** El sistema debe permitir cualquier valor de BPM entero comprendido entre $20$ y $300$.
- **REQ-METRO-02 (Marcas de Tempo en Tiempo Real):** La interfaz debe desplegar de forma reactiva el término italiano correspondiente al valor de BPM actual.
- **REQ-METRO-03 (Ajuste Bidireccional Preciso):** El usuario podrá deslizar continuamente o presionar botones incrementales de ajuste fino ($\pm 1$ BPM) o atajos por salto de tempo.
- **REQ-METRO-04 (Compensación de Deriva Temporal en Isolate):** La emisión de sub-ticks no debe acumular latencia ni deriva temporal por acumulación de errores de redondeo de microsegundos en el Isolate.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/domain/tempo_entity.dart`)
Modelo inmutable y puramente matemático en Dart que mapea cualquier valor entero de BPM a su objeto `TempoMark`:
- Nombre en italiano (*Allegro*, *Adagio*, etc.).
- Descripción y rango canónico.
- Verificación de límites $[20, 300]$.

### 4.2 Capa de Infraestructura / Datos (`lib/data/metronome_service.dart`)
- El Isolate recibe comandos de actualización de tempo o calcula con `Stopwatch` / `DateTime.now()` acumulado el target de tick futuro para eliminar cualquier jitter de `Timer.periodic`.
- Destrucción atómica y creación sin acumulación de listeners.

### 4.3 Capa de Presentación (`lib/presentation/`)
- Despliegue de etiqueta italiana con tipografía moderna sobre el slider.
- Selector de tempo continuo e interactivo con soporte de 20 a 300 BPM.

---

## 5. Criterios de Rendimiento y Calidad

- **Consumo de CPU:** $\le 0.5\%$ en el hilo de temporización del Isolate.
- **Jitter acumulado:** $\le 1\text{ ms}$ en 30 minutos de sesión continua.
- **Cobertura de Pruebas Unitarias:** $\ge 95\%$ en el modelo de dominio `tempo_entity.dart` y en `MetronomeService`.

---

## 6. Referencias Técnicas

1. *Read, Gardner. Music Notation: A Manual of Modern Practice.*
2. *W3C SMuFL Standard (Standard Music Font Layout).*
3. *AGENTS.md: Reglas Cardinales de Operación de Tunner.*
