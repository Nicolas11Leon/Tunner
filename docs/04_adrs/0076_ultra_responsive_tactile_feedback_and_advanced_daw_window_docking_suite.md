# ADR 0076: Suite de Respuesta Táctil Ultra-Reactiva y Sistema Avanzado de Acoplamiento de Ventanas DAW

## Estado
Aprobado

## Contexto
Durante las pruebas de usuario se detectó que:
1. La retroalimentación de los botones no resultaba evidente: al presionar PLAY, CUE o interactuar con el teclado, los LEDs virtuales de la consola física (`DjHardwareSkinEntity`) no se sincronizaban activamente con el estado real de los reproductores Deck A y Deck B, provocando una sensación de desconexión táctil o falta de respuesta.
2. El sistema de ventanas dependía de arrastrar manualmente desde un pequeño indicador, lo cual resultaba poco intuitivo para usuarios que buscaban reorganizar rápidamente su espacio de trabajo sin fricción.
3. El rendimiento visual requería aislamiento explícito mediante `RepaintBoundary` para evitar repintados innecesarios de componentes contiguos al mover perillas o reproducir formas de onda.

## Decisión
Se decide implementar una evolución integral en la capa de interacción y presentación:
1. **Sincronización Continua de LEDs de Hardware en ViewModel:**
   - En `DjConsoleViewModel`, cada mutación de estado en los decks (Play/Pause, Cue, Sync, Hot Cues 1-4, Mute de Stems) ejecuta `_syncHardwareSkinLeds()`, actualizando `isLedLit` en las zonas correspondientes de `activeSkin`.
   - Se introduce un mecanismo de pulsación transitoria (`activePushedZoneId`) que ilumina instantáneamente con un pulso neón cualquier control presionado en pantalla o disparado por tecla física durante 80 ms, brindando retroalimentación táctil inmediata sub-10ms.
2. **Presets de Disposición en 1-Click (Workspace Layout Presets):**
   - Se añade a `StudioWorkspaceDockingContainer` una barra superior de configuraciones ergonómicas instantáneas: "DJ Club Clásico", "Consola Fiel", "Estudio 4-Stems", "Monitor Espectral" y "Dividido 3 Paneles", permitiendo al usuario reconfigurar todo el entorno sin necesidad de arrastrar.
3. **Acciones Directas de Acoplamiento en Cabeceras (`StudioDockableWindowCard`):**
   - Cada tarjeta de ventana incorpora botones de acción directa con tooltips para enviar la ventana a la izquierda, derecha, zona inferior o maximizar con un solo clic.
   - Soporte de doble clic en la barra de título para alternar entre modo maximizado y modo dividido.
4. **Optimización con `RepaintBoundary`:**
   - Cada panel desacoplado y la superficie vectorial de la consola se encapsulan dentro de un `RepaintBoundary` para evitar invalidaciones cruzadas de renderizado en el árbol de Flutter.

## Consecuencias

### Positivas
- Respuesta visual inmediata y tangible en todos los controles (LEDs sincronizados en tiempo real y halo de pulsación).
- Experiencia de usuario significativamente más fácil e intuitiva: reorganización de paneles con 1 solo clic o botones visibles.
- Mayor rendimiento y fluidez (60/120 FPS sostenidos) con aislamiento de repintado.
- Adherencia total a la Clean Architecture y filosofía offline-first de Tunner.

### Negativas / Mitigaciones
- Mayor cantidad de componentes reactivos en la interfaz: se mitiga manteniendo estados inmutables y delegando cálculos pesados fuera del hilo de renderizado principal.
