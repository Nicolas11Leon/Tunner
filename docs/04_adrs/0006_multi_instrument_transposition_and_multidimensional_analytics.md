# ADR-0006: Multi-Instrument Transposition and Multi-Dimensional Performance Analytics

---

## Metadatos del Registro

- **ID del Registro:** `ADR-0006`
- **Título:** `Transposición Multi-Instrumento y Analítica Multidimensional de Interpretación`
- **Estado:** `Approved`
- **Fecha de Decisión:** `2026-10-24`
- **Fase Asociada:** `Fase 3 & Fase 4`
- **Autor / Arquitecto:** `Nicolas Leon (Mantenedor Principal)`
- **Casos de Uso Relacionados:** `docs/02_use_cases/10_uc_multi_instrument_transposition_and_multidimensional_metrics.md`

---

## 1. Contexto y Problemática

El análisis de ejecución musical no puede reducirse a una simple verificación binaria de acierto o fallo. En la práctica real de conservatorio:
1. **Instrumentos Transpositores:** Trompetas, clarinetes, saxofones y cornos leen partituras en tonos transpuestos respecto al sonido real captado por el micrófono (*Concert Pitch*). Si el software no transpone automáticamente, los instrumentistas de viento no pueden utilizar la aplicación sin reescribir manualmente cada partitura.
2. **Dimensiones de Interpretación:** Un músico necesita evaluar:
   - **Afinación:** Desvío de cents y estabilidad de afinación (vibrato / jitter).
   - **Tempo & Ataque:** Latencia temporal en milisegundos y tendencia rítmica: si tiende a adelantarse (*rushing*) o a retrasarse (*dragging*).
   - **Sostenimiento (Sustain):** Si sostiene las notas durante el 100% de su valor o las acorta indebidamente.

---

## 2. Decisión Arquitectónica

Se aprueba la implementación de dos pilares desacoplados bajo Clean Architecture:

1. **Feature `lib/features/instrument/`:**
   - **Dominio Puro (`domain/`):**
     - `InstrumentKey`: Clave tonal del instrumento (`concertC`, `bFlat`, `eFlat`, `fKey`, `bassC`).
     - `InstrumentProfileEntity`: Modelo inmutable que encapsula nombre del instrumento, familia (maderas, metales, cuerdas, voz), clave tonal, desplazamiento de semitonos de transposición y rango de frecuencias mín/máx.
     - `IInstrumentTranspositionService`: Contrato abstracto para convertir notas escritas a notas sonoras (*sounding pitch*) y viceversa.
   - **Datos (`data/`):**
     - `InstrumentTranspositionService`: Implementación canónica con cálculo semitonal exacto sobre el círculo de quintas / escala cromática temperada de 12 tonos.

2. **Extensión Multidimensional de `lib/features/practice_evaluator/`:**
   - `TempoDriftTendency`: Clasificación de tendencia rítmica acumulada (`stable`, `rushing`, `dragging`).
   - `sustainRatioPercentage`: Métrica de duración de nota sostenida vs. duración teórica.
   - Ponderación de calificación integral de 4 factores:
     $$\text{Puntaje} = (\text{Afinación} \times 0.45) + (\text{Tempo} \times 0.30) + (\text{Sostenimiento} \times 0.25)$$

---

## 3. Consecuencias y Beneficios

### Positivas:
- **Universalidad Instrumental:** Trompetistas, saxofonistas, clarinetistas, cornistas, flautistas, cantantes y chelistas pueden utilizar la misma partitura sin conversión manual.
- **Pedagogía Cuantitativa Profunda:** El reporte post-estudio diagnostica si el alumno corre en el tempo o si "pica" las notas antes de tiempo.
- **100% Offline & Pure Dart:** Cero dependencias nativas complejas; transposición y métricas ejecutadas en tiempo $O(1)$.
