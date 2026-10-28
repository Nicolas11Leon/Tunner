# ADR 0025: Supresión de Eco Acústico y Clic Percusivo Atonal para Metrónomo

## Estado
Aprobado

## Contexto
En Tunner, al ejecutar el metrónomo sonoro por los altavoces integrados del dispositivo, el micrófono capta el sonido emitido. Como el clic original se sintetizaba mediante ondas senoidales de 2200 Hz y 1400 Hz con decaimiento suave, el estimador de tono MPM (McLeod Pitch Method) detectaba con alta claridad ($> 0.90$) notas agudas ($C\#_7$ y $F_6$), lo que causaba saltos erráticos en la aguja del afinador y falsos fallos en el evaluador de práctica.

Se requería una solución robusta, 100% offline, sin latencia añadida y que no interrumpiera notas musicales legítimas sostenidas por el usuario.

## Decisión
Se implementa una solución de doble barrera en la arquitectura de audio:
1. **Rediseño Físico-Acústico del Clic (`PcmWavSynthesizer`):** Sustituir ondas senoidales estáticas por un impulso percusivo atonal tipo bloque de madera (*woodblock*) con barrido rápido de frecuencias descendentes (chirp exponencial de 3500 Hz a 600 Hz en menos de 4 ms) y amortiguamiento veloz ($\tau \le 2.5\text{ ms}$). Este transitorio carece de periodicidad constante, colapsando los picos de la función de autocorrelación NSDF a valores inferiores a $0.35$, siendo descartado por MPM como ruido percusivo no tonal.
2. **Entidad de Dominio `AcousticEchoSuppressor`:** Mecanismo de compuerta temporal inteligente (Acoustic Echo Suppression) en `lib/features/tuner/domain/acoustic_echo_suppressor.dart` que, tras cada disparo de clic del metrónomo, activa una ventana de inmunidad de 65 ms. Si un frame de tono aislado en alta frecuencia ocurre en dicha ventana, es suprimido. Si el instrumentista ya sostenía una nota legítima antes del clic, dicha frecuencia se mantiene sin salto ni interrupción.

## Consecuencias
### Positivas
- Se elimina por completo el sangrado del metrónomo hacia el afinador y el evaluador.
- La aguja del afinador se mantiene totalmente estable cuando el metrónomo hace tictac en altavoces.
- Las evaluaciones de práctica y la transcripción no registran notas falsas.
- Cero dependencias externas y cero impacto en el rendimiento de CPU/batería.

### Negativas / Mitigaciones
- Si un músico toca un staccato ultrarrápido exactamente en el microsegundo del clic en un registro extremadamente agudo ($> 1200\text{ Hz}$), podría atenuarse; se mitiga permitiendo frecuencias sostenidas y manteniendo la ventana en el mínimo estricto de 65 ms.
