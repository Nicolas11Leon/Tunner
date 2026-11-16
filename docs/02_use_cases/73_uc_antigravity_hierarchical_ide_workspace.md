# Caso de Uso 73: Espacio de Trabajo Jerárquico Desktop Estilo Antigravity / Adobe Audition

## 1. Identificación y Metadatos

- **ID del Caso de Uso:** `UC-073`
- **Nombre:** `Operación y Navegación Jerárquica de Proyectos y Módulos de Audio en Entorno de Escritorio Profesional`
- **Actores:** Músico Profesional, Diseñador de Sonido, Docente de Conservatorio.
- **Módulo Asociado:** `lib/core/design_system/organisms/studio_desktop_app_shell.dart`, `lib/core/design_system/molecules/studio_tree_view.dart`, `lib/features/navigation/presentation/main_app_shell.dart`.
- **Precondiciones:** La aplicación se ejecuta en una resolución de pantalla de escritorio (`>= 720px`).
- **Postcondiciones:** La interfaz presenta un sidebar de carpetas y proyectos jerárquicos multinivel idéntico a Antigravity IDE, con selector de ajustes, breadcrumbs interactivos y barra de comandos acústicos.

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
graph TD
    User(["Músico / Productor Desktop"])

    subgraph DesktopStudioShell["Estación de Trabajo Jerárquica Tunner IDE"]
        UC1["Navegar Árbol Jerárquico de Carpetas<br/>(tunner, Estudio, Laboratorio, Conservatorio)"]
        UC2["Expandir / Colapsar Carpetas de Proyecto<br/>(Visualizar Stems, Tomas y Modos de Afinación)"]
        UC3["Lanzar Herramienta de Audio Activa<br/>(Afinador, Rack DSP, Espectrograma, Partituras)"]
        UC4["Acceder a Automatizaciones & Metrónomo Continuo"]
        UC5["Abrir Panel de Ajustes & Calibración de Audio (Settings)"]
        UC6["Ejecutar Comandos Rápidos desde Prompt Inferior"]
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6
```

---

## 3. Diagrama de Flujo y Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musician as Músico / Productor
    participant Shell as StudioDesktopAppShell
    participant Tree as StudioTreeView (Multi-Folder)
    participant Engine as TunerViewModel
    participant Viewport as Workspace Central (Editor)
    participant Prompt as StudioPromptBar

    Musician->>Shell: Inicia aplicación en Linux Desktop
    Shell->>Tree: Renderiza proyectos y carpetas con glifos (folder, chevron)
    Tree-->>Musician: Despliega árbol con 'tunner', 'Estudio', 'Acústica', etc.
    Musician->>Tree: Clic en carpeta 'Laboratorio Acústico'
    Tree->>Tree: Anima apertura de carpeta (chevron_down + folder_open)
    Tree-->>Musician: Muestra nodos hijos: 'Espectrograma FFT', 'Analizador Polifónico'
    Musician->>Tree: Selecciona 'Espectrograma FFT'
    Tree->>Shell: Notifica evento onSelect(item_spectrogram)
    Shell->>Viewport: Actualiza vista central y breadcrumb: 'tunner / Laboratorio Acústico / Espectrograma FFT'
    Shell->>Prompt: Actualiza contexto activo
    Musician->>Prompt: Introduce comando rápido 'bpm 135' o atajo
    Prompt->>Engine: Despacha actualización de parámetros sin latencia
```

---

## 4. Descripción del Flujo de Interacción

### 4.1 Flujo Principal (Navegación Jerárquica)
1. El usuario visualiza la barra lateral izquierda organizada por niveles:
   - **Nivel Superior de Utilidades:** Enlaces a `Automatizaciones` y `Personalizaciones / Plugins DSP`.
   - **Cabecera de Proyectos:** Etiqueta `Projects` con botones de filtrado y creación de nuevas sesiones.
   - **Árbol de Proyectos:** Carpetas temáticas expandibles que contienen sesiones y submódulos de audio.
2. Al hacer clic sobre cualquier carpeta (ej. `tunner`, `Estudio & Grabación`, `Laboratorio Acústico`), esta se abre mostrando sus módulos hijos con sangría elegante y glifos técnicos.
3. El elemento activo se destaca con un contenedor de fondo pulido, dot indicador de actividad y badge de estado.
4. El área central actualiza instantáneamente el breadcrumb superior y el canvas de trabajo correspondiente.
5. En la parte inferior de la barra lateral, el usuario cuenta con el acceso a `Ajustes` (`Settings`) y el control rápido del instrumento seleccionado.

### 4.2 Flujos Alternativos y Excepciones
- **A1: Búsqueda o Filtrado Rápido:** El usuario presiona `Ctrl+K` o el icono de búsqueda en la barra superior para saltar directamente a cualquier herramienta sin desplegar manualmente las carpetas.
- **A2: Pantalla Reducida:** Si el usuario redimensiona la ventana a un ancho inferior a 720 px, la interfaz se adapta fluidamente a la vista compacta sin perder el estado de la sesión activa.
