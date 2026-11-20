# UC-135: Endurecimiento Pre-v1.0.0 Ola C (Notacion SMuFL, Parsers/Exporters, Pedagogia, Navegacion, Shell y DSL)

## 1. Metadata
- **ID:** UC-135
- **Issue:** #94
- **Milestone:** Pre-v1.0.0 Final Wave C
- **Actores:** Musico / Estudiante, Compositor / Arreglista, Ingeniero de Audio / Operador DSL, Sistema Tunner

## 2. Descripcion
Garantiza la correccion estructural, matematica y de flujo de usuario en los subsistemas de notacion musical SMuFL, edicion de partitura, exportacion/importacion (PDF, MusicXML, MIDI, ABC, OMR), evaluacion pedagogica (lecciones guiadas, entrenamiento auditivo, repeticion espaciada), transcripcion en vivo, navegacion/modales del shell, docking y ejecucion del DSL/Terminal OS.

## 3. Diagrama de Casos de Uso
```mermaid
flowchart LR
  Musico["Musico / Estudiante"] --> UC1["Visualizar Notacion SMuFL y Lineas Adicionales"]
  Musico --> UC2["Completar Lecciones Guiadas y Entrenamiento Auditivo"]
  Compositor["Compositor / Arreglista"] --> UC3["Editar, Importar y Exportar Partituras (PDF/MusicXML/MIDI/ABC)"]
  Operador["Operador DSL / Shell"] --> UC4["Navegar Modales, Docking y Terminal OS/DSL"]
  UC1 --> Sistema["Motor Tunner Offline"]
  UC2 --> Sistema
  UC3 --> Sistema
  UC4 --> Sistema
```

## 4. Diagrama de Secuencia (Flujos Endurecidos)
```mermaid
sequenceDiagram
  participant U as Usuario
  participant UI as Shell / Modales / Docking
  participant SM as SMuFL / Editor / Exporters
  participant PD as Pedagogia / SRS
  participant DSL as OS Kernel / DSL

  U->>SM: Renderizar o dividir nota / exportar PDF-MusicXML-MIDI-ABC
  SM-->>U: Lineas adicionales con signo correcto, cabezas huecas preservadas, PDF con xref exacto y roundtrip integro
  U->>PD: Completar leccion guiada o responder intervalo auditivo
  PD-->>U: Vista de completado alcanzable, evaluacion enarmonica MIDI, rechazo de silencio (0 Hz), nextReview al 90%
  U->>UI: Abrir Busqueda/QuickJump/Docking
  UI-->>U: Todas las acciones enrutadas, layouts <= 1.0 sin overflow
  U->>DSL: Ejecutar comandos fs/io o script DSL secuencial
  DSL-->>U: Sin fugas FFI, temporizacion secuencial real y solfeo correcto
```

## 5. Precondiciones y Postcondiciones
- **Precondiciones:** Wave B integrada en `qa`.
- **Postcondiciones:**
  - `SmuflGlyphPathEngine` dibuja lineas adicionales arriba/abajo con el signo correcto y usa `PathFillType.evenOdd` en redondas.
  - `ScoreEditorOperations` preserva la cola al dividir notas y marca silencios con `isRest: true`; `AlgorithmicExerciseGenerator` marca silencios con `isRest: true`.
  - `CanonicalPdfExporter` no corrompe bemoles en espanol (`MIB4` -> `Eb4`), no tapa cabezas huecas y lee el compas real.
  - `PedagogicalReportPdfGenerator` genera `xref` con offsets de bytes `latin1` exactos, sin operador ilegal `arc`, usando matriz absoluta `Tm`, hash `sha256` real, respetando `includeRhythmJitter` y marca `"TUNNER"`.
  - `GuidedLessonsModal`, `PracticeEvaluatorService`, `BlindEarTrainerEngine` y `EbbinghausSpacedRepetitionEngine` evaluan enarmonicos por MIDI, rechazan `0 Hz`, muestran pantalla de completado y alinean `nextReview` con `retentionAt(nextReview) == 0.90`.
  - Parsers/Exporters (MusicXML, MIDI, ABC, PDF/OMR, AudioToScore) y `TunnerOsKernel` / `TunnerDslInterpreter` / `StudioWorkspaceDockingContainer` / `ToolSearchModal` / `TaskQuickJumpModal` operan sin datos mock, fugas ni overflows.

## 6. Flujo Principal y Alternativos
- **Flujo Principal:** Cada componente valida entradas malformadas o casos borde (enarmonicos, compases compuestos, silencios, layouts extremos) y produce salida determinista.
- **Flujos Alternativos / Error:**
  - WAV con `channels == 0` o `sampleRate == 0` es rechazado con error controlado sin division por cero.
  - Scripts DSL con `isDryRun: true` simulan sin despachar audio ni mutar estado.
  - Paneles dockeados con suma `left + right > 1.0` se ajustan proporcionalmente al espacio disponible.
