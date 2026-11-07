# Plan de Implementación: Interoperabilidad Atómica y Sinergia de Herramientas de Estudio

- **ID del Plan:** `PLAN-2026-049`
- **Fase:** Fase 4 & Global
- **Fecha:** 2026-11-07
- **Estado:** Ready for Execution

---

## 1. Objetivos

1. Extender `SignalType` con los nuevos tipos de señal: `tuningCalibration` y `spectralData`.
2. Crear la jerarquía inmutable de eventos atómicos `AtomicSignalEvent` en `lib/features/modular_rack/domain/atomic_signal_event.dart`.
3. Crear el contrato `InteroperableModuleNode` para que cada módulo del rack declare formalmente su capacidad de procesar y emitir señales tipadas.
4. Mejorar `SignalBus` para despachar eventos polimórficos validados por tipo de señal y enrutar transmisiones uno-a-uno y uno-a-muchos (Broadcast).
5. Implementar adaptadores/nodos atómicos para las herramientas principales:
   - Metrónomo (Emite `temporalClock` y `transportControl`).
   - Afinador Estroboscópico (Consume `audioPcm`, emite `pitchEvents`).
   - Pentagrama SMuFL (Consume `temporalClock` y `pitchEvents`).
   - Grabador de Práctica (Consume `audioPcm`, `temporalClock` y `transportControl`).
   - Consola Maestra Multitarea (Emite `tuningCalibration` y `transportControl` a todos los módulos conectados).
6. Implementar suites de pruebas unitarias exhaustivas con 100% de éxito.

---

## 2. Tareas de Implementación

- [ ] **Tarea 1 (Dominio):** Extender `SignalType` en `signal_type.dart` con `tuningCalibration` y `spectralData`.
- [ ] **Tarea 2 (Dominio):** Crear `atomic_signal_event.dart` con eventos polimórficos inmutables (`ClockTickEvent`, `AudioPcmEvent`, `PitchStreamEvent`, `TransportEvent`, `TuningCalibrationEvent`, `SpectralDataEvent`).
- [ ] **Tarea 3 (Dominio):** Crear `interoperable_module_node.dart` para regular la interacción atómica de cada módulo.
- [ ] **Tarea 4 (Dominio):** Actualizar `SignalBus` con despacho tipado, validación de compatibilidad y desacoplamiento de errores.
- [ ] **Tarea 5 (Presentación / ViewModel):** Integrar la sinergia atómica en `ModularRackViewModel` para que los módulos reaccionen a eventos cruzados.
- [ ] **Tarea 6 (Pruebas Unitarias):** Crear `test/features/modular_rack/atomic_tool_synergy_test.dart` cubriendo ruteo, sincronía temporal, propagación de afinación y tolerancia a fallos.
- [ ] **Tarea 7 (Verificación y Documentación):** Ejecutar `flutter analyze` y `flutter test`, verificar 0 warnings y documentar los resultados.
