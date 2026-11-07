# Plan de Implementación: Personalización Microtonal por Instrumento y Teclado Emulador de Estrofas

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE4-CUSTOM-EMULATOR-2026-0048`
- **Título de la Implementación:** Motor de Desafinación Microtonal por Tecla/Cuerda, Personalización Tímbrica y Teclado Emulador de Estrofas Musicales
- **Fase del Proyecto:** Fase 4 (Estudio de Producción y Emulación Acústica Universal)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0044](../../docs/04_adrs/0044_microtonal_instrument_customization_and_phrase_emulator.md)
- **Documento Funcional Base:** [Documento Técnico](../../docs/01_product_vision/doc_microtonal_instrument_customization_and_phrase_emulator.md) y [Caso de Uso 48](../../docs/02_use_cases/48_uc_microtonal_instrument_customization_and_phrase_emulator.md)

---

## 1. Alcance y Objetivos

### 1.1 Objetivo Primario
Facultar al usuario para ajustar el timbre (ADSR, armónicos), afinación base ($A_4$) y aplicar **desafinaciones microtonales individuales por cuerda o tecla**, permitiendo además simular y escuchar cualquier nota o estrofa musical completa en cualquier instrumento mediante un **Teclado Maestro Universal Polifónico**.

### 1.2 Límites del Alcance
- **Incluido (In-Scope):**
  - Entidades de dominio: `PerNoteDetuningProfile`, `InstrumentCustomizationProfile`, `MusicalPhraseEntity`.
  - Sintetizador procedural con soporte para desviaciones microtonales en cents y síntesis de secuencias de estrofas.
  - Modales y widgets: `InstrumentCustomizationModal`, `UniversalMasterKeyboardWidget`.
  - Integración en `ModularStudioRackView` y `MultitaskMasterConsoleWidget`.
  - Pruebas unitarias de dominio y widgets al 100%.
- **Excluido (Out-of-Scope):**
  - Conexión a hardware MIDI físico externo (mantiene el enfoque 100% offline in-process de software).

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Implementar `lib/features/instrument/domain/per_note_detuning_profile.dart`.
- [x] Implementar `lib/features/instrument/domain/instrument_customization_profile.dart`.
- [x] Implementar `lib/features/instrument/domain/musical_phrase_entity.dart` con catálogo de estrofas canónicas.
- [x] Redactar y ejecutar pruebas unitarias de dominio en `test/features/instrument/per_note_detuning_test.dart`.

### Paso 2: Capa de Infraestructura / Datos (Síntesis Microtonal)
- [x] Extender `ProceduralInstrumentSynthesizer` para calcular frecuencias compuestas (temperamento + cents de desafinación).
- [x] Implementar síntesis de secuencias melódicas (estrofas).

### Paso 3: Capa de Presentación (UI Táctil y Teclado Emulador)
- [x] Implementar `InstrumentCustomizationModal` con sliders de armónicos, ADSR y desafinación por cuerda/tecla.
- [x] Implementar `UniversalMasterKeyboardWidget` con selector de octava, teclado polifónico y reproductor de estrofas.
- [x] Integrar botón de personalización rápida en la Consola Multitarea y en las tarjetas de rack.

### Paso 4: Pruebas, Verificación y Documentación
- [x] Ejecutar `flutter analyze` asegurando 0 errores y 0 advertencias.
- [x] Ejecutar `flutter test` verificando que todas las pruebas pasen al 100%.
- [x] Actualizar estado del plan a completado y realizar commit Git.

---

## 3. Criterios de Aceptación (Definition of Done)
- [ ] Cálculo microtonal verificado con fórmula $f = f_0 \cdot 2^{\frac{\Delta c}{1200}}$.
- [ ] Pruebas unitarias pasando al 100%.
- [ ] Cero busy-waiting loops.
- [ ] Documentación canónica (UC, ADR, Plan) actualizada.
