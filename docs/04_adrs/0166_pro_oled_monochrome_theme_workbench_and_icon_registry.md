# ADR-0166: Tema Por Defecto OLED Monochrome, Hub Técnico Pro-DAW y Registro Progresivo de Iconos

- **Estado:** `Accepted`
- **Fecha:** `2026-11-22`
- **Fase:** `Fase 6 / v1.0 Visual Polish`

## Contexto
La auditoría visual del creador sobre la build v1.0 en Linux detectó que la pantalla inicial (`HomeDashboardScreen`) y los acentos verde neón/cian heredados proyectaban una estética genérica de dashboard web HTML, y que los iconos estándar de Material (`Icons.*`) restaban identidad de herramienta profesional de primera línea. Además, el creador generará sus propios iconos inicialmente en formato **PNG optimizado** y los reemplazará gradualmente por **SVG**.

## Decisión
1. Incorporar `StudioDesignTokens.studioOledMonochrome` (`id: 'studio_oled_monochrome'`) como tema por defecto de `StudioThemeController`, basado en Negro OLED (`#000000` / `#07080A`), paneles grafito (`#0D0F12`), bordes `1px` (`#22262E`) y tipografía/acentos monocromáticos plata (`#F5F7FA` / `#E2E6EE`), reservando los colores semánticos exclusivamente para telemetría de audio/DSP.
2. Crear `StudioIconCatalog` y el átomo `StudioIcon` en `lib/core/design_system/` con 44 identificadores canónicos (`StudioIconId`) y resolución progresiva `SVG -> PNG (assets/icons/png/) -> IconData` de respaldo.
3. Rediseñar `HomeDashboardScreen` eliminando las tarjetas grandes tipo SaaS y sustituyéndolas por un **Project Hub & Rack Launcher técnico de alta densidad** alineado a `StudioDesignTokens` (sin colores neón hardcoded).

## Consecuencias
- **Positivas:** Identidad visual sobria y profesional en toda la shell; transición cero-fricción desde PNG optimizados a SVG conforme el creador entregue los assets; compatibilidad total con los 4 temas de `StudioDesignTokens`.
- **Negativas / Trade-offs:** Mientras no existan los archivos físicos en `assets/icons/png/`, `StudioIcon` mostrará el `IconData` de respaldo; se requiere declarar `assets/icons/png/` en `pubspec.yaml`.
