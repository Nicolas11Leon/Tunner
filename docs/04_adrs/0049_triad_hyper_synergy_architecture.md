# ADR 0049: Tríada de Hyper-Sinergia: Visualizador Polifónico Armónico, Entrenador Auditivo a Ciegas y Suite 1.0

- **Estado:** Accepted
- **Fecha:** 2026-11-09
- **Fase:** Fase 5 & Release 1.0 Global
- **Autor:** Tunner Architecture & Pedagogy Core Team

---

## 1. Contexto

Tunner ha acumulado una suite de 52 casos de uso que cubren desde afinación estroboscópica y algoritmos YIN/MPM, hasta importación MusicXML/MIDI, OMR en partituras PDF, consolas modulares y atajos globales.

Para alcanzar el hito Milestone 1.0 ("Conservatory & Pro Audio Grade"), se requiere converger tres capacidades complementarias que se potencien mutuamente bajo una **Hyper-Sinergia**:
1. **Pilar 1 (Visualizador Polifónico & Armónicos):** Los músicos con instrumentos armónicos (piano, guitarra, arreglos vocales) necesitan ver las notas simultáneas de sus acordes y los armónicos superiores ($H_1 \dots H_8$) con su función armónica (tónica, 3ª, 5ª, tensiones).
2. **Pilar 2 (Entrenador Auditivo a Ciegas):** El entrenamiento auditivo en conservatorios exige aislar el oído ("Blind Mode") para que el estudiante no dependa de gráficos de afinador o pantallas, reconociendo intervalos, afinando por batimentos y respondiendo mediante atajos o canto.
3. **Pilar 3 (Suite de Release 1.0 & Documentación):** Se debe empaquetar la versión 1.0 con manual de usuario exhaustivo, catálogo de atajos contextual y notas de versión que demuestren estabilidad industrial.

---

## 2. Decisión

1. **Integración con el SignalBus Atómico:**
   - Tanto el Entrenador de Oído como el Visualizador Polifónico se integran al `SignalBus`.
   - Cuando el Entrenador de Oído sintetiza el intervalo de referencia, emite un evento `audioPcm` que los analizadores consumen.
   - Cuando el usuario canta o toca la respuesta, el detector de tono inyecta el `PitchDetectionEvent` en el bus para ser evaluado en cents y latencia por el motor del entrenador en $< 1\text{ ms}$.
2. **Dominio Puro para Entrenamiento Auditivo:**
   - Se crea `MusicalInterval` y `BlindEarTrainerEngine` en `lib/features/ear_training/domain/` como código 100% puro Dart, sin dependencias de Flutter ni librerías de UI, garantizando portabilidad y testeo unitario exhaustivo.
3. **Modo "A Ciegas" (Blind Mode) con Controles Rápidos:**
   - La interfaz de usuario del entrenador auditivo permite oscurecer la vista para centrar la cognición exclusivamente en la percepción auditiva.
   - Se habilitan los atajos `1-4` para elección múltiple rápida y `Espacio` para repetir el intervalo sin latencia.
4. **Catálogo de Ayuda y Manual 1.0:**
   - Se incorpora ayuda contextual en `ToolHelpCatalog` para el visualizador polifónico y el entrenador auditivo.
   - Se redacta el `manual_usuario_tunner_1.0.md` y `RELEASE_NOTES_v1.0.md` como activos canónicos del repositorio.

---

## 3. Consecuencias

### Positivas:
- **Interoperabilidad Total:** Las tres herramientas colaboran mediante el bus existente sin duplicar lógica de audio ni introducir microservicios o dependencias de red.
- **Rigor Pedagógico:** Ofrece tanto la muleta visual de alta precisión (Pilar 1) como el método de erradicación de muletas visuales para el desarrollo del oído interno (Pilar 2).
- **Consistencia de Producto:** La versión 1.0 queda formalmente documentada, probada y respaldada por especificaciones rigurosas.

### Negativas / Mitigaciones:
- Mayor cantidad de atajos mapeados en el shell: Se mitiga limitando las teclas numéricas `1-4` al contexto activo del modal del Entrenador Auditivo, evitando colisiones con los atajos globales de transporte.
