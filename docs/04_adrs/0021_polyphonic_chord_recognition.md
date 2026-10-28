# ADR-0021: Reconocimiento Polifónico de Acordes en Tiempo Real mediante Vectores de Cromagrama (Chroma Vectors)

- **Estado:** Approved
- **Fecha:** 2026-10-27
- **Fase:** Fase 7.4 (Vanguardia Acústica y Conservatorio)
- **Autor:** Antigravity / Nicolas Leon

---

## 1. Contexto

Hasta la Fase 7.3, **Tunner** ha implementado un detector monofónico estroboscópico de ultra-alta precisión basado en el Método de Tono de McLeod (MPM), ideal para cuerdas solistas, cantantes y vientos afinando nota por nota.

Sin embargo, los músicos de conservatorio, pianistas, guitarristas, teóricos musicales y ensambles de cámara requieren una herramienta analítica polifónica: la capacidad de identificar instantáneamente qué acorde o tríada está sonando en el espacio acústico, evaluar la afinación de las notas que componen el acorde y verificar progresiones armónicas en vivo.

El análisis polifónico tradicional presenta desafíos computacionales:
1. Las redes neuronales profundas (e.g. Spleeter, Chordino VST) consumen decenas de megabytes, introducen latencia inaceptable ($> 150\text{ ms}$) y requieren dependencias nativas complejas.
2. La FFT cruda tiene fugas espectrales y sobrecarga en hilos móviles si se calculan decenas de miles de bins.

---

## 2. Decisión

Implementar un motor de extracción de características musicales basado en **Vectores de Cromagrama / Pitch Class Profile (PCP)** y clasificación por **Similitud de Coseno** en el Dominio puro de Dart:

1. **Extracción Cromática de 12 Semitonos (`ChromaVectorCalculator`):**
   - Evalúa selectivamente la energía en los semitonos de la escala temperada a lo largo del registro útil ($C_2 \approx 65\text{ Hz}$ a $C_6 \approx 1046\text{ Hz}$, cubriendo 48 notas cromáticas) mediante correlación trigonométrica dirigida.
   - Pondera cada nota $m$ por su energía espectral y la acumula en el semitono $c = m \pmod{12}$.
   - Normaliza el vector resultante mediante norma euclídea $L_2$: $\|\mathbf{v}\|_2 = 1.0$.

2. **Plantillas Armónicas Canónicas (`PolyphonicChordRecognizer`):**
   - 108 plantillas unitarias para las 9 familias de acordes:
     - Tríadas: Mayor, Menor, Disminuida, Aumentada, Sus4, Sus2.
     - Cuatriadas: Séptima de Dominante, Séptima Mayor, Séptima Menor.
   - Clasificación por similitud de coseno:
     $$\text{Score}(V, T_i) = \sum_{j=0}^{11} V_j \cdot T_{i, j}$$
   - Regla de decisión de máxima verosimilitud con umbral dinámico de confianza ($> 0.60$).
   - Filtro de histéresis temporal de 3 fotogramas para eliminar parpadeo y falsas transiciones.

3. **Cero Dependencias UI o Nativas:**
   - 100% código Dart puro en `lib/features/chord_analyzer/domain/`, ejecutable en cualquier plataforma (Android, iOS, Web, Desktop, Linux, macOS, Windows) y verificable con tests unitarios instantáneos.

---

## 3. Consecuencias

### Positivas
- Permite reconocimiento de acordes polifónicos a $\le 4\text{ ms}$ por búfer de audio.
- Coexistencia perfecta con el afinador estroboscópico monofónico MPM.
- Cero dependencias binarias pesadas; huella de memoria insignificante ($< 25\text{ KB}$).
- Posibilita pedagogía auditiva y teórica en conservatorio (identificación de grados e inversiones).

### Negativas / Mitigaciones
- Acordes muy complejos o disonantes (e.g. poliacordes, novenas alteradas) pueden resolverse a su tríada más cercana: mitigado exponiendo el vector cromático completo en el `ChordRadarWidget` para visualización analítica de todas las frecuencias presentes.
