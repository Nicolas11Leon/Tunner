# Architecture Decision Record: ADR-0109 - Automatización de Compilación Cruzada en CI y Supervisión de Rama QA

---

## Metadatos del Documento

- **ID del ADR:** `ADR-0109`
- **Título:** Automatización de Compilación Cruzada en CI y Supervisión de Rama QA
- **Estado:** `Accepted`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 9 (Aceleración Nativa Bare-Metal & dart:ffi) - Épica 9.4`
- **Contexto Técnico:** Issue #65
- **Autor / Revisor Principal:** `Nicolas Leon (Mantenedor Principal)`

---

## 1. Contexto

Con la introducción de la biblioteca compartida en C99 (`libtunner_dsp`) para aceleración SIMD de audio mediante `dart:ffi`, surgió una necesidad operativa crítica:
1. El archivo de flujo de trabajo `.github/workflows/ci.yml` únicamente vigilaba las ramas `main` y `develop`, omitiendo la rama `qa` sobre la cual se ejecutan todos los ciclos de control de calidad y fusión de tareas comunitarias según la política innegociable de GitFlow.
2. Los ejecutores en la nube de GitHub Actions (`ubuntu-latest`) cuentan con CMake y GCC preinstalados, pero el workflow no invocaba la compilación de la biblioteca antes de ejecutar `flutter test`. En consecuencia, las pruebas de CI no podían evaluar la ejecución nativa real en la nube.

---

## 2. Decisión Arquitectónica

1. **Ampliación de Disparadores en CI:**
   - Se modifica `.github/workflows/ci.yml` para incorporar `qa` en `on.push.branches` y en `on.pull_request.branches`.

2. **Etapa de Compilación Nativa Pre-Test:**
   - Se agrega un paso formal en el job de CI:
     ```yaml
     - name: Build Native DSP Library (CMake & C99 SIMD)
       run: ./scripts/build_native_dsp.sh
     ```
   - Este paso compila `libtunner_dsp.so` con optimizaciones de producción `-O3 -fPIC` y ubica el binario en la raíz del proyecto para su resolución automática por parte de `NativeDspFfiBridge`.

3. **Garantía de Bloqueo de Calidad:**
   - Las pruebas de paridad matemática de FFI y los comandos de benchmark de terminal ahora se ejecutan en el entorno de CI verificando tanto el enlace binario como la resiliencia en caso de contingencia.

---

## 3. Consecuencias

### Positivas
- **Alineación 100% con GitFlow:** Todo Pull Request dirigido hacia `qa` es verificado de forma autónoma por la compuerta de calidad de GitHub Actions antes de la aprobación del Mantenedor Principal.
- **Validación Continua de Código C:** Cualquier error sintáctico, advertencia de compilación o fuga en `native/dsp/tunner_dsp.c` o `tunner_dsp.h` quebrará el pipeline de CI antes de llegar a la rama `qa`.
- **Integridad de Cobertura:** El reporte de cobertura `coverage/lcov.info` refleja la ejecución integral de las pruebas nativas.

### Mitigaciones de Seguridad
- El script de compilación corre bajo `set -euo pipefail` asegurando que cualquier fallo intermedio aborte el job inmediatamente.
