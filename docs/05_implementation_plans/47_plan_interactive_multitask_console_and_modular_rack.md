# Plan de Implementación: Consola Multitarea Central y Rack de Estudio Modular Interactivo con Estilos por Instrumento

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-MODULAR-RACK-2026-0047`
- **Título de la Implementación:** Consola Multitarea Central, Bus de Señales por IDs y Rack de Estudio Modular Drag & Drop con Estilos Adaptativos de Instrumento
- **Fase del Proyecto:** Fase 4 (Estudio de Producción y Usabilidad Avanzada)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0043](../../docs/04_adrs/0043_interactive_multitask_console_and_modular_rack.md)
- **Documento Funcional Base:** [Documento Técnico](../../docs/01_product_vision/doc_interactive_multitask_console_and_modular_rack.md) y [Caso de Uso 47](../../docs/02_use_cases/47_uc_interactive_multitask_console_and_modular_rack.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Revolucionar la experiencia de usuario (UX) de **Tunner** proporcionando un espacio de trabajo modular donde los músicos puedan arrastrar y soltar herramientas, interconectarlas dinámicamente mediante identificadores de puerto tipados (Audio PCM, Pitch, Partituras y Reloj), coordinar sesiones de práctica o producción mediante una Consola Multitarea Maestra, y disfrutar de una estética visual inmersiva ajustada a la identidad física y acústica de cada instrumento.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación del modelo de dominio puro de enrutamiento: `SignalType`, `PortId`, `ModuleConnection`, `SignalBus` y pruebas unitarias completas.
  - Creación de los modelos y entidades de módulos de rack (`RackModuleEntity`, `RackModuleType`, `InstrumentStyleProfile`).
  - Creación de la Consola Multitarea Central (`MultitaskMasterConsoleWidget`) con transporte sincronizado (Play/Pause/Rec global) y visualizador de conexiones por ID.
  - Creación del lienzo interactivo de rack con reordenamiento Drag & Drop (`ModularStudioRackView`) con soporte para expandir, colapsar y cerrar módulos.
  - Integración de los módulos interactivos clave:
    1. Afinador Estroboscópico de Conservatorio.
    2. Metrónomo Determinista con Tap Tempo.
    3. Pentagrama Vectorial SMuFL con modo "Escuchar y Transcribir en Vivo".
    4. Grabador de Estudio con cadena conectable de Autotune.
    5. Dron Armónico Tonal.
    6. Analizador de Espectro / Acordes.
  - Motor de Estilos Visuales por Instrumento (Guitarras/Bajos, Cuerdas frotadas, Vientos y Voz).
  - Acceso directo a este nuevo modo desde la navegación principal (`MainAppShell`).
- **Excluido (Out-of-Scope):**
  - Servidores o sincronización en la nube (se mantiene la estricta regla 100% Offline First de AGENTS.md).
  - Protocolos propietarios externos fuera de los estándares abiertos ya soportados (MIDI, MusicXML, WAV/AAC).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.x` (lenguaje base estricto).
- **Flutter Framework:** Componentes nativos de Material 3, `ReorderableListView` con físicas personalizadas, `CustomPainter` vectoriales.
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias de red o servicios externos?: **No** (100% local e in-process).
  - ¿Afecta el rendimiento del bucle principal?: **No**; el bus de señales y el procesamiento de audio corren en memoria directa o sub-Isolates sin bucles de espera activa (*zero busy-waiting*).

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Implementar `lib/features/modular_rack/domain/signal_type.dart` y `port_id.dart`.
- [x] Implementar `lib/features/modular_rack/domain/module_connection.dart` y topologías de conexión (Punto a Punto vs Broadcast).
- [x] Implementar `lib/features/modular_rack/domain/signal_bus.dart` para despacho de eventos reactivo sin dependencias de UI.
- [x] Implementar `lib/features/modular_rack/domain/rack_module_entity.dart` y estados de visualización (compacto, expandido, puertos disponibles).
- [x] Implementar `lib/features/modular_rack/domain/instrument_style_profile.dart` con configuraciones estéticas y ergonómicas por instrumento.
- [x] Redactar y ejecutar suite de pruebas unitarias exhaustiva en `test/features/modular_rack/domain/`.

### Paso 2: Capa de Infraestructura / Adaptadores
- [x] Implementar conectores de señal para el flujo de afinación, metrónomo, grabador y autotune.
- [x] Garantizar el manejo seguro de desconexiones en caliente (*hot-swapping*) y descarte de streams sin fugas de memoria.

### Paso 3: Capa de Presentación (ViewModels y UI Interactiva)
- [x] Implementar `lib/features/modular_rack/presentation/modular_rack_viewmodel.dart` para gestionar el estado del rack, conexiones activas y transporte maestro.
- [x] Implementar el widget de la Consola Multitarea `MultitaskMasterConsoleWidget` con vúmetros animados y panel de matriz de IDs.
- [x] Implementar el contenedor de tarjeta `RackUnitCard` con manija de arrastre (drag handle), selectores de puerto In/Out y estilo temático del instrumento.
- [x] Implementar la vista del lienzo `ModularStudioRackView` con bandeja de módulos arrastrables (*Drawer de Módulos*).
- [x] Conectar la vista en `MainAppShell` como el nuevo espacio de trabajo estelar de Tunner.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecución de `flutter analyze` verificando 0 errores y 0 advertencias de linter.
- [x] Ejecución de `flutter test` verificando que todas las pruebas pasen al 100%.
- [x] Verificación de fluidez de animaciones a 60/120 FPS y cumplimiento estricto de [AGENTS.md](../../AGENTS.md).

---

## 4. Estrategia de Rollback (Plan de Contingencia)

Si se detectan caídas de FPS o inestabilidad en la gestión de memoria:
- El código se estructura de manera puramente modular en su propio paquete `lib/features/modular_rack/`.
- La navegación en `MainAppShell` puede desacoplar el acceso a este nuevo espacio sin afectar la estabilidad de las vistas tradicionales preexistentes.
- Punto de restauración Git: `HEAD` en commit `00a8515`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero busy-waiting loops en Isolates y subprocesos.
- [ ] Pruebas unitarias de dominio y presentación pasando al 100%.
- [ ] Caso de uso `47_uc...`, ADR `0043...` y Plan `47_plan...` completamente redactados y versionados en `docs/`.
