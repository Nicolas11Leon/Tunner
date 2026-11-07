# ADR 0048: Adopción del Estándar Universal de Memoria Muscular de DAWs para Tunner

- **Estado:** Accepted
- **Fecha:** 2026-11-07
- **Fase:** Fase 4 & Global
- **Autor:** Tunner Architecture & Ergonomics Team

---

## 1. Contexto

La investigación de mercado sobre las aplicaciones profesionales de audio (Ableton Live, Logic Pro, Avid Pro Tools, MuseScore) demuestra que los músicos desarrollan memoria motora cinemática:
- La mano izquierda suele descansar sobre la barra espaciadora (`Space`) y modificadores (`Shift`, `Cmd/Ctrl`).
- La tecla `Enter/Return` siempre devuelve el cursor o playhead al compás 1.
- La tecla `C` siempre alterna el modo de bucle/ciclo.
- Las teclas `,` y `.` realizan *nudge* (desplazamiento de compás o pulso hacia atrás o adelante).
- La tecla `R` o `F9` siempre activa la grabación de toma.

Implementar combinaciones arbitrarias o propietarias aumentaría la fricción cognitiva y el tiempo de reacción. Adoptar el estándar universal consolida a Tunner como una herramienta de grado profesional.

---

## 2. Decisión

Se adopta formalmente el mapa unificado de memoria muscular:
1. **Transporte Pro Tools / Logic:**
   - `Space`: Play / Stop.
   - `Enter` / `Return`: Rebobinado al inicio del tema (compás 1, pulso 0).
   - `R`: Armed Record / Detener grabación.
   - `C`: Conmutar modo bucle/ciclo de práctica.
2. **Nudge y Navegación de Línea de Tiempo:**
   - `,` (Coma): Mover playhead 1 compás/pulso atrás.
   - `.` (Punto): Mover playhead 1 compás/pulso adelante.
   - `[` / `]`: Ajustar tempo fino en $\pm 1$ BPM.
   - `Shift + [` / `Shift + ]`: Ajustar tempo grueso en $\pm 5$ BPM.
3. **Búsqueda Global:**
   - `Cmd/Ctrl + K` y `Cmd/Ctrl + F` abren la Command Palette Spotlight.

---

## 3. Consecuencias

### Positivas:
- **Cero Curva de Aprendizaje:** Cualquier usuario que conozca Logic, Pro Tools, Ableton o MuseScore puede operar Tunner de inmediato.
- **Sin Infracción de Propiedad Intelectual:** Los mapeos de teclas son convenciones de interfaz pública sin derechos propietarios.
- **Soporte de Pedaleras:** Los pedales de cambio de página o Bluetooth (AirTurn, PageFlip) mapean por defecto a `Space`, `Enter` o flechas, funcionando de inmediato.
