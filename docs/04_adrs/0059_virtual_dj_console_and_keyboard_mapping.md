# ADR 0059: Arquitectura de Consola de DJ Virtual con Decks Duales y Motor Universal de Mapeo QWERTY

## Estado
Aprobado (Approved) - 2026-11-13

## Contexto
El aprendizaje de técnicas de mezcla, beatmatching, transiciones y manipulación de pistas en tiempo real se encuentra tradicionalmente restringido a usuarios que poseen consolas de DJ físicas dedicadas. Dentro del ecosistema de Tunner, surge la necesidad de dotar a los estudiantes y músicos de una herramienta creativa que les permita interactuar con pistas de práctica, acompañamientos y stems aislados directamente desde su teclado estándar de ordenador (o controladores MIDI USB conectados), garantizando una latencia de respuesta inferior a 10 milisegundos y un control acústico profesional.

Los desafíos principales son:
1. **Desacoplamiento de Eventos de Hardware y Acciones de Mezcla:** Los eventos de teclado varían según el sistema operativo (Windows, Linux, macOS, Web). No se debe atar la lógica de DJ a widgets de Flutter.
2. **Respuesta Acústica del Crossfader:** La atenuación no puede ser una simple resta lineal sin provocar caídas de volumen en el punto de mezcla central o artefactos de distorsión por suma de fases.
3. **Consumo de Recursos en Renderizado de Jog Wheels:** Los platos giratorios virtuales deben rotar a 60/120 FPS sin saturar el hilo principal ni provocar reconstrucciones de widgets innecesarias.

## Decisión
1. **Capa de Dominio Pura (`lib/features/dj_console/domain/`):**
   - **`DjDeckEntity`:** Modelo inmutable en Dart puro que gestiona el estado de cada reproductor (BPM, tasa de pitch, estado de reproducción, marcas de Hot Cues, volumen individual, ganancias de EQ High/Mid/Low y estado de kill switch).
   - **`DjCrossfaderEntity`:** Modelo con soporte para tres curvas de transferencia acústica: Potencia Constante ($\cos(\theta) / \sin(\theta)$), Lineal y Fast Cut (Scratch).
   - **`DjKeymapProfileEntity`:** Modelo de configuración que asocia códigos de tecla físicos (`LogicalKeyboardKey.keyId` o cadenas serializadas) a enumeraciones canónicas de `DjAction` (`deckAPlayPause`, `deckACue`, `crossfaderLeft`, `crossfaderCenter`, etc.).
   - **`DjPerformanceOrchestrator`:** Orquestador de dominio puro que coordina eventos, calcula ganancias instantáneas y mantiene la sincronización de tempo.
2. **Capa de Infraestructura y Procesamiento (`lib/features/dj_console/data/`):**
   - **`DjAudioProcessor`:** Maneja los canales de salida estéreo, aplicando ecualización de 3 bandas y control de volumen con limitador suave para evitar clipping digital.
   - **`JsonDjKeymapPersistenceService`:** Persistencia y recuperación local de esquemas de mapeo QWERTY en el almacenamiento local del dispositivo.
3. **Capa de Presentación (`lib/features/dj_console/presentation/`):**
   - **`DjConsoleViewModel`:** Expone el estado reactivo consumido por los widgets.
   - **`VectorJogWheel`:** Widget optimizado que utiliza `CustomPainter` y `RepaintBoundary` para pintar el plato de vinilo y el marcador de rotación sin invalidar el resto del árbol de widgets.
   - **`DjKeymapEditorModal`:** Interfaz visual para reasignar cualquier tecla del teclado a una acción DJ con detección interactiva en vivo y validación de conflictos.

## Consecuencias

### Positivas
- **Democratización de la Mezcla DJ:** Cualquier usuario puede practicar y tocar mezclas completas utilizando exclusivamente el teclado de su laptop o PC de escritorio.
- **Acústica Profesional de Mezcla:** El crossfader de potencia constante previene caídas de volumen percibido en el centro de la transición.
- **Rendimiento de 60/120 FPS:** Aislamiento del repintado de jog wheels y respuesta de teclado determinista $\le 8\text{ ms}$.
- **Arquitectura Limpia:** Totalmente desacoplada de la infraestructura, probada unitariamente al 100% en Dart puro.

### Negativas / Mitigaciones
- **Pulsación Múltiple Simultánea (Key Rollover / Ghosting) en Teclados Económicos:** Ciertos teclados de membrana de bajo coste no registran más de 3 o 4 teclas pulsadas a la vez.
  *Mitigación:* Se diseñó un mapa de distribución por defecto que separa las teclas de Deck A (mano izquierda) y Deck B (mano derecha) minimizando colisiones matriciales de hardware.