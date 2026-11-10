# ADR 0052: Arquitectura Global de Sinergias Inter-Herramientas, Motor de Políticas de Enlace y Refactorización Atómica

## Estado
Aprobado (Approved) - 2026-11-09

## Contexto
Tunner dispone de 16 herramientas con implementaciones de alta calidad acústica. Sin embargo, permitir que cualquier módulo se conecte arbitrariamente con cualquier otro sin restricciones provocaría comportamientos indeseados (por ejemplo, arruinar un examen a ciegas aplicando autotune, o desestabilizar la detección de fundamental MPM enviando un acorde con 4 notas simultáneas). Se requiere una arquitectura gobernada que distinga formalmente las hiper-sinergias de valor pedagógico comprobado frente a los cruces forzados o incompatibles.

## Decisión
1. **Matriz de Interoperabilidad y Motor de Políticas (`SynergyPolicyEngine`):**
   - Se formalizan las 6 grandes hiper-sinergias: Lectura en Vuelo, Suite Vocal Autotune, Afinador Inteligente con Reconocimiento Tímbrico, Modo Minus-One con Ensamble SoundFont, Afinación por Batimento y Análisis Polifónico de Temperamentos.
   - Se crea un motor de validación de políticas que rechaza formalmente los enlaces destructivos (ej. Autotune en tests a ciegas, acordes polifónicos a detectores monofónicos sin split).
2. **Refactorización Modular de Señales (`SignalBus`):**
   - Estandarización de 5 tipos de señal fundamentales: `temporalClock`, `pitchEstimate`, `audioPcm`, `scoreData` y `controlEvent`.
   - Comunicación completamente in-process en memoria con latencia $< 1\text{ ms}$, eliminando cualquier overhead de red o serialización innecesaria.
3. **Evolución Gradual y Preservación de Código Estable:**
   - La refactorización mantiene la compatibilidad total hacia atrás con los ViewModels y pantallas existentes, introduciendo adaptadores y fachadas (`InteroperableModuleNode`).

## Consecuencias

### Positivas
- **Claridad Conceptual Absoluta:** Tanto los desarrolladores como los usuarios comprenden qué combinaciones son virtuosas y cuáles son anti-patrones.
- **Robustez Acústica:** Los algoritmos DSP (MPM, FFT, Autotune) reciben únicamente señales dentro de sus supuestos matemáticos de operación.
- **Escalabilidad Infinita:** Nuevas herramientas (ej. afinador microtonal para sitar o laúd, sintetizador granular) podrán acoplarse declarando sus puertos compatibles.

### Negativas / Mitigaciones
- **Reglas de Validación Adicionales:** Requiere mantener el registro de políticas de compatibilidad de puertos. *Mitigación:* Se implementa como un conjunto inmutable de reglas en la capa de dominio puro de Dart.
