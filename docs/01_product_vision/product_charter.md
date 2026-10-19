# Product Charter: Tunner Platform

---

## Metadatos del Documento

- **ID del Documento:** `DOC-PROD-2026-001`
- **Título Oficial:** `Carta Constitutiva del Producto y Manifiesto de Visión: Tunner`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-10-19`
- **Última Modificación:** `2026-10-19`
- **Fase Asociada:** `Global`
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Resumen Ejecutivo (Executive Summary)

**Tunner** es una iniciativa de software libre diseñada para democratizar el acceso a la educación musical de alto nivel mediante el uso de tecnología acústica de precisión de estudio. Su propósito primordial es eliminar las barreras de costo, complejidad pedagógica y subjetividad auditiva que tradicionalmente limitan a las personas al aprender a cantar o a tocar un instrumento.

La plataforma combina algoritmos de estimación de frecuencia fundamental ($F_0$) en tiempo real, análisis microtonal en cents, un reloj rítmico determinista de consumo cero en reposo y un motor de descomposición interactiva de partituras. Tunner concibe la educación musical no como un producto comercial privativo, sino como un bien común accesible para toda la humanidad de forma offline y soberana en cualquier dispositivo.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
1. **La barrera de la subjetividad en el aprendizaje autodidacta:** Cuando un estudiante practica solo, carece de un oído entrenado para discernir si está afinando con precisión de centésimas o si sus desviaciones rítmicas son sistemáticas.
2. **Herramientas comerciales privativas y fragmentadas:** Las aplicaciones existentes en el mercado suelen pertenecer a dos extremos opuestos:
   - *Afinadores rudimentarios:* Simples agujas analógicas sin contexto pedagógico, incapaces de relacionar el sonido emitido con una partitura o método de práctica.
   - *Plataformas comerciales de suscripción mensual:* Ecosistemas cerrados, dependientes de servidores remotos con conexión obligatoria a internet, y con bibliotecas de canciones bajo muros de pago.
3. **Latencia y degradación acústica:** El procesamiento de audio en red introduce latencias superiores a 50 ms que rompen el bucle neuro-muscular de retroalimentación auditiva del estudiante (que exige latencias $\le 10\text{ ms}$).

### 2.2 Fundamento Teórico y Pedagógico
- **El Modelo de Práctica Deliberada (Deliberate Practice):** La adquisición de competencia musical acelerada exige retroalimentación inmediata, mediciones cuantitativas no punitivas y la descomposición del pasaje complejo en elementos atómicos aislados (altura tonal vs. subdivisión rítmica).
- **Relación Frecuencia-Tono (Escala Temperada):**
  La percepción del tono es logarítmica. La desviación respecto a la frecuencia de referencia $f_0$ de una nota MIDI se mide en centésimas de semitono (cents):
  $$\text{cents} = 1200 \cdot \log_2\left(\frac{f}{f_{\text{teórica}}}\right)$$
  Un semitono equivale a 100 cents. El umbral de discriminación del oído humano no entrenado ronda los $\pm 10\text{ a } 25\text{ cents}$, mientras que un instrumentista o cantante profesional opera con tolerancias inferiores a $\pm 5\text{ cents}$.

---

## 3. Especificación de Objetivos y Filosofía de Producto

### 3.1 Mentalidad de Producto vs. Mentalidad de Proyecto
- **Proyecto (Bifurcado en Fases):** Define hitos temporales y arquitectónicos acotados para garantizar que el código se construya sobre cimientos matemáticos y de software impecables.
- **Producto (Visión Trascendente):** Tunner es un producto evolutivo y permanente. No se optimiza para métricas de retención comercial ni monetización, sino para la pureza del aprendizaje, la fidelidad acústica y la accesibilidad humana.

### 3.2 Principios Rectores
1. **Acceso Universal Gratuito y Libre:** 100% código abierto (Licencia MIT), sin muros de pago, sin publicidad intrusiva y sin recolección de datos privados.
2. **Soberanía y Offline-First:** Toda la cadena de procesamiento de señales (captura, DSP, metrónomo, análisis y renderizado) opera íntegramente de manera local en el procesador del usuario.
3. **Rigor Científico y Estética de Estudio:** Diseñado con precisión instrumental apta tanto para un niño dando sus primeros pasos como para un estudiante de conservatorio o profesional de estudio.

---

## 4. Usuarios Objetivo (Personas)

| Perfil | Caso de Uso Principal | Necesidad Crítica |
| :--- | :--- | :--- |
| **Estudiante de Canto** | Práctica de escalas, colocación y control de afinación sostenida. | Tolerancia al vibrato natural, feedback de curva continua y eliminación de saltos de octava. |
| **Músico de Viento / Cuerdas** | Control de embocadura, afinación en diferentes registros y precisión de digitación. | Detección limpia de transitorios de ataque y precisión microtonal de $\pm 1\text{ cent}$. |
| **Educador Musical** | Asignación de partituras y seguimiento de ejercicios de lectura a primera vista. | Visualización estándar SMuFL y deconstrucción de compases en subdivisiones lentas. |
| **Músico Autodidacta** | Aprendizaje desde cero de lectura de partituras e interiorización del pulso. | Modo espera (*Wait Mode*), metrónomo audible sin sobrecalentamiento del equipo. |

---

## 5. Criterios de Rendimiento Global

- **Latencia de Extremo a Extremo:** Tiempo total desde que el micrófono detecta la vibración del aire hasta que la pantalla actualiza la posición del afinador: $< 10\text{ ms}$.
- **Rango Espectral:** Captura ininterrumpida desde $A_0$ ($27.5\text{ Hz}$) hasta $C_8$ ($4186\text{ Hz}$).
- **Eficiencia Energética:** 0% de consumo parásito en reposo; utilización óptima de hilos secundarios (Isolates / OS timers) respetando la autonomía de batería en dispositivos móviles y portátiles.

---

## 6. Referencias Técnicas

1. *Bregman, A. S. (1994). Auditory Scene Analysis: The Perceptual Organization of Sound. MIT Press.*
2. *De Cheveigné, A., & Kawahara, H. (2002). YIN, a fundamental frequency estimator for speech and music. J. Acoust. Soc. Am.*
3. *W3C Music Notation Community Group. Standard Music Font Layout (SMuFL) Specification.*
