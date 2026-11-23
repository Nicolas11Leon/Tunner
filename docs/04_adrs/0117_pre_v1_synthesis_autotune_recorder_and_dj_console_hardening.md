# ADR 0117: Endurecimiento de Motores de Síntesis, Auto-Tune Vocal TD-PSOLA, Grabación de Estudio y Consola DJ Pro (Ola 3)

## Estado
Aprobado

## Contexto
Durante la auditoría forense pre-v1.0.0 (`PLAN-PRE-V1-FEATURE-HARDENING-2026-002`), se identificaron varias brechas de implementación en los módulos de síntesis, post-producción y DJ:
1. `PolyphonicVoicePool` y `SoundFontSynthesizerService` poseían la lógica de decodificación SF2 y generación ADSR, pero requerían integración directa con `renderBlock()` en el pipeline maestro de stems y exportación.
2. `VocalAutoTuneProcessor` requería estabilización matemática en el algoritmo TD-PSOLA (Time-Domain Pitch Synchronous Overlap-Add) con periodos fraccionarios para evitar desgarro de fase en cambios de octava o semitonos bruscos.
3. `DjConsoleViewModel` precisaba garantizar la persistencia de mezclas en disco mediante `DjMixWavEncoder` con cabeceras RIFF de 44 bytes estrictas y sincronización exacta de BPM entre Decks A y B sin artefactos de scratch.
4. `StudioPatchbayRoutingService` y `SignalBus` requerían garantizar entrega única de eventos (idempotencia contra doble entrega) y atenuación de ganancia/mute consistente en todos los módulos del rack.

## Decisión
1. **Síntesis y SoundFont en Tiempo Real:**
   - Conectar la generación de bloques estéreo de `PolyphonicVoicePool` al flujo de renderizado de `StemAudioSynthesizer`.
   - Garantizar interpolación lineal en muestreo PCM de regiones SF2 con soporte completo para zonas globales y parámetros de Release.
2. **Auto-Tune Vocal TD-PSOLA Riguroso:**
   - Implementar ventanas Hann simétricas centradas en las marcas de pitch de la fundamental con solapamiento 50% OLA (Overlap-Add) continuo.
   - Preservar formantes vocales aplicando escalamiento temporal en el dominio del tiempo puro sin transformar el espectro armónico de envolvente.
3. **Consola DJ y Motor de Audio en Disco:**
   - Habilitar grabación real de sesión DJ en disco local codificada en PCM 16-bit estéreo a 44.1 kHz.
   - Procesar filtros EQ de 3 bandas mediante biquads dedicados con curvas shelving e interpolación en caliente de parámetros.
4. **Matriz Patchbay y Bus Modular:**
   - Garantizar unicidad de entrega en `SignalBus` indexando conexiones por pares fuente-destino normalizados.
   - Soporte para eventos de mute y atenuación de señal sin degradación de rendimiento.

## Consecuencias
- **Positivas:**
  - Rendimiento sonoro profesional sin distorsión ni saltos audibles en la síntesis y en el pitch-shifter vocal.
  - La Consola DJ y el Estudio de Grabación operan como un DAW completo e independiente en el dispositivo.
  - Cero dependencias externas y 100% de ejecución offline en Dart puro.
- **Negativas / Desafíos:**
  - Mayor consumo de CPU en algoritmos TD-PSOLA continuos; se mitiga optimizando bucles internos en Dart con arreglos tipados (`Float32List`).
