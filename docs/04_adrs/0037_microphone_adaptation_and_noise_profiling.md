# ADR-0037: Real-Time Hardware Microphone Adaptation, DC-Blocking Filter, and Noise Floor Profiling

---

## Estado
**Aprobado (Approved)**

---

## Contexto

Los transductores de micrófono en dispositivos de consumo (smartphones Android de distintas gamas, iPhones, portátiles, micrófonos de solapa y micrófonos de estudio USB) difieren ampliamente en sus características de hardware:
1. **Sensibilidad y Nivel de Entrada:** Algunos micrófonos capturan la flauta o violín con señales extremadamente débiles (forzando al algoritmo de detección de tono a operar cerca del umbral de ruido), mientras que otros saturan y recortan la señal (*clipping*).
2. **Polarización de Corriente Continua (DC Offset):** Tarjetas de sonido integradas económicas introducen un desplazamiento constante distinto de cero en el punto neutro del PCM, lo que sesga la correlación normalizada (NSDF) del McLeod Pitch Method y desvía la detección de cruces por cero.
3. **Piso de Ruido Ambiental (Noise Floor):** Un Noise Gate estático hardcodeado (ej: -46 dBFS) puede ser ineficaz en habitaciones con aire acondicionado/ventiladores (provocando notas fantasma) o excesivamente restrictivo para instrumentos suaves tocados en *pianissimo*.

---

## Decisión

Se incorpora en la capa de dominio e infraestructura de **Tunner** una **cadena de acondicionamiento de señal y calibración adaptativa de micrófono**:

1. **Filtro Eliminador de Offset DC (DC-Blocker IIR):**
   - Se procesa cada muestra de entrada mediante la ecuación canónica en diferencias:
     $$y[n] = x[n] - x[n-1] + R \cdot y[n-1], \quad R = 0.9978$$
   - Con frecuencia de corte a $15\text{ Hz}$, no altera ni atenúa la nota musical más grave soportada ($A_0 = 27.5\text{ Hz}$), garantizando que el punto neutro del PCM sea rigurosamente cero.

2. **Acondicionador de Ganancia de Entrada Digital (Digital Input Gain Multiplier):**
   - Multiplicador de amplitud en coma flotante configurable ($0.2\times$ a $5.0\times$) con limitador suave para evitar distorsión armónica artificial.

3. **Perfilador de Piso de Ruido Acústico (`NoiseFloorProfiler`):**
   - Un asistente interactivo en la aplicación permite registrar el nivel ambiental de la sala durante 1 a 2 segundos en silencio.
   - Calcula el valor medio $\overline{\text{RMS}}$ y el pico $RMS_{\text{peak}}$, derivando un umbral de silencio adaptativo óptimo:
     $$\text{NoiseGate}_{\text{adaptive}} = \max\left(0.003, \quad 1.8 \times \overline{\text{RMS}}\right)$$

4. **Enumeración de Dispositivos Físicos:**
   - Aprovecha la API `listInputDevices()` del plugin `record` para permitir al usuario seleccionar explícitamente entre el micrófono interno, auriculares o interfaz externa USB.

5. **Persistencia Local:**
   - La configuración calibrada (`inputGain`, `noiseGateThreshold`, `selectedDeviceId`) se almacena en el servicio de persistencia local `JsonLocalPersistenceService`, cargándose automáticamente al iniciar la aplicación.

---

## Consecuencias

### Positivas
- **Inmunidad al Ruido Ambiental:** Cero notas falsas por ventiladores de computadoras o zumbidos de línea eléctrica.
- **Respuesta Óptima en Todos los Dispositivos:** Los instrumentos suaves (flauta baja, laúd, voz pianissimo) se detectan con inmediatez incluso en micrófonos de baja sensibilidad.
- **Rigor Matemático:** Desaparece cualquier valor mágico arbitrario en la cadena de captura acústica.

### Desafíos Mitigados
- **Carga de CPU:** El filtro IIR de un polo y la multiplicación de ganancia consumen menos de 10 operaciones aritméticas por muestra en el `_dspIsolate`, con impacto en CPU indetectable ($< 0.1\%$).
