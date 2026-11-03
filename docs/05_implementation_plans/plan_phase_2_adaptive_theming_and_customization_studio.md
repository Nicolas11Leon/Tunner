# Implementation Plan: Adaptive Aesthetic Theming and User Customization Studio

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-THEMING-CUSTOMIZATION-2026-001`
- **Título de la Implementación:** `Implementación del Motor de Estéticas Adaptables, tokens semánticos y Custom Theme Studio`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `Completado`
- **ADR Relacionado:** [ADR-0007](docs/04_adrs/0007_adaptive_theme_engine_and_user_customization_model.md)
- **Documento Funcional Base:** [UC-11](docs/02_use_cases/11_uc_adaptive_aesthetic_theming_and_user_customization.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Expandir el sistema de tematización visual de Tunner de un enum estático restringido a un modelo dinámico, extensible y personalizable por el usuario. Implementar 7 estéticas maestras predefinidas (preservando y perfeccionando los temas negros preferidos por el usuario, y añadiendo variantes acústicas, orquestales, claras y neón), desarrollar el **Theme Customization Studio** con editor visual de paletas e importación/exportación JSON, y corregir las fallas de contraste en componentes clave (`StrobeTunerWidget` y `RealSheetMusicPainter`).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Refactorización de `TunnerThemePalette` para admitir IDs, estado personalizado (`isCustom`), `Brightness`, tokens semánticos (`surfaceBorderColor`, `surfaceHighlightColor`, `onPrimaryColor`), y serialización JSON (`toJson` y `fromJson`).
  - Incorporación de los 7 presets curados: `Obsidian Studio`, `OLED Pure Black`, `Royal Symphony`, `Acoustic Wood`, `Cyberpunk Synthwave`, `Vintage Conservatory Parchment` y `Nordic Frost`.
  - Métodos de gestión de paletas en `TunerViewModel`: `setPalette`, `addCustomPalette`, `updateCustomPalette`, `deleteCustomPalette`, `importPaletteFromJson`.
  - Creación del widget modular `ThemeCustomizationModal` y `ThemeEditorDialog` con paleta interactiva de colores y previsualización en vivo.
  - Corrección de colores estáticos `Colors.white` / `Colors.white24` en `StrobeTunerWidget` y `RealSheetMusicPainter` para asegurar legibilidad en cualquier fondo claro u oscuro.
  - Suite de pruebas unitarias cubriendo dominio, serialización JSON, ViewModel y componentes visuales.
- **Excluido (Out-of-Scope):**
  - Cambios en el algoritmo DSP de detección de tono YIN o el motor de síntesis de audio senoidal (permanecen intactos).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal estable con Material 3 y CustomPainter.
- **Riesgo Tecnológico:**
  - Cero dependencias nativas adicionales; 100% código Dart puro y Flutter estándar.
  - Sin impacto en el hilo de audio; los cambios de paleta sólo actualizan los atributos de pintura de los widgets.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos de Tema y Serialización)
- [x] Actualizar `TunnerThemePalette` con propiedades dinámicas, factories para los 7 presets, método `createCustom()`, `toJson()` y `fromJson()`.
- [x] Mantener retrocompatibilidad 100% con `TunnerThemeMode` y `fromMode()`.
- [x] Añadir helpers semánticos de contraste (`surfaceBorderColor`, `surfaceHighlightColor`, `onPrimaryColor`, etc.).
- [x] Escribir pruebas unitarias exhaustivas en `test/core/theme/tunner_theme_test.dart`.

### Paso 2: Capa de Gestión de Estado (TunerViewModel)
- [x] Integrar lista reactiva de paletas disponibles (`availablePalettes`) y métodos `setPalette`, `addCustomPalette`, `updateCustomPalette`, `deleteCustomPalette`, `importPaletteFromJson`.
- [x] Mantener `setThemeMode()` como delegado para no romper llamadas existentes.

### Paso 3: Corrección de Contraste y Tokens en Componentes Gráficos
- [x] Reemplazar colores estáticos en `StrobeTunerWidget` con tokens de `TunnerThemePalette`.
- [x] Asegurar contraste en `RealSheetMusicPainter` (círculo del puntero en vivo, líneas de pentagrama, números de compás).
- [x] Verificar sincronización de la barra del sistema operativo (`SystemChrome.setSystemUIOverlayStyle`) en `main.dart` para soportar temas claros y oscuros.

### Paso 4: Capa de Presentación (Theme Customization Studio UI)
- [x] Crear diálogo/modal interactivo `ThemeCustomizationModal` con previsualización de swatches de color, selector de métricas y acceso al editor de temas.
- [x] Crear `ThemeEditorDialog` para que los usuarios creen y personalicen sus propias estéticas interactivamente (nombre, base, acento primario y previsualización en vivo).
- [x] Permitir exportar e importar temas en JSON mediante un diálogo simple.
- [x] Integrar el modal en `TunerScreen`.

### Paso 5: Verificación, Pruebas y Limpieza
- [x] Ejecutar `flutter analyze` y asegurar cero advertencias de linter.
- [x] Ejecutar `flutter test` y asegurar que el 100% de las pruebas pasen.
- [x] Documentar el resultado en el informe de auditoría.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- Si ocurre alguna regresión en UI, `TunnerThemePalette.fromMode()` mantendrá la compatibilidad intacta con los valores originales por defecto (`Obsidian Studio`).
- Restauración git al commit previo si se presenta cualquier incompatibilidad imprevista.

---

## 5. Criterios de Aceptación (Definition of Done)

- [x] Las 7 estéticas curadas están disponibles y renderizan con contraste y ergonomía visual impecable.
- [x] Los usuarios pueden crear un tema personalizado seleccionando su base y acentos, guardarlo y usarlo inmediatamente.
- [x] Los temas personalizados se pueden exportar e importar en formato JSON.
- [x] Cero advertencias en `flutter analyze`.
- [x] Suite completa de pruebas pasando con éxito en `flutter test`.
