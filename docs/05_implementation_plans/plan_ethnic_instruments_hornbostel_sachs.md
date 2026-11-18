# Implementation Plan: Presets Instrumentales Étnicos según Taxonomía Hornbostel-Sachs

**Issue Asociado:** #52 (Comunidad - Help Wanted)  
**Rama:** `feature/ethnic-instruments-expansion`  
**Rama Base:** `qa`  
**Fecha:** 2026-11-18  

---

## 1. Resumen y Objetivos

Incorporar cinco instrumentos tradicionales representativos de diversas geografías y culturas (Kora, Sitar, Shakuhachi, Charango y Cuatro Venezolano) en el catálogo unificado `UniversalInstrumentDefinition` de la capa de Dominio, preservando la taxonomía científica Hornbostel-Sachs y configurando sus tablas de afinación nominales en Hz.

---

## 2. Tareas de Implementación

### Tarea 1: Perfiles Visuales y Tímbricos de Dominio
- [ ] Verificar o añadir presets tímbricos en `TimbralProfile` si se requieren perfiles específicos para cuerdas de tripa/nylon/metal o aerófono de bambú sin bisel:
  - `TimbralProfile.koraHarpLute` (o adaptar plucked harp/lute).
  - `TimbralProfile.sitarResonant`.
  - `TimbralProfile.shakuhachiBamboo`.
  - `TimbralProfile.charangoBright`.
  - `TimbralProfile.cuatroLlanero`.
- [ ] Verificar perfiles visuales en `VisualInterfaceProfile`.

### Tarea 2: Definición Organológica en `UniversalInstrumentDefinition`
- [ ] Agregar constante `koraWestAfrican`:
  - `universalId: 'chordophone.plucked_strings.kora_west_african'`
  - 21 cuerdas en afinación Tomora Ba / Sawuta ($F_2$ a $G_5$).
- [ ] Agregar constante `sitarIndian`:
  - `universalId: 'chordophone.plucked_strings.sitar_indian'`
  - GM 104, cuerdas baaj y chikari ($C_2$ a $C_6$).
- [ ] Agregar constante `shakuhachiJapanese`:
  - `universalId: 'aerophone.woodwind.shakuhachi_japan'`
  - GM 77, escala pentatónica fundamental 1.8 Shaku ($D_4$ a $D_7$).
- [ ] Agregar constante `charangoAndean`:
  - `universalId: 'chordophone.plucked_strings.charango_andean'`
  - Afinación reentrante en 5 órdenes dobles ($E_5, A_4, E_5/E_4, C_5, G_4$).
- [ ] Agregar constante `cuatroVenezuelan`:
  - `universalId: 'chordophone.plucked_strings.cuatro_venezuelan'`
  - Afinación reentrante tradicional "Cambur Pintón" ($B_3, F\sharp_4, D_4, A_3$).
- [ ] Incorporar los 5 instrumentos a `masterCatalog`.

### Tarea 3: Batería de Pruebas Unitarias
- [ ] Crear `test/features/instrument/ethnic_instruments_catalog_test.dart`:
  - Validar identificadores universales normalizados bajo la jerarquía `[categoria].[subfamilia].[id]`.
  - Validar cobertura de notas de afinación estándar para cada instrumento étnico.
  - Validar búsqueda rápida por términos vernáculos (ej. "kora", "sitar", "shakuhachi", "charango", "cuatro venezolano", "cambur pinton").
  - Validar límites de frecuencias mínimas y máximas en `AcousticRange`.
- [ ] Ejecutar `universal_instrument_test.dart` y asegurar que la suite completa continúe pasando.

---

## 3. Criterios de Aceptación (DoD)
- Todas las pruebas unitarias pasan sin incidencias.
- `flutter analyze --no-fatal-infos` con 0 errores y 0 advertencias.
- Cero emojis en código, comentarios, commits y documentación.
- PR creado hacia `qa` y fusionado en `qa`.
