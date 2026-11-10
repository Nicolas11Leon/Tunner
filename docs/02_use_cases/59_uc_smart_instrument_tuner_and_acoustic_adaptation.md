# Caso de Uso 59: Afinador Inteligente por Reconocimiento Tímbrico y Adaptación Acústica

## 1. Descripción
El Afinador Inteligente monitorea de forma pasiva la entrada del micrófono, extrayendo la frecuencia fundamental y la distribución de armónicos $H_1-H_8$. Mediante el algoritmo de clasificación acústica multivariada, identifica automáticamente el instrumento musical en uso, reconfigura los filtros pasa-altos y de supresión de ruido del micrófono, y ajusta la emisión del diapasón acústico para utilizar el timbre real del instrumento.

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User((Músico))
    Mic[Micrófono Input]
    SmartDetector[Motor SmartInstrumentDetector]
    AcousticLab[Laboratorio Acústico / Filtros]
    TunerEngine[Afinador MPM / Estroboscópico]
    SoundFontEngine[Sintetizador SoundFont SF2]

    User -->|Toca una nota o frase| Mic
    Mic -->|Audio PCM y Pitch Frame| SmartDetector
    SmartDetector -->|Calcula firma acústica & confianza| SmartDetector
    SmartDetector -->|Detecta instrumento con confianza >= 85%| AcousticLab
    AcousticLab -->|Adapta filtros min/max Hz y Noise Gate| TunerEngine
    SmartDetector -->|Selecciona timbre SoundFont real| SoundFontEngine
    TunerEngine -->|Visualización estroboscópica calibrada| User
    SoundFontEngine -->|Diapasón con timbre real| User
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Musico
    participant UI as TunerScreen
    participant VM as TunerViewModel
    participant Detector as SmartInstrumentDetector
    participant PitchService as PitchDetectionService
    participant Synth as SoundFontSynthesizer

    Musico->>UI: Toca nota física (ej. Clarinete en Sib)
    UI->>VM: onPitchDetected(freq: 466.16 Hz, clarity: 0.95)
    VM->>Detector: evaluateAcousticFrame(frequency, overtones)
    Detector->>Detector: Calcular similitud armónica y rango
    Detector-->>VM: SmartInstrumentMatch(clarinet_bb, confidence: 0.92)
    alt Modo Auto-Switch Activado
        VM->>VM: setInstrumentProfile(clarinet_bb)
        VM->>PitchService: setInstrumentAcousticFilter(range: 116-1800 Hz)
        VM->>Synth: selectPatch(clarinet_sf2_patch)
        VM-->>UI: Notifica cambio automático con animación háptica
    else Modo Sugerencia Asistida
        VM-->>UI: Muestra SmartInstrumentBadge("¿Clarinete Sib? [Adaptar]")
        Musico->>UI: Toca botón "Adaptar"
        UI->>VM: confirmInstrumentMatch(clarinet_bb)
    end
```

---

## 4. Precondiciones
1. La entrada de micrófono debe estar activa y calibrada.
2. El modo de Afinador Inteligente debe estar habilitado en la configuración o ViewModel.
3. El sonido entrante debe superar la compuerta de ruido básica del sistema.

---

## 5. Flujo Principal
1. El usuario emite un sonido con su instrumento musical.
2. El `SmartInstrumentDetector` analiza la frecuencia fundamental y la distribución de armónicos $H_1-H_8$.
3. El sistema calcula la similitud espectral con los perfiles acústicos de la base de datos de Tunner.
4. Al obtener un match con confianza $\ge 0.85$, se sugiere o actualiza automáticamente el perfil de instrumento activo.
5. El filtro acústico del afinador MPM se ajusta al ancho de banda exacto del instrumento.
6. El sintetizador SoundFont asigna el patch timbral del instrumento para la reproducción del diapasón.

---

## 6. Flujos Alternativos y Excepciones
- **Confianza insuficiente (< 0.70):** Si el sonido es ambiguo (ej. un tono senoidal o ruido ambiental), el sistema mantiene el perfil instrumental previamente configurado sin cambios intempestivos.
- **Instrumento no catalogado:** Si el instrumento no está en la base de datos, el sistema clasifica por familia general (Vientos Madera, Vientos Metal, Cuerdas, Percusión Afinada) y aplica filtros genéricos de familia.
