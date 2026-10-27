# ADR-0019: Motor de Temperamentos Históricos y Afinaciones No-Iguales

- **Estado:** Approved
- **Fecha:** 2026-10-27
- **Fase:** Fase 7.2 (Vanguardia Acústica y Conservatorio)
- **Autor:** Antigravity / Nicolas Leon

---

## 1. Contexto

La casi totalidad de afinadores electrónicos modernos se limitan a evaluar la frecuencia contra el Temperamento Igual (12-EDO), asumiendo que cada semitono mide exactamente 100 cents. Sin embargo:
1. En agrupaciones de cámara, coros y orquestas históricas (música barroca, renacentista y clásica), el uso de afinación igual produce batimentos molestos en terceras y sextas.
2. Los conservatorios enseñan la afinación de terceras puras (386.31 cents en lugar de 400 cents) y quintas pitagóricas o mesotónicas.
3. Para posicionar a Tunner como la suite de aprendizaje musical más potente del ecosistema libre, es imprescindible ofrecer precisión matemática nativa para temperamentos históricos con transposición de tónica en tiempo real.

---

## 2. Decisión

Implementar un motor de dominio puro en Dart (`TemperamentEngine`) con:
1. Definición formal de offsets en cents relativos al temperamento igual para los 12 grados cromáticos.
2. Soporte nativo para 8 sistemas de temperamento:
   - Equal Temperament (12-EDO)
   - Pythagorean Tuning
   - Just Intonation (5-Limit)
   - Meantone 1/4 Comma (Pietro Aron)
   - Werckmeister III (1691)
   - Kirnberger III (1779)
   - Vallotti (1779)
   - Young II (1800)
3. Modulación circular de la nota raíz o tónica (Do, Do#, Re, etc.) para aplicar las desviaciones microtonales según la tonalidad de la pieza.
4. Integración transparente en `TunerViewModel`: el cálculo de cents de la nota detectada se evalúa contra la frecuencia objetivo del temperamento activo.
5. Persistencia offline en `AppUserSettingsEntity`.

---

## 3. Consecuencias

### Positivas
- Permite a cantantes, violinistas, chelistas, flautistas de pico y teclistas afinar con resonancia armónica pura.
- Cero dependencias externas y ejecución en tiempo real en Dart puro ($\le 0.1\text{ ms}$ de cómputo por evaluación).
- Persistencia automática de las preferencias sin conexión a internet.

### Negativas / Mitigaciones
- Mayor complejidad cognitiva para principiantes: mitigada manteniendo el Temperamento Igual (12-EDO) como valor predeterminado y ubicando el selector avanzado en el Modo Conservatorio Pro y accesible vía chip.
