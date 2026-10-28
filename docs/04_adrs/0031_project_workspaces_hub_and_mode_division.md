# ADR 0031: Arquitectura de Hub de Espacios de Trabajo y Desacoplamiento de Vistas

## Estado
Aprobado

## Contexto
A medida que **Tunner** incorporó capacidades profesionales avanzadas (DSP de afinación, metrónomo anti-bleed, motor andragógico/pedagógico, visor y descomponedor de partituras, laboratorio espectral, importador universal, analizador de acordes y dron armónico), la pantalla principal `TunerScreen` concentró más de 1600 líneas de código y hasta 15 botones y medidores simultáneos.
Esta saturación introduce sobrecarga cognitiva extrínseca (Sweller) y diluye la experiencia del usuario según su rol primario:
- Estudiantes que solo requieren afinador, metrónomo y feedback biomecánico.
- Compositores que precisan el pentagrama interactivo, descomposición a partituras y herramientas de edición/notación.
- Productores e ingenieros acústicos que requieren espectrogramas FFT, análisis de acordes, temperamentos históricos y calibración de cámara A4.

## Decisión
1. Definir un modelo de dominio puro `WorkspaceType` con tres valores: `learning`, `composition`, `production`.
2. Modelar `WorkspaceConfigurationEntity` para encapsular la configuración y metadatos de cada espacio.
3. Incorporar `activeWorkspace` en `AppUserSettingsEntity` para almacenamiento local offline automático.
4. Desacoplar la interfaz de usuario en vistas especializadas por espacio:
   - `LearningPracticeWorkspaceView`
   - `CompositionNotationWorkspaceView`
   - `ProductionAcousticLabWorkspaceView`
5. Proveer un conmutador de espacios minimalista (`WorkspaceSwitchBar`) en la cabecera de la aplicación para navegación inmediata con un solo toque y transiciones fluidas.
6. Mantener retrocompatibilidad con las claves de prueba existentes para garantizar un 100% de éxito en la suite de pruebas automatizadas.

## Consecuencias
- **Positivas:**
  - Reducción drástica de la carga visual y complejidad mental para cada tipo de usuario.
  - Código desacoplado, modular y de alta cohesión.
  - Mayor mantenibilidad de cada espacio sin interferir con las herramientas de los otros modos.
- **Negativas / Mitigaciones:**
  - Requiere asegurar que las claves semánticas y widgets compartidos se sincronicen en el `TunerViewModel` sin crear bucles de refresco innecesarios.
