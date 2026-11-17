# Caso de Uso 78: Erradicación Integral de Mocks, Persistencia de Estado de Rack y Menús Desktop Profesionales

## Metadatos
- **ID:** `UC-WORKSTATION-78`
- **Nombre:** Erradicación Integral de Mocks, Persistencia de Estado de Rack y Menús Desktop Profesionales
- **Fase:** Fase 3 (Estación de Trabajo Desktop & Arquitectura Modular)
- **Actores:** Músico Profesional, Productor de Audio, Estudiante de Conservatorio
- **Estado:** Aprobado

---

## 1. Descripción
Este caso de uso describe la interacción fluida y profesional del usuario con la estación de trabajo desktop de **Tunner**. Resuelve de manera integral la presencia de funciones incompletas o simuladas en los menús de la cabecera superior, las opciones de utilidades del sistema (`Automations`, `Customizations`, `Settings`), la barra omnibox interactiva de comandos (`StudioCommandPromptBar`) y la preservación de estado continuo del rack modular de efectos e instrumentos (`ModularRackViewModel`).

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User([Músico / Productor]) --> M1[Interactuar con Menús Desktop]
    User --> M2[Acceder a Automatizaciones de Práctica]
    User --> M3[Personalizar Parámetros DSP y Visuales]
    User --> M4[Gestionar Ajustes Generales del Estudio]
    User --> M5[Ejecutar Comandos Omnibox / y @]
    User --> M6[Configurar Rack Modular sin Pérdida de Estado]

    subgraph Estación de Trabajo Desktop Tunner
        M1 --> A1[Menú Tunner: Info, Atajos, Salir]
        M1 --> A2[Menú Workspace: Nuevo Proyecto, Importar]
        M1 --> A3[Menú View: Alternar Rack y Paneles]
        M1 --> A4[Menú Window: Navegación de Herramientas]
        M2 --> D1[Modal de Automatizaciones de Práctica]
        M3 --> D2[Modal de Personalización DSP y Motor]
        M4 --> D3[Modal de Ajustes y Calibración A4]
        M5 --> C1[Autocompletado y Ejecución Inmediata]
        M6 --> R1[Persistencia de Módulos y Enrutamiento en Sesión]
    end
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musico as Músico / Productor
    participant Shell as StudioDesktopAppShell
    participant Main as MainAppShellState
    participant Prompt as StudioCommandPromptBar
    participant RackVM as ModularRackViewModel
    participant TunerVM as TunerViewModel

    Note over Musico, Shell: Interacción con Menú Desktop Superior
    Musico->>Shell: Clic en menú "Workspace"
    Shell->>Musico: Despliega opciones (Nuevo Proyecto, Importar, etc.)
    Musico->>Shell: Selecciona "Importar Archivo"
    Shell->>Main: Dispara importación nativa
    Main->>Musico: Abre diálogo selector de archivos

    Note over Musico, Prompt: Ejecución de Comandos Omnibox
    Musico->>Prompt: Escribe "@rack" o "/calibrar 442"
    Prompt->>Prompt: Filtra sugerencias en tiempo real
    Prompt->>Musico: Muestra ventana emergente con atajos y descripción
    Musico->>Prompt: Presiona Enter o selecciona sugerencia
    Prompt->>Main: Ejecuta acción atómica asociada
    Main->>TunerVM: Actualiza tono de referencia o navega a pestaña

    Note over Musico, RackVM: Preservación de Estado del Rack
    Musico->>Main: Navega al Rack Modular y añade módulo "Afinador Pro"
    Main->>RackVM: addModule(strobeTuner)
    Musico->>Main: Cambia a pestaña "Afinador" y luego regresa a "Estudio"
    Main->>RackVM: Lee módulos activos persistentes
    RackVM-->>Musico: Módulo "Afinador Pro" permanece montado intacto
```

---

## 4. Flujo Principal de Trabajo

1. **Acceso a Menús Superiores:**
   - El usuario hace clic en `Tunner`, `Workspace`, `View` o `Window` en la barra superior.
   - La aplicación despliega inmediatamente un menú emergente nativo con opciones claras, atajos de teclado y acciones directas.
   - El usuario selecciona la acción deseada (ej. crear partitura, importar audio, alternar rack) y la aplicación responde de inmediato.
2. **Uso de Herramientas de Barra Lateral:**
   - Al pulsar `Automations`, se despliega un panel de rutinas automatizadas (calentamiento técnico, rampa de BPM de metrónomo, auto-grabación).
   - Al pulsar `Customizations`, se abre el diálogo de personalización técnica (motor DSP Tartini/YIN/MPM, tasa de refresco 60/120 FPS, resolución de centésimas).
   - Al pulsar `Settings`, se abre el diálogo de configuración acústica (frecuencia A4, temperamento histórico, clave de afinación).
3. **Consola Omnibox y Autocompletado:**
   - El usuario escribe en la barra inferior. Al tipear `/` ve comandos de transporte y afinación (`/afinar`, `/metro`, `/bpm`, `/calibrar`, `/grabar`, `/help`).
   - Al tipear `@` visualiza herramientas y módulos disponibles para conmutar directamente (`@afinador`, `@metronomo`, `@partitura`, `@grabador`, `@rack`, `@espectrograma`, `@acordes`).
   - El autocompletado navega con teclas de flecha y se selecciona con `Tab` o `Enter`.
4. **Persistencia del Rack Modular:**
   - El usuario agrega módulos y ajusta diales en la vista modular.
   - Al navegar a cualquier otra sección (Biblioteca, Afinador, Ejercicios) y volver, toda la disposición modular se encuentra preservada.

---

## 5. Flujos Alternativos y Excepciones

- **A1. Comando no reconocido:**
  - Si el usuario tipea un comando inválido y presiona Enter, la barra notifica amablemente que el comando no existe y sugiere escribir `/help`.
- **A2. Cancelación de menús:**
  - Si el usuario hace clic fuera del menú o presiona Escape, el menú contextual o la ventana emergente de sugerencias se cierra limpiamente sin dejar residuos visuales.

---

## 6. Precondiciones y Postcondiciones

- **Precondición:** La aplicación debe estar inicializada en modo escritorio o responsive.
- **Postcondición:** Todas las interacciones de cabecera, utilidades y comandos producen respuestas funcionales reales; el estado de trabajo del rack no se reinicia durante la sesión.
