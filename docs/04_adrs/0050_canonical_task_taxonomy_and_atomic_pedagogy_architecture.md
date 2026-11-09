# ADR 0050: Adopción del Sistema Canónico de Taxonomía de Tareas (TTC) y Salto Rápido ("Jump to Task")

- **Estado:** Accepted
- **Fecha:** 2026-11-09
- **Fase:** Fase 5 & Milestone 1.0 Global
- **Autor:** Tunner Architecture & Pedagogy Core Team

---

## 1. Contexto

Para que la suite de Tunner sea capaz de albergar miles de ejercicios y lecciones sin degradar la experiencia de usuario ni incurrir en acoplamientos entre herramientas, se requiere un sistema unificado para identificar, clasificar, indexar y lanzar cualquier tarea didáctica.

La navegación exclusivamente visual por pestañas o árboles de carpetas resulta lenta cuando un estudiante o profesor busca un ejercicio específico asignado en clase. Asimismo, la falta de una jerarquía común para representar tareas (ritmo, oído, afinación, lectura, armonía) fragmentaría el código fuente.

---

## 2. Decisión

1. **Adopción del Código TTC (`TaskTaxonomyCode`):**
   - Se establece la estructura fija: `[DOMINIO].[NIVEL].[SUBTIPO].[SECUENCIAL]` (ej: `EAR.01.INTV.001`).
   - El código se modela como un Value Object inmutable en Pure Dart con validación regex y soporte `Comparable`.
2. **Índice en Memoria de Alta Velocidad (`TaskCatalogIndex`):**
   - Se crea una estructura de índice en memoria local que organiza las tareas por clave primaria de código, prefijo de dominio, nivel de dificultad y etiquetas de búsqueda, logrando tiempos de respuesta de filtrado en $< 0.5\text{ ms}$.
3. **Mecanismo de Salto Rápido (*Jump to Task* vía tecla `J`):**
   - Se implementa el modal `TaskQuickJumpModal` vinculado al atajo de teclado universal `J` y `Cmd+J`. Permite saltar a cualquier lección escribiendo su código o número y presionando `Enter`.
4. **Diseño Atómico de UI Heredable:**
   - Se construyen componentes y widgets base abstractos (`TaskCardBase`, `TaskBadgeAtom`, `TaskLevelPill`), garantizando que cualquier nuevo tipo de tarea implemente o extienda la misma base visual y de interacción sin duplicar código.

---

## 3. Consecuencias

### Positivas:
- **Escalabilidad Ilimitada:** El catálogo soporta hasta $999$ tareas por cada subtipo, permitiendo decenas de miles de tareas sin colisiones.
- **Eficiencia Cognitiva Máxima:** Los usuarios y docentes pueden referenciar, buscar y ejecutar ejercicios en 1 segundo usando códigos compactos.
- **Adherencia a SOLID & Clean Architecture:** El dominio es 100% puro Dart; la presentación es modular y reutilizable.

### Mitigaciones:
- Para evitar colisiones con atajos de texto cuando se escribe en campos de formulario, el atajo `J` solo se activa cuando ningún campo de texto tiene el foco de edición del sistema.
