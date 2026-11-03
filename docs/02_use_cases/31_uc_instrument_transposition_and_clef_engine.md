# Caso de Uso 31: Motor de Transposición Tonal, Instrumentos Transpositores y Claves Musicales

---

## Metadatos del Documento

- **ID del Caso de Uso:** `UC-TRANS-031`
- **Nombre Formal:** Transposición Acústica de Instrumentos, Visualización Dual de Afinador y Soporte de Clave de Fa
- **Fase Asociada:** `Fase 11`
- **Actor Principal:** Músico / Estudiante de Vientos / Metales / Cuerdas Graves
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-28

---

## 1. Descripción del Caso de Uso

Un instrumentista (por ejemplo, clarinetista en Si♭ o saxofonista en Mi♭) utiliza Tunner para afinar su instrumento y practicar partituras. El sistema calcula y muestra instantáneamente la nota que el intérprete debe leer en sus dedos (nota escrita) mientras verifica la frecuencia acústica física (nota de concierto sonando), además de renderizar la clave correspondiente (Clave de Fa para instrumentos graves o Clave de Sol para agudos) y permitir transponer partituras completas a la afinación de su instrumento.

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
graph TD
    User["Intérprete / Músico"]
    
    subgraph Tunner["Sistema Tunner"]
        UC_SelectInst["Seleccionar Instrumento del Catálogo"]
        UC_DualDisplay["Afinación Dual (Nota Escrita vs. Sonando)"]
        UC_ClefRender["Renderizar Partitura en Clave (Sol / Fa)"]
        UC_ScoreTranspose["Transponer Partitura a Tonalidad del Instrumento"]
    end
    
    User --> UC_SelectInst
    UC_SelectInst --> UC_DualDisplay
    UC_SelectInst --> UC_ClefRender
    User --> UC_ScoreTranspose
    UC_ScoreTranspose --> UC_ClefRender
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musico as Intérprete (Vientos / Metales)
    participant UI as TunerScreen / StrobeTuner
    participant VM as TunerViewModel
    participant TransService as InstrumentTranspositionService
    participant Painter as RealSheetMusicPainter
    participant Mic as Micrófono / PitchDetector

    Musico->>UI: Selecciona "Trompeta en Si♭" (Key: Bb, Clef: Sol)
    UI->>VM: selectInstrument(bbTrumpet)
    VM->>VM: Actualizar perfil activo y notificar observadores
    VM->>UI: Refresca badges y configura Clave
    
    Musico->>Mic: Toca nota afinada en su instrumento
    Mic->>VM: onPitchDetected(233.08 Hz)
    VM->>VM: Calcular nota de concierto -> "La#3" / "Si♭3"
    VM->>TransService: getWrittenNote("Si♭3", bbTrumpet)
    TransService-->>VM: Retorna nota escrita -> "Do4"
    VM->>UI: Actualiza visualizador heroico:
    Note over UI: Muestra "Do4" (Escrita) y "Si♭3" (Sonando)
    
    Musico->>UI: Presiona "Transponer Partitura a Si♭"
    UI->>VM: transposeScoreForInstrument(bbTrumpet)
    VM->>Painter: Actualizar notas transpuestas y renderizar pentagrama
```

---

## 4. Flujo de Eventos

### 4.1 Precondiciones
- El usuario ha iniciado Tunner.
- El micrófono se encuentra habilitado para captura de audio.

### 4.2 Flujo Principal
1. El usuario abre el selector de instrumentos desde la barra superior o pedagógica.
2. Selecciona un instrumento transpositor (e.g. Clarinete en Si♭, Saxofón Alto en Mi♭ o Violonchelo en Clave de Fa).
3. El ViewModel actualiza el instrumento activo y recalcula las notas escritas.
4. Si el usuario toca su instrumento:
   - El micrófono estima la frecuencia física fundamental $f_0$.
   - El sistema calcula la nota física sonando.
   - El servicio de transposición aplica el offset de semitonos inverso para proyectar la nota escrita exacta que el instrumentista leyó en su método.
   - La pantalla muestra la nota escrita en tamaño grande y la nota física en subtítulo.
5. Si el instrumento tiene configurada Clave de Fa, el visor de partituras dibuja automáticamente la Clave de Fa y ajusta las posiciones verticales de las notas.

### 4.3 Flujos Alternativos
- **A1: Instrumento en tono de concierto (Flauta, Violín, Voz):**
  - El offset de transposición es 0. El afinador muestra la nota directamente sin etiqueta dual.
- **A2: Instrumento de clave de Fa en partitura de clave de Sol:**
  - El usuario puede conmutar manualmente la clave de visualización si desea leer en clave de Sol o transponer la octava.

---
## 8. Guía de Pruebas Manuales y Bitácora de Validación

### 8.1 Precondiciones y Preparación del Entorno
- Partitura con pentagrama visible en pantalla.

### 8.2 Procedimiento de Ejecución Paso a Paso
1. Abrir el menú de transposición y claves del pentagrama.
2. Cambiar la clave de **Clave de Sol en 2ª** a **Clave de Fa en 4ª**.
3. Observar la reubicación de las cabezas de nota sobre las líneas del pentagrama.
4. Cambiar a **Clave de Do en 3ª** (viola) y **Clave de Do en 4ª** (trombón/fagot).
5. Aplicar una transposición de intervalo (+2 semitonos / un tono arriba).

### 8.3 Checklist de Validación Sensorial (Resultado Esperado)
- [ ] Redibujado visual inmediato de las notas en la posición correcta de la nueva clave.
- [ ] La reproducción sonora sigue sonando en la altura tonal real de concierto.
- [ ] La armadura de clave se actualiza coherentemente según el círculo de quintas.
- [ ] Ausencia de superposiciones o choques visuales entre notas y armadura.

### 8.4 Registro de Bitácora de Ejecución de Campo
| Fecha | Tester / Músico | Dispositivo / SO | Clave Evaluada | Resultado | Observaciones / Aspectos por Pulir |
| :---: | :---: | :---: | :---: | :---: | :--- |
| *Pendiente* | - | - | - | [ ] Pendiente | *Registrar observaciones de claves y transposición* |
