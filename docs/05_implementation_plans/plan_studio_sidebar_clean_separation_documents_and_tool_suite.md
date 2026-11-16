# Template: Implementation Plan (Plantilla Plan de Implementación)

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE2-SIDEBAR-CLEAN-SEPARATION-2026-0077`
- **Título de la Implementación:** Separación Arquitectónica y Estética del Panel Lateral: 'Documentos del Proyecto' vs. 'Suite de Herramientas'
- **Fase del Proyecto:** Fase 2 (Afinación Acústica, Notación Jerárquica y Workspace Studio)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0067](../04_adrs/0067_studio_sidebar_clean_separation_documents_and_tool_suite.md)
- **Documento Funcional Base:** [Caso de Uso 77](../02_use_cases/77_uc_studio_sidebar_clean_separation_documents_and_tool_suite.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Resolver la ambigüedad conceptual en el panel lateral de navegación (`StudioTreeView`) reorganizándolo en dos secciones visualmente distintas, rigurosamente calculadas y atómicas:
1. **`Documentos del Proyecto`:** 100% puro para archivos y documentos creados o importados por el usuario (`Partituras del Proyecto`, `Tomas de Grabación WAV`, `Presets de Afinación`). Erradicar la inclusión de herramientas intrusas (como "Rack Modular" dentro de tomas de audio).
2. **`Suite de Herramientas`:** Catálogo estético y categorizado de instrumentos, procesadores y utilidades de conservatorio, agrupadas en:
   - *Afinación & Entonación* (Afinador Estroboscópico, Dron Armónico, Dashboard).
   - *Análisis Acústico & Laboratorio* (Espectrograma FFT, Analizador Polifónico).
   - *Pedagogía & Conservatorio* (Tutor de Compás, Entrenador Auditivo a Ciegas).
   - *Producción & Enrutamiento* (Rack Modular de Pedales DSP).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Refactorización de `_buildNavigationSections` en `lib/features/navigation/presentation/main_app_shell.dart`.
  - Extracción de herramientas fuera de las carpetas de documentos de usuario.
  - Creación de las dos secciones de primer nivel en `StudioTreeSection`.
  - Pruebas de widgets verificando ambas secciones y sus interacciones.
- **Excluido (Out-of-Scope):**
  - Cambios en el motor de persistencia JSON o algoritmos de audio DSP.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.5`
  - Flutter SDK: Canal oficial estable
- **Riesgo Tecnológico:** Cero riesgo. Reorganización a nivel de presentación sin introducir nuevas dependencias de terceros ni afectar la concurrencia de audio.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Documentación Canónica y Arquitectónica
- [x] Redacción de Plan de Implementación formal.
- [x] Redacción de Caso de Uso 77 con diagramas Mermaid (Casos de Uso y Secuencia).
- [x] Redacción de ADR 0067 formalizando la separación conceptual.

### Paso 2: Refactorización de la Capa de Presentación
- [ ] Limpiar `folder_studio` en `main_app_shell.dart` para que contenga única y exclusivamente tomas de audio grabadas (`recordingHistory`), sin el item de rack de pedales.
- [ ] Estructurar la sección 1: `Documentos del Proyecto (tunner)` con carpetas de partituras, tomas y presets.
- [ ] Estructurar la sección 2: `Suite de Herramientas de Estudio` con carpetas por disciplina técnica (Afinación, Análisis, Pedagogía, Producción).

### Paso 3: Pruebas y Verificación
- [ ] Crear prueba en `test/features/navigation/studio_sidebar_separation_test.dart` verificando la independencia y correcta visualización de ambas secciones.
- [ ] Ejecutar `flutter analyze lib/ test/`.
- [ ] Ejecutar suites de pruebas unitarias y de widgets.
- [ ] Compilar el binario Linux y verificar en pantalla activa (`DISPLAY=:0`).
- [ ] Confirmar cambios y sincronizar en Git.
