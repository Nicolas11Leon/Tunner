# Especificación Técnica: Sistema Pro OLED Monochrome, Workbench Directo y Registro Progresivo de Iconos

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-174`
- **Título Oficial:** `Sistema Visual OLED Monochrome, Rediseño Pro-DAW del Workbench y Registro Progresivo de Iconografía (PNG -> SVG)`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-22`
- **Última Modificación:** `2026-11-22`
- **Fase Asociada:** `Fase 6 / v1.0 Visual Polish`
- **Autor / Revisor Principal:** `Nicolas Leon / Antigravity`

---

## 1. Resumen Ejecutivo (Executive Summary)

Esta especificación define la evolución estética y estructural de **Tunner v1.0** para transformar la interfaz de usuario desde un esquema de tarjetas web genéricas hacia una estación de trabajo de audio digital (DAW / IDE Pro) de alta densidad inspirada en herramientas de primera línea (Unity Pro, Adobe Audition, Logic Pro).

Se introducen tres pilares coordinados: (1) un tema por defecto **Negro OLED + Blanco/Plata Monocromático** (`studioOledMonochrome`) que elimina el ruido cromático y reserva el color estrictamente para telemetría DSP activa; (2) un **Registro Progresivo de Iconografía (`StudioIconRegistry` + `StudioIcon`)** que permite al creador incorporar iconos propios en formato **PNG optimizado** y migrarlos gradualmente a **SVG vectorial** sin modificar código de UI; y (3) la reestructuración de `HomeDashboardScreen` desde tarjetas promocionales hacia un **Workbench Pro / Project Hub técnico** con costuras de `1px`, tipografía tabular y acceso directo a telemetría e instrumentos.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
1. **Estética genérica tipo dashboard HTML:** `HomeDashboardScreen` renderizaba 5 tarjetas grandes con descripciones textuales, badges de colores saturados y enlaces `Abrir X ->`, junto con un banner verde saturado para el instrumento activo y botones cian hardcoded (`0xFF00E5FF`).
2. **Dependencia total de `Material Icons`:** Los 915 usos de `Icons.*` (308 nombres distintos con duplicación de variantes `_rounded`/`_outlined`) restan identidad visual propia a la herramienta.
3. **Transición gradual de assets:** El creador producirá los iconos personalizados inicialmente en PNG optimizado (bajo peso) y los reemplazará progresivamente por SVG vectoriales, por lo que la UI debe desacoplarse completamente del formato concreto del asset.

### 2.2 Fundamento Visual y Ergonómico
- **Jerarquía de Luminancia OLED:** Fondo base `#000000` / `#07080A`, paneles `#0D0F12`, cabeceras `#12151A`, elevación `#181B22` y divisores `1px` `#22262E`.
- **Acento Monocromático y Telemetría Estricta:** Controles, tabs y botones primarios usan alto contraste plata/blanco (`#E6E9EF` / `#9CA3AF`), mientras que verde (`#22C55E`), ámbar (`#F59E0B`) y rojo (`#EF4444`) se restringen exclusivamente a vúmetros, LEDs de estado DSP y desviación en cents.

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos
- **REQ-01 (Tema OLED Monochrome por Defecto):** `StudioDesignTokens.studioOledMonochrome` (`id: 'studio_oled_monochrome'`) debe estar registrado como tema por defecto en `StudioThemeController`, manteniendo `studioDark`, `studioObsidian` y `studioLight` disponibles.
- **REQ-02 (Catálogo Canónico de Iconos):** Definir un enum/registro canónico `StudioIconId` con los 44 identificadores semánticos que unifican los 308 iconos Material de la aplicación en 4 bloques (`module_*`, `transport_*`/`audio_*`, `file_*`/`tool_*`, `ui_*`).
- **REQ-03 (Resolución Progresiva PNG -> SVG -> Fallback):** El widget `StudioIcon` debe intentar resolver en orden: (a) SVG en `assets/icons/svg/<id>.svg` cuando el adaptador SVG esté habilitado, (b) PNG optimizado en `assets/icons/png/<id>.png` mediante `AssetImage` con `errorBuilder`, y (c) fallback determinista al `IconData` canónico asignado cuando el asset aún no exista en el bundle.
- **REQ-04 (Workbench / Project Hub Técnico):** Eliminar las tarjetas grandes tipo SaaS en `HomeDashboardScreen` y reemplazarlas por una vista técnica densa con:
  - Barra de estado DSP compacta sin colores neón arbitrarios.
  - Panel de Acceso Rápido a Módulos en formato **Inspector / Grid técnico de `1px`** (sin textos de relleno ni flechas promocionales).
  - Panel de **Proyectos Canónicos, Toma Reciente e Instrumento Activo** en formato tabular compacto con tipografía monoespaciada para métricas (`Hz`, `BPM`, `ms`, `bits`).
  - Acceso directo a `Workbench` (Afinador + Rack + Espectro) desde el arranque o mediante conmutación inmediata.

### 3.2 Casos de Borde y Condiciones de Error
- **Asset PNG faltante o corrupto:** `StudioIcon` nunca debe lanzar `FlutterError` en runtime ni en tests; ante ausencia del archivo en `assets/icons/png/`, `errorBuilder` o verificación de manifiesto cae limpiamente al `IconData` de respaldo.
- **Compatibilidad con tests existentes:** Todos los keys (`btn_quick_search`, `btn_open_terminal_os`, etc.) y callbacks de navegación de `HomeDashboardScreen` deben mantenerse intactos para preservar la suite de regresión.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/core/design_system/domain/`)
- `StudioIconId` y `StudioIconCatalog`: Mapeo puro en Dart de cada identificador semántico a su ruta relativa (`png/<id>.png`, `svg/<id>.svg`) y nombre descriptivo.

### 4.2 Capa de Presentación (`lib/core/design_system/` y `lib/features/navigation/`)
- `StudioDesignTokens.studioOledMonochrome` en `studio_design_tokens.dart`.
- `StudioThemeController` en `studio_theme_provider.dart` actualizado para iniciar en `studioOledMonochrome`.
- `StudioIcon` en `lib/core/design_system/atoms/studio_icon.dart` consumiendo `StudioIconCatalog` e `Image.asset(..., errorBuilder: ...)` sin dependencias externas bloqueantes.
- `HomeDashboardScreen` refactorizado con densidad Pro-DAW (`1px` borders, `radius: 2–4px`, sin tarjetas SaaS).

---

## 5. Criterios de Rendimiento y Benchmarking

- **Latencia de Pintado:** `0 ms` de bloqueo en UI thread; `Image.asset` utiliza caché de `PaintingBinding.instance.imageCache` con `cacheWidth` acotado en HiDPI.
- **Peso de Assets:** PNGs optimizados (`64x64` / `96x96`) para mantener el bundle liviano hasta su sustitución por SVGs.

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] Pruebas unitarias de `StudioIconCatalog` verificando los 44 IDs canónicos y rutas únicas.
- [ ] Pruebas de widget de `StudioIcon` verificando fallback limpio cuando no existe el PNG y respeto de tamaño/color.
- [ ] Pruebas de `StudioDesignTokens.studioOledMonochrome` y `HomeDashboardScreen` verificando contraste OLED, ausencia de desbordamientos y conservación de todos los flujos de navegación.
- [ ] `flutter analyze --no-fatal-infos` y suite de tests de navegación/design system al 100%.

---

## 7. Referencias Técnicas y Bibliografía

1. *Human Interface Guidelines & Pro-App Dark Surfaces (Apple Logic Pro / Adobe Spectrum).*
2. *Flutter Asset Resolution & ImageCache Optimization (`flutter.dev`).*
