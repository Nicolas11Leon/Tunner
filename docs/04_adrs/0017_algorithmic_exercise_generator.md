# ADR-0017: Generador Procedural de Ejercicios y Escalas de Conservatorio

- **Estado:** Aprobado
- **Fecha:** 2026-10-27
- **Autor:** Nicolas Leon / Antigravity Engine
- **Área:** Pedagogía Musical, Algoritmos Diatónicos y Composición Procedural

---

## Contexto

El desarrollo técnico instrumental exige la repetición metódica de escalas diatónicas, arpegios e intervalos en todas las tonalidades. Integrar un generador paramétrico en el cliente permite a los estudiantes practicar cualquier escala o ejercicio técnico sin depender de conexión a internet ni de partituras estáticas pre-descargadas.

---

## Decisión

1. **Generación Determinista en Dominio Puro:**
   Implementar `AlgorithmicExerciseGenerator` en `lib/features/exercise_generator/domain/` como Dart puro sin dependencias de UI.
2. **Modelado Teórico-Musical Riguroso:**
   - Soporte para escalas Mayores, Menores Naturales, Menores Armónicas, Menores Melódicas y Pentatónicas.
   - Generación de arpegios e intervalos de terceras continuas.
   - Estudios de Notas Largas para afinación sostenida.
3. **Acoplamiento con la Rejilla Rítmica:**
   Generación de compases métricamente exactos ($4/4$, 16 ticks por compás) con división en semicorcheas, corcheas o negras.
4. **Integración Directa con el Ecosistema:**
   El resultado es un `SongPackage` de primera clase, lo que habilita de inmediato reproducción procedural ADSR, práctica asistida con evaluación 4D y exportación a MusicXML y MIDI.

---

## Consecuencias

### Positivas
- Generación instantánea de miles de variaciones de ejercicios para cualquier instrumento.
- Respeta estrictamente los principios de Clean Architecture y Monolito Modular.
- Facilita rutinas de estudio dinámicas y de alto valor pedagógico.
