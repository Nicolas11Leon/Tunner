# Plan de Implementación: Sistema Modular de Herramientas, Conectores Hiper-Sincronizados y Formato de Proyecto Propietario Hiper-Comprimido (.tunner / .tnt)

Este documento define la estructura obligatoria que debe redactarse y validarse antes de ejecutar cualquier cambio significativo en el código fuente de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-MODULAR-PROJECT-FORMAT-2026-082`
- **Título de la Implementación:** `Sistema de Herramientas Modulares Reordenables, Patchbay de Conectores Hiper-Sincronizados, Renombrado/Exportación de Herramientas (.tnt) y Formato Binario de Proyecto Propietario Hiper-Comprimido (.tunner)`
- **Fase del Proyecto:** `Fase 2`
- **Estado:** `En Progreso`
- **ADR Relacionado:** [ADR 0072: Formato Binario Comprimido Propietario (.tunner / .tnt) y Patchbay de Conectores](../04_adrs/0072_modular_patchbay_hyper_sync_and_compressed_project_format.md)
- **Documento Funcional Base:** [Caso de Uso 82](../02_use_cases/82_uc_modular_patchbay_hyper_sync_and_compressed_project_format.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Transformar el flujo de trabajo de la estación de estudio en una experiencia fluida, intuitiva y de nivel profesional:
1. **Arrastre y creación instantánea de herramientas:** Facilitar la creación, duplicación y reordenamiento por arrastre de módulos en el rack.
2. **Hiper-sincronización entre salidas con conectores:** Implementar un sistema interactivo de conectores (Patchbay virtual) donde cada herramienta expone sus puertos de Entrada y Salida (Audio PCM, Pitch/Cents, Reloj BPM, Notas Musicales), permitiendo conectar cualquier salida con entradas compatibles con latencia cero en el `SignalBus`.
3. **Identidad y persistencia por herramienta (.tnt):** Permitir renombrar cualquier herramienta en vivo (ej: "Afinador Voz Lead", "Bajo Sintetizador") y exportarla/importarla como un archivo de preset individual atómico `.tnt` (Tunner Tool).
4. **Formato de Archivo Propietario Hiper-Comprimido (.tunner):** Diseñar e implementar desde cero el formato de archivo de proyecto propietario de Tunner (`.tunner`), un contenedor binario de compresión sin pérdidas (zlib/deflate) con cabecera de verificación (`TUNP`), checksum de integridad, metadatos, serialización de módulos y grafo completo de conexiones.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio `TunnerProjectPackage` y `TunnerToolPreset`.
  - Entidad de enrutamiento `PatchbayRoutingConnection`.
  - Códec binario `TunnerBinaryProjectCodec` con firma `0x54554E50` ("TUNP"), compresión de ratio $>80\%$ y validación de versión.
  - Repositorio de persistencia local `ProjectStorageRepository` para guardar y cargar proyectos `.tunner` y herramientas `.tnt`.
  - Métodos en `ModularRackViewModel` para renombrar herramientas, exportar/importar presets `.tnt`, conectar/desconectar puertos y serializar/deserializar el proyecto completo.
  - Componente modal/hoja de diálogo interactiva de conexionado de puertos `StudioPatchbayModal`.
  - Cuadro de diálogo de renombrado en `RackUnitCard`.
  - Pruebas unitarias de compresión/descompresión, integridad de datos, y pruebas de widgets.
- **Excluido (Out-of-Scope):**
  - Almacenamiento en servidores en la nube (la aplicación cumple con la regla no negociable de **100% Offline-First**).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` estándar.
  - Flutter SDK: Canal estable.
  - Compresión binaria: `dart:io` (`GZipCodec`, `ZLibCodec`) y `dart:typed_data` nativo puro. Cero librerías externas pesadas.
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI adicionales? No, utiliza los códecs deterministas integrados de Dart.
  - ¿Afecta el rendimiento del bucle principal de Flutter? No, la serialización binaria se ejecuta de forma asíncrona y no bloqueante.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Crear `lib/features/project_format/domain/patchbay_routing_connection.dart`.
- [x] Crear `lib/features/project_format/domain/tunner_tool_preset.dart`.
- [x] Crear `lib/features/project_format/domain/tunner_project_package.dart`.
- [x] Crear contrato abstracto `lib/features/project_format/domain/project_storage_repository.dart`.
- [x] Pruebas unitarias de serialización/deserialización en memoria.

### Paso 2: Capa de Infraestructura / Datos (Códec Binario y Almacenamiento)
- [x] Implementar `lib/features/project_format/data/tunner_binary_project_codec.dart`:
  - Magic bytes: `0x54, 0x55, 0x4E, 0x50` (`TUNP`).
  - Versión del protocolo: `1`.
  - Empaquetado binario comprimido con ZLib/GZip.
  - Métodos `Uint8List encodeProject(TunnerProjectPackage package)` y `TunnerProjectPackage decodeProject(Uint8List bytes)`.
  - Métodos `Uint8List encodeToolPreset(TunnerToolPreset preset)` y `TunnerToolPreset decodeToolPreset(Uint8List bytes)`.
- [x] Implementar `lib/features/project_format/data/local_project_storage_repository.dart`.

### Paso 3: Capa de Presentación (ViewModels, UI de Conectores y Diálogos)
- [x] Extender `ModularRackViewModel` con:
  - `renameModule(String moduleId, String newTitle)`.
  - `saveProjectToFile(String filePath, String projectName)`.
  - `loadProjectFromFile(String filePath)`.
  - `exportToolPresetToFile(String moduleId, String filePath)`.
  - `importToolPresetFromFile(String filePath)`.
- [x] Implementar `StudioPatchbayModal`: Matriz interactiva de conectores por herramienta donde el usuario ve las salidas disponibles y las conecta a entradas con 1 click.
- [x] En `RackUnitCard`: agregar botón para renombrar herramienta en vivo y exportar preset `.tnt`.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Pruebas unitarias completas de códec y preservación de conexiones.
- [x] Pruebas de widgets de interfaz.
- [x] Ejecución de `flutter analyze` (cero advertencias).
- [x] Ejecución de `flutter test`.
- [x] Compilación y lanzamiento del binario en desktop.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit `419b4e9`.
- **Mitigación Inmediata:** Si la compresión binaria fallara, el `SignalBus` actual en memoria continúa operando de forma aislada sin degradación.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](AGENTS.md).
- [ ] Cero dependencias de microservicios o red (100% Offline-First).
- [ ] Pruebas unitarias pasando al 100%.
- [ ] Formato binario `.tunner` y `.tnt` con compresión superior al 80% frente a JSON plano.
- [ ] Documentación técnica y ADR redactados.
