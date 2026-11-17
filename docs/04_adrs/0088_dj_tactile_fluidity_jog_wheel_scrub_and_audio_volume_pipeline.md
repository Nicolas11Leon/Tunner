# ADR 0088: Fluidez Táctil de Botones, Rebobinado Físico de Jog Wheels y Estabilidad de Volumen en Consola DJ

## Estado
Aprobado

## Contexto
Durante pruebas de ejecución manual en la Consola DJ Pro Studio, se manifestaron tres anomalías de respuesta táctil y acústica:
1. Al girar el plato / Jog Wheel en reversa, la canción no se rebobinaba (solo cambiaba temporalmente la velocidad de reproducción hacia adelante, sin alterar el cursor de reproducción). Adicionalmente, el arrastre táctil utilizaba una heurística lineal `(dx - dy)` que no correspondía a un movimiento circular real.
2. Al deslizar el volumen a cero y elevarlo de nuevo, el audio dejaba de sonar completamente en entornos Linux debido a que el sumidero GStreamer de `audioplayers` se pausaba al recibir volumen cero o llamadas concurrentes saturadas.
3. El fader vertical en el mezclador de canal (`DjVerticalChannelStrip`) contenía un valor estático sin enlazar al volumen real del deck (`onChanged: (_) {}`).

## Decisión
1. **Física Angular Polar en `VectorJogWheel`:**
   Calcular el ángulo polar exacto en cada actualización de arrastre:
   $$\Delta \theta = \text{atan2}(y_2 - c_y, x_2 - c_x) - \text{atan2}(y_1 - c_y, x_1 - c_x)$$
   normalizando en $[-\pi, \pi]$ para eliminar saltos de cuadrante.
2. **Rebobinado Real en Milisegundos (`scratchDeck`):**
   Vincular el desplazamiento angular al posicionamiento temporal del buffer:
   $$\Delta t = \Delta \theta \cdot 350\text{ ms}$$
   despachando `seekDeckPlayback` y `seekDeck` tanto en el orquestador como en el motor de audio hardware.
3. **Piso Anti-Freeze y Serialización en `DjDeckAudioService`:**
   Implementar en `setDeckVolume`:
   - Mapeo de volumen mínimo atenuado a $0.0001$ ($-80\text{ dBFS}$) durante reproducción activa para mantener el pipeline GStreamer en ejecución continua.
   - Si el volumen asciende y el deck está en estado `isPlaying`, verificar y reanudar activamente la reproducción mediante `player.resume()`.
   - Serializar y controlar llamadas repetidas para evitar congestión en el canal asíncrono.
4. **Enlace del Fader Vertical de Canal:**
   Conectar el `Slider` vertical de `DjVerticalChannelStrip` directamente a `viewModel.setDeckVolume(deckId, val)` y ampliar su tamaño táctil.

## Consecuencias
- **Positivas:**
  - El usuario puede rebobinar o avanzar cualquier canción suavemente girando el plato con los dedos.
  - Subir y bajar el volumen rápidamente mantiene la reproducción continua y sin caídas de audio.
  - El fader de canal modula el volumen físico de cada deck en tiempo real.
  - Respuesta táctil ágil y profesional en botones de transporte.
- **Negativas / Mitigaciones:**
  - Ninguna observada; la matemática polar se ejecuta en tiempo constante $O(1)$.
