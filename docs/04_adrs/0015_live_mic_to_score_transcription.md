# ADR-0015: Motor de Transcripción de Micrófono a Partitura en Tiempo Real

- **Estado:** Aprobado
- **Fecha:** 2026-10-27
- **Autor:** Nicolas Leon / Antigravity Engine
- **Área:** Audio DSP, Cuantización Rítmica y Notación SMuFL

---

## Contexto

Tunner dispone de un detector de tono de alta resolución mediante el Método de McLeod (MPM), un reloj determinista de metrónomo por sub-ticks y un editor vectorial de partituras SMuFL. Sin embargo, para transcribir melodías tocadas en instrumentos reales a la partitura, el usuario dependía de ingresar notas manualmente o importar archivos externos. La transcripción directa de señal de micrófono a partitura es una de las tecnologías más codiciadas en la educación musical y producción asistida, pero presenta desafíos acústicos complejos:
1. Ruido de fondo y transitorios de ataque que fragmentan notas continuas.
2. Fluctuación natural de tempo y micro-vibrato que desalinean la rejilla métrica.
3. Consumo de CPU si el análisis rítmico se realiza en el hilo de interfaz.

---

## Decisión

1. **Separación Estricta de Responsabilidades (Clean Architecture):**  
   Implementar la lógica de cuantización y secuenciamiento en `lib/features/transcription/domain/` como Dart puro, sin dependencias de Flutter UI ni de bibliotecas de terceros.
2. **Máquina de Estados de Transcripción Determinista:**  
   Utilizar una máquina de estados finitos (`idle`, `detecting_onset`, `sustaining_note`, `note_closed`) con filtro de histéresis temporal ($N_{\text{min}} = 2\text{ frames}$) y umbral de claridad de correlación normalizada ($\text{clarity} \ge 0.85$).
3. **Cuantizador Rítmico Cuadrático:**  
   Proyectar la duración acústica medida en sub-ticks sobre las figuras de conservatorio ($1, 2, 4, 8, 16\text{ ticks}$), garantizando compases consistentes y métricamente válidos.
4. **Integración con el Patrón Memento:**  
   Cada sesión o bloque de transcripción se respalda en el `ScoreUndoRedoHistory`, permitiendo al usuario revertir o corregir compases instantáneamente con 1 toque.

---

## Consecuencias

### Positivas
- Transcripción instantánea mientras el usuario toca, reduciendo drásticamente la barrera de entrada a la notación musical.
- Zero dependencias en la nube (100% offline y privado).
- Operación en tiempo real sin pausas de recolección de basura o allocations excesivas.
- Compatible con todos los instrumentos acústicos y registros de conservatorio.

### Negativas / Mitigaciones
- En pasajes muy rápidos a tempi elevados ($>200\text{ BPM}$), la duración de una semicorchea puede acercarse a la ventana de análisis de audio ($40\text{ ms}$). *Mitigación:* Se recomienda un tempo de práctica moderado ($60 - 120\text{ BPM}$) para máxima fidelidad de transcripción.
