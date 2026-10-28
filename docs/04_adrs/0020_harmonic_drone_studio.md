# ADR-0020: Estudio de Dron Armónico de Referencia Continua (Tone Drone Studio)

- **Estado:** Approved
- **Fecha:** 2026-10-27
- **Fase:** Fase 7.3 (Vanguardia Acústica y Conservatorio)
- **Autor:** Antigravity / Nicolas Leon

---

## 1. Contexto

En la pedagogía musical de conservatorio y entre instrumentistas solistas (cuerdas frotadas, vientos madera, metales y cantantes líricos), la práctica con "drones" (notas pedal sostenidas continuas) es el estándar de oro para el desarrollo del oído interno y la intonación acústica.

Tocar escalas, arpegios o pasajes contra una nota pedal fundamental y su quinta armónica permite al músico escuchar físicamente los batimentos acústicos (interferencias de fase entre frecuencias cercanas) y eliminarlos hasta lograr consonancia perfecta.

Los reproductores de audio convencionales o clips pregrabados sufren de:
1. Ruido y "clicks" percutivos en los puntos de unión de los bucles (loop seam artifacts).
2. Falta de adaptabilidad a la calibración de concierto activa ($A_4$ ajustable entre 415 Hz y 466 Hz).
3. Falta de integración con los temperamentos históricos (e.g. Just Intonation, Werckmeister III, Mesotónico).
4. Sobrecarga en hilos de UI o dependencia de servidores de audio remotos.

---

## 2. Decisión

Implementar un generador de síntesis procedural de audio en memoria RAM en el Dominio puro (`HarmonicDroneSynthesizer`):
1. **Modelado Puro en Dart:**
   - `HarmonicDroneConfig`: entidad inmutable con tono fundamental ($f_0$), octava (2 a 4), activación de quinta ($1.5\times f_0$ o según temperamento activo), activación de octava ($2\times f_0$), balance armónico y envolventes tímbricas (`DroneTimbre`: Senoidal, Flauta Cálida, Cello, Órgano).
2. **Bucle Continuo Matemático Sin Discontinuidades (Seamless Zero-Discontinuity Loop):**
   - El sintetizador genera un buffer PCM de 16 bits Mono a 44100 Hz.
   - Aplica un fundido cruzado simétrico (equal-power crossfade) de 40 ms entre el final del buffer y su inicio, eliminando cualquier discontinuidad de fase o pop percusivo al repetirse en bucle continuo con `ReleaseMode.loop`.
3. **Calibración Microtonal en Tiempo Real:**
   - Las frecuencias del dron se calculan respetando la frecuencia de concierto de referencia ($A_4$) y el temperamento musical activo en `TemperamentEngine`.
4. **Coexistencia Total con el Detector de Tono:**
   - El dron corre en el canal de síntesis procedural mientras el micrófono y el algoritmo MPM continúan analizando la voz o instrumento del usuario de forma concurrente y desacoplada.

---

## 3. Consecuencias

### Positivas
- Permite a cualquier estudiante o concertista practicar afinación interválica de alta fidelidad sin hardware adicional.
- Cero dependencias en archivos de audio de terceros (cero MB añadidos al peso de la app).
- Compatibilidad directa con afinaciones barrocas (415 Hz), orquestales (442 Hz) y temperamentos históricos.
- 100% offline, deterministic memory footprint.

### Negativas / Mitigaciones
- La generación de ondas compuestas con armónicos requiere cálculo trigonométrico en memoria: mitigado limitando la duración del buffer a 2.0 segundos (88200 muestras PCM, menos de 180 KB de RAM) que se generan en menos de 3 ms en CPU móvil estándar.
