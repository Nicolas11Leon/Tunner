# ADR 0002: Árbol de Notación Musical Jerárquico en Dominio Puro y Métricas Variables

---

## Estado
**Aprobado (Approved)** - Fecha: 2026-10-20

## Contexto
En la versión preliminar del sistema, las partituras estaban modeladas a través de una lista plana de notas (`SongNote`) atada rígidamente a un único compás de 4/4 dividido en exactamente 16 sub-ticks (semicorcheas).
Esta estructura impedía:
1. Representar compases ternarios comunes (3/4 para vals o estudios de conservatorio, 6/8 para música andina o barroca, 2/4 para marchas).
2. Estructurar obras de múltiples compases consecutivos con cambios de armadura o métrica.
3. Avanzar hacia el soporte universal de archivos estándar MusicXML y MIDI proyectados en la Fase 4.

## Decisión
1. **Modelado Jerárquico Inmutable en Dart Puro (`lib/domain/score_tree.dart`):**
   - Se crea una jerarquía de entidades limpias: `HierarchicalScore` $\rightarrow$ `MeasureEntity` $\rightarrow$ `HierarchicalNote`.
   - Cero dependencias de Flutter UI, plugins o infraestructura (Clean Architecture estricta).
2. **Métricas de Compás (`TimeSignature`):**
   - Cada compás encapsula su numerador (pulsos) y denominador (unidad de pulso).
   - El sistema calcula dinámicamente los sub-ticks por compás con resolución base en semicorcheas:
     $$\text{totalTicks} = \text{numerator} \times \left(\frac{16}{\text{denominator}}\right)$$
     (Ejemplo: 4/4 = 16 ticks; 3/4 = 12 ticks; 2/4 = 8 ticks; 6/8 = 12 ticks).
3. **Retrocompatibilidad:**
   - La entidad legacy `SongNote` se mantiene como adaptador temporal o se extiende para que la UI existente siga operando sin regresiones.

## Consecuencias

### Positivas:
- **Flexibilidad Musical:** El sistema puede representar cualquier compás métrico universal de la música clásica y contemporánea.
- **Preparación para MusicXML:** La estructura jerárquica mapea 1:1 con la especificación W3C MusicXML (`<score-partwise>` $\rightarrow$ `<part>` $\rightarrow$ `<measure>` $\rightarrow$ `<note>`).
- **Pruebas Unitarias Robustas:** La lógica rítmica y de subdivisión se puede probar al 100% en Dart sin levantar el motor de Flutter.

### Negativas / Mitigaciones:
- El `RealSheetMusicPainter` de la interfaz debe consultar la métrica del compás para calcular el ancho horizontal de los ticks en lugar de asumir el divisor fijo 16.
