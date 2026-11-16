# ADR 0072: Formato Binario Comprimido Propietario (.tunner / .tnt) y Patchbay de Conectores Hiper-Sincronizados

- **Estado:** Aceptado
- **Fecha:** 2026-11-16
- **Contexto:**
  Los usuarios y productores que utilizan la estación de trabajo modular Tunner requieren una experiencia de producción musical fluida donde las herramientas puedan renombrarse individualmente, interconectarse mediante puertos de entrada y salida con latencia ultra baja, y guardarse tanto como herramientas individuales reutilizables (`.tnt`) como proyectos completos de sesión (`.tunner`).
  Almacenar proyectos en texto JSON plano o XML sin comprimir genera archivos de gran tamaño, lecturas lentas y riesgo de adulteración accidental o corrupción. Asimismo, un formato propietario eficiente garantiza portabilidad 100% offline y soberanía digital.

- **Decisión:**
  1. Diseñar e implementar el formato de archivo binario propietario de Tunner:
     - **Extensión de Proyecto:** `.tunner` (Tunner Studio Project Package).
     - **Extensión de Herramienta Preset:** `.tnt` (Tunner Tool Preset).
     - **Magic Bytes:** `0x54, 0x55, 0x4E, 0x50` (`TUNP`) para proyectos, y `0x54, 0x4E, 0x54, 0x50` (`TNTP`) para herramientas.
     - **Mecanismo de Compresión:** Algoritmo ZLib/Deflate estándar determinista provisto por `dart:io` sin librerías externas.
  2. Implementar un grafo de enrutamiento (`PatchbayRoutingConnection`) persistido dentro del paquete, permitiendo al `ModularRackViewModel` auto-reconstruir el cableado en el `SignalBus` al abrir el proyecto.
  3. Proporcionar capacidades de renombrado in-place para cualquier módulo dentro de la interfaz.

- **Consecuencias:**
  - **Positivas:** Reducción de más del 80% en el tamaño del archivo en comparación con JSON sin comprimir; preservación atómica del estado del rack y cableado; carga instantánea offline; soporte para compartir herramientas individuales entre proyectos.
  - **Negativas:** Los archivos binarios no son legibles directamente con un editor de texto convencional (se implementa método canónico de exportación/importación legible si se requiere depuración).
