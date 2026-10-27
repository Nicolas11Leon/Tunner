# Documentación Técnica: Generador Algorítmico de Ejercicios y Escalas de Conservatorio

Este documento define la arquitectura y formulación del motor procedural de generación de repertorio técnico y escalas de **Tunner**.

---

## Metadatos del Documento

- **ID del Documento:** `DOC-EXERCISE-GEN-2026-001`
- **Título Oficial:** Generador Procedural de Escalas, Arpegios, Intervalos y Rutinas Técnicas
- **Estado:** `Approved`
- **Fecha de Creación:** 2026-10-27
- **Última Modificación:** 2026-10-27
- **Fase Asociada:** `Fase 6 (Avanzada)`
- **Autor / Revisor Principal:** Nicolas Leon / Antigravity Engine

---

## 1. Resumen Ejecutivo (Executive Summary)

El **Generador Algorítmico de Ejercicios y Escalas** automatiza la creación de material de estudio técnico de conservatorio adaptado al instrumento activo. Con un único toque, el intérprete puede generar rutinas de escalas diatónicas (mayores, menores armónicas/melódicas), arpegios de tríada y séptima, saltos de intervalos (terceras, cuartas, quintas) y estudios de notas largas para desarrollo del timbre. El material generado se ensambla en un árbol canónico `SongPackage` renderizado al instante en el pentagrama vectorial SMuFL, compatible con auto-reproducción procedural ADSR, evaluación 4D y exportación universal MusicXML / MIDI.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Los estudiantes y profesionales de música dependen de métodos impresos en papel o colecciones estáticas de partituras para calentar y practicar digitación e intervalos. Si un músico necesita practicar la escala de Re mayor en corcheas o terceras en Si bemol para saxofón o flauta, debe buscar el método físico o transcribirlo manualmente. No existía un sistema libre que generase de forma algorítmica y paramétrica ejercicios infinitos acotados a la tesitura física del instrumento del usuario.

### 2.2 Fundamento Teórico / Musical

1. **Estructura Interválica de Modos y Escalas Diatónicas:**
   - **Escala Mayor (Jónico):** Tonos y Semitonos: $[2, 2, 1, 2, 2, 2, 1]$.
   - **Escala Menor Natural (Eólico):** $[2, 1, 2, 2, 1, 2, 2]$.
   - **Escala Menor Armónica:** $[2, 1, 2, 2, 1, 3, 1]$ (séptima mayor sensibilizada).
   - **Escala Menor Melódica (Ascendente):** $[2, 1, 2, 2, 2, 2, 1]$.
   - **Escala Pentatónica Mayor:** $[2, 2, 3, 2, 3]$.

2. **Patrones de Digitazione e Intervalos:**
   - **Arpegios:** Grados I - III - V - VIII.
   - **Intervalos de Terceras:** Patrón $n \rightarrow n+2 \rightarrow n+1 \rightarrow n+3 \dots$.
   - **Notas Largas (Tone Building):** Notas de redonda o blanca con apoyatura para control del flujo de aire y afinación microtonal.

3. **Acotamiento a la Tesitura del Instrumento:**
   El motor consulta el rango tonal del `InstrumentProfileEntity` (ej. Flauta: $C_4 - D_7$; Clarinete: $D_3 - G_6$) y transpone o acota el ejercicio para garantizar que todas las notas sean físicamente ejecutables en el instrumento configurado.

---

## 3. Especificación Funcional

- **REQ-GEN-01:** Selección de tonalidad raíz (12 centros tonales cromáticos).
- **REQ-GEN-02:** Selección de tipo de ejercicio: Escalas (Mayor, Menor Natural, Armónica, Melódica, Pentatónica), Arpegios, Terceras continuas y Notas Largas.
- **REQ-GEN-03:** Selección de figura rítmica (Negras = 4 ticks, Corcheas = 2 ticks, Semicorcheas = 1 tick).
- **REQ-GEN-04:** Generación inmutable de `SongPackage` con compases $4/4$ matemáticamente equilibrados y silencios finales de reposo.
