# Plan de Implementacion - US-2.4: Superficie Tactil Hardware Interactiva y Persistencia Real de Consolas DJ

## 1. Descripcion del Cambio
Implementar controles reactivos continuos (knobs y faders) en `DjHardwareConsolePainter`, soporte de arrastre continuo en `DjVisualMappingOverlay`, metodos de lectura y actualizacion de controles en `DjConsoleViewModel`, dinamizacion de atajos en `DjStudioWorkstationView` y persistencia real de blueprints en `DjConsoleModelBuilderModal`.

## 2. Archivos Afectados
- `lib/features/dj_console/presentation/dj_hardware_console_painter.dart`:
  - Recibir `double Function(DjSkinZoneEntity zone)? getControlValue`.
  - Calcular angulo rotatorio preciso en `_paintKnob` (arco $270^\circ$, de $135^\circ$ a $405^\circ$).
  - Calcular desplazamiento de tapa en `_paintFader` (horizontal y vertical).
- `lib/features/dj_console/presentation/dj_visual_mapping_overlay.dart`:
  - Recibir `double Function(DjSkinZoneEntity zone)? getControlValue`.
  - Recibir `void Function(DjSkinZoneEntity zone, double delta)? onContinuousControl`.
  - Diferenciar en `onPanUpdate` entre controles continuos (`fader`, `knob`, `jogWheel`) y botones discretos.
- `lib/features/dj_console/presentation/dj_console_view_model.dart`:
  - Implementar `double getControlValue(DjSkinZoneEntity zone)`.
  - Implementar `void updateContinuousControl(DjSkinZoneEntity zone, double delta)`.
- `lib/features/dj_console/presentation/dj_studio_workstation_view.dart`:
  - Pasar `getControlValue` y `onContinuousControl` a las instancias de `DjVisualMappingOverlay`.
  - Dinamizar `_buildShortcutsHud` usando `vm.keymapProfile`.
  - Pasar `DjConsoleBlueprintStorageService()` a `DjConsoleModelBuilderModal.show`.
- `lib/features/dj_console/presentation/dj_console_model_builder_modal.dart`:
  - Registrar la consola creada en `DjHardwareCatalog.registerCustomSkin(skin)`.
  - Aplicar `setKeymapProfile` al guardar y emular.
- `test/features/dj_console/us_2_4_dj_hardware_overlay_and_model_builder_test.dart`:
  - Pruebas unitarias de calculo angular/desplazamiento, interaccion continua y persistencia de blueprints.

## 3. Plan Paso a Paso
1. Crear metodos `getControlValue` y `updateContinuousControl` en `DjConsoleViewModel`.
2. Actualizar `DjHardwareConsolePainter` para pintar agujas y tapas reactivas segun el valor.
3. Actualizar `DjVisualMappingOverlay` para pasar valores y gestionar `onPanUpdate`.
4. Dinamizar atajos en `DjStudioWorkstationView` e inyectar almacenamiento en modal de construccion.
5. Registrar consola en `DjHardwareCatalog` en `DjConsoleModelBuilderModal`.
6. Redactar suite de pruebas unitarias y verificar analisis estatico con 0 issues.
