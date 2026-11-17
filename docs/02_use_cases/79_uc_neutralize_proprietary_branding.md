# Caso de Uso 79: Neutralización de Marcas Propietarias y Adopción de Tunner Studio Design System

## Metadatos
- **ID:** `UC-BRANDING-79`
- **Nombre:** Neutralización de Marcas Propietarias y Adopción de Tunner Studio Design System
- **Fase:** Fase 3 (Estación de Trabajo Desktop & Arquitectura Visual Limpia)
- **Actores:** Músico, Desarrollador, Diseñador de Sistema
- **Estado:** Aprobado

---

## 1. Descripción
Este caso de uso formaliza el renombramiento de todos los temas visuales, selectores de paleta y tokens de diseño para erradicar cualquier referencia a marcas comerciales ajenas (como Adobe o sus productos), adoptando una identidad de marca 100% propia y original denominada **Tunner Studio Design System**, con variantes de paleta: `Studio Dark`, `Studio Obsidian`, `Studio Slate Dark` y `Studio Light`.

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User([Usuario de la Estación]) --> U1[Conmutar Tema de la Estación]
    User --> U2[Configurar Apariencia en Preferencias]

    subgraph Tunner Studio Design System
        U1 --> T1[Studio Dark: Fondo estándar de bajo brillo]
        U1 --> T2[Studio Obsidian: Alto contraste acústico]
        U1 --> T3[Studio Light: Modo de alta luminosidad]
        U2 --> T4[Studio Slate Dark: Editor avanzado]
    end
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Usuario as Músico / Productor
    participant Switcher as StudioThemeSwitcher
    participant Ctrl as StudioThemeController
    participant Tokens as StudioDesignTokens
    participant Tree as Árbol de Renderizado

    Usuario->>Switcher: Clic en botón de conmutación de tema
    Switcher->>Ctrl: selectById('studio_obsidian')
    Ctrl->>Tokens: Obtiene tokens de Studio Obsidian
    Ctrl->>Tree: Notifica cambio reactivo a InheritedNotifier
    Tree-->>Usuario: Actualiza lienzo con nueva paleta libre de marcas de terceros
```

---

## 4. Flujo Principal

1. El usuario visualiza en la esquina superior derecha del shell de escritorio la insignia de tema activo (ej. `Studio Dark`).
2. Al pulsar el botón, la aplicación cicla o abre el selector de temas propios de la suite.
3. Todas las etiquetas mostradas al usuario corresponden a nombres genéricos y técnicos de **Tunner Studio** (`Studio Dark`, `Studio Obsidian`, `Studio Light`), garantizando cumplimiento de propiedad intelectual y ausencia de marcas registradas ajenas.

---

## 5. Precondiciones y Postcondiciones

- **Precondición:** La aplicación ejecuta el sistema de temas atómico `StudioThemeScope`.
- **Postcondición:** Cero ocurrencias de nombres de marcas comerciales ajenas en la interfaz gráfica y en las definiciones de tokens del código fuente.
