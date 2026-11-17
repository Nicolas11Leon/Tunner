# ADR 0084: Formato Canónico (.tunner), DSL Musical y Kernel Studio OS

- **Estado:** Aceptado
- **Fecha:** 2026-11-16
- **Contexto:** Arquitectura de Ecosistema, Portabilidad Universal de Proyectos y Programabilidad en Vivo
- **Fase:** Fase 4 (Horizonte de Escalabilidad y Ecosistema de Plataforma)

---

## 1. Contexto

A medida que **Tunner** unifica componentes profesionales (Consola DJ, Editor de Partituras SMuFL, Teclado Maestro de Instrumentos, Detector de Tono YIN/MPM, Sistema de Archivos Local y Matriz de Parcheo Universal), se hace indispensable garantizar su escalabilidad a largo plazo mediante tres pilares de plataforma:
1. **Problema de Fragmentación de Archivos:** Actualmente, una partitura se guarda como MusicXML, una toma de audio como WAV y un preset como JSON en carpetas independientes. Se requiere un formato de archivo único, comprimido y autocontenido (`.tunner`) que encapsule todo el proyecto musical sin dependencias externas.
2. **Problema de Programabilidad y Automatización:** El usuario necesita interactuar con la suite mediante comandos rápidos, scripts de automatización y live-coding sin depender exclusivamente de gestos de ratón.
3. **Problema de Coordinación en Proceso:** Se necesita una capa de Micro-Kernel formal que gobierne la comunicación de memoria compartida y eventos entre herramientas con latencia determinista $\le 10\text{ ms}$.

---

## 2. Decisión

Se aprueba y adopta la hoja de ruta estratégica para convertir a Tunner en un **Entorno Operativo Musical (Studio OS)** articulado en tres subsistemas:
1. **Formato Canónico Universal (`.tunner`):** Contenedor comprimido DEFLATE (ZIP) estándar de 64 bits con verificación criptográfica SHA-256. Alberga en una jerarquía canónica el manifiesto del proyecto, la matriz de enrutamiento, partituras MusicXML, stems WAV reales, perfiles de afinación histórica y modelos de consola DJ.
2. **Lenguaje Específico de Dominio (Tunner DSL):** Motor de lenguaje declarativo/procedural basado en una gramática formal EBNF libre de ambigüedades. Cuenta con un Lexer y Parser en Dart puro para construir un Árbol de Sintaxis Abstracta (AST) ejecutable en tiempo real sobre el bus de audio.
3. **Micro-Kernel de Audio en Proceso:** Capa central desacoplada (`StudioOsAudioKernel`) que actúa como despachador de eventos de reloj determinista, arbitro de memoria compartida entre Isolates y enrutador maestro del Patchbay.
4. **Terminal / Consola REPL Integrada:** Interfaz de línea de comandos en tiempo real para escribir scripts, consultar estado del sistema y disparar macros musicales.

---

## 3. Consecuencias

### Positivas
- **Independencia Total y Cero Bloqueo de Proveedor:** Proyectos 100% *Offline First* almacenados en un único archivo estándar legible en cualquier sistema operativo.
- **Escalabilidad Infinita:** Permite a la comunidad, educadores y productores crear bibliotecas de canciones, ejercicios automáticos y scripts de presentación reproducibles.
- **Rendimiento Máximo:** La gramática compacta y el paso de búferes por referencia en memoria compartida evitan sobrecargas de serialización o demoras en el hilo de renderizado.

### Negativas / Mitigaciones
- **Complejidad del Intérprete:** La implementación de un parser DSL puede acarrear casos de borde léxicos.
  *Mitigación:* Se define una gramática EBNF estricta, minimalista y tipada con suite exhaustiva de pruebas sintácticas antes de su despliegue en producción.
