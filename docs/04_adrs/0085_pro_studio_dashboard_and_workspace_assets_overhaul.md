# ADR 0085: Rediseño Pro del Dashboard de Inicio y Activos de Espacio de Trabajo

- **Estado:** Aceptado
- **Fecha:** 2026-11-16
- **Contexto:** Ergonomía de Usuario, Accesibilidad de la Consola DJ y Fidelidad Visual del Explorador
- **Fase:** Fase 1 / Consolidación de Experiencia y Estética de Estudio

---

## 1. Contexto

Durante las pruebas manuales sobre la pantalla principal de Tunner (`HomeDashboardScreen`), se evidenciaron debilidades ergonómicas y estéticas:
1. La **Consola DJ Pro Workstation**, desarrollada intensivamente en fases previas, no figuraba en la lista de módulos principales del dashboard; solo existía como una pequeña pestaña superior o un elemento secundario en la barra lateral.
2. En resoluciones de escritorio (pantallas anchas de 1080p), los módulos se desplegaban en una columna estrecha y vertical, dejando más del 50% de la pantalla como un fondo plano y vacío.
3. El árbol `Documentos del Proyecto` en la barra lateral lateralizaba conteos `(0)` en todas sus carpetas, transmitiendo una sensación de estado vacío e inacabado al usuario novato.

---

## 2. Decisión

Se adopta una refactorización de presentación y de inicialización de datos en el ViewModel:
1. **Inclusión de Consola DJ Pro en Inicio:** Agregar `card_action_dj` a la lista de módulos de `HomeDashboardScreen` conectada a `onNavigateToTab(5)`.
2. **Rejilla Responsiva de Estudio:** Emplear una distribución de cuadrícula de 2 columnas para pantallas de escritorio con tarjetas mejoradas que incluyen gradientes oscuros sutiles, micro-bordes de alta definición y micro-métricas.
3. **Población Inicial de Activos:** Asegurar que `TunerViewModel` inicialice `_workspaceScores` con las 3 partituras maestras de la biblioteca curada, `_recordingHistory` con 2 tomas de referencia y `_customTuningPresets` con 2 presets históricos estándar.
4. **Interactividad Sonora en Instrumento Activo:** Permitir la audición inmediata del diapasón de referencia sin abandonar la pantalla de inicio.

---

## 3. Consecuencias

### Positivas
- Acceso inmediato y prominente a todas las suites de trabajo (Afinador, Lecciones, Rack, Partituras y Consola DJ).
- El software aprovecha las pantallas panorámicas de escritorio con estética de DAW profesional.
- El explorador de proyectos lateral muestra contenido real listo para ser probado.

### Negativas / Mitigaciones
- La adición de elementos por defecto en el ViewModel no debe sobreescribir las preferencias guardadas del usuario.
  *Mitigación:* La inicialización por defecto solo se activa si la lista deserializada de persistencia se encuentra vacía.
