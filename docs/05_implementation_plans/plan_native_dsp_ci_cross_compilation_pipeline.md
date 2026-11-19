# Implementation Plan: Automatización de Compilación Cruzada en CI y Supervisión de Rama QA

**Issue Asociado:** #65 (Fase 9 - Épica 9.4)  
**Rama:** `feature/ci-native-dsp-cmake-pipeline`  
**Rama Base:** `qa`  
**Fecha:** 2026-11-18  

---

## 1. Resumen y Objetivos

Actualizar el pipeline de integración continua `.github/workflows/ci.yml` para incorporar la rama `qa` en los disparadores de eventos `push` y `pull_request`, e integrar el paso de compilación automatizada de `libtunner_dsp` mediante `./scripts/build_native_dsp.sh` antes de ejecutar la suite de análisis y pruebas de Flutter.

---

## 2. Tareas de Implementación

### Tarea 1: Actualización de `.github/workflows/ci.yml`
- [ ] Incorporar la rama `qa` en `on.push.branches`.
- [ ] Incorporar la rama `qa` en `on.pull_request.branches`.
- [ ] Añadir paso de compilación nativa previa:
  ```yaml
  - name: Build Native DSP Library (CMake & C99 SIMD)
    run: |
      chmod +x scripts/build_native_dsp.sh
      ./scripts/build_native_dsp.sh
  ```
- [ ] Ajustar la versión de Flutter en el workflow si es requerido para asegurar consistencia con el SDK activo.

### Tarea 2: Validación Local y Simulación de CI
- [ ] Probar la ejecución completa de la cadena de comandos del CI localmente:
  1. `./scripts/build_native_dsp.sh`
  2. `flutter pub get --enforce-lockfile`
  3. `flutter analyze --no-fatal-infos`
  4. `flutter test`
- [ ] Verificar que no existan errores de sintaxis en el archivo YAML de workflow.

---

## 3. Criterios de Aceptación (DoD)
- Archivo `.github/workflows/ci.yml` válido y bien estructurado.
- Rama `qa` cubierta en `push` y `pull_request`.
- Paso de compilación de `libtunner_dsp` presente en el pipeline.
- Todas las pruebas unitarias pasan sin fallos.
- `flutter analyze --no-fatal-infos` con 0 incidencias.
- Cero emojis en código, workflow, documentación, comentarios y commits.
- PR creado hacia `qa` y fusionado en `qa`.
