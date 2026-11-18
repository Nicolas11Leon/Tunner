# Implementation Plan: Expansión de Temperamentos Históricos (Werckmeister IV, Kirnberger I y Neidhardt)

**Issue Asociado:** #51 (Comunidad - Good First Issue)  
**Rama:** `feature/historical-temperaments-expansion`  
**Rama Base:** `qa`  
**Fecha:** 2026-11-18  

---

## 1. Resumen y Objetivos

Incorporar tres sistemas canónicos de afinación histórica barroca y clásica (Werckmeister IV Septenarius, Kirnberger I y Neidhardt 1724) en el motor de dominio `TemperamentEngine`, ampliando el catálogo de 8 a 11 temperamentos e integrándolos automáticamente con el selector visual de conservatorio y la aguja estroboscópica.

---

## 2. Tareas de Implementación

### Tarea 1: Ampliación del Dominio Pure Dart (`TemperamentEngine`)
- [ ] Incorporar `MusicalTemperament` para `werckmeister_iv`:
  - `id: 'werckmeister_iv'`
  - `name: 'Werckmeister IV (Septenarius 1691)'`
  - `centsOffsets: [0.0, -6.0, -4.0, -6.0, -8.0, 2.0, -10.0, -4.0, -8.0, -6.0, 0.0, -8.0]`
- [ ] Incorporar `MusicalTemperament` para `kirnberger_i`:
  - `id: 'kirnberger_i'`
  - `name: 'Kirnberger I (1771)'`
  - `centsOffsets: [0.0, -7.82, 3.91, -5.87, -13.69, -1.96, -9.78, 1.96, -5.87, -15.64, -3.91, -11.73]`
- [ ] Incorporar `MusicalTemperament` para `neidhardt_1724`:
  - `id: 'neidhardt_1724'`
  - `name: 'Neidhardt (1724, Grosse Stadt)'`
  - `centsOffsets: [0.0, -7.82, -3.91, -3.91, -7.82, 1.96, -9.78, -1.96, -5.87, -5.87, 0.0, -7.82]`
- [ ] Exponer getters de acceso canónico `werckmeisterIV`, `kirnbergerI`, `neidhardt1724`.
- [ ] Actualizar comentarios de cabecera indicando la existencia de 11 temperamentos canónicos.

### Tarea 2: Actualización de la Suite de Pruebas Unitarias
- [ ] Actualizar `test/features/tuner/temperament_engine_test.dart`:
  - Verificar que `allTemperaments.length` es exactamente 11.
  - Verificar que cada uno de los 11 temperamentos posee 12 offsets de cents.
  - Verificar que Kirnberger I produce una tercera mayor Mi (índice 4) con offset de -13.69 cents, logrando un ratio armónico 5:4 puro ($E_4 / C_4 = 1.25$).
  - Verificar la quinta de lobo $D-A$ en Kirnberger I (reducción de coma sintónica).
  - Verificar la precisión acústica de Werckmeister IV y Neidhardt 1724.
  - Comprobar que la búsqueda por ID (`getById('werckmeister_iv')`, `getById('kirnberger_i')`, `getById('neidhardt_1724')`) resuelve la instancia correcta.

### Tarea 3: Verificación Integral
- [ ] Ejecutar `flutter test` asegurando que ninguna prueba previa sufra regresión.
- [ ] Ejecutar `flutter analyze --no-fatal-infos` asegurando 0 errores y 0 advertencias.
- [ ] Comprobar que el modal `TemperamentSelectorModal` muestra los 11 elementos sin desbordamientos de pantalla.

---

## 3. Criterios de Aceptación (DoD)
- Todas las pruebas unitarias pasan con éxito.
- `flutter analyze` reporta "No issues found!".
- Cero emojis en código, commits, PR y documentación.
- PR creado con destino `qa` y fusionado en `qa`.
