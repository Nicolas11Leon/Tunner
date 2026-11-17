# ADR 0065: Sistema de Diseño Atomizado Independiente de la Lógica Funcional (Adobe Studio Style)

- **Estado:** Aceptado
- **Fecha:** 2026-11-15
- **Contexto Relacionado:** [DOC-UI-2026-071](../01_product_vision/doc_adobe_spectrum_atomized_design_system.md)

---

## 1. Contexto

El usuario solicitó elevar la calidad visual de Tunner a un estándar profesional estilo **Adobe (Photoshop / Audition / Premiere Pro)**, sin emojis, con paneles técnicos limpios y **100% atomizado** para poder cambiar el estilo visual de manera completamente independiente a las funciones.

## 2. Decisión Arquitectónica

1. **Separación Estricta Tokens vs. Lógica:**
   Se crea `lib/core/design_system/` con `StudioDesignTokens` inmutable, `StudioThemeController` y `StudioThemeScope` (`InheritedNotifier`), totalmente agnósticos a cualquier feature (`dj_console`, `media_vault`, `tuner`, etc.).
2. **Componentes Atómicos Únicos (`atoms/`):**
   Se crean `StudioPanel`, `StudioToolbar`, `StudioButton`, `StudioToggleChip` y `StudioBadge`. Las vistas funcionales consumen estos átomos en lugar de instanciar `Card`, `ElevatedButton` o colores literales.
3. **Estética Adobe Spectrum:**
   Paleta base neutra (`#1E1E1E`, `#252526`, `#2D2D30`, bordes `1px` `#3E3E42`, acento `#1473E6`, radios `2px–4px`, métricas tabulares).

## 3. Consecuencias

### Positivas
- Cambiar o agregar skins (`Adobe Dark`, `Adobe Darkest`, `Adobe Light`, etc.) no requiere modificar ningún ViewModel ni lógica de negocio.
- Consistencia visual inmediata de grado estudio profesional en todas las herramientas migradas.

### Negativas / Compromisos
- Requiere migrar progresivamente las vistas legadas para que adopten los átomos de `lib/core/design_system/`.
