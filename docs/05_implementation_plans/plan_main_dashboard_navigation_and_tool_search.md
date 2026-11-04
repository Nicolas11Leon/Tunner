# Implementation Plan: Dashboard Principal con Tarjetas y Buscador Universal de Herramientas

Este documento define la estructura y ejecución paso a paso para transformar la experiencia de usuario de **Tunner**, pasando de una pantalla única congestionada a una arquitectura de navegación moderna basada en un **Dashboard de Inicio (Home Hub)** con tarjetas de gran formato, una **Barra de Navegación Inferior (BottomNavigationBar)** y un **Buscador Universal de Herramientas (Spotlight Search)**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE3-UI-2026-0046`
- **Título de la Implementación:** Dashboard Principal, Navegación por Módulos y Buscador Universal de Herramientas
- **Fase del Proyecto:** Fase 3 (Educación Musical Universal y Monolito Modular)
- **Estado:** En Progreso
- **ADR Relacionado:** `docs/04_adrs/0042_main_dashboard_navigation_and_universal_search.md`
- **Documento Funcional Base:** `docs/02_use_cases/46_uc_main_dashboard_navigation_and_tool_search.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Crear un punto de entrada centralizado e intuitivo (`HomeDashboardScreen` / `MainAppShell`) que reciba al usuario con tarjetas visuales claras y organizadas por intención de uso ("Afinar mi Instrumento", "Aprender a Tocar", "Estudio de Grabación & Práctica", "Biblioteca de Canciones & Partituras", "Laboratorio Acústico"), complementado con un Buscador Universal (`ToolSearchModal`) que permita encontrar y lanzar cualquier herramienta en menos de 2 segundos.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidad de dominio `AppToolItem` y catálogo de búsqueda `AppToolCatalog`:
    - Registro formal de todas las herramientas, modales, pantallas y ajustes de la app con palabras clave (tags), descripciones, iconos y acciones de ejecución.
  - Buscador Universal `ToolSearchModal`:
    - Filtro predictivo en tiempo real por nombre, alias o descripción.
    - Acceso rápido a herramientas de afinación, calibración, transposición, lecciones, grabación, canciones, drones, temperamentos y autotune.
  - Pantalla principal `HomeDashboardScreen`:
    - Saludo y badge con el instrumento musical activo y afinación de referencia.
    - Tarjetas de gran formato táctiles para las 5 áreas clave del software.
    - Accesos rápidos a herramientas frecuentes.
  - `MainAppShell`:
    - Barra de navegación inferior con pestañas:
      0: 🏠 Inicio (Dashboard)
      1: 🎯 Afinador (TunerScreen limpio)
      2: 🎓 Aprender (GuidedLessonsModal / Tutor)
      3: 🎙️ Grabación & Práctica (PracticeRecorder & Evaluador)
      4: 🎼 Canciones & Partituras (SongLibrary & Importador)
  - Descongestión visual de `TunerScreen`.
- **Excluido (Out-of-Scope):**
  - Alterar la lógica interna de los algoritmos DSP o audio FFI (se preservan al 100%).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal estable oficial
- **Riesgo Tecnológico:**
  - Cero dependencias nativas adicionales. Componentes en Flutter Material 3 adaptados a la paleta temática del software (`TunnerThemePalette`).
  - Navegación indexada fluida a 60/120 FPS sin reconstrucciones innecesarias de Isolates de audio.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Catálogo de Herramientas y Búsqueda)
- [x] Crear `lib/features/navigation/domain/app_tool_item.dart`:
  - Modelo inmutable `AppToolItem` con `id`, `title`, `category`, `description`, `icon`, `keywords` y acción.
  - Clase `AppToolCatalog` con la indexación completa de todas las funciones del software.
- [x] Crear pruebas unitarias en `test/features/navigation/app_tool_catalog_test.dart`.

### Paso 2: Capa de Presentación (Buscador Universal)
- [x] Crear `lib/features/navigation/presentation/tool_search_modal.dart`:
  - Campo de texto predictivo con autofocus.
  - Lista interactiva de resultados con navegación directa.

### Paso 3: Capa de Presentación (Dashboard de Inicio y Navegación)
- [x] Crear `lib/features/navigation/presentation/home_dashboard_screen.dart`:
  - Header con saludo, instrumento activo y botón de búsqueda rápida.
  - Grid/Lista de tarjetas grandes de acción inmediata.
- [x] Crear `lib/features/navigation/presentation/main_app_shell.dart`:
  - `Scaffold` con `BottomNavigationBar` o `NavigationBar` elegante.
  - Integración transparente con `TunerViewModel`.

### Paso 4: Integración en la Aplicación
- [x] Actualizar `lib/main.dart` para arrancar en `MainAppShell`.
- [x] Crear pruebas de UI y navegación en `test/features/navigation/main_app_shell_test.dart`.

### Paso 5: Verificación, Documentación y DoD
- [x] Redactar Caso de Uso canónico `docs/02_use_cases/46_uc_main_dashboard_navigation_and_tool_search.md`.
- [x] Redactar ADR `docs/04_adrs/0042_main_dashboard_navigation_and_universal_search.md`.
- [x] Actualizar `docs/06_qa_and_manual_testing/bitacora_maestra_pruebas_manuales.md`.
- [x] `flutter analyze` (0 issues).
- [x] `flutter test` (100% passing).
- [x] Git commit y push.
