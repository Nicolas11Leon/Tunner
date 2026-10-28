# ADR 0033: Motor de Detección Polifónica Multitonal en Tiempo Real mediante Tamiz Armónico

## Estado
Aprobado

## Contexto
El analizador de acordes de **Tunner** extraía vectores de cromagrama (PCP de 12 clases) e identificaba la especie armónica global del acorde (ej. "Do Mayor", "Sol Menor"). Sin embargo, no era capaz de aislar y reportar las frecuencias fundamentales individuales ($f_0$) ni las alturas exactas con octava (ej. $C_3, E_3, G_3, B_3$) que sonaban concurrentemente en la señal acústica.
Para instrumentos acústicos polifónicos como la guitarra o el piano, una nota grave produce armónicos enteros ($2f_0, 3f_0, 4f_0, 5f_0$) que coinciden casi exactamente con las notas superiores del acorde (octava, quinta, tercera armónica), generando falsos positivos de notas superpuestas o enmascarando las notas reales tocadas por el instrumentista.

## Decisión
1. **Algoritmo de Tamiz Armónico y Función de Salience (Harmonic Sieve & Salience):**
   - Implementar `PolyphonicMultiToneDetector` en la capa de dominio en Pure Dart (`lib/features/chord_analyzer/domain/`).
   - Para cada frecuencia candidata $f_0$ entre $E_2$ (~82.4 Hz) y $E_6$ (~1318.5 Hz), evaluar la función de salience sumando la energía espectral ponderada de sus armónicos $k \in \{1, 2, 3, 4, 5\}$ con ponderación exponencialmente decreciente $w_k = \frac{1}{\sqrt{k}}$.
   - Sustracción iterativa de armónicos: una vez identificada la voz dominante (ej. la fundamental del bajo), sustraer su peine armónico para permitir la detección precisa de las voces interiores con menor energía relativa.
2. **Modelado de Entidades Inmutables:**
   - `DetectedPolyphonicVoice`: Nombre con octava (ej. "Mi2" / "E2"), frecuencia exacta en Hz, número MIDI, desviación microtonal en cents y salience normalizado.
   - `PolyphonicMultiToneAnalysisResult`: Lista de voces ordenadas de grave a agudo, acorde asociado, conteo de polifonía y rol armónico (Raíz, Tercera, Quinta, Séptima).
3. **Capa de Presentación Reactiva:**
   - Crear `MultiToneVoicingWidget` e integrarlo en `ChordAnalyzerModal`.
   - Mostrar tarjetas individuales para cada cuerda/voz detectada con su desviación en cents y visualización de teclas activas.
4. **Rendimiento y Restricciones:**
   - Cero busy-waiting loops.
   - Cero dependencias nativas o externas; 100% matemática analítica en Dart.

## Consecuencias
- **Positivas:**
  - Descomposición transparente de acordes complejos de guitarra y piano en notas reales individuales con octava.
  - Información de afinación por cuerda/nota simultánea útil tanto para estudiantes como para productores e ingenieros acústicos.
  - Aislamiento arquitectónico estricto (Clean Architecture).
- **Negativas / Mitigaciones:**
  - El análisis espectral polifónico de alta resolución requiere ventanas de 2048 a 4096 muestras PCM; se optimizan las transformadas espectrales mediante tablas precalculadas para mantener fluidez a 60 FPS sin degradar la batería.
