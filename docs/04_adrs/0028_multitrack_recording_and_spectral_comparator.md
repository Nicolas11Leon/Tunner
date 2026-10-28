# ADR 0028: Arquitectura de Grabación Multi-Pista y Comparador Visual Espectral de Tomas

## Estado
Aprobado

## Contexto
En la metodología pedagógica de conservatorio, la autoevaluación instrumental requiere contrastar el desempeño actual contra tomas previas para validar mejoras en afinación, regularidad tímbrica y estabilidad dinámica. La arquitectura actual de Tunner contaba con grabación de tomas individuales lineales (`PracticeRecordingEntity`) y visualización espectral estática (`HarmonicSeriesAnalyzer`), pero carecía de una estructura multi-pista estructurada y de un motor que correlacione temporalmente dos tomas y renderice un comparador visual con métricas diferenciales objetivas.

Se requerían tres capacidades esenciales:
1. Agrupación de tomas en sesiones multi-pista con controles individuales de pista (Mute, Solo, Ganancia).
2. Estructuras de datos puras de dominio para almacenar muestras discretas de afinación (cents) y centroide tímbrico asociadas a marcas de tiempo.
3. Un algoritmo diferencial en memoria que calcule estabilidad de cents, brillo espectral y correlación rítmica, junto con un `CustomPainter` vectorial que superponga las curvas sin jank ni caídas de fotogramas.

## Decisión
1. **Entidades Inmutables de Dominio Puro:**
   - Crear `MultiTrackSessionEntity`, `PracticeTakeEntity`, `TimedPitchSample` y `TimedSpectralSample` en `lib/features/practice_recorder/domain/`.
   - Garantizar cero dependencias de Flutter UI en estas estructuras para permitir pruebas unitarias matemáticas aisladas y deterministas.
2. **Servicio de Comparación Espectral y Tonal:**
   - Implementar `SpectralComparatorService` con métodos de interpolación temporal y evaluación estadística ($\bar{\epsilon}_A$, $\bar{\epsilon}_B$, $\Delta_{\text{estabilidad}}$, $\Delta_{\text{centroide}}$).
   - Manejar tomas de longitud variable mediante remuestreo lineal o acotación al horizonte temporal común.
3. **Lienzo Gráfico Vectorial Sincronizado:**
   - Implementar `SpectralComparatorPainter` en `lib/features/practice_recorder/presentation/` que dibuje una rejilla con línea central en 0 cents, bandas de tolerancia de conservatorio ($\pm 5$ y $\pm 15$ cents) y curvas poligonales suavizadas para la Toma A y la Toma B con paletas temáticas dinámicas.
4. **Orquestación en TunerViewModel:**
   - Integrar la gestión de la sesión multi-pista activa, permitiendo registrar nuevas tomas en caliente y conmutar la audición entre tomas (Audición A/B).

## Consecuencias

### Positivas
- Permite a estudiantes y docentes visualizar de inmediato si un intervalo específico mejoró en precisión entre intentos consecutivos.
- Cero latencia de procesamiento al operar completamente en memoria y 100% offline.
- Total compatibilidad con el sistema de temas estéticos (`TunnerThemePalette`).

### Negativas / Mitigaciones
- El almacenamiento de múltiples tomas con muestras de tono y espectro incrementa el consumo de memoria en sesiones largas.  
  *Mitigación:* Se implementa decimación temporal de muestras (máximo 1 muestra cada 20 ms, o 50 Hz de tasa de muestreo para las curvas de pitch), reduciendo el peso en memoria a unos pocos kilobytes por toma.
