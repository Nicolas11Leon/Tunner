# ADR 0034: Arquitectura del Módulo de Lecciones Guiadas Interactivas y Evaluación Paso a Paso

## Estado
Aprobado

## Contexto
En el espacio de trabajo de **Aprender**, los instrumentistas contaban con afinación continua libre, metrónomo interactivo y generador de ejercicios. Sin embargo, no existía una experiencia de aprendizaje guiado formal donde un estudiante (especialmente principiante o intermedio) reciba una meta explícita de práctica paso a paso con validación acústica objetiva de cada nota requerida.
La pedagogía musical moderna (Suzuki, Dalcroze) enfatiza el establecimiento de objetivos micro-conductuales medibles (ej. sostener una nota afinada durante $N$ segundos antes de pasar al siguiente grado de la escala).

## Decisión
1. **Modelado en la Capa de Dominio Puro (`lib/features/guided_lessons/domain/`):**
   - Crear entidades inmutables libres de dependencias de Flutter:
     - `GuidedLessonCategory`: Categorías formativas (Fundamentos, Notas Largas, Intervalos, Escalas, Afinación Fina).
     - `GuidedLessonStepEntity`: Modela cada paso con nota objetivo ($f_0$), duración requerida de sostenimiento, tolerancia de cents y consejos biomecánicos.
     - `GuidedLessonEntity`: Encapsula título, nivel de dificultad, categoría y lista inmutable de pasos.
     - `GuidedLessonProgressEntity`: Rastrea el estado en tiempo real (progreso acumulado en segundos, índice de paso actual, estado de validación y precisión).
   - `GuidedLessonEvaluator`:
     - Motor de cálculo matemático en Pure Dart que recibe cada muestra de afinación en tiempo real y actualiza el acumulador de sostenimiento únicamente si la nota emitida coincide con el objetivo y se ubica dentro de la tolerancia de cents.
   - `CuratedGuidedLessons`: Catálogo canónico predefinido de secuencias didácticas estructuradas por niveles (Principiante a Avanzado).
2. **Integración con el Perfil Pedagógico Adaptativo:**
   - La tolerancia en cents de cada paso se ajusta dinámicamente según el perfil del estudiante (`LearnerProfileEntity` y `centsTolerance`), aplicando andamiaje pedagógico (Scaffolding).
3. **Capa de Presentación Reactiva (`lib/features/guided_lessons/presentation/`):**
   - Implementar `GuidedLessonsModal` con selector de lecciones didácticas y visor de práctica paso a paso en vivo con anillo de progreso de sostenimiento y feedback biomecánico inmediato.
   - Integrar botón de acceso rápido `open_guided_lessons_chip` en `LearningPracticeWorkspaceView`.

## Consecuencias
- **Positivas:**
  - Experiencia pedagógica estructurada, guiada y gamificada sin salir del flujo de trabajo de afinación.
  - Mayor retención y reducción de frustración en estudiantes novatos y adultos principiantes.
  - Respeto total de Clean Architecture y ejecución 100% offline.
- **Negativas / Mitigaciones:**
  - Requiere sincronización precisa de temporizadores en milisegundos sin introducir bucles de busy-waiting; se implementa mediante cálculo delta-tiempo entre frames recibidos.
