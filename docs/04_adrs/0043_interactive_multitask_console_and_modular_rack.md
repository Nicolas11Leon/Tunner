# ADR 0043: Consola Multitarea Central y Rack de Estudio Modular con Ruteo por IDs y Estilos por Instrumento

---

## Estado
**Aprobado (Approved)**

---

## Contexto
Actualmente, la arquitectura de presentación de **Tunner** organiza sus funcionalidades en múltiples pantallas estáticas (`TunerScreen`, `Workspaces`, `HomeDashboardScreen`) y recurre extensivamente a ventanas modales inferiores (`showModalBottomSheet`) para parametrizar herramientas acústicas esenciales (espectrograma, grabador, analizador de acordes, autotune, selector de temperamentos y lecciones guiadas).

Esta disposición genera una alta fricción cognitiva y operativa en el músico (UX deficiente):
1. **Falta de concurrencia visual:** Un músico no puede afinar con el dial estroboscópico mientras ve el pentagrama dinámico o supervisa la señal procesada por el módulo de autotune, dado que las ventanas modales bloquean la vista subyacente.
2. **Aislamiento de flujos de datos:** Aunque existen algoritmos de transcripción (mic-to-score), grabación, autotune y evaluación en el dominio, no existe un mecanismo desacoplado para que el usuario conecte la salida de un módulo (ej. audio procesado por autotune) a la entrada de otro (ej. grabador de práctica) de forma interactiva y en tiempo real.
3. **Rigidez estética:** Los instrumentos (guitarras, maderas, metales, cuerdas frotadas, voz) poseen características ergonómicas y acústicas únicas que demandan una presentación visual temática propia (diales analógicos de ganancia, visualizadores de trastes o afinación continua, curvas tonales vocales) en lugar de formularios genéricos.

---

## Decisión Arquitectónica

Se decide diseñar e implementar:

### 1. Modelo de Dominio de Puertos, Buses y Ruteo Desacoplado (`lib/domain/routing/`)
- **`PortId` & `SignalBus`:** Cada módulo expone puertos formales de entrada y salida clasificados por tipo de dato:
  - `SignalType.audioPcm`: Flujo binario de muestras de audio normalizadas en coma flotante.
  - `SignalType.pitchEvents`: Detección en tiempo real de tono ($f$ en Hz, nota, cents de desviación y amplitud).
  - `SignalType.musicalNotes`: Entidades estructuradas de partitura (notas, silencios, duraciones rítmicas).
  - `SignalType.temporalClock`: Pulsos de sincronización y sub-ticks de tempo emitidos por el Isolate del metrónomo.
- **Topología de Conexión:** Cada puerto de salida puede enrutarse en modo **Punto a Punto (`specific(moduleId)`)** o en modo **Difusión Global (`broadcast`)** a través de identificadores de bus alfanuméricos inmutables.

### 2. Consola Multitarea Central (Master Control & Orchestration)
- Coordina el estado de transporte global (`Play`, `Pause`, `Record`, `Mute`, `Solo`).
- Supervisa los retardos y compensa las latencias de procesamiento para asegurar que los eventos transcritos en el pentagrama coincidan temporalmente al milisegundo con el audio grabado y el pulso del metrónomo.
- Administra el ciclo de vida de los módulos en pantalla para evitar fugas de memoria y bucles de cálculo innecesarios.

### 3. Rack de Estudio Interactivo con Reordenamiento Drag & Drop (`lib/presentation/modular_rack/`)
- Lienzo dinámico donde cada herramienta reside como un bloque independiente (*Rack Unit*).
- Los módulos pueden arrastrarse para reordenar la jerarquía visual de trabajo, expandirse para ajuste fino o colapsarse en widgets compactos de lectura rápida.
- Integración visual de puertos con indicadores de conexión activos y enlaces de un solo toque.

### 4. Motor de Estilos Visuales Adaptativos por Instrumento (Instrument Theming Engine)
- Extensiones semánticas al sistema de diseño con paletas y acabados dedicados según la familia del instrumento:
  - **Guitarra / Bajo:** Estilo *Analogue Tone Lab* con diapasón visual, perillas tipo amplificador y veteado profundo.
  - **Cuerdas Frotadas:** Estilo *Classical Atelier* con diapasón continuo sin trastes e indicador de vibrato.
  - **Vientos (Madera / Metal):** Estilo *Concert Brass & Woodwind* con transposición automática visible en el encabezado del módulo y feedback de columna de aire.
  - **Voz:** Estilo *Studio Vocalist* con gráficos vectoriales de formantes y curva tonal de autotune en vivo.

---

## Consecuencias

### Positivas
- **Máxima interactividad y libertad de flujo:** El usuario compone su propio estudio de ensayo según sus necesidades del día con un simple arrastre.
- **Interoperabilidad completa de herramientas:** Permite casos de uso avanzados simultáneos como tocar y transcribir a la partitura mientras se graba con autotune.
- **Cero ventanas modales bloqueantes:** Toda la interacción ocurre dentro del espacio de trabajo visible.
- **Rigor acústico y de rendimiento:** La separación estricta de buses de señal en memoria local preserva la regla de latencia $\le 10\text{ ms}$ y la ausencia absoluta de *busy-waiting*.

### Negativas / Mitigaciones
- **Mayor complejidad en la gestión de estado:** Se mitiga encapsulando la lógica de enrutamiento en un `SignalBus` puro en la capa de Dominio, respaldado por pruebas unitarias exhaustivas con 100% de cobertura.
- **Carga de renderizado concurrentes:** Se mitiga permitiendo colapsar módulos no prioritarios y delegando los cálculos pesados de DSP y autotune a sub-Isolates de Dart.
