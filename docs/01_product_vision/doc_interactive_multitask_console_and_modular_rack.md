# Documento Técnico: Consola Multitarea Central y Rack de Estudio Modular Interactivo

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-0043`
- **Título Oficial:** Arquitectura de Rack Modular Interactivo Drag & Drop, Bus de Señales por IDs y Consola Multitarea de Coordinación
- **Estado:** Approved
- **Fecha de Creación:** 2026-11-06
- **Última Modificación:** 2026-11-06
- **Fase Asociada:** Fase 4 (Estudio de Producción y Usabilidad Avanzada)
- **Autor / Revisor Principal:** Equipo de Arquitectura Tunner & Creador del Proyecto

---

## 1. Resumen Ejecutivo (Executive Summary)

Este documento especifica la transformación de la experiencia de usuario (UX) y la infraestructura de presentación de **Tunner**. Se reemplaza el esquema tradicional de pantallas desconectadas y modales invasivos por un **Rack de Estudio Modular Interactivo (Drag & Drop)** gobernado por una **Consola Multitarea**. 

El sistema habilita la composición libre de espacios de trabajo para el músico, la interconexión dinámica entre herramientas (como cantar con autotune mientras se graba, o interpretar un instrumento acústico mientras el pentagrama vectorial transcribe las notas en tiempo real) a través de un bus de señales desacoplado con **identificadores de puerto (Port IDs)**, y una capa visual estilizada que se adapta a las características ergonómicas y acústicas de cada instrumento musical.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Hasta ahora, las herramientas profesionales de Tunner (Afinador Estroboscópico, Metrónomo, Pentagrama SMuFL, Grabador, Autotune, Espectrograma) funcionaban como islas independientes o requerían abrir diálogos modales superpuestos. Esto provocaba:
1. Interrupción del flujo interpretativo del músico al obligarlo a pausar para abrir un menú.
2. Imposibilidad de conectar herramientas entre sí (ej. el grabador no recibía directamente el audio procesado por el autotune, ni el pentagrama recibía el stream de notas en vivo mientras se practicaba una lección).
3. Monotonía visual independiente del instrumento seleccionado.

### 2.2 Fundamento Teórico y Topología de Señales
El sistema adopta el principio de **flujo de datos dirigido (Directed Dataflow Graph)** sin ciclos bloqueantes. Cada módulo es un nodo que procesa flujos continuos o discretos:

1. **Flujos Continuos de Audio ($S_{\text{audio}}$):**
   $$S_{\text{audio}}(t) \in [-1.0, 1.0], \quad f_s = 44100\text{ Hz}$$
   Procesados en bloques (buffers de $N = 1024$ o $2048$ muestras) a través de Isolates dedicados.
2. **Flujos Discretos de Eventos de Tono ($E_{\text{pitch}}$):**
   $$E_{\text{pitch}} = \langle f_0, \text{cents}, \text{amplitude}, t_{\text{timestamp}} \rangle$$
   Donde la desviación en cents se calcula respecto a la frecuencia de referencia $f_{\text{ref}}$:
   $$\text{cents} = 1200 \cdot \log_2\left(\frac{f_0}{f_{\text{ref}}}\right)$$
3. **Flujos Estructurados de Partitura ($E_{\text{score}}$):**
   Eventos que encapsulan altura tonal quantizada, compás, subdivisión métrica y duración rítmica vectorial según el estándar SMuFL.
4. **Flujos de Sincronización Temporal ($C_{\text{clock}}$):**
   Tick determinista de metrónomo que coordina la alineación temporal de todos los consumidores:
   $$t_{\text{tick}} = \frac{60}{BPM \cdot \text{subdivisiones}}$$

---

## 3. Especificación Funcional Detallada

### 3.1 Comportamiento del Sistema y Requerimientos

- **REQ-RACK-01 (Manipulación Drag & Drop):** El usuario puede reordenar módulos vertical u horizontalmente mediante gestos de arrastre fluidos a $60/120\text{ FPS}$.
- **REQ-RACK-02 (Estados Compacto / Expandido):** Cada tarjeta de módulo dispone de un botón de alternancia rápida entre vista compacta (mini-indicador de 48px) y vista expandida (controles profundos).
- **REQ-ROUTING-01 (Puertos e Identificadores):** Cada módulo expone puertos de entrada y salida con nombres tipados (ej. `mic.raw`, `pitch.stream`, `score.notes`, `clock.master`).
- **REQ-ROUTING-02 (Ruteo Específico o Broadcast):** Un puerto de salida puede enlazarse a un único consumidor (punto a punto) o distribuirse en modo broadcast a todos los módulos compatibles de la sesión.
- **REQ-CONSOLE-01 (Consola Multitarea Maestra):** Un panel persistente de control maestro permite iniciar, pausar y grabar todas las herramientas conectadas con un único toque sincronizado.
- **REQ-STYLE-01 (Estética Específica por Instrumento):** La interfaz adopta temas y controles personalizados según la familia de instrumento (Guitarras con diales analógicos y diapasón, Cuerdas frotadas con diapasón continuo, Vientos con transposición integrada y Voz con curvas de formantes).

### 3.2 Casos de Borde y Condiciones de Error
- **Desconexión en caliente de un módulo proveedor:** Si un módulo emisor se cierra o apaga, los consumidores suscritos pasan limpiamente a estado neutral sin arrojar excepciones ni congelar el hilo de UI.
- **Buffers de audio desfasados:** La Consola Multitarea sincroniza las marcas de tiempo ($t_{\text{timestamp}}$) de modo que las notas dibujadas en el pentagrama coincidan con el audio grabado independientemente de la latencia del buffer acústico.

---

## 4. Diseño Técnico y Arquitectura de la Solución

### 4.1 Capa de Dominio (`lib/domain/routing/`)
- `SignalType`: Enumeración inmutable (`audioPcm`, `pitchEvents`, `musicalNotes`, `temporalClock`).
- `PortId`: Objeto de valor inmutable con identificador alfanumérico y tipo de señal.
- `ModuleConnection`: Entidad que modela el enlace entre un puerto de salida y una entrada.
- `SignalBus`: Servicio de dominio en Dart puro que gestiona el registro de puertos, suscripciones y despacho reactivo de eventos sin dependencias de Flutter.

### 4.2 Capa de Infraestructura / Datos (`lib/data/routing/`)
- Adaptadores de Isolate que conectan los streams nativos del micrófono (`AudioStreamService`), el estimador MPM (`PitchEstimatorIsolate`) y el motor de autotune con el `SignalBus` local.

### 4.3 Capa de Presentación (`lib/presentation/modular_rack/`)
- `ModularStudioRackView`: Lienzo principal con soporte para listas reordenables (`ReorderableListView` personalizada con físicas elásticas).
- `MultitaskMasterConsoleWidget`: Barra o panel de control maestro con vúmetros luminosos, matriz de IDs y botones de transporte.
- `RackUnitCard`: Contenedor base de cada módulo con cabecera de arrastre, botón de compactar/expandir, selectores de puerto In/Out y skin adaptativa según el instrumento.

---

## 5. Criterios de Rendimiento y Benchmarking

- **Latencia de Despacho entre Módulos:** $\le 2\text{ ms}$ en la capa de dominio en memoria.
- **Rendimiento de Renderizado:** Mantenimiento de $60/120\text{ FPS}$ en pantalla durante la animación de arrastre y la actualización continua de vúmetros y pentagrama.
- **Uso de Memoria:** Determinista; reutilización de buffers circulares sin recolección de basura masiva durante la sesión.

---

## 6. Plan de Pruebas y Validación (QA)

- [ ] Pruebas unitarias de dominio para `SignalBus`, `PortId` y `ModuleConnection` con cobertura $\ge 95\%$.
- [ ] Pruebas de integración simulando flujos concurrentes (Mic $\rightarrow$ Autotune $\rightarrow$ Grabador y Mic $\rightarrow$ Pentagrama).
- [ ] Validación de la persistencia de configuraciones de rack y estilos de instrumento.

---

## 7. Referencias Técnicas y Bibliografía

1. *Clean Architecture: A Craftsman's Guide to Software Structure and Design (Robert C. Martin).*
2. *Pure Data & Max/MSP Modular Dataflow Paradigm.*
3. *W3C Web Audio API AudioNode Graph Specification.*
4. *Standard Music Font Layout (SMuFL) Specification v1.4.*
