# Caso de Uso 58: Sinergia Integral Inter-Herramientas, Detección de Fricción y Orquestación Modular

## 1. Descripción
Formalizar el protocolo por el cual las herramientas de Tunner intercambian eventos estructurados mediante la matriz del `SignalBus` maestro, garantizando la activación de hiper-sinergias de alto impacto (Lectura en Vuelo, Afinador Inteligente, Suite Vocal Autotune, Descomponedor Minus-One) y previniendo de forma determinista los cruces forzados o incompatibles (ej. Autotune en Entrenador a Ciegas, sobrecarga polifónica directa a detectores monofónicos MPM).

---

## 2. Diagrama de Casos de Uso (Mermaid)

```mermaid
flowchart TD
    User((Músico / Estudiante))
    StudioConsole[Consola de Estudio / Rack Modular]
    PolicyEngine[Motor de Políticas de Sinergia]
    SignalBus[SignalBus Multiplexer]

    subgraph HiperSinergias["Hiper-Sinergias Permitidas (10x)"]
        S1[Lectura en Vuelo: Metro + Pentagrama + Afinador]
        S2[Suite Vocal: Autotune + Grabador + Pentagrama + Mixer]
        S3[Afinador Inteligente: Afinador + Instrumento + Lab Acústico]
        S4[Minus-One: Descomponedor + Mixer + SoundFont + Grabador]
        S5[Batimento: Dron + Espectrograma + Afinador]
    end

    subgraph CrucesRechazados["Cruces Forzados / Incompatibles (Rechazados)"]
        C1[Autotune directo a Oído a Ciegas]
        C2[Acorde Polifónico directo a MPM Monofónico]
        C3[Dron Armónico a Alta Velocidad en Pasajes Virtuosos]
    end

    User -->|Selecciona modo o conecta puertos| StudioConsole
    StudioConsole -->|Valida compatibilidad y política| PolicyEngine
    PolicyEngine -->|Aprobado| HiperSinergias
    PolicyEngine -.->|Rechazado con advertencia pedagógica| CrucesRechazados
    HiperSinergias -->|Ruteo de señales < 1ms| SignalBus
```

---

## 3. Diagrama de Secuencia (Mermaid)

```mermaid
sequenceDiagram
    autonumber
    actor Usuario
    participant Rack as ModularStudioRack
    participant Policy as SynergyPolicyEngine
    participant Bus as SignalBus
    participant Producer as Módulo Productor (ej. Mic / Metro)
    participant Consumer as Módulo Consumidor (ej. Pentagrama / Grabador)

    Usuario->>Rack: Conectar puerto Producer.out -> Consumer.in
    Rack->>Policy: validateConnection(sourcePort, targetPort)
    alt Es una combinación forzada o incompatible (ej. Autotune -> Oído a Ciegas)
        Policy-->>Rack: ConnectionRejectedException("Conflicto pedagógico o de dominio")
        Rack-->>Usuario: Muestra notificación explicativa y sugiere ruta alternativa
    else Es una conexión válida / Hiper-sinergia
        Policy-->>Rack: ConnectionApproved
        Rack->>Bus: connect(sourcePort, targetPort)
        Bus-->>Rack: Enlace activo (< 1ms latencia)
        loop Flujo Reactivo de Eventos
            Producer->>Bus: emitSignal(AtomicSignalEvent)
            Bus->>Consumer: onSignalReceived(event)
            Consumer->>Consumer: Actualizar estado y renderizar a 60/120 FPS
        end
    end
```

---

## 4. Precondiciones
1. Las herramientas participantes deben implementar el contrato `InteroperableModuleNode`.
2. El `SignalBus` maestro debe estar instanciado y operativo en memoria.
3. Los módulos involucrados deben contar con sus puertos tipados definidos en el dominio.

---

## 5. Flujo Principal
1. El usuario o una tarea TTC selecciona un flujo multi-herramienta.
2. El `SynergyPolicyEngine` valida que el enlace pertenezca a una topología acústicamente válida.
3. Se configuran las suscripciones en el `SignalBus` para los tipos de señal correspondientes (`temporalClock`, `pitchEstimate`, `audioPcm`, `scoreData`).
4. Los productores emiten eventos en tiempo real sin bloquear el hilo de interfaz.
5. Los consumidores reaccionan de inmediato con feedback auditivo o visual en los CustomPainters.

---

## 6. Flujos Alternativos y Manejo de Excepciones
- **Intento de conexión de cruce forzado:** Si el usuario intenta rutear una señal incompatible (ej. audio polifónico directo a la entrada monofónica del afinador MPM), el sistema bloquea el enlace con advertencia técnica y ofrece interponer el módulo de descomposición polifónica (*Polyphonic Multi-Tone Splitter*).
- **Sobrecarga de búfer o caída de FPS:** Si la multitarea combinada satura el procesador, las herramientas no críticas (como el renderizado del espectrograma) bajan su tasa de refresco a 30 FPS, manteniendo el reloj del metrónomo con jitter $< 1\text{ ms}$.
