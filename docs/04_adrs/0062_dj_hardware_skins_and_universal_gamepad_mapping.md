# ADR 0062: Emulación Visual de Hardware DJ y Mapeo Universal de Gamepad / Teclado

## Estado
Aprobado (Approved) - 2026-11-13

## Contexto
La Consola DJ Virtual de Tunner contaba con una interfaz modular estándar y un motor de mapeo QWERTY. Sin embargo, para cumplir la visión pedagógica de democratizar el arte del DJing sin obligar a los estudiantes a comprar costosas controladoras de \$300 a \$3,000 USD:
1. Se requería que la consola pudiera representarse visualmente de forma idéntica a los equipos físicos más usados en la industria (Pioneer DDJ-FLX4, CDJ-3000 / DJM-900NXS2, Traktor S4 MK3).
2. Se requería un método interactivo "hacer clic y asignar" (MIDI / Controller Learn Mode) para mapear cualquier botón en pantalla a teclas de PC o botones de mandos de consola (Xbox / PlayStation).
3. El uso de imágenes rasterizadas (PNG/JPG pesadas) debía evitarse para mantener el binario liviano ($\le 50\text{ KB}$), offline y con renderizado nítido a 60/120 FPS en pantallas de cualquier densidad.

## Decisión
1. **Capa de Dominio (`lib/features/dj_console/domain/`):**
   - **`DjHardwareSkinEntity` & `DjSkinZoneEntity`:** Modelos inmutables en Dart puro que definen el chasis, la marca/modelo, dimensiones relativas y una colección de zonas de control normalizadas `(x, y, width, height)` vinculadas a `DjAction`.
   - **`DjControllerProfileEntity`:** Diccionario unificado de entradas físicas (etiquetas de teclado `Key W`, `Space` y botones de gamepad `Xbox_A`, `Xbox_B`, `Trigger_RT`) asociadas a acciones `DjAction`.
2. **Capa de Datos e Infraestructura (`lib/features/dj_console/data/`):**
   - **`DjHardwareCatalog`:** Catálogo estático con los esquemas vectoriales precisos de:
     - *Pioneer DDJ-FLX4* (2 canales, 8 pads por deck, jog wheels táctiles, Sound Color FX y EQ de 3 bandas).
     - *Pioneer CDJ-3000 + DJM-900NXS2* (Estándar de festivales mundiales).
     - *Traktor Kontrol S4 MK3* (Layout de 4 decks con jogs hápticos y medidores LED).
   - **`DjGamepadInputService`:** Traductor de eventos de mandos USB/Bluetooth y teclado hacia acciones de dominio `DjAction`.
   - **Persistencia atómica offline:** Extensión de `DjKeymapPersistenceService` para guardar el perfil activo de skins y mandos en formato JSON determinista.
3. **Capa de Presentación (`lib/features/dj_console/presentation/`):**
   - **`DjHardwareConsolePainter`:** CustomPainter vectorial que dibuja el chasis industrial, botones LED retroiluminados, potenciómetros con ángulo de rotación, faders y medidores VU reactivos a 60/120 FPS.
   - **`DjVisualMappingOverlay`:** Capa de asignación visual con modo "Learn" que detecta toques sobre las zonas del skin y captura la siguiente pulsación física.
   - **`DjConsoleModal`:** Incorporación de selector de consola física en la cabecera e interruptor para alternar entre vista estándar y vista de consola física real.

## Consecuencias

### Positivas
- **Accesibilidad y Experiencia Profesional:** Cualquier usuario con una PC y un teclado o control de Xbox puede practicar con la misma disposición ergonómica que encontrará en una cabina de club real.
- **Cero Dependencia de Red y Huella Mínima:** Todos los esquemas vectoriales son generados por código geométrico en menos de $50\text{ KB}$, sin descargar megabytes de imágenes raster ni causar pixelación.
- **Latencia Sub-8ms:** Comunicación directa por eventos sin intermediarios pesados ni bucles bloqueantes.

### Negativas / Mitigaciones
- **Variabilidad de Gamepads entre Plataformas:** Algunos navegadores o sistemas operativos identifican botones de gamepad con nombres o códigos dispares.
  *Mitigación:* Se implementa un normalizador de botones que estandariza las etiquetas de entrada comunes (Xbox, DualShock y Gamepad estándar HID).
