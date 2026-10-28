# Plan de Implementación: Grabación Multi-Pista y Comparador Visual Espectral de Tomas

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-PRACTICE-2026-032`
- **Título de la Implementación:** Motor Multi-Pista, Multi-Toma y Comparador Espectral Gráfico de Ensayo
- **Fase del Proyecto:** Fase 12
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0028](../04_adrs/0028_multitrack_recording_and_spectral_comparator.md)
- **Documento Funcional Base:** [doc_multitrack_recording_and_spectral_comparator.md](../01_product_vision/doc_multitrack_recording_and_spectral_comparator.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un sistema integral de grabación multi-toma que capture simultáneamente audio, curvas de entonación (desviación en cents) y centroide espectral, junto con un comparador visual superpuesto que permita contrastar analítica y auditivamente dos tomas de ensayo (A/B testing de conservatorio).

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido:**
  - Entidades de dominio: `MultiTrackSessionEntity`, `PracticeTakeEntity`, `TimedPitchSample`, `TimedSpectralSample`, `SpectralComparisonResult`.
  - Servicio de dominio: `SpectralComparatorService` para cálculo de métricas de estabilidad y alineación.
  - Pintor vectorial: `SpectralComparatorPainter` con renderizado de curvas de cents, banda de afinación perfecta ($\pm 5$ cents) y envolventes espectrales.
  - Componente de interfaz: `SpectralComparatorModal` con selector de tomas A y B, controles de pista (Mute, Solo, Ganancia) y audición conmutada.
  - Integración en `TunerViewModel`.
  - Cobertura de pruebas unitarias y de interfaz de usuario.
- **Excluido:**
  - Mezcla destructiva de pistas en un archivo MP3 exportado (reservado para fase de producción discográfica posterior).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`.
  - Flutter SDK: Canal estable oficial.
- **Riesgo Tecnológico:**
  - Cero dependencias nativas adicionales; reutiliza la infraestructura de captura y síntesis existente.
  - Cero bucles de espera activa (no busy-waiting).

---

## 3. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Crear `lib/features/practice_recorder/domain/multitrack_session_entity.dart`:
  - `TimedPitchSample`, `TimedSpectralSample`.
  - `PracticeTakeEntity` (id, name, duration, peaks, pitch samples, spectral samples, gain, mute, solo).
  - `MultiTrackSessionEntity` (id, title, takes, selectedTakeAId, selectedTakeBId, bpm).
- [x] Crear `lib/features/practice_recorder/domain/spectral_comparator_service.dart`:
  - Algoritmo de comparación diferencial de entonación y brillo tímbrico.
  - Generación de `SpectralComparisonResult`.
- [x] Pruebas unitarias de dominio en `test/features/practice_recorder/spectral_comparator_service_test.dart`.

### Paso 2: Capa de Presentación Vectorial (Lienzo Comparador)
- [x] Crear `lib/features/practice_recorder/presentation/spectral_comparator_painter.dart`:
  - Eje central de 0 cents con bandas de tolerancia $\pm 5$ y $\pm 15$ cents.
  - Curvas de entonación continuas para Toma A y Toma B.
  - Barra inferior de brillo espectral (centroide).
- [x] Crear `lib/features/practice_recorder/presentation/spectral_comparator_modal.dart`:
  - Visualización del gráfico comparativo.
  - Tarjetas de métricas: Delta de Estabilidad, Centroide A vs B, Afinación Promedio.
  - Controles de selección de tomas y audición A/B.

### Paso 3: Orquestación en TunerViewModel y Pantalla Principal
- [x] Extender `TunerViewModel` con gestión de sesiones multi-pista:
  - Registro de tomas con captura de pitch/spectral samples durante la práctica.
  - Getter de sesión multi-pista y métodos para alternar tomas de comparación.
- [x] Agregar acceso directo al comparador espectral desde la barra de práctica o modal de grabaciones en `TunerScreen`.

### Paso 4: Pruebas, Verificación y Aprobación
- [x] Pruebas de integración UI en `test/features/practice_recorder/spectral_comparator_ui_test.dart`.
- [x] 100% de pruebas pasando en la suite completa.
- [x] `flutter analyze` limpio con cero issues.
- [x] Merge a `main` con `--no-ff`.
