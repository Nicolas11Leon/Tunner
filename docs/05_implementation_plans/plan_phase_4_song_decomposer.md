# Implementation Plan: Phase 4 Song Reader, Decomposer & Extended Repertoire Library

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-SONG-DECOMPOSER-2026-010`
- **Título de la Implementación:** `Lector y Descompositor de Canciones con Biblioteca de Repertorio Multi-Pista`
- **Fase del Proyecto:** `Fase 4`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `docs/04_adrs/0003_hybrid_song_library_and_midi_parser.md`
- **Documento Funcional Base:** `docs/02_use_cases/08_uc_song_reader_and_decomposer.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Crear el subsistema de biblioteca y descompositor de canciones de **Tunner**. Permitirá a los músicos:
1. Navegar por una **Biblioteca de Repertorio Curada** (obras populares y estudios con múltiples compases, géneros y pistas de acompañamiento separadas: Piano, Voz, Vientos/Guitarras).
2. Utilizar un **Lector/Descompositor de Canciones** que admita subir o cargar canciones personalizadas, extrayendo dinámicamente sus pistas para la consola mezcladora (`MixerConsoleEntity`) y sus notas melódicas para el pentagrama interactivo.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio pura `lib/domain/song_package_entity.dart` para representar una canción completa descompuesta (título, autor, dificultad, género, compases jerárquicos y pistas de audio/stems asociadas).
  - Servicio de dominio `lib/domain/song_decomposer_service.dart` para procesar y descomponer obras en pistas individuales y notas afinadas.
  - Repertorio curado canónico expandido (ej. Clásicos universales: "Para Elisa", "Canon de Pachelbel", "Oda a la Alegría", "Estudio Barroco").
  - Interfaz de usuario en `TunerScreen`: Selector y explorador de biblioteca con vista previa de pistas, botón para importar canción personalizada y conexión inmediata con el mezclador y pentagrama.
  - Pruebas unitarias de dominio completas.
- **Excluido (Out-of-Scope):**
  - Conexión a tiendas de pago en la nube (la plataforma es 100% offline y gratuita).

---

## 2. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos de Canción Descompuesta y Descompositor)
- [x] Crear `lib/domain/song_package_entity.dart` con metadatos (género, autor, nivel) y sus stems específicos (`List<AudioTrack>`).
- [x] Crear `lib/domain/song_decomposer_service.dart` con la lógica de descomposición en capas.
- [x] Pruebas unitarias en `test/domain/song_decomposer_test.dart`.

### Paso 2: Capa de Infraestructura / ViewModel
- [x] Conectar `TunerViewModel` para cargar cualquier `SongPackage` de la biblioteca o subido por el usuario, actualizando de forma atómica:
  - Los compases y notas del pentagrama.
  - Las pistas de acompañamiento en `mixerConsole`.
  - El tempo base de la canción y su métrica.

### Paso 3: Capa de Presentación (Explorador de Biblioteca e Ingesta en UI)
- [x] Modal / diálogo estilizado de "Biblioteca de Repertorio & Subir Canción" con filtrado por género/dificultad.
- [x] Opción para importar canción personalizada con descomposición en vivo.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecutar `flutter test` y `flutter analyze`.

---

## 3. Criterios de Aceptación (Definition of Done)

- [x] El usuario puede seleccionar canciones con pistas de acompañamiento separadas de la biblioteca.
- [x] El usuario puede cargar una canción personalizada y ver sus pistas descompuestas en la consola de mezcla.
- [x] Cero dependencias de servidores en la nube.
- [x] 100% de pruebas unitarias pasando.
