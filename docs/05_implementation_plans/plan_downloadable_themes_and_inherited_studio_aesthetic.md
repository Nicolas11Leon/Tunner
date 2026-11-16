# Plan de Implementación: Sistema Atómico de Estéticas Heredadas, Skins Descargables (.tntheme) y Acabado Pro Studio

Este documento formaliza el plan de ingeniería para dotar a **Tunner** de una **Arquitectura de Estéticas 100% Heredadas**, eliminando cualquier color o estilo hardcodeado, integrando un **Catálogo de Skins Descargables e Importables (.tntheme)** y elevando el acabado estético general a nivel de software profesional de alta gama ("software caro de licencia").

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-INHERITED-AESTHETICS-DOWNLOADABLE-SKINS-2026-0089`
- **Título:** Estéticas Heredadas, Motor de Skins Descargables (.tntheme) y Acabado Pro Studio
- **Fase del Proyecto:** Fase 2 (Diseño de Sistemas, Skins y Estaciones de Trabajo)
- **Estado:** Aprobado para Implementación
- **ADR Relacionado:** [ADR 0079: Arquitectura de Estéticas Heredadas y Skins Descargables](../04_adrs/0079_downloadable_themes_and_inherited_studio_aesthetic_suite.md)
- **Documento Funcional Base:** [Caso de Uso 89: Gestión de Skins Descargables y Herencia de Apariencia Total](../02_use_cases/89_uc_downloadable_themes_and_inherited_studio_aesthetic_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Erradicar por completo los colores planos y valores hexadecimales arbitrarios dispersos en los componentes, implementando una **herencia centralizada y reactiva de apariencia** (`StudioThemeScope` y `StudioDesignTokens`). Permitir que la estética completa de la plataforma pueda cambiarse al instante, exportarse o descargarse/importarse como paquetes de temas (`.tntheme`), ofreciendo:
1. **Herencia Absoluta de Apariencia (Zero Hardcoded Styles):**
   - El explorador de archivos, la barra de canales, los plugs, modales, faders y decks heredan el 100% de sus colores de superficie, bordes, tipografías y acentos desde `StudioThemeScope.tokensOf(context)`.
2. **Motor de Estéticas y Skins Descargables (.tntheme):**
   - Formato serializable en JSON/Binario de tokens de diseño (`StudioThemeSkinEntity`).
   - Importación y exportación de archivos de estética `.tntheme`.
   - Catálogo integrado con 5 estéticas de grado profesional:
     - **Obsidian Pro DAW:** Negro mate profundo, acentos cian láser y líneas de división finas de 1px.
     - **Neve 88RS Vintage Console:** Pizarra cálida, metal cepillado analógico y ámbar vintage.
     - **Tokyo Cyberpunk Synthwave:** Medianoche violeta, neón cian y fucsia club.
     - **Nord Electro Crimson:** Grafito industrial oscuro y rojo rubí satinado.
     - **Conservatory Ivory Paper:** Fondo marfil claro para lectura diurna, tonos sepia y acentos dorados.
3. **Modal de Gestión y Descarga de Estéticas (`StudioThemeManagerModal`):**
   - Selector visual de skins con previsualización en vivo de paleta (Canvas, Panel, Acento, Texto).
   - Botón para importar archivo `.tntheme` desde el sistema de archivos del usuario.
   - Botón para exportar y compartir la estética activa.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio: `StudioThemeSkinEntity` con serialización JSON/binaria.
  - Servicio de infraestructura: `StudioThemeCatalogService` con persistencia local de skins importadas.
  - Refactorización de componentes: `StudioVsCodeExplorerWidget`, `StudioFolderTreeTile`, `StudioFileTreeTile`, `StudioExplorerActionHeader`, `StudioChannelPatchbayBarWidget`, `StudioModularPlugWidget`, modales de archivo y canal para consumir tokens heredados.
  - Modal de UI: `StudioThemeManagerModal`.
  - Pruebas unitarias de serialización y cambio reactivo de tema.
- **Excluido (Out-of-Scope):**
  - Conexiones con servidores en la nube (respeto estricto al principio Offline-First).

---

## 2. Fundamentos de Diseño y Principios Ergonómicos (HCI)

1. **Software Caro de Licencia (High-End Tactile Perception):**
   - Líneas de división de 1 píxel exacto (`borderHairline`).
   - Jerarquía clara de superficies: Canvas de fondo $\rightarrow$ Paneles de trabajo $\rightarrow$ Superficies elevadas $\rightarrow$ Campos de entrada de datos.
   - Contraste WCAG AAA en tipografía técnica y monoespaciada para lecturas numéricas.
2. **Atomización e Intercambiabilidad:**
   - Ningún widget define sus propios colores de forma aislada; cualquier cambio en el tema activo repercute de forma instantánea en toda la ventana sin parpadeos ni reconstrucciones lentas.

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Entidades de Skin y Tokens)
- [ ] Implementar `lib/core/design_system/domain/studio_theme_skin_entity.dart`:
  - Modelo inmutable `StudioThemeSkinEntity` con soporte `toJson()`, `fromJson()` y conversión hacia `StudioDesignTokens`.
  - Presets canónicos de estudio: Obsidian Pro, Neve 88RS, Cyberpunk Synthwave, Nord Crimson, Conservatory Ivory.

### Paso 2: Capa de Infraestructura / Datos (Servicio de Catálogo de Temas)
- [ ] Implementar `lib/core/design_system/data/studio_theme_catalog_service.dart`:
  - Registro de skins disponibles (nativas y descargadas/importadas por el usuario).
  - Métodos `exportTheme(skinId)`, `importThemeFromBytes(bytes)`, `setActiveSkin(skinId)`.
  - Conexión con `StudioThemeController` para notificar a toda la interfaz.

### Paso 3: Capa de Presentación (Herencia Completa y Selector de Estéticas)
- [ ] Actualizar componentes de explorador y canales para consumir `StudioThemeScope.tokensOf(context)`:
  - `StudioVsCodeExplorerWidget`
  - `StudioFolderTreeTile`
  - `StudioFileTreeTile`
  - `StudioExplorerActionHeader`
  - `StudioChannelPatchbayBarWidget`
  - `StudioModularPlugWidget`
  - `StudioChannelModals` y `StudioFileSystemModals`
- [ ] Implementar `lib/core/design_system/molecules/studio_theme_manager_modal.dart`:
  - Diálogo de selección de estéticas con tarjetas de previsualización, selector de tema e importador/exportador `.tntheme`.
- [ ] Integrar botón de acceso rápido al gestor de temas en la cabecera del estudio (`StudioThemeSwitcher`).

### Paso 4: Pruebas, Verificación y Build Nativo
- [ ] Pruebas unitarias de serialización, importación y cambio de tema en `test/core/design_system/studio_theme_skins_test.dart`.
- [ ] `flutter analyze` con 0 errores y 0 advertencias.
- [ ] Compilación Linux nativa y lanzamiento en pantalla.

---

## 4. Criterios de Aceptación (Definition of Done)
1. Cero colores fijos hardcodeados en los componentes de explorador y canales; todos se heredan de `StudioDesignTokens`.
2. El usuario puede cambiar de estética entre las 5 opciones de estudio al instante.
3. El usuario puede importar o exportar archivos `.tntheme`.
4. El acabado visual proyecta orden, rigor y sofisticación técnica de grado DAW profesional.
