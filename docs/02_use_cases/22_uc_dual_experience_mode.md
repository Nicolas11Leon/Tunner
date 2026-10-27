# Caso de Uso 22: Experiencia Dual Progresiva (Modo Esencial vs. Modo Conservatorio Pro)

Este documento define la especificación formal del modelo de interfaz adaptativa dual en **Tunner**.

---

## 1. Diagrama de Caso de Uso (Mermaid)

```mermaid
flowchart TD
    Actor([Músico Principiante o Profesional])

    subgraph Tunner Core UX System
        UC1[Alternar Modo de Experiencia]
        UC2[Renderizar Modo Esencial Minimalista]
        UC3[Visualizar Dial Estroboscópico & Nota Gigante]
        UC4[Renderizar Modo Conservatorio Pro]
        UC5[Desplegar Atril SMuFL, Stems, Lab & Analítica]
        UC6[Persistir Modo Preferido en JSON Atómico]
    end

    Actor --> UC1
    UC1 --> UC2
    UC1 --> UC4
    UC2 --> UC3
    UC4 --> UC5
    UC2 --> UC6
    UC4 --> UC6
```

---

## 2. Diagrama de Secuencia y Flujo Detallado (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musico as Usuario
    participant UI as TunnerScreen
    participant VM as TunnerViewModel
    participant Storage as JsonLocalPersistenceService

    Musico->>UI: Pulsa selector de modo ("Esencial" / "Conservatorio Pro")
    UI->>VM: toggleDisplayMode()
    VM->>VM: _displayMode = isEssential ? conservatoryPro : essential
    VM->>Storage: saveSettings(updatedSettings)
    VM-->>UI: notifyListeners()

    alt Modo Esencial
        UI->>UI: Ocultar pentagrama, mezcladora y grabadora
        UI->>UI: Expandir dial estroboscópico monumental y lectura de nota
    else Modo Conservatorio Pro
        UI->>UI: Mostrar estación acústica completa (SMuFL, Stems, Lab, Analítica)
    end
    UI-->>Musico: Interfaz adaptada instantáneamente sin parpadeos
```

---

## 3. Especificación Formal del Caso de Uso

### 3.1 Actores
* **Músico Principiante / Aficionado:** Desea una afinación visual rápida, limpia, sin curva de aprendizaje ni saturación cognitiva.
* **Músico Avanzado / Maestro de Conservatorio:** Requiere partitura SMuFL interactiva, edición, reproducción ADSR, análisis espectral de armónicos y consola de pistas.

### 3.2 Precondiciones
* La aplicación se encuentra en ejecución en cualquier plataforma soportada (Linux, Android, macOS, Windows, iOS).

### 3.3 Postcondiciones
* La interfaz se reconfigura en el mismo frame a 60 FPS sin recargar el estado del motor de afinación.
* El modo seleccionado se almacena de forma persistente y atómica en `tunner_settings.json`.
