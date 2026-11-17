# ADR 0069: Neutralización de Marcas Propietarias y Adopción de Tunner Studio Design System

## Estado
Aprobado

## Fecha
2026-11-16

## Contexto
Durante las fases iniciales de diseño y maquetación de la estación de trabajo desktop, se utilizaron provisionalmente nombres comerciales de terceros (como "Adobe", "Adobe Dark", "Adobe Spectrum") para categorizar las paletas mates de bajo brillo inspiradas en el software de producción digital profesional.
Para evitar cualquier conflicto de propiedad intelectual, infracción de marcas registradas o confusión de identidad de producto, es imperativo eliminar cualquier referencia a marcas comerciales ajenas tanto de la interfaz gráfica orientada al usuario como de los tokens del código fuente.

## Decisión
1. **Renombramiento de Paletas de Tokens:**
   - `adobeSpectrumDark` $\rightarrow$ `studioDark` (nombre visible: `Studio Dark`, id: `studio_dark`).
   - `adobeSpectrumDarkest` $\rightarrow$ `studioObsidian` (nombre visible: `Studio Obsidian`, id: `studio_obsidian`).
   - `adobeSpectrumLight` $\rightarrow$ `studioLight` (nombre visible: `Studio Light`, id: `studio_light`).
2. **Reemplazo en la Interfaz Gráfica:**
   - La insignia del conmutador de tema superior ahora muestra `Studio Dark` en lugar de `Adobe Dark`.
   - El selector de bases temáticas en el editor de personalización ahora muestra `Studio Slate Dark`.
3. **Depuración de Documentación y Comentarios:**
   - Se actualizan todos los comentarios en el sistema de diseño para referirse a estándares generales de estaciones de trabajo de audio digital (DAWs profesionales) y al propio *Tunner Studio Design System*.

## Consecuencias
- **Positivas:**
  - Plena conformidad legal y de propiedad intelectual.
  - Identidad de marca sólida y propia para el proyecto **Tunner**.
  - Código y comentarios 100% neutrales y profesionales.
- **Negativas / Desafíos:**
  - Actualización sincronizada de pruebas unitarias que validaban cadenas de texto específicas.
