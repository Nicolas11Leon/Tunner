# ADR 0145: Superficie Tactil Hardware Interactiva y Persistencia Real de Consolas DJ

## Estado
Aprobado

## Contexto
El emulador de hardware DJ contaba con una representacion grafica de alta fidelidad, pero adolecia de tres deficiencias cardinales:
1. `DjHardwareConsolePainter` renderizaba todos los potenciometros fijos a las 12 en punto y todos los faders clavados al 50% (`rect.center`), desfasados del estado acustico real del motor.
2. `DjVisualMappingOverlay` trataba los gestos de arrastre (`onPanUpdate`) sobre knobs, faders y jogs como simples taps discretos `onActionTriggered`, impidiendo modulaciones analogicas continuas de volumen, crossfader o barrido de filtro.
3. `DjConsoleModelBuilderModal` se instanciaba con `NoOpDjConsoleBlueprintStorageService`, descartando los controladores construidos por el usuario y omitiendo su inclusion en el catalogo de hardware (`DjHardwareCatalog`). Ademas, la barra HUD mostraba combinaciones de teclas estaticas sin sincronizacion con `keymapProfile`.

## Decision
1. Incorporar en `DjHardwareConsolePainter` la lectura de valores de control en tiempo real mediante `double Function(DjSkinZoneEntity zone)? getControlValue`.
2. Mapear los knobs en un arco circular analogico de $270^\circ$ ($0.75\pi$ a $2.25\pi$), calculando la posicion angular exacta de la aguja indicadora segun el valor normalizado.
3. Mapear los faders (horizontales para crossfader y verticales para canal/pitch) calculando la coordenada de la tapa en funcion del valor normalizado `[0.0, 1.0]`.
4. Extender `DjVisualMappingOverlay` y `DjConsoleViewModel` con soporte para modulacion continua bidireccional (`updateContinuousControl`), distinguiendo controles continuos de botones discretos en `onPanUpdate`.
5. Integrar `DjConsoleBlueprintStorageService` en `DjConsoleModelBuilderModal`, registrar skins creadas en `DjHardwareCatalog.registerCustomSkin` y dinamizar el HUD de atajos leyendo directamente `vm.keymapProfile`.

## Consecuencias
- Coherencia visual y acustica absoluta en toda la suite de consolas DJ emuladas.
- Experiencia de usuario tactil y de raton fluida a 60/120 FPS sin bucles de espera ni retardos.
- Soporte completo para diseno, emulacion y persistencia permanente de controladores fisicos personalizados.
