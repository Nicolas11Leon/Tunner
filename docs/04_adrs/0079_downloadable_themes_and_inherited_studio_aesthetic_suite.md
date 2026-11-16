# ADR 0079: Arquitectura de Estéticas Heredadas y Skins Descargables (.tntheme)

## Estado
Aprobado

## Contexto
El usuario ha señalado una deficiencia estética crítica: el uso de colores fijos dispersos generaba una apariencia visual plana y barata ("se sigue viendo barato, no implementaste la estética que manejamos"). Para resolver esto de raíz y de manera 100% escalable:
1. La apariencia de cualquier control, contenedor, botón o panel debe **heredarse siempre desde un único punto de verdad (`StudioThemeScope`)**.
2. Las estéticas deben ser intercambiables, serializables y descargables/importables (`.tntheme`), permitiendo a los usuarios compartir o instalar temas visuales completos sin tocar una sola línea de código fuente.

## Decisión
Se implementa una arquitectura de tokens de diseño heredados y serializables:

1. **Capa de Dominio (`lib/core/design_system/domain`):**
   - `StudioThemeSkinEntity`: Entidad inmutable que encapsula la especificación completa de diseño: colores de superficie jerárquica (canvas, panel, header, elevated, input, hover), líneas de separación (hairline, subtle, focus), acentos funcionales (primary, secondary, success, warning, danger), escala tipográfica y radios geométricos.
   - Presets canónicos profesionales:
     - `Obsidian Pro DAW` (Mastering estricto en negros y cian láser).
     - `Neve 88RS Vintage Console` (Consola analógica británica en pizarra cálida y ámbar).
     - `Tokyo Cyberpunk Synthwave` (Medianoche violeta con brillo cian y fucsia).
     - `Nord Electro Crimson` (Grafito industrial con acentos rojo rubí).
     - `Conservatory Ivory Paper` (Fondo marfil y tonos sepia para atril y conservatorio).

2. **Capa de Infraestructura y Datos (`lib/core/design_system/data`):**
   - `StudioThemeCatalogService`: Gestor del catálogo de skins. Permite registrar skins, persistir temas importados por el usuario y exportar el tema activo como archivo serializado en formato `.tntheme` (JSON codificado en UTF-8 o ZLib binario).
   - `StudioThemeController`: Controlador reactivo que propaga cualquier cambio a través de `StudioThemeScope`.

3. **Capa de Presentación:**
   - Refactorización de todos los widgets de Explorador (`StudioVsCodeExplorerWidget`, `StudioFolderTreeTile`, `StudioFileTreeTile`, `StudioExplorerActionHeader`), Barra de Canales (`StudioChannelPatchbayBarWidget`), Plugs (`StudioModularPlugWidget`) y Modales para consumir exclusivamente `tokens.canvasBackground`, `tokens.panelBackground`, `tokens.borderHairline`, `tokens.accentPrimary`, `tokens.textPrimary`, `tokens.textSecondary`, etc.
   - `StudioThemeManagerModal`: Diálogo interactivo para previsualizar, seleccionar, importar y exportar skins descargables.

## Consecuencias

### Positivas
- Cero colores hardcodeados: cualquier ajuste o tema descargado transforma armoniosamente la interfaz entera.
- Nivel de acabado visual refinado y costoso ("software caro de licencia") con contrastes cuidados, líneas de 1px y legibilidad técnica.
- Extensibilidad ilimitada: los usuarios pueden crear y compartir sus propios archivos `.tntheme`.

### Negativas / Mitigaciones
- Requiere disciplina estricta para no reintroducir `Color(...)` fijos en nuevos widgets: se documenta en las reglas y se valida en las revisiones.
