# ADR 0042: Arquitectura de Navegación por Dashboard Central y Buscador Universal de Herramientas

## Estado
Aceptado

## Contexto
A medida que el proyecto **Tunner** creció para abarcar afinación estroboscópica, síntesis SoundFont SF2, metrónomo polirrítmico, grabador de práctica con comparación espectral, lecciones guiadas interactivas, autotune vocal y temperamentos históricos, la interfaz de usuario se concentró casi en su totalidad en una única pantalla monolítica (`TunerScreen`).

Esta concentración provocó:
1. **Sobrecarga Cognitiva:** Múltiples botones, chips táctiles y modales compitiendo por espacio visual en la barra superior.
2. **Dificultad de Descubrimiento:** Usuarios nuevos, estudiantes, niños o incluso ingenieros de audio experimentaban desorientación al intentar localizar herramientas específicas (ej. dónde calibrar el micrófono, dónde abrir el descompositor de canciones o dónde practicar intervalos).
3. **Falta de una Jerarquía Clara de Producto:** La app carecía de una pantalla de bienvenida que presentara las capacidades del software de forma estructurada e intuitiva.

## Decisión
Se decide adoptar el patrón de diseño estándar de la industria (utilizado en DAWs y aplicaciones educativas líderes como GarageBand, Ableton Live y Simply Piano):
1. **`MainAppShell` como Contenedor Principal:** Un contenedor con `BottomNavigationBar` persistente que organiza la aplicación en 5 contextos bien delimitados:
   - Pestaña 0: **Inicio / Dashboard Hub**
   - Pestaña 1: **Afinador & Metrónomo** (pantalla de práctica instrumental)
   - Pestaña 2: **Aprender a Tocar** (tutor y lecciones interactivas)
   - Pestaña 3: **Estudio de Grabación & Práctica** (grabador, espectrograma, evaluador)
   - Pestaña 4: **Canciones & Partituras** (biblioteca, MusicXML, editor y descompositor)
2. **Dashboard de Inicio con Tarjetas de Gran Formato:** Pantalla inicial (`HomeDashboardScreen`) con saludo, resumen del instrumento activo y tarjetas táctiles directas.
3. **Buscador Universal de Herramientas (`Spotlight Search` / `ToolSearchModal`):** Un catálogo indexado en dominio puro (`AppToolCatalog`) que permite buscar por texto predictivo y lanzar cualquier herramienta en 1 toque.

## Consecuencias

### Positivas
- Reducción drástica de la fricción y la curva de aprendizaje: cualquier usuario comprende de inmediato qué ofrece la app.
- Acceso instantáneo a cualquier herramienta en menos de 2 segundos mediante el buscador universal.
- `TunerScreen` queda descongestionada, permitiendo que la aguja y el estroboscopio brillen con máxima visibilidad.
- Preservación del rendimiento: las pestañas comparten el mismo `TunerViewModel` sin recrear hilos de audio.

### Negativas / Mitigaciones
- Necesidad de mantener actualizado el catálogo de herramientas al incorporar nuevas funcionalidades en fases futuras. Se mitiga centralizando el catálogo en `AppToolCatalog`.
