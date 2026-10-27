# Caso de Uso 13: Calibración de Afinación de Concierto A4 & Persistencia Local Offline

---

## 1. Identificación y Metadatos

- **ID:** `UC-13`
- **Nombre:** Calibración de Afinación de Concierto A4 y Motor de Persistencia Local Offline
- **Actor Principal:** Músico / Estudiante / Pedagogo
- **Fase:** Fase 4 (Estudio de Práctica & Integración Universal)
- **Prioridad:** Alta (Requisito de Precisión Acústica e Integridad de Sesión)

---

## 2. Descripción

Permite al intérprete ajustar libremente la frecuencia de concierto del tono La4 ($A_4$) entre $415.0\text{ Hz}$ y $466.0\text{ Hz}$ (con presets a 432 Hz, 440 Hz, 442 Hz y 444 Hz), adaptando instantáneamente los cálculos de afinación estroboscópica y aguja de cents. Paralelamente, garantiza que las preferencias acústicas, los temas de interfaz personalizados, el historial de evaluación de notas y los metadatos de las grabaciones de auto-escucha queden respaldados en el almacenamiento no volátil del dispositivo sin requerir conexión a internet.

---

## 3. Diagramas Mermaid Obligatorios

### 3.1 Diagrama de Casos de Uso Formal

```mermaid
flowchart LR
    User([Músico / Usuario])

    subgraph AppSystem [Tunner: Subsistema de Afinación & Persistencia]
        UC_Calibrate["Calibrar Tono Concierto A4 (415-466 Hz)"]
        UC_QuickPreset["Seleccionar Preset Típico (432, 440, 442, 444 Hz)"]
        UC_RecalculatePitch["Recalcular Desviación Cents en Tiempo Real"]
        UC_PersistSettings["Persistir Preferencias y Temas en Disco"]
        UC_PersistHistory["Persistir Historial de Práctica y Grabaciones"]
        UC_RestoreOnBoot["Restaurar Estado al Iniciar la App"]
    end

    User --> UC_Calibrate
    User --> UC_QuickPreset
    UC_Calibrate --> UC_RecalculatePitch
    UC_QuickPreset --> UC_RecalculatePitch
    UC_Calibrate -.->|Auto-save| UC_PersistSettings
    User -.->|Completa Práctica| UC_PersistHistory
    AppSystem --> UC_RestoreOnBoot
```

### 3.2 Diagrama de Flujo / Secuencia Detallado

```mermaid
sequenceDiagram
    autonumber
    actor Musician as Músico / Usuario
    participant UI as TunerScreen / ConcertPitchModal
    participant VM as TunerViewModel
    participant Domain as NoteEntity / AppUserSettingsEntity
    participant Storage as JsonLocalPersistenceService
    participant Disk as Almacenamiento Local (POSIX)

    Note over Musician, Disk: Flujo 1: Calibración de Afinación A4
    Musician->>UI: Toca Chip "A4 = 440 Hz" o abre menú de afinación
    UI->>Musician: Despliega Modal de Calibración con Presets (432, 440, 442, 444 Hz)
    Musician->>UI: Selecciona "442 Hz (Sinfónico)" o ajusta slider fino
    UI->>VM: setReferencePitch(442.0)
    VM->>Domain: NoteEntity.fromFrequency(pitch, a4Ref: 442.0)
    Domain-->>VM: Nota recalculada y desviación en cents adaptada
    VM->>UI: notifyListeners() (Aguja y Strobe giran con nuevo centro de afinación)
    VM->>Storage: saveSettings(activeSettings)
    Storage->>Disk: Escritura atómica en tunner_settings.json.tmp -> renameSync
    Storage-->>VM: Persistencia exitosa garantizada

    Note over Musician, Disk: Flujo 2: Arranque de la Aplicación y Restauración
    Musician->>UI: Inicia Tunner
    UI->>VM: loadPersistedState()
    VM->>Storage: loadSettings()
    Storage->>Disk: Lee tunner_settings.json
    Disk-->>Storage: JSON válido de preferencias e historial
    Storage-->>VM: AppUserSettingsEntity restaurada
    VM->>VM: Aplica A4 (442.0 Hz), Tema activo, Instrumento y Sesiones
    VM->>UI: notifyListeners() con estado recuperado idéntico al anterior
```

---

## 4. Precondiciones, Postcondiciones y Flujos

### 4.1 Precondiciones
- La aplicación está instalada y dispone de acceso de lectura/escritura en su directorio privado de documentos (`getApplicationDocumentsDirectory()`).

### 4.2 Postcondiciones
- El motor de afinación calcula el temperamento igual respecto a la frecuencia $A_4$ elegida.
- El archivo `tunner_settings.json` contiene la última versión serializada del estado de la aplicación.
- No se produce ningún consumo de red ni busy-waiting en el hilo de UI.

### 4.3 Flujo Principal
1. El usuario visualiza en la interfaz del afinador la frecuencia de referencia actual ($A_4 = 440.0\text{ Hz}$).
2. El usuario toca el indicador y se abre el modal `ConcertPitchSelectorModal`.
3. El usuario pulsa una pastilla rápida (ej. "442 Hz Orquesta") o desliza el regulador de precisión.
4. El sistema actualiza el estado, recalcula instantáneamente las notas captadas por el micrófono y programa la persistencia en segundo plano.
5. El modal se cierra y la interfaz refleja el nuevo centro tonal.

### 4.4 Flujos Alternativos y de Error
- **FA-1 (Archivo de configuración inexistente o corrupto):** Si es la primera vez que se ejecuta la app o si el JSON estuviera corrupto, `JsonLocalPersistenceService` captura la excepción sin lanzar error y genera un estado por defecto canónico ($A_4 = 440.0$, tema Obsidian Studio, flauta traversa).
- **FA-2 (Frecuencia fuera de rango):** Si el usuario ingresa un valor menor a $415.0\text{ Hz}$ o mayor a $466.0\text{ Hz}$, el sistema lo restringe estrictamente (*clamping*) dentro del rango acústico seguro.
