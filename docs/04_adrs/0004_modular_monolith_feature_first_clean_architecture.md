# ADR 0004: Adopción Estricta de Monolito Modular "Feature-First Clean Architecture"

---

- **Estado:** `Approved`
- **Fecha:** `2026-10-24`
- **Autores:** `Tunner Engineering & Nicolas Leon`
- **Decisores:** `Nicolas Leon (Creador), Antigravity AI`
- **Fase del Proyecto:** `Fase 2 / Fase 3 / Fase 4 (Refactorización Estructural)`

---

## 1. Contexto

El proyecto **Tunner** comenzó organizándose bajo un esquema horizontal por capas genéricas (*Layer-First*: `lib/domain/`, `lib/data/`, `lib/presentation/`). 

A medida que el alcance creció (Afinador Estroboscópico, Metrónomo de alta resolución, Motor de Partituras Jerárquico, Consola Mezcladora de Stems y Biblioteca de Canciones), esta organización provocó:
1. **Acoplamiento Directo (Violación del Principio de Inversión de Dependencias - DIP):** La capa de presentación (`TunerViewModel`) pasó a instanciar directamente servicios concretos de hardware e Isolates (`PitchDetectorService`, `MetronomeService`) sin interfaces abstractas en el dominio.
2. **Falta de Límites Cohesivos (Bounded Contexts):** Modelos y servicios de dominios completamente distintos (acústica, tiempo/reloj, partituras, mezcla de audio) coexistían en carpetas monolíticas planas.
3. **Duplicidad de Modelos:** Coexistencia de entidades legadas planas (`SongEntity`) con el nuevo árbol canónico (`HierarchicalScore`).
4. **Riesgo Futuro:** Si en el futuro se busca evolucionar partes críticas hacia enlaces nativos de alto rendimiento (`dart:ffi` con C/C++/Rust) o aplicar patrones de migración controlada (*Strangler Fig*), una arquitectura desordenada provocaría fricciones y deuda técnica inmanejable.

---

## 2. Decisión Arquitectónica

Se aprueba la reestructuración completa del código hacia un **Monolito Modular con enfoque Feature-First Clean Architecture**:

### 2.1 Principios Rectores
1. **Feature-First como primer nivel de partición:** Cada funcionalidad nuclear del producto vive en su propio módulo independiente dentro de `lib/features/<feature_name>/`.
2. **Clean Architecture estricta dentro de cada Feature:**
   - `domain/`: Entidades inmutables, Value Objects y **contratos/interfaces abstractas**. Cero dependencias de Flutter, paquetes de terceros o plugins del sistema operativo.
   - `data/`: Implementaciones de los contratos de dominio, Isolates de procesamiento, llamadas a hardware, audio PCM y repositorios.
   - `presentation/`: Widgets de UI, CustomPainters atómicos y ViewModels que interactúan exclusivamente con las abstracciones de dominio.
3. **Core transversal (`lib/core/`):**
   - Aloja exclusivamente utilidades y tipos compartidos verdaderamente agnósticos de una feature específica (tokens de diseño, constantes matemáticas/acústicas base).
4. **Inyección de Dependencias Explícita:**
   - La orquestación y el cableado de dependencias se configuran en el punto de entrada de la aplicación (`lib/main.dart` / DI container), desacoplando totalmente la capa de presentación de la construcción de servicios de datos.

### 2.2 Mapa de Features (Bounded Contexts)
- **`features/tuner`**: Detección de tono microtonal, afinador virtual estroboscópico, interfaz `IPitchDetectorService`.
- **`features/metronome`**: Temporización de reloj Isolate sin drift, marcas de tempo italianas, interfaz `IMetronomeService`.
- **`features/sheet_music`**: Árbol de notación musical jerárquico (`HierarchicalScore`), métricas (`TimeSignature`), renderizador vectorial `RealSheetMusicPainter`.
- **`features/mixer`**: Pistas de audio (`AudioTrack`), consola de stems multicanal, síntesis de clics PCM, interfaz `IMixerConsoleRepository`.
- **`features/song_library`**: Paquete de canciones (`SongPackage`), biblioteca curada y descompositor de canciones personalizadas.

---

## 3. Consecuencias

### Consecuencias Positivas
- **Aislamiento Modular Total:** Cada módulo puede probarse de forma 100% aislada con mocks limpios.
- **Preparado para FFI Nativo:** La capa `data/` de cualquier feature (ej. DSP de afinación o síntesis de audio) puede reemplazarse por bibliotecas compiladas en Rust o C++ sin modificar ni una sola línea de código en la UI ni en el Dominio.
- **Legibilidad y Mantenibilidad Profesional:** El repositorio refleja una ingeniería de software de clase mundial, apta para escalar sin degradación técnica.

### Consecuencias Negativas / Mitigaciones
- Reubicación de archivos e imports en todo el proyecto: mitigado ejecutando la migración de forma incremental, validando con `flutter analyze` y `flutter test` en cada paso.
