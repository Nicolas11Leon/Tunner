# ADR 0074: Modelos Fidedignos de Consolas de Hardware DJ y Suite de Mapeo Interactivo de Teclado QWERTY

## Estado
Aprobado

## Contexto
El usuario y la especificación de producto de **Tunner** requieren que la consola virtual no se limite a tarjetas genéricas abstractas, sino que refleje fielmente los modelos de hardware físico reconocidos de la industria musical (Pioneer DDJ-FLX4, Pioneer CDJ-3000 + DJM-900NXS2, Traktor Kontrol S4 MK3, Denon DJ Prime 4+, Numark Mixtrack Pro FX). Además, para garantizar que cualquier usuario en computadora de escritorio pueda operar la consola con la misma destreza que un controlador físico, se requiere un sistema integral de configuración de teclado QWERTY:
1. Posibilidad de hacer clic en cualquier control físico (botón, perilla, fader) y presionar una tecla física para asignarla instantáneamente.
2. Visualización reactiva de las teclas asignadas como insignias (`badges`) flotantes sobre los controles del hardware.
3. Captura global de eventos de teclado mediante `KeyboardListener` con foco permanente en la estación de trabajo.
4. Un visualizador de teclado gráfico QWERTY con perfiles ergonómicos estándar de la industria (VirtualDJ, Traktor Pro, Serato DJ).

## Decisión
Se implementa una arquitectura modular desacoplada basada en Clean Architecture:
1. **Modelado Vectorial Industrial en `DjHardwareConsolePainter`:**
   - Pintura matemática sin dependencias de mapas de bits pesados, garantizando escalabilidad infinita a resoluciones 4K/retina y tasas de refresco de 60/120 FPS.
   - Texturizado procedural de vinilo con estrías micrométricas, marcadores de posición rotatoria, platos de arrastre, botones luminiscentes con bisel metálico y faders con pista de carbono.
   - Capa de renderizado condicional de insignias de teclas (`Key Badges`) superpuestas en cada control activo.
2. **Ampliación de `DjHardwareCatalog`:**
   - Incorporación de modelos emblemáticos con relaciones de aspecto y zonificación física normalizada exacta: `pioneer_ddj_flx4`, `pioneer_cdj_3000`, `traktor_kontrol_s4`, `denon_prime_4`, `numark_mixtrack_pro_fx`.
3. **Mapeo Interactivo y Captura de Eventos:**
   - Inclusión de `FocusNode` y `KeyboardListener` en `DjStudioWorkstationView` con invocación directa a `DjConsoleViewModel.handleKeyEvent(event)`.
   - Soporte para asignación instantánea en modo Learn (`bindKey`) y persistencia local inmediata mediante `DjKeymapPersistenceService`.
   - Perfiles preconfigurados en `DjKeymapProfileEntity`: `defaultErgonomic()`, `virtualDjStandard()`, `traktorProStandard()`, `seratoDjStandard()`.
4. **Visualizador Gráfico de Teclado QWERTY (`DjInteractiveKeymapVisualizerModal`):**
   - Representación interactiva de las filas de teclas del teclado de computadora con iluminación codificada por color según la acción musical asignada.

## Consecuencias

### Positivas
- Experiencia de usuario inmersiva con sensación de hardware físico profesional de alta gama.
- Operabilidad táctil y por teclado 100% fluida sin necesidad de periféricos externos costosos.
- Cero sobrecarga de red o servicios externos; funcionamiento puramente local y offline-first.
- Mantenimiento estricto del rendimiento a 60/120 FPS mediante renderizado vectorial optimizado.

### Negativas / Mitigaciones
- Complejidad en la densidad geométrica de los modelos de 4 canales: se mitiga empleando sistemas de coordenadas normalizadas `[0.0, 1.0]` y recorte seguro de zonas interactivas (`HitTestBehavior.opaque`).
