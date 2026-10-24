# ADR-0005: Interactive Practice Evaluator and Performance Analytics Architecture

---

## Metadatos del Registro

- **ID del Registro:** `ADR-0005`
- **Título:** `Arquitectura del Evaluador de Práctica Interactivo y Analítica de Desempeño`
- **Estado:** `Approved`
- **Fecha de Decisión:** `2026-10-24`
- **Fase Asociada:** `Fase 3 & Fase 4`
- **Autor / Arquitecto:** `Nicolas Leon (Mantenedor Principal)`
- **Casos de Uso Relacionados:** `docs/02_use_cases/09_uc_practice_evaluation_and_performance_analytics.md`

---

## 1. Contexto y Problemática

El software de práctica musical tradicional suele operar de forma pasiva (un metrónomo que suena en segundo plano o una partitura fija). Para que un estudiante alcance un nivel superior sin un profesor presente físicamente, necesita:
1. Conocer si cada nota ejecutada estuvo afinada (en cents) y a tiempo.
2. Contar con un modo de "Espera Inteligente" (*Smart Wait*) que no lo deje atrás si se equivoca de digitación o nota.
3. Recibir una evaluación cuantitativa global al terminar cada sesión de práctica con indicadores de tendencia (mejora o desvío respecto a sesiones anteriores).

El desafío técnico consiste en evaluar continuamente la corriente de audio entrante contra las notas del pentagrama a 60/120 FPS sin generar sobrecarga en el hilo de interfaz ni violar las reglas de Clean Architecture.

---

## 2. Decisión Arquitectónica

Se aprueba la incorporación del módulo `lib/features/practice_evaluator/` bajo **Feature-First Clean Architecture**:

1. **Capa de Dominio (`lib/features/practice_evaluator/domain/`):**
   - Pureza absoluta de Dart: Cero dependencias de Flutter o plugins.
   - Entidad `NoteEvaluation`: Modela la comparación entre la nota esperada y la detectada, incluyendo desvío en cents, latencia temporal ($ms$), calificación porcentual y estado booleano de acierto (`isHit`).
   - Entidad `PracticeReport`: Compila las métricas globales de una sesión: porcentaje de afinación, precisión rítmica, promedio de cents, notas con mayor dificultad (*critical notes*), calificación de conservatorio (*Grade*: S, A, B, C, D) y marca temporal.
   - Entidad `HistoricalProgress`: Computa el delta de tendencia cuantitativa ($\Delta\%$) comparando la sesión actual contra el promedio histórico.
   - Contrato `IPracticeEvaluatorService`: Define la interfaz de cálculo determinista para desacoplar la lógica matemática de la presentación.

2. **Capa de Datos / Infraestructura (`lib/features/practice_evaluator/data/`):**
   - `PracticeEvaluatorService`: Implementación canónica de `IPracticeEvaluatorService` que aplica ponderaciones matemáticas transparentes:
     $$\text{Afinación} = \max\left(0, 100 - \frac{|\text{cents}|}{\text{tolerancia}} \times 50\right)$$

3. **Capa de Presentación (`lib/features/practice_evaluator/presentation/`):**
   - `PracticeReportModal`: Componente de diálogo analítico ultra-premium que presenta gráficos circulares de precisión, el sello de calificación y el análisis de tendencia con estética coherente al `TunnerTheme`.

---

## 3. Consecuencias y Beneficios

### Positivas:
- **Zero-Latency In-Memory:** Todas las evaluaciones se realizan localmente en microsegundos, permitiendo feedback visual instantáneo.
- **Trazabilidad Pedagógica:** El estudiante obtiene retroalimentación accionable inmediata al finalizar cada pieza musical.
- **Testabilidad Exhaustiva:** Las fórmulas de evaluación, cálculo de notas críticas y comparación histórica se prueban con pruebas unitarias de dominio puras.

### Negativas / Mitigaciones:
- *Riesgo:* Ruido ambiental o silencios entre notas podrían falsear la calificación.  
  *Mitigación:* Se implementa un filtro de silencio (descarte de frames sin detección de $F_0$) para calificar únicamente los eventos con emisión sonora activa.
