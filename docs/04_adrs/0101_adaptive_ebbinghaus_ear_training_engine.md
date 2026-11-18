# Registro de Decisión de Arquitectura (ADR) 0101: Motor Adaptativo de Entrenamiento Auditivo con Curva de Ebbinghaus

---

## Metadatos

- **ID del ADR:** `ADR-0101`
- **Título:** Motor Cognitivo de Repetición Espaciada para Entrenamiento Auditivo e Intervalos Basado en la Curva de Retención de Ebbinghaus
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 8`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 112](../02_use_cases/112_uc_adaptive_ebbinghaus_ear_training_engine.md)
- **Plan Relacionado:** [Plan Épica 8.1](../05_implementation_plans/plan_adaptive_ebbinghaus_ear_training.md)
- **Issue Asociado:** [#39](https://github.com/Nicolas11Leon/Tunner/issues/39)

---

## 1. Contexto

El entrenamiento auditivo en la educación musical formal (solfeo, afinación de intervalos, discriminación microtonal) sufre a menudo del síndrome de práctica aleatoria o intensiva de corto plazo (*massed practice*), donde el estudiante olvida rápidamente los intervalos menos familiares. 

Para lograr memoria auditiva permanente e infalible (oído absoluto y relativo de alta precisión), se requiere planificar las sesiones según el modelo neurocognitivo de la memoria a largo plazo modelado por Hermann Ebbinghaus y enriquecido con algoritmos de repetición espaciada continua.

Restricciones no negociables:
1. **Clean Architecture:** Capa de dominio pura en `lib/features/pedagogy/domain/` sin dependencias de Flutter UI, plugins externos ni bases de datos remotas.
2. **Determinismo y Rendimiento:** Cómputo matemático instantáneo de retención $R(t) = e^{-t/S}$ y actualización del factor de facilidad sin bloqueos de hilo ni operaciones asíncronas pesadas.
3. **Ponderación Acústica:** El algoritmo no debe ser un simple contador binario acierto/fallo, sino considerar la desviación en microcents y la latencia cognitiva de reconocimiento.

---

## 2. Decisión

Se decide implementar un **Motor de Repetición Espaciada Paramétrico en Dart Puro** compuesto por:

1. **`EarTrainingItemEntity`:**
   - Entidad inmutable que modela cada ítem pedagógico (intervalo melódico, intervalo armónico, acorde, microtono).
   - Atributos: `id`, `name`, `category`, `baseFrequencyHz`, `targetFrequencyHz`, `stabilityDays` ($S$), `easeFactor` ($\text{EF}$), `consecutiveCorrectAnswers`, `totalAttempts`, `lastReviewedAt`, `nextReviewDue`, `averageCentsError`.

2. **`EbbinghausSpacedRepetitionEngine`:**
   - Cálculo analítico de retención proyectada: $R(t) = e^{-t / S}$.
   - Algoritmo de calificación de calidad $q \in [0, 5]$ combinando acierto binario, proximidad microtonal ($\Delta \text{cents}$) y tiempo de respuesta ($T_{\text{response}}$).
   - Actualización adaptativa del factor de facilidad ($\text{EF}'$) y de la estabilidad ($S_{n} = S_{n-1} \cdot \text{EF}'$).
   - Filtro inteligente de ítems vencidos (`getDueItems`) ordenados por prioridad de retención crítica ($R \le 0.90$).

3. **Integración con Terminal Tunner OS:**
   - Incorporación del comando `train` en `TunnerOsKernel` (`train review`, `train status`, `train submit <id> <grade>`).

---

## 3. Consecuencias

### Positivas
- **Eficiencia Cognitiva Máxima:** Los intervalos más difíciles para el estudiante se repiten con alta frecuencia, mientras que los ya consolidados se espacian exponencialmente.
- **Portabilidad Absoluta:** Al residir en el dominio puro de Dart, puede ejecutarse offline, en CLI, en web o en dispositivos móviles sin cambios en el código.
- **Sincronización con el Sintetizador del Estudio:** Los ítems pedagógicos son ejecutables directamente a través de los generadores de síntesis o el teclado maestro.

### Negativas / Mitigaciones
- **Dependencia de la Hora del Sistema:** El cálculo de $t$ depende del reloj local (`DateTime.now()`). Se permite inyectar un proveedor de tiempo abstracto para pruebas unitarias deterministas.
