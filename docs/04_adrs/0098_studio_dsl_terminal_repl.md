# Registro de Decisión de Arquitectura (ADR) 0098: Terminal REPL y Consola de Scripting Interactiva para Tunner Studio OS

---

## Metadatos

- **ID del ADR:** `ADR-0098`
- **Título:** Arquitectura de la Consola Acoplable REPL y Editor Multilínea para Live Coding y Automatización Acústica
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 6`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 109](../02_use_cases/109_uc_studio_dsl_terminal_repl.md)
- **Plan Relacionado:** [Plan Épica 6.4](../05_implementation_plans/plan_studio_dsl_terminal_repl.md)
- **Issue Asociado:** [#36](https://github.com/Nicolas11Leon/Tunner/issues/36)

---

## 1. Contexto

La infraestructura del lenguaje Tunner DSL y el micro-kernel de audio permiten evaluar código declarativo en caliente. Sin embargo, para que los usuarios puedan interactuar de forma inmediata y didáctica, se requiere un entorno de edición interactivo tipo REPL embebido en el espacio de trabajo que cumpla con:

1. **Diseño Visual Atómico y Profesional:** Paleta dark slate, líneas hairline de 1 px, tipografía monoespaciada para métricas y código, y cero emojis.
2. **Fluidez 60/120 FPS:** La edición, análisis sintáctico y renderizado de resultados deben realizarse sin bloquear el hilo de interfaz de usuario.
3. **Ergonomía de Estudio:** Soporte para atajos de hardware (`Ctrl+Enter` / `Cmd+Enter`), plantillas acústicas listas para usar y diagnóstico visual inmediato.

---

## 2. Decisión

Se implementa el widget **`StudioDslTerminalPanelWidget`** en `lib/core/terminal/presentation/`:

1. **Estructura Visual:**
   - **Barra Superior de Control:** Selector de plantillas predefinidas (`quick_jam.tun`, `mastering_chain.tun`), botones de ejecución rápida y limpieza de historial.
   - **Editor de Código Multilínea:** Campo de texto con atajos de teclado (`Ctrl+Enter`, `Cmd+Enter`), soporte para tabulaciones y desplazamiento vertical suave.
   - **Consola de Salida y Diagnósticos:** Visor monoespaciado que detalla reportes de ejecución exitosa en verde mate o errores sintácticos con coordenadas en rojo mate.

2. **Plantillas Acústicas Embebidas:**
   - `quick_jam.tun`: Configura tempo a 128 BPM, canal sintetizador con onda senoidal, notas y acordes en bucle.
   - `mastering_chain.tun`: Configura ganancia maestra, curvas de ecualización de 3 bandas y umbral de compresión.

3. **Integración con Clean Architecture:**
   - La presentación interactúa exclusivamente a través del contrato `TunnerOsKernel` y `TunnerDslInterpreter`, sin llamadas directas a hardware de bajo nivel.

---

## 3. Consecuencias

### Positivas
- **Inmediatez Creativa:** Los productores pueden experimentar con código declarativo y escuchar los cambios sonoros en milisegundos.
- **Didáctica Musical:** Los errores de sintaxis muestran diagnósticos claros que enseñan la gramática musical del DSL.
- **Rendimiento Óptimo:** La evaluación en memoria local mantiene el renderizado a 60/120 FPS sin latencia de red.
