# UC-171: Catalogo Unificado de 40 Instrumentos (Hornbostel-Sachs) y Superficies Tactiles Interactivas

## 1. Informacion General

| Campo | Valor |
| :--- | :--- |
| **ID** | UC-171 |
| **Historia de Usuario** | US-6.4 (EPIC-06) |
| **Actores** | Musico / Estudiante (Usuario), `InstrumentSelectorModal`, `InstrumentProfileEntity`, `FretboardTactileWidget`, `InstrumentEmulationSurfaceWidget` |
| **Precondiciones** | El usuario abre `InstrumentSelectorModal` o interactua con `FretboardTactileWidget` o `InstrumentEmulationSurfaceWidget`. |
| **Postcondiciones** | Todos los 40 instrumentos de `UniversalInstrumentDefinition.masterCatalog` (incluyendo Kora, Sitar, Shakuhachi, Charango, Cuatro) son seleccionables en `InstrumentSelectorModal`; todos los trastes `1..totalFrets` de `FretboardTactileWidget` sintetizan f = f_open * 2^(fret/12); cada llave o piston en `_buildGenericAcousticSurface` dispara un grado diatonico/armonico real. |

---

## 2. Diagrama de Casos de Uso

```mermaid
flowchart LR
    Usuario((Musico / Estudiante))
    subgraph CatalogoYSuperficies["Catalogo Universal y Superficies Tactiles"]
        UC1["Seleccionar entre 40 Instrumentos"]
        UC2["Tocar Trastes 1..totalFrets en Diapason"]
        UC3["Tocar Llaves / Pistones con Grados Reales"]
    end

    Usuario --> UC1
    Usuario --> UC2
    Usuario --> UC3
```

---

## 3. Diagrama de Secuencia

```mermaid
sequenceDiagram
    actor U as Usuario
    participant ISM as InstrumentSelectorModal
    participant FTD as FretboardTactileWidget
    participant IES as InstrumentEmulationSurfaceWidget

    U->>ISM: Abre selector de instrumentos
    ISM-->>U: Lista >= 40 instrumentos (incluyendo Hornbostel-Sachs)
    U->>FTD: Pulsa traste fret (1..totalFrets) en cuerda s
    FTD->>FTD: Calcula f = f_open * 2^(fret/12)
    FTD-->>U: onNoteTriggered(f)

    U->>IES: Pulsa llave/piston indice k
    IES->>IES: Calcula f = baseHz * 2^(semitoneOffset[k]/12)
    IES-->>U: onFrequencyTriggered(f)
```

---

## 4. Flujo Principal

1. `InstrumentProfileEntity.standardInstruments` sincroniza los perfiles correspondientes a los 40 instrumentos de `UniversalInstrumentDefinition.masterCatalog` (conservando los 21 IDs clasicos).
2. `FretboardTactileWidget` agrega zonas interactivas (`InkWell`/`GestureDetector`) para cada traste `1..totalFrets` de cada cuerda, calculando $f = f_{\text{open}} \cdot 2^{\text{fret}/12}$.
3. `InstrumentEmulationSurfaceWidget._buildGenericAcousticSurface` asigna un grado de escala diatonica/armonica real a cada boton de llave/piston dentro de `[minFrequencyHz, maxFrequencyHz]`, en lugar de emitir siempre el promedio `(min + max) / 2`.

---

## 5. Flujos Alternativos y de Error

- **FA-1 (Cuerda fuera de rango de afinacion):** Si `s >= tuningFrequencies.length`, el toque se ignora de forma segura sin `RangeError`.
- **FA-2 (Rango acustico invertido o nulo):** Si `minFrequencyHz <= 0` o `maxFrequencyHz <= minFrequencyHz` en `_buildGenericAcousticSurface`, se usa `220.0 Hz` como base segura y se acota la frecuencia resultante.
