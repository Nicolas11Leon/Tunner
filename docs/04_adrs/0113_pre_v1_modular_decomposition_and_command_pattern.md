# Architecture Decision Record: ADR-0113 - Descomposición Modular y Patrón Command en Núcleo y Presentación

---

## Metadatos del Documento

- **ID del ADR:** `ADR-0113`
- **Título:** Descomposición Modular de Clases Monolíticas, Intents de Navegación y Command Pattern en Terminal
- **Estado:** `Accepted`
- **Fecha:** `2026-11-19`
- **Fase Asociada:** `Pre-Release Gate v1.0.0 - Ola 4`
- **Contexto Técnico:** Issue #71
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Contexto

El análisis de cohesión detectó archivos monolíticos que dificultaban la lectura y mantenimiento: `TunerViewModel` (`3,062` LOC), `MainAppShell` (`1,763` LOC con `_buildPromptSuggestions` de `398` LOC y 25 `Intent`s), `TunnerOsKernel` (`1,199` LOC con 20 handlers en un solo archivo), y `VocalAutoTuneModal` (`build()` continuo de `774` LOC).

---

## 2. Decisión Arquitectónica

1. **Command Registry en `TunnerOsKernel`:**
   - Introducir `ITerminalCommandHandler` en `core/terminal/domain/i_terminal_command_handler.dart` y módulos de comandos separados en `core/terminal/application/handlers/`.
2. **Extracción Modular en `MainAppShell` y `VocalAutoTuneModal`:**
   - Extraer `studio_keyboard_intents.dart` y `studio_prompt_suggestions_builder.dart` en `features/navigation/presentation/`.
   - Fragmentar `VocalAutoTuneModal.build()` en métodos/widgets especializados por sección funcional (`< 150` LOC por método).
3. **Modularización Segura de `TunerViewModel`:**
   - Dividir `TunerViewModel` por dominio mediante bibliotecas `part` cohesivas en `features/` (grabación/loopback, edición SMuFL/exportación, laboratorio armónico/pedagogía, autotune/minus-one), reduciendo el archivo principal de `3,062` LOC a `< 600` LOC sin alterar un solo contrato público consumido por los widgets y las `1,075+` pruebas.

---

## 3. Consecuencias

### Positivas
- Reducción drástica del tamaño por archivo y por método `build()`.
- Extensibilidad $O(1)$ de nuevos comandos de terminal sin modificar `TunnerOsKernel.execute()`.
- Cero regresiones en la suite completa de pruebas.
