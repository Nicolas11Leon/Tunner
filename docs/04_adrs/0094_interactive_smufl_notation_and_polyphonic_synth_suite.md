# ADR 0094: Suite de Notación Musical Vectorial SMuFL y Síntesis Polifónica Interactiva

- **Estado:** Propuesto
- **Fecha:** 2026-11-17
- **Autor:** Equipo de Ingeniería Tunner
- **Casos de Uso Relacionados:** [UC-105](../02_use_cases/105_uc_interactive_smufl_notation_and_polyphonic_synth_suite.md)
- **Plan de Implementación:** [plan_interactive_smufl_notation_and_polyphonic_synth_suite.md](../05_implementation_plans/plan_interactive_smufl_notation_and_polyphonic_synth_suite.md)

---

## 1. Contexto

La visualización de partituras en Tunner utilizaba una combinación de caracteres Unicode de fuentes de texto estándar (e.g. `'serif'`) y primitivas geométricas elementales en `RealSheetMusicPainter`. Esta aproximación presenta limitaciones técnicas y pedagógicas críticas:
1. **Falta de Fidelidad Tipográfica:** Los caracteres Unicode no respetan la estandarización internacional SMuFL (Standard Music Font Layout, desarrollada por el W3C Music Notation Community Group), provocando inconsistencias en el anclaje de plicas, proporciones de cabezas de nota, corchetes y dibujos de claves musicales en diferentes resoluciones y plataformas.
2. **Desconexión Sonora en la Interacción con la Partitura:** Al interactuar visualmente con el pentagrama (seleccionar una nota o cambiar de compás), no existía una respuesta auditiva polifónica instantánea. La partitura actuaba como un elemento puramente visual o dependía de pistas de audio pre-grabadas.
3. **Necesidad de un Motor de Síntesis Polifónica Determinista:** Para la práctica auditiva, lectura a primera vista y composición, el sistema requiere generar tonos acústicos limpios con múltiples voces simultáneas (acordes, contrapunto), control de envolvente ADSR suave sin transitorios desagradables y enrutamiento directo hacia la consola de masterización.

---

## 2. Decisión

Se adopta una solución arquitectónica que unifica la renderización vectorial tipográfica SMuFL con un motor de síntesis polifónica puro en Dart:

### 2.1 Motor de Renderizado Vectorial SMuFL (`SmuflGlyphPathEngine`)
- Implementación de un motor geométrico que genera trazados vectoriales matemáticos (`Path`) basados en la especificación formal SMuFL:
  - **Cabezas de Nota:** Redonda (`gClef`, `noteheadWhole`), Blanca (`noteheadHalf`), Negra/Corchea (`noteheadBlack`), con el ángulo de inclinación estándar de $12^\circ$ a $15^\circ$ y relación de aspecto proporcional al espaciado entre líneas del pentagrama ($sp$).
  - **Claves Musicales:** Clave de Sol (`gClef`) con espiral de proporción áurea y Clave de Fa (`fClef`) con los dos puntos delimitadores centrados en la cuarta línea.
  - **Silencios y Alteraciones:** Silencios vectoriales (redonda, blanca, negra, corchea, semicorchea) y símbolos de sostenido ($\sharp$), bemol ($\flat$) y becuadro ($\natural$).
  - **Líneas Adicionales Dinámicas (*Ledger Lines*):** Trazado automático de líneas auxiliares cuando la nota supera los límites inferior o superior del pentagrama.

### 2.2 Motor de Síntesis Polifónica Pura (`PolyphonicVoicePool`)
- **Grupo de Voces Asignable:** Creación de un pool de 16 voces polifónicas independientes (`PolyphonicSynthVoice`).
- **Osciladores Multi-Forma de Onda:** Generación matemática pura de:
  - Senoidal: $y(t) = \sin(2\pi f t)$
  - Sierra: $y(t) = 2 \left(t \cdot f - \lfloor t \cdot f + 0.5 \rfloor\right)$
  - Pulso / Cuadrada con PWM: modulación de ciclo de trabajo $d \in [0.1, 0.9]$.
  - Triángulo: $y(t) = 2 \left|2 \left(t \cdot f - \lfloor t \cdot f + 0.5 \rfloor\right)\right| - 1$
- **Generador de Envolvente ADSR de Precisión:**
  - Etapas de Ataque ($1\text{ ms}$ a $500\text{ ms}$), Decaimiento ($10\text{ ms}$ a $1000\text{ ms}$), Sostenimiento ($0.0$ a $1.0$) y Liberación ($10\text{ ms}$ a $2000\text{ ms}$).
  - Transición suave entre estados para garantizar cero transitorios o saltos de fase.
- **Estrategia de Robo de Voces (*Voice Stealing*):**
  - Ante saturación de polifonía, se reutiliza la voz con menor amplitud en fase de liberación, aplicando rampa descendente de 2 ms.

### 2.3 Coordinador de Reproducción Partitura-Audio (`ScorePlaybackCoordinator`)
- Orquesta el avance métrico del playhead en el pentagrama sincronizado con `StudioMasterClockService`.
- A cada sub-tick de tiempo, lee las notas activas en el compás del `ScoreTree` y despacha eventos `noteOn` y `noteOff` hacia el `PolyphonicVoicePool`.
- Permite la audición táctil inmediata (*tap-to-listen*): al presionar una nota en el pentagrama, suena instantáneamente.

### 2.4 Integración en Consola Master y Matriz de Audio
- La salida estéreo del `PolyphonicVoicePool` se integra como canal de entrada `'score_synth'` en `StudioAudioDeviceMatrixService`.
- La señal pasa por los faders de canal, el ecualizador paramétrico de 3 bandas, el compresor master y está disponible para captura en vivo a WAV.

---

## 3. Consecuencias

### 3.1 Positivas
- **Fidelidad Visual Profesional:** La partitura adquiere estándares tipográficos de nivel editorial (Dorico/Sibelius) sin requerir fuentes TTF externas pesadas.
- **Experiencia Pedagógica Integrada:** El estudiante o compositor puede escuchar al instante cada nota y acorde mientras los visualiza en el pentagrama.
- **Rendimiento Excepcional:** Cero bucles de espera activa (*zero busy-waiting*), renderizado a 60/120 FPS y síntesis en tiempo real con latencia menor a 10 ms.
- **Compatibilidad con la Cadena Master:** Todo el audio sintetizado es procesable por la cadena de masterización y grabable a disco.

### 3.2 Negativas / Retos Mitigados
- **Cálculo Vectorial de Glifos:** Trazar glifos SMuFL complejos en `Path` requiere definiciones geométricas precisas. Se mitiga encapsulando los trazados en un motor reutilizable `SmuflGlyphPathEngine` con pruebas unitarias de geometría.
- **Carga de CPU en Polifonía Alta:** La síntesis matemática en tiempo real de 16 voces simultáneas podría sobrecargar el hilo si no se optimiza. Se mitiga desactivando el procesamiento de voces cuyo multiplicador de amplitud ADSR caiga por debajo de $-60\text{ dB}$.
