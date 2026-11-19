# ADR 0116: Unificacion de Motores de Audio por Inyeccion de Dependencias, Matematica DSP Canonica y Precision MPM

- **Estado:** Aceptado
- **Fecha:** 2026-11-19
- **Autor:** Equipo de Arquitectura Tunner
- **Fase Asociada:** Pre-v1.0.0 Feature Hardening (Ola 2)
- **Issue:** #79

## Contexto
La auditoria forense pre-v1.0.0 (`PLAN-PRE-V1-FEATURE-HARDENING-2026-002`) descubrio fallas de diseno y matematicas en la capa de audio y DSP:
1. **Split-Brain DI:** `StudioCompositionRoot` creaba instancias aisladas de `IStudioAudioEngine` e `IStudioAudioInputEngine`, mientras que ViewModels como `TunerViewModel` y `DjConsoleViewModel` creaban o accedian a instancias privadas o al singleton `.instance`. Como consecuencia, silenciar o modificar ganancias en la consola master no afectaba el audio reproducido por otros modulos.
2. **Defectos Matematicos en DSP:**
   - `StudioMasterAudioMixer`: el limitador soft-clipper presentaba una discontinuidad del 21% al cruzar el umbral $\pm0.95$, inyectando distorsion armonica de alta frecuencia inaceptable.
   - `AllPassFilter` y `SchroederReverbEngine`: la implementacion de filtro pasatodo sumaba incorrectamente senales generando una ganancia de +8.9 dB en lugar de ganancia unitaria plana $|H(e^{j\omega})| = 1$, provocando sobrecargas en cascada.
   - `BinauralPannerEngine`: presentaba saltos angulares en $\pm180^\circ$ que rompian la coherencia de fase interaural (ITD e ILD).
3. **Imprecisiones en el Algoritmo MPM y Afinacion:**
   - El filtro IIR de eliminacion de corriente continua (DC-blocker) se reinicializaba sobre cada ventana solapada, introduciendo un escalon en $t=0$ de cada calculo.
   - La funcion de autocorrelacion normalizada (NSDF) no omitia el primer cruce negativo por cero, causando deteccion erratica de armonicos superiores en registros graves y voz humana.
   - La ventana de analisis de 1024/2048 muestras era insuficiente para resolver la nota mas grave del piano ($A_0 = 27.5\text{ Hz}$), la cual requiere al menos dos ciclos completos ($2 \cdot 44100 / 27.5 \approx 3207$ muestras).
   - Se asumia una frecuencia de muestreo constante de 44.1 kHz, provocando un error sistematico de +147 cents en hardware configurado a 48 kHz.
   - En `TemperamentEngine`, la afinacion justa (Just Intonation) calculaba frecuencias relativas a $C$, dejando $A_4$ en 436.05 Hz (-15.64 cents respecto al diapason estandar de 440 Hz).
4. **Reloj Maestro y Metronomo:**
   - El primer pulso del metronomo se emitia tras el primer intervalo de espera ($t = 60/BPM$) en lugar de dispararse inmediatamente en $t = 0$.

## Decision
1. **Unificacion Estricta de DI:**
   - Centralizar la creacion del motor de salida (`IStudioAudioEngine`) y de entrada (`IStudioAudioInputEngine`) unicamente en `StudioCompositionRoot`.
   - Inyectar explicitamente las instancias en todos los ViewModels y servicios dependientes.
   - Proteger el ciclo de vida: el cierre de un canal secundario nunca detiene el pipeline principal de mezcla.
2. **Correccion Matematica de Filtros y Efectos DSP:**
   - Sustituir la funcion de recorte por un soft-clipper cubico $C^1$-continuo:
     $$f(x) = \begin{cases} x & \text{si } |x| \le 0.8 \\ \operatorname{sgn}(x)\left(0.8 + 0.2 \tanh\left(\frac{|x| - 0.8}{0.2}\right)\right) & \text{si } |x| > 0.8 \end{cases}$$
   - Implementar la ecuacion de diferencias estandar de Schroeder para filtros pasatodo con ganancia $|H(z)| = 1$:
     $$y[n] = -g \cdot x[n] + x[n - D] + g \cdot y[n - D]$$
   - Mantener actualizacion de coeficientes in-place (`updateParameters`) en filtros biquad de segundo orden.
3. **Blindaje Acustico de MPM y Afinador:**
   - Mantener el estado del filtro DC-blocker en memoria estatica continua entre bloques sucesivos de captura.
   - Evaluar picos del NSDF unicamente tras el primer cruce por cero en sentido negativo a positivo.
   - Ampliar el tamano del buffer a 4096 muestras para cubrir $A_0 = 27.5\text{ Hz}$ de forma determinista.
   - Parametrizar la frecuencia de muestreo segun la tasa real del stream de hardware (`sampleRate`).
   - Normalizar todas las tablas de temperamentos historicos fijando $A_4 = 440.0\text{ Hz}$ como constante inmutable, y corregir las tablas de Vallotti y Young II.
4. **Disparo Inmediato del Reloj:**
   - Emitir el primer pulso del compas inmediatamente en $t=0$ y programar los pulsos subsecuentes con temporizadores basados en tiempo transcurrido de alta precision.

## Consecuencias
- **Positivas:**
  - Control de volumen, mute y ruteo master 100% efectivo sobre todo el flujo de audio del estudio.
  - Cero artefactos de distorsion o saltos discontinuos en el limitador y reverbs de estudio.
  - Afinacion de extrema precision (< 1 cent) desde el registro subgrave ($A_0$) hasta el agudo orquestal ($C_8$).
  - Sincronia instantanea y musical en el metronomo y transporte.
- **Negativas / Compromisos:**
  - El buffer de 4096 muestras en bajas frecuencias requiere computo de FFT o correlacion optimizada, mitigado por el uso de SIMD/C99 en el puente FFI cuando esta disponible.
