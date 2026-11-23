# Plan de Implementación: Estética Pro OLED Monochrome, Hub Técnico y Sistema Progresivo de Iconos

## Metadatos del Plan

- **ID del Plan:** `PLAN-F6-UI-OLED-2026-174`
- **Título de la Implementación:** `Sistema Visual OLED Monochrome, Rediseño Técnico de HomeDashboardScreen y Registro Progresivo StudioIcon`
- **Fase del Proyecto:** `Fase 6 (v1.0 Visual Polish)`
- **Estado:** `Aprobado`
- **ADR Relacionado:** [ADR-0166](../04_adrs/0166_pro_oled_monochrome_theme_workbench_and_icon_registry.md)
- **Documento Funcional Base:** [pro_oled_workbench_and_icon_system.md](../01_architecture/pro_oled_workbench_and_icon_system.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Elevar la calidad visual de **Tunner v1.0** al estándar de herramientas profesionales de escritorio (Unity / Adobe / Logic Pro) mediante un tema Negro OLED Monocromático por defecto, la eliminación de tarjetas web genéricas en `HomeDashboardScreen`, y un sistema desacoplado de iconografía (`StudioIcon`) listo para PNGs optimizados y futura migración a SVG.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - `pubspec.yaml` y directorio `assets/icons/png/` (con `.gitkeep` y `README.md` de especificación de assets).
  - `lib/core/design_system/studio_design_tokens.dart` y `studio_theme_provider.dart` (`studioOledMonochrome` como default).
  - `lib/core/design_system/domain/studio_icon_catalog.dart` y `lib/core/design_system/atoms/studio_icon.dart` (44 iconos canónicos).
  - `lib/features/navigation/presentation/home_dashboard_screen.dart` (rediseño técnico Pro-DAW sin tarjetas SaaS ni colores neón hardcoded, usando `StudioIcon` y `StudioDesignTokens`).
  - Pruebas unitarias y de widget en `test/core/design_system/studio_icon_and_oled_theme_test.dart`.
- **Excluido (Out-of-Scope):**
  - Generación gráfica de los archivos PNG/SVG finales (responsabilidad del creador).
  - Refactorización de lógica de audio DSP, parsers o motores de dominio.

---

## 2. Análisis de Dependencias y Tecnologías

- **Flutter / Dart SDK:** Sin nuevas dependencias de terceros requeridas en esta fase (el soporte PNG usa `Image.asset` nativo de Flutter y `StudioIcon` expone gancho limpio para `flutter_svg` cuando se integren SVGs).
- **Riesgo Tecnológico:** Bajo. No altera hilos de audio ni `dart:ffi`.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio y Assets (`StudioIconCatalog` + `pubspec.yaml`)
- [ ] Declarar `assets/icons/png/` en `pubspec.yaml` y crear `assets/icons/png/README.md` con la lista exacta de los 44 nombres canónicos y especificación (`64x64` / `96x96` PNG transparente optimizado).
- [ ] Crear `StudioIconId` y `StudioIconCatalog` en `lib/core/design_system/domain/studio_icon_catalog.dart`.

### Paso 2: Sistema de Diseño y Átomo `StudioIcon`
- [ ] Añadir `StudioDesignTokens.studioOledMonochrome` en `studio_design_tokens.dart` e integrarlo en `availableThemes` y como default en `studio_theme_provider.dart`.
- [ ] Implementar `StudioIcon` en `lib/core/design_system/atoms/studio_icon.dart` con resolución `PNG -> fallback IconData` (y extensión preparada para SVG).

### Paso 3: Rediseño Técnico de `HomeDashboardScreen`
- [ ] Reemplazar el banner verde gigante, las 5 tarjetas SaaS y los chips neón por un **Workbench & Project Hub técnico**:
  - Cabecera compacta de instrumento activo y motor DSP con tipografía tabular.
  - Matriz técnica de módulos (`1px` hairlines, `radius: 2–4px`, `StudioIcon`, sin texto promocional ni flechas `->`).
  - Sección compacta de Plantillas Canónicas y Calibración Rápida coherente con OLED Monochrome.
- [ ] Preservar todos los `Key` y callbacks de navegación existentes.

### Paso 4: Pruebas y Verificación
- [ ] Crear `test/core/design_system/studio_icon_and_oled_theme_test.dart`.
- [ ] Ejecutar `flutter analyze --no-fatal-infos` y pruebas de navegación y design system.

---

## 4. Estrategia de Rollback
- **Punto de Restauración Git:** Branch `main` (`9485dcb`).
- **Mitigación Inmediata:** Reversión de la rama `feat/v1-pro-oled-workbench-and-icon-system` sin impacto en motores de audio o persistencia.

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Documentación técnica, `UC-174` y `ADR-0166` creados.
- [ ] `studioOledMonochrome` activo por defecto sin colores neón arbitrarios en el hub.
- [ ] `StudioIcon` con 44 IDs canónicos, carga de PNG desde `assets/icons/png/` y fallback seguro.
- [ ] `flutter analyze` y suite de tests en verde.
