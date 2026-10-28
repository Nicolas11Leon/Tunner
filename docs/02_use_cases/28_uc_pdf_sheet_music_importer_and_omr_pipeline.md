# Caso de Uso 28: Ingesta de Partituras en PDF mediante OMR Vectorial

## 1. Identificación y Actores

- **ID del Caso de Uso:** `UC-28`
- **Nombre:** Importación y Reconocimiento Óptico de Partituras en PDF (Vector OMR Pipeline)
- **Actores:**
  - **Músico / Usuario:** Desea cargar una partitura en formato PDF para tocarla, practicarla con metrónomo interactivo o editarla.
  - **Motor Vectorial OMR Tunner:** Decodifica las primitivas gráficas del PDF, localiza pentagramas, extrae notas y construye un `HierarchicalScore`.
- **Nivel:** Resumen / Nivel de Usuario

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User((Músico / Usuario))

    subgraph Tunner PDF OMR Engine
        UC28_1[Seleccionar Archivo PDF de Partitura]
        UC28_2[Extraer Instrucciones Gráficas del PDF]
        UC28_3[Clustering de Líneas de Pentagrama]
        UC28_4[Detección de Barras de Compás y Notas]
        UC28_5[Construir HierarchicalScore y Desplegar en Visor SMuFL]
    end

    User --> UC28_1
    UC28_1 --> UC28_2
    UC28_2 --> UC28_3
    UC28_3 --> UC28_4
    UC28_4 --> UC28_5
```

---

## 3. Diagrama de Secuencia y Flujo de Procesamiento (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Usuario
    participant UI as ScoreImportTabView / Modal
    participant Importer as UniversalScoreImporterService
    participant PdfParser as PdfScoreParser
    participant OMR as VectorOmrEngine
    participant VM as TunerViewModel
    participant Canvas as RealSheetMusicPainter

    Usuario->>UI: Selecciona partitura PDF
    UI->>Importer: parseScoreData(bytes, "obra.pdf")
    Importer->>PdfParser: canParse("obra.pdf", bytes) -> true
    Importer->>PdfParser: parseScoreData(bytes, "obra.pdf")
    PdfParser->>PdfParser: Extrae streams de dibujo (m, l, re, c)
    PdfParser->>OMR: processVectorCommands(drawCommands)
    OMR->>OMR: Agrupa 5 líneas de pentagrama (Delta y equidistante)
    OMR->>OMR: Localiza barras de compás verticales
    OMR->>OMR: Mapea coordenadas Y de cabezas de nota a notas diatónicas
    OMR-->>PdfParser: HierarchicalScore construido
    PdfParser-->>Importer: ParsedScoreResult(HierarchicalScore)
    Importer-->>UI: Carga confirmada
    UI->>VM: addSongPackage(package)
    VM->>Canvas: Renderiza en pentagrama vectorial interactivo SMuFL
```

---

## 4. Precondiciones, Postcondiciones y Flujos

### 4.1 Precondiciones
1. El usuario tiene un archivo PDF local disponible en el sistema de archivos del dispositivo.
2. La ejecución es completamente autónoma y 100% offline.

### 4.2 Flujo Principal
1. El usuario presiona "Seleccionar Archivo Local" o el botón de muestra de partitura PDF.
2. El sistema valida la cabecera `%PDF-`.
3. El motor `VectorOmrEngine` detecta los sistemas de pentagramas y las notas asociadas.
4. Se calcula la duración de cada figura y se empaquetan en compases estándar.
5. La partitura se monta en el visor principal con playback, stems y aguja estroboscópica.

### 4.3 Flujos de Error
- **PDF protegido con contraseña o dañado:** El sistema captura el error y emite una `FormatException` amigable en la interfaz.
- **PDF sin gráficos vectoriales reconocibles:** Informa al usuario que el documento no contiene vectores musicales legibles.
