# Registro de Decisión de Arquitectura (ADR) 0099: Procesador de Reverberación Algorítmica Schroeder-Moorer y Convolución IR 100% Offline

---

## Metadatos

- **ID del ADR:** `ADR-0099`
- **Título:** Topología de Reverberación Algorítmica Schroeder-Moorer y Procesador de Convolución Acústica Offline
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 7`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 110](../02_use_cases/110_uc_schroeder_moorer_reverb_and_convolution.md)
- **Plan Relacionado:** [Plan Épica 7.1](../05_implementation_plans/plan_schroeder_moorer_reverb_and_convolution.md)
- **Issue Asociado:** [#37](https://github.com/Nicolas11Leon/Tunner/issues/37)

---

## 1. Contexto

La espacialización acústica es un componente esencial para otorgar profundidad y realismo a la producción musical y entrenamiento auditivo. El procesamiento de reverberación presenta dos necesidades distintas:
1. **Tiempo Real (Monitoreo y Síntesis en Vivo):** Requiere un algoritmo ligero, de latencia predecible y cero consumo excesivo de memoria o CPU. La topología clásica de Schroeder-Moorer cumple estos requisitos al sintetizar reflexiones tempranas y cola difusa mediante líneas de retardo con realimentación y dispersión de fase.
2. **Post-Producción y Masterización Offline:** Requiere fidelidad acústica absoluta mediante convolución directa de respuestas al impulso (IR) grabadas en recintos reales sobre búferes de audio completos sin restricciones de tiempo real.

---

## 2. Decisión

Se implementa una arquitectura modular de reverberación en Dart puro dentro de `lib/core/audio/domain/reverb/`:

1. **Topología de Retardo con Búferes Circulares Preasignados (`Float32List`):**
   - Cero asignaciones de memoria durante el ciclo de procesamiento de audio para evitar pausas por *Garbage Collection*.
   - Índices de retardo en muestras primos entre sí para prevenir resonancias parásitas (*flutter echo*):
     - Comb 1: 1116 muestras (~25.3 ms a 44.1 kHz)
     - Comb 2: 1188 muestras (~26.9 ms)
     - Comb 3: 1277 muestras (~29.0 ms)
     - Comb 4: 1356 muestras (~30.7 ms)
     - All-Pass 1: 225 muestras (~5.1 ms, ganancia $a = 0.5$)
     - All-Pass 2: 556 muestras (~12.6 ms, ganancia $a = 0.5$)

2. **Parámetros Acústicos Didácticos y de Estudio:**
   - `roomSize`: Factor de escala de realimentación (0.0 a 0.98).
   - `damping`: Filtro paso-bajo de un polo que simula la absorción de frecuencias agudas por materiales blandos de la sala.
   - `preDelay`: Retardo inicial previo a las primeras reflexiones (0 a 100 ms).
   - `dryWetMix`: Balance lineal entre señal directa y reverberada (0.0 = 100% dry, 1.0 = 100% wet).

3. **Convolución Directa Offline (`IrConvolutionProcessor`):**
   - Aplica matemáticamente la integral de convolución discreta:
     $$y[n] = \sum_{k=0}^{M-1} x[n - k] \cdot h[k]$$
   - Implementado en Dart puro para procesamiento de archivos y stems sin dependencias nativas complejas.

---

## 3. Consecuencias

### Positivas
- **Determinismo Numérico:** Salida idéntica en cualquier plataforma soportada (Linux, macOS, Windows, Android, iOS, Web).
- **Eficiencia DSP Extrema:** Un bloque de 512 muestras se procesa en menos de 0.2 ms en un procesador móvil estándar.
- **Integrabilidad con Tunner DSL:** Los parámetros pueden modularse mediante comandos declarativos (ej. `set @reverb.room = 0.75;`).
