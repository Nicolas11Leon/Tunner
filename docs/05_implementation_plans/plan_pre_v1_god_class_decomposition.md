# Implementation Plan: Descomposición Modular de God Classes y Pantallas Monolíticas (Ola 4)

**Issue Asociado:** #71 (Pre-v1.0.0 - Ola 4)  
**Rama:** `refactor/pre-v1-god-class-decomposition`  
**Rama Base:** `qa`  
**Fecha:** `2026-11-19`  

---

## 1. Resumen y Objetivos

Descomponer los archivos monolíticos más críticos (`MainAppShell`, `VocalAutoTuneModal`, `TunnerOsKernel`, `TunerViewModel`) en módulos cohesivos y mantenibles manteniendo el 100% de compatibilidad funcional y cobertura de pruebas.

---

## 2. Tareas de Implementación

- [ ] **Paso 1 (`MainAppShell`):** Extraer `studio_keyboard_intents.dart` (25 `Intent`s) y `studio_prompt_suggestions_builder.dart` (`398` LOC) fuera de `main_app_shell.dart`.
- [ ] **Paso 2 (`VocalAutoTuneModal`):** Fragmentar el método `build()` de `774` LOC en sub-métodos/widgets cohesivos (`< 150` LOC).
- [ ] **Paso 3 (`TunnerOsKernel`):** Definir `ITerminalCommandHandler` y extraer el registro modular de comandos manteniendo la API pública intacta.
- [ ] **Paso 4 (`TunerViewModel`):** Modularizar los bloques de grabación/espectro, editor/exportación SMuFL, dron/acordes/pedagogía y autotune/minus-one en módulos cohesivos sin romper firmas.
- [ ] **Paso 5 (Verificación):** `flutter analyze` (`0` issues) y `flutter test` (`100%` en verde).
