# ADR 0053: Arquitectura del Afinador Inteligente por Reconocimiento Tímbrico y Adaptación Acústica

## Estado
Aprobado (Approved) - 2026-11-09

## Contexto
El afinador de Tunner cuenta con soporte para más de 60 instrumentos, transposición automática y filtros acústicos pasa-altos y de histéresis. Sin embargo, los músicos deben seleccionar manualmente su instrumento en listas o atajos de teclado (`Cmd+I`). Diseñar un motor de reconocimiento tímbrico que identifique de forma pasiva el instrumento a partir del análisis de sobretonos armónicos y adapte el afinador automáticamente eleva a Tunner a un nivel de vanguardia único en la industria.

## Decisión
1. **Creación del Servicio de Dominio Puro `SmartInstrumentDetector`:**
   - Ubicado en `lib/features/instrument/domain/smart_instrument_detector.dart`.
   - Modela `AcousticSignature` y `SmartInstrumentMatch`.
   - Algoritmo determinista y sin dependencias de machine learning externo en red (100% offline-first en Dart puro, tiempo de cálculo $< 1\text{ ms}$).
2. **Integración Bidireccional en `TunerViewModel`:**
   - Incorpora la bandera `isSmartInstrumentTuningActive` y el modo `autoSwitchInstrument`.
   - Se conecta al flujo de procesamiento de frames de pitch y espectrograma.
   - Sincroniza automáticamente los filtros del afinador MPM y el patch del sintetizador SoundFont (`selectSoundFontPatch`).
3. **Indicador de Sinergia Visual:**
   - Se expone `SmartInstrumentBadge` en la interfaz del afinador para dar feedback transparente al músico.

## Consecuencias

### Positivas
- **Cero Fricción para el Músico:** El usuario toma su instrumento, toca una nota, y la aplicación se auto-configura instantáneamente.
- **Mayor Precisión de Afinación:** Los filtros pasa-altos y pasa-bajos sintonizados al instrumento eliminan falsos positivos causados por ruidos externos o resonancias de la sala.
- **Simpatía Auditiva:** El diapasón y el tono de referencia suenan con el timbre real del instrumento (ej. violonchelo para chelistas, trompeta para trompetistas).

### Negativas / Mitigaciones
- **Falsas Detecciones en Notas Aisladas:** Un unísono puro de baja energía puede sonar similar entre flauta y soprano. *Mitigación:* Se exige un umbral de confianza $\ge 0.85$ y confirmación multi-frame antes de conmutar automáticamente.
