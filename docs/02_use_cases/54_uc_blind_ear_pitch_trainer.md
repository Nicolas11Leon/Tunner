# Caso de Uso 54: Entrenador Auditivo a Ciegas y Gamificación de Intervalos (Blind Ear Pitch Trainer)

## 1. Descripción
Permitir a estudiantes de conservatorio, cantantes e instrumentistas perfeccionar la discriminación de intervalos musicales, afinación relativa y reconocimiento tímbrico sin muletas visuales (Modo "A Ciegas"), mediante síntesis pura de frecuencias de referencia, captura de respuesta vocal o instrumental en tiempo real, medición de precisión en cents y atajos ergonómicos de teclado (`1-4`, `Espacio`, `C`).

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart LR
    Estudiante((Estudiante / Músico))
    TrainerUI[BlindEarTrainerModal]
    Engine[BlindEarTrainerEngine]
    Synth[AudioSynthesizer / Tone Generator]
    Mic[Mic In / PitchDetector]
    Bus[SignalBus Atómico]

    Estudiante -->|Inicia ejercicio o pulsa Espacio| TrainerUI
    TrainerUI -->|Genera nuevo reto de intervalo| Engine
    Engine -->|Sintetiza frecuencia base y destino| Synth
    Synth -->|Onda senoidal pura / SoundFont| Estudiante
    Estudiante -->|Canta o selecciona opción con 1-4| TrainerUI
    Mic -->|Detecta entonación cantada| Bus
    Bus -->|Valida cents y latencia| Engine
    Engine -->|Actualiza racha y puntuación| TrainerUI
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Estudiante as Estudiante de Canto
    participant UI as BlindEarTrainerModal
    participant Engine as BlindEarTrainerEngine
    participant Synth as AudioSynthesizer
    participant Mic as PitchDetector / Bus

    Estudiante->>UI: Abre Entrenador a Ciegas (Atajo Shift+E o Menú)
    UI->>Engine: startPracticeSession()
    Engine->>UI: Presenta pregunta (ej. Cuarta Justa ascendente desde A4)
    UI->>Synth: playInterval(440.0 Hz, 587.33 Hz)
    Synth-->>Estudiante: Emite intervalo auditivo sin mostrar nombre en pantalla (Blind Mode)
    
    alt Respuesta vía Teclado Rápido (1-4)
        Estudiante->>UI: Presiona '2' (Opción: 4ª Justa)
        UI->>Engine: submitChoice(interval)
        Engine-->>UI: Resultado: Correcto (+100 pts, Racha: 5)
    else Respuesta vía Canto / Instrumento
        Estudiante->>Mic: Canta la nota D5
        Mic->>Engine: emitPitch(587.1 Hz, deviation: -0.7 cents)
        Engine-->>UI: Precisión perfecta: -0.7 cents. Calificación: Óptima.
    end
    UI->>Synth: playFeedbackChime(isCorrect: true)
```

---

## 4. Precondiciones
1. La aplicación Tunner está ejecutándose y los motores de síntesis de audio (`AudioSynthesizerService`) y detección de tono están disponibles.
2. Los atajos de teclado primarios están activos en el shell de la aplicación.

---

## 5. Postcondiciones
1. Las métricas de desempeño pedagógico (racha de aciertos, desvío promedio en cents, tiempo de respuesta en milisegundos) se registran en la sesión del usuario.
2. El estudiante recibe retroalimentación inmediata auditiva y visual (revelando la respuesta una vez contestada).

---

## 6. Flujo Principal
1. El estudiante activa el Entrenador Auditivo a Ciegas utilizando el atajo de teclado o seleccionándolo en la barra de herramientas.
2. El sistema configura el modo "Pantalla Oculta / Blind Canvas", donde las pistas visuales de frecuencia se apagan temporalmente.
3. El motor sintetiza el intervalo musical objetivo (e.g. Segunda menor, Tercera mayor, Quinta justa, etc.).
4. El usuario puede volver a escuchar el estímulo pulsando la tecla `Espacio`.
5. El usuario responde seleccionando una de las 4 opciones aleatorizadas mediante las teclas numéricas `1`, `2`, `3` o `4`, o bien entonando la nota en el micrófono.
6. El motor valida la respuesta y entrega el desglose teórico (semitonos, relación matemática de frecuencias $f_2/f_1$, desvío en cents).
7. La sesión continúa fluidamente al siguiente ejercicio garantizando cero tiempos muertos.

---

## 7. Flujos Alternativos y Manejo de Errores
- **Repetición del Estímulo Auditivo:** Si el estudiante no identificó el intervalo al primer intento, la barra espaciadora (`Espacio`) repite el tono inmediatamente sin penalización.
- **Cambio de Rango Vocal:** Si el usuario no puede entonar una frecuencia aguda, puede cambiar el registro base (Bajo, Barítono, Tenor, Contralto, Soprano) para centrar los intervalos en su tesitura.
- **Salida o Pausa:** El usuario puede pulsar `Escape` en cualquier momento para pausar o cerrar el ejercicio y retornar al panel general conservando su estadística de sesión.
