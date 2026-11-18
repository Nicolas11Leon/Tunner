# Implementation Plan: Biblioteca Canónica de Scripts Declarativos Tunner DSL (.tun)

**Issue Asociado:** #50 (Comunidad - Good First Issue)  
**Rama:** `feature/community-dsl-templates`  
**Rama Base:** `qa`  
**Fecha:** 2026-11-18  

---

## 1. Resumen y Objetivos

Implementar la biblioteca canónica de scripts declarativos en formato `.tun` dentro de `assets/dsl/`, junto con su catálogo tipado de Dominio en Dart puro (`TunnerDslTemplateCatalog`), y conectar los comandos interactivos `dsl list` y `dsl load <template>` dentro de la terminal de control `TunnerOsKernel`.

---

## 2. Tareas de Implementación

### Tarea 1: Creación de Scripts Declarativos Canónicos
- [ ] Crear `assets/dsl/ambient_chords.tun`:
  - Tempo lento (72 BPM).
  - Parámetros de reverberación espacial: `set @reverb.room = 0.85; set @reverb.wet = 0.65; set @spatial.distance = 2.5;`.
  - Configuración de sintetizador: onda triangular con ataque de 350 ms y liberación de 1200 ms.
  - Progresión modal rica: `[D3, F3, A3, C4, E4]`, `[G2, F3, B3, E4]`, `[C3, E3, G3, B3, D4]`.
- [ ] Crear `assets/dsl/acid_bassline.tun`:
  - Tempo enérgico a 135 BPM (`tempo 135;`).
  - Envolvente ADSR percusiva: onda diente de sierra (`sawtooth`), ataque de 5 ms, decaimiento de 90 ms, sustain 0.2, liberación 50 ms.
  - Ecualización con realce de graves (`set @eq.low = 4.0 dB;`).
  - Línea de bajo arpegiada en bucle (`loop 2 { ... }`).
- [ ] Crear `assets/dsl/vocal_warmup_routine.tun`:
  - Tempo moderado (96 BPM).
  - Envolvente suave para voz (`sine`, ataque 50 ms, liberación 150 ms).
  - Escalas diatónicas de 5 tonos ascendentes y descendentes transpuestas por semitonos/tonos (C mayor, D mayor, E mayor).
- [ ] Actualizar `pubspec.yaml` para incluir los activos en `assets/dsl/`.

### Tarea 2: Entidad y Catálogo de Dominio Pure Dart
- [ ] Crear `lib/core/dsl/domain/tunner_dsl_template_catalog.dart`:
  - Clase inmutable `TunnerDslTemplate` (id, title, category, tempoBpm, description, sourceCode).
  - Clase estática / de catálogo `TunnerDslTemplateCatalog` con `allTemplates`, `findById(String id)` y helpers de acceso.
  - 100% Dart puro sin dependencias de Flutter UI.

### Tarea 3: Extensión de la Terminal Tunner OS
- [ ] Actualizar `_handleDsl` en `lib/core/terminal/domain/tunner_os_kernel.dart`:
  - Soporte para subcomandos:
    - `dsl list` o `dsl templates`: lista todas las plantillas registradas con su ID y resumen.
    - `dsl load <template_id>`: busca la plantilla en el catálogo, la parsea y la ejecuta inmediatamente en el kernel.
  - Actualizar `help` para documentar estos subcomandos.

### Tarea 4: Batería de Pruebas Unitarias
- [ ] Crear `test/core/dsl/tunner_dsl_templates_test.dart`:
  - Verificar que todos los scripts del catálogo parsean con 0 errores y 0 diagnósticos de advertencia.
  - Verificar que el intérprete despacha los eventos correctos para cada una de las tres plantillas.
  - Verificar que los archivos físicos en `assets/dsl/` existen y coinciden con el código del catálogo.
- [ ] Crear / actualizar pruebas en `test/core/terminal/tunner_os_kernel_dsl_templates_test.dart`:
  - Comprobar la respuesta de `dsl list`.
  - Comprobar la ejecución exitosa de `dsl load ambient_chords`, `dsl load acid_bassline` y `dsl load vocal_warmup_routine`.
  - Comprobar el manejo de error cuando se solicita una plantilla inexistente.

---

## 3. Criterios de Aceptación (DoD)
- Todas las pruebas de `flutter test` pasan (>= 1020 pruebas).
- `flutter analyze --no-fatal-infos` con 0 errores y 0 advertencias.
- Cero emojis en código, commits, PR y documentación.
- PR creado hacia `qa` y fusionado en `qa`.
