# ADR 0012: Adopción del McLeod Pitch Method (MPM) con NSDF e Interpolación Parabólica en Pure Dart

## Estado
Aceptado (Accepted)

---

## Contexto
El motor de afinación original de Tunner delegaba la estimación de tono en la librería `pitch_detector_dart`, la cual implementa un algoritmo YIN básico con limitaciones:
1. En señales acústicas de viento (flauta travesera, clarinete) y vocales, la energía de los armónicos pares/impares puede superar al fundamental, provocando saltos de octava ("octave jumps").
2. El filtrado de ruido de entrada convertía bytes sin signo en lugar de enteros de 16 bits con signo (`toSigned(16)`), distorsionando el cálculo de energía RMS.
3. Depender de librerías externas de terceros para el núcleo DSP del dominio compromete la independencia del proyecto y la reproducibilidad determinista en pruebas unitarias.

---

## Decisión
1. Desarrollar e incorporar una implementación canónica y 100% pura Dart del **McLeod Pitch Method (MPM)** en `lib/features/tuner/domain/mcleod_pitch_method.dart`.
2. Computar la **Función de Diferencia Cuadrada Normalizada (NSDF)**:
   $$r'_t(\tau) = \frac{2 \sum_{j=0}^{W - \tau - 1} x[j] x[j+\tau]}{\sum_{j=0}^{W - \tau - 1} (x[j]^2 + x[j+\tau]^2)}$$
3. Implementar **Dynamic Peak Picking** con umbral relativo $k = 0.90$ para seleccionar sistemáticamente el tono fundamental frente a los armónicos superiores.
4. Aplicar **Interpolación Parabólica Sub-Muestra** en el vértice del pico para obtener una precisión sub-cent sin sobremuestreo costoso.
5. Ejecutar la estimación dentro del worker Isolate secundario en `PitchDetectorService`, garantizando cero impacto en la tasa de refresco (60/120 FPS) del hilo principal de UI.

---

## Consecuencias

### Positivas
- **Inmunidad a Saltos de Octava:** Detección precisa y robusta para flautas, guitarras, violines y voz.
- **Resolución Continua Sub-Cent:** Variaciones menores a $\pm 0.1$ cents capturadas con fluidez.
- **Clean Architecture Pura:** Lógica matemática aislada en la capa de dominio sin dependencias de Flutter ni SDKs externos.
- **Testabilidad al 100%:** Permite crear pruebas unitarias de laboratorio con señales senoidales puras sintetizadas matemáticamente.
- **Eficiencia Energética:** Cálculo de RMS con descarte precoz (Noise Gate) cuando no hay señal útil.

### Desafíos y Mitigaciones
- **Cómputo O(N * tau_max):** Para ventanas de 2048 muestras a 44.1 kHz, el cálculo de la NSDF toma típicamente menos de 2 a 4 ms en dispositivos modernos. Se ejecuta en un Isolate secundario, dejando la UI de Flutter completamente libre.
