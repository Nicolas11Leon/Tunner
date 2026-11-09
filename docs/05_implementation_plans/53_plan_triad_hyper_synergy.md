# Template: Implementation Plan (Plantilla Plan de Implementación)

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE5-TRIAD-HYPER-SYNERGY-2026-053`
- **Título de la Implementación:** `Implementación de la Tríada de Hyper-Sinergia: Visualizador Polifónico, Entrenador Auditivo a Ciegas y Suite Release 1.0`
- **Fase del Proyecto:** `Fase 5 & Release 1.0 Global`
- **Estado:** `En Progreso`
- **ADR Relacionado:** `docs/04_adrs/0049_triad_hyper_synergy_architecture.md`
- **Documento Funcional Base:** `docs/01_product_vision/doc_triad_hyper_synergy_polyphonic_blind_ear_release.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Integrar armónicamente el Visualizador Polifónico de Voicing (`PolyphonicLiveVoicingWidget`), el Entrenador Auditivo de Intervalos a Ciegas (`BlindEarTrainerEngine` & `BlindEarTrainerModal`), y la Suite de Documentación y Lanzamiento v1.0, conectándolos al `SignalBus` maestro, a la paleta de comandos, al catálogo de ayuda contextual (`ToolHelpCatalog`) y a los atajos de teclado sinérgicos.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelos de dominio puros en Dart para intervalos musicales, cálculo de desvío en cents y motor de ejercicios (`lib/features/ear_training/domain/`).
  - Componente visualizador continuo de notas polifónicas y tensiones armónicas (`lib/features/chord_analyzer/presentation/polyphonic_live_voicing_widget.dart`).
  - Modal interactivo con modo oscuro pedagógico ("Blind Mode") y atajos numéricos (`1-4`, `Espacio`) (`lib/features/ear_training/presentation/blind_ear_trainer_modal.dart`).
  - Integración en `MainAppShell`, `ToolHelpCatalog` y `CommandPalette`.
  - Manual de Usuario 1.0 (`docs/03_user_guides/manual_usuario_tunner_1.0.md`) y `RELEASE_NOTES_v1.0.md`.
  - Pruebas unitarias de dominio y de widgets pasando con 100% de éxito.
- **Excluido (Out-of-Scope):**
  - Servidores en la nube o sincronización remota (se respeta la regla 100% Offline-First de AGENTS.md).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `>=3.0.0 <4.0.0`
  - Flutter SDK: Stable
  - Paquetes existentes: `flutter_test`, `provider` (o ViewModels locales), sin nuevas dependencias externas innecesarias.
- **Riesgo Tecnológico:**
  - Sin dependencias nativas adicionales ni llamadas bloqueantes.
  - El motor de entrenamiento corre en el hilo principal con cálculos matemáticos puros en $O(1)$ sin riesgo de caídas de FPS.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Documentación funcional (`doc_triad_hyper_synergy...`, Casos de uso 53, 54, 55, ADR 0049).
- [ ] Creación de `MusicalInterval`: Enum con semitonos, razón de frecuencia $f_2/f_1$, nombre en español e inglés y centavos justos vs temperados.
- [ ] Creación de `EarTrainingQuestion` y `EarTrainingResult`: Entidades inmutables de ejercicio.
- [ ] Creación de `BlindEarTrainerEngine`: Motor determinista de sesión pedagógica con generación de opciones, cálculo de racha y evaluación de respuestas.
- [ ] Pruebas unitarias puras en Dart en `test/features/ear_training/blind_ear_trainer_test.dart`.

### Paso 2: Capa de Presentación e Integración Sinérgica
- [ ] Implementación de `PolyphonicLiveVoicingWidget` en `lib/features/chord_analyzer/presentation/`.
- [ ] Implementación de `BlindEarTrainerModal` en `lib/features/ear_training/presentation/` con soporte de atajos numéricos `1-4`, `Espacio` (repetir audio) y botón de alternancia Blind Mode.
- [ ] Registro en `ToolHelpCatalog` con sus tarjetas de ayuda y fórmulas teóricas.
- [ ] Enlace en la paleta de comandos (`CommandPalette`) y barra de acciones rápidas.

### Paso 3: Suite de Documentación y Lanzamiento 1.0
- [ ] Redacción exhaustiva de `docs/03_user_guides/manual_usuario_tunner_1.0.md`.
- [ ] Redacción de `RELEASE_NOTES_v1.0.md` destacando los 55 casos de uso y la arquitectura sinérgica.
- [ ] Actualización de `README.md` reflejando el estatus de la versión 1.0.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecución de `flutter analyze` verificando 0 advertencias y 0 errores.
- [ ] Ejecución de `flutter test` verificando que todas las pruebas pasen al 100%.

---

## 4. Estrategia de Rollback (Plan de Contingencia)
- Si surge alguna regresión, se puede revertir al commit base `947e193` (`main`) mediante `git checkout main`.

---

## 5. Criterios de Aceptación (Definition of Done)
- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero dependencias en Flutter en la capa de dominio (`lib/features/ear_training/domain/`).
- [ ] Pruebas unitarias completas pasando al 100%.
- [ ] Documentación técnica, ADRs y casos de uso formalizados.
