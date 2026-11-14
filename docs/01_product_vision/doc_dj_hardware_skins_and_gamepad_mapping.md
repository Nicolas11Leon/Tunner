# DJ Console Visual Hardware Skins and Universal Controller Mapping (PC & Gamepad)

Documento de visión de producto y arquitectura técnica para la emulación visual de consolas físicas reales y el sistema universal de mapeo de controles (teclado QWERTY, mandos Xbox / PlayStation y MIDI) en **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-068`
- **Título Oficial:** Emulador Visual de Consolas DJ Reales de la Industria y Mapeo Universal de Periféricos (Teclado PC & Gamepads)
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-13`
- **Última Modificación:** `2026-11-13`
- **Fase Asociada:** `Fase 3 (Herramientas Creativas Avanzadas) & Fase 4 (Estudio de Producción)`
- **Autor / Revisor Principal:** `Nicolás León / Tunner Architecture Team`

---

## 1. Resumen Ejecutivo (Executive Summary)

El propósito de esta especificación es dotar a la Consola DJ Virtual de Tunner de una representación visual fotorrealista / esquemática vectorial de alta fidelidad basada en las controladoras de DJ físicas más emblemáticas y utilizadas en el mercado y la industria musical (como la **Pioneer DDJ-FLX4 / DDJ-400**, **Pioneer CDJ-3000 / DJM-900NXS2** y **Traktor Kontrol S4 MK3**), permitiendo a cualquier usuario, estudiante o productor tocar y mezclar en vivo utilizando exclusivamente el teclado de su computadora o un control de videojuegos (Xbox Controller, PlayStation DualSense o gamepad USB genérico) sin necesidad de adquirir equipamiento físico costoso.

El sistema introduce un motor de skins vectoriales ultraligeros basados en matrices de coordenadas normalizadas, un modo interactivo de asignación y captura ("Learn Mode") donde hacer clic en cualquier potenciómetro, jog wheel, fader o botón físico de la consola permite reasignarlo instantáneamente a cualquier tecla o botón de control, y una arquitectura de retroalimentación lumínica reactiva que ilumina los botones en pantalla al ser accionados físicamente con latencia imperceptible ($\le 8\text{ ms}$).

---

## 2. Contexto del Problema y Justificación Tecnológica

### 2.1 La Barrera de Entrada al DJing y la Producción en Vivo
El equipamiento físico de DJ profesional representa un costo elevado que oscila entre los \$300 USD para controladoras básicas de dos canales hasta más de \$5,000 USD para cabinas de festival estándar (Nexus / CDJ-3000). Esto genera una severa barrera socioeconómica para estudiantes y entusiastas en países en desarrollo.

### 2.2 Por qué Archivos Vectoriales y Esquemas Ligeros sobre Imágenes Raster Pesadas
El uso de imágenes PNG o JPEG de 4K presenta desventajas severas:
- Alto consumo de memoria RAM y almacenamiento (15 a 40 MB por imagen).
- Pérdida de nitidez al reescalar en pantallas de alta densidad (Retina / 4K).
- Imposibilidad de animar de forma independiente potenciómetros, faders y botones iluminados sin recrear texturas completas.

**Solución Arquitectónica:**
Un sistema de **Skins Vectoriales Interactivos (Vector Skin Layouts)**:
- Archivos de configuración ligeros ($\le 50\text{ KB}$) que definen la geometría, colores, tipografía industrial y zonas interactivas `Rect(x, y, width, height)` normalizadas en rango $[0.0, 1.0]$.
- Cada zona interactiva vincula visualmente un elemento físico (ej. `deckA_cue`, `deckB_play`, `crossfader`, `eq_mid_a`, `jog_wheel_a`) con su respectiva acción del motor `DjAction`.
- Renderizado por lienzo `CustomPainter` a 60/120 FPS sin pérdida de resolución en ninguna escala.

### 2.3 Periféricos Universales: Teclado de PC y Controles de Videojuegos (Gamepad)
Casi todos los hogares y computadoras cuentan con un teclado QWERTY o un mando de consola (Xbox One/Series, PS4/PS5, Logitech, 8BitDo).
La matriz de mapeo universal estandariza:
1. **Controles de Videojuegos (Xbox / PlayStation):**
   - **Botones Frontales (A, B, X, Y / Cruz, Círculo, Cuadrado, Triángulo):** Play/Pausa, Cue, Hot Cues 1-2.
   - **Gatillos Analógicos (LT / RT, L2 / R2):** Barrido de filtro bipolar continuo $[-1.0, 1.0]$ o pitch bend dinámico.
   - **Bumpers (LB / RB, L1 / R1):** Sincronización automática de tempo (Sync) y salto de compás.
   - **Sticks Analógicos (Left / Right Stick):** Control horizontal del Crossfader y scratch del Jog Wheel.
   - **D-Pad (Cruceta direccional):** Pitch fino ($\pm 0.1\%$) y navegación de pistas.
2. **Teclado de Computadora:** Mapeo ergonómico estandarizado estilo dos manos (Mano izquierda Deck A, Mano derecha Deck B, Teclas centrales para Mixer y Crossfader).

---

## 3. Especificación Funcional

### 3.1 Biblioteca de Consolas Físicas Soportadas
1. **Preset Pioneer DDJ-FLX4 / DDJ-400:**
   - Disposición de 2 canales con 8 Performance Pads por deck (Hot Cue, Beat Loop, Sampler).
   - Mezclador central de 3 bandas EQ, Trim, filtro sweep Sound Color FX y crossfader Magvel.
   - Jog wheels capacitivos con aro lumínico perimetral.
2. **Preset Pioneer CDJ-3000 + DJM-900NXS2 (Club Standard):**
   - Pantalla superior con forma de onda, jog wheels de 206 mm con display central.
   - Faders lineales de 60 mm y sección de Beat FX cuantizados.
3. **Preset Traktor Kontrol S4 MK3:**
   - Jog wheels motorizados hápticos y displays LED compactos por canal.

### 3.2 Modo "Learn / Asignación Interactiva"
1. El usuario hace clic en el botón "Asignar Controles" (Mapeo Visual).
2. El usuario hace clic sobre cualquier botón, perilla o fader en la consola virtual.
3. Se abre un indicador de escucha: `"Presiona una tecla en tu teclado o un botón en tu control Xbox..."`.
4. El motor detecta el evento de entrada entrante (KeyEvent de teclado o GamepadButtonEvent).
5. La asignación se registra y persiste atómicamente en almacenamiento local (`DjControllerMappingPersistenceService`).
6. El botón asignado muestra un badge flotante con la tecla o botón asignado (ej. `[Space]`, `[Xbox A]`, `[RT]`).

### 3.3 Retroalimentación Lumínica Reactiva (Hardware LED Emulation)
- Cuando el usuario presiona una tecla o botón físico, el componente correspondiente en la consola virtual se ilumina en tiempo real emulando la retroiluminación LED del hardware real:
  - Botón Play: Verde fosforescente brillante.
  - Botón Cue: Ámbar brillante.
  - Performance Pads: Iluminación RGB según la función asignada.
  - Medidores VU Meter: Barras LED estéreo de 10 segmentos con indicador de pico a 0 dBFS.

---

## 4. Arquitectura de Software y Módulos

1. **Capa de Dominio (`lib/features/dj_console/domain/`):**
   - `dj_hardware_skin_entity.dart`: Representación inmutable de la consola física (nombre, fabricante, dimensiones de aspecto, lista de zonas interactivas `DjSkinZoneEntity`).
   - `dj_skin_zone_entity.dart`: Coordenadas normalizadas $(x, y, w, h)$, tipo de control (botón momentáneo, perilla rotativa, fader lineal, jog wheel), acción asociada `DjAction` y etiqueta visual.
   - `dj_gamepad_profile_entity.dart`: Mapeo de botones de gamepad (botones A/B/X/Y, bumpers, triggers, d-pad, sticks) a `DjAction`.
2. **Capa de Infraestructura / Datos (`lib/features/dj_console/data/`):**
   - `dj_hardware_catalog.dart`: Catálogo canónico con los layouts vectoriales de Pioneer DDJ-FLX4, CDJ-3000 y Traktor S4.
   - `dj_gamepad_input_service.dart`: Normalizador de eventos de gamepad y teclado para traducción determinista hacia `DjAction`.
   - `dj_controller_mapping_persistence_service.dart`: Almacenamiento JSON local offline de las configuraciones de hardware y perfiles personalizados.
3. **Capa de Presentación (`lib/features/dj_console/presentation/`):**
   - `dj_hardware_console_painter.dart`: CustomPainter vectorial a 60/120 FPS que dibuja el chasis metálico/plástico industrial, los potenciómetros, faders, jog wheels y la iluminación LED reactiva.
   - `dj_visual_mapping_overlay.dart`: Capa táctil interactiva que detecta toques sobre las zonas del skin y gestiona el "Learn Mode".
   - `dj_console_modal.dart`: Selector superior de consola visual (Pioneer DDJ-FLX4 / CDJ-3000 / Traktor S4 / Modo Clásico).

---

## 5. Rendimiento y No Negociables de Ingeniería

- **Latencia de Entrada:** $\le 8\text{ ms}$ desde el evento de teclado/gamepad hasta la reacción visual y acústica.
- **Tasa de Cuadros:** 60/120 FPS sostenidos en renderizado vectorial de jog wheels y medidores de nivel sin pérdida de frames ni bloqueos del hilo de UI.
- **Tamaño de Archivo:** Layouts vectoriales embebidos en código o JSON ligero ($\le 50\text{ KB}$ en total), evitando descargas lentas o imágenes raster pesadas.
- **Política de Cero Emojis:** Estricto cumplimiento en todo el código, UI y documentación.
