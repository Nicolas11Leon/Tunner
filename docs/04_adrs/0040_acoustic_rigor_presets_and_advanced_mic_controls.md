# ADR 0040: Presets de Rigurosidad Acústica por Contexto y Controles de Micrófono de Doble Nivel (Noob vs. Pro)

---

## Estado
Aprobado (Approved)

---

## Contexto
Diferentes perfiles de usuario y situaciones operativas requieren niveles de exigencia acústica diametralmente opuestos:
1. **Principiantes y Niños ("Noobs"):** Carecen de estabilidad en el flujo de aire o en la presión del arco/dedo. Un umbral estricto descarta notas reales inestables, causando frustración. Requieren alta tolerancia y retroalimentación inmediata (1 frame de latencia, tolerancia de cents amplia).
2. **Ensayos y Salas Comunes:** Requieren un balance intermedio para ignorar ruidos moderados de la habitación sin sacrificar reactividad.
3. **Escenarios Ruidosos / Bandas:** Existen fugas audibles severas de batería, cajas de guitarra y público. Requieren compuertas de ruido de alto impacto y Tone Lock multi-frame (3 frames) para impedir que los platillos o el bajo del vecino activen el afinador.
4. **Productores, Ingenieros de Sonido y Conservatorios:** Exigen precisión quirúrgica, ajuste manual de micro-parámetros (claridad MPM, Noise Gate milimétrico, tiempo de confirmación) y diagnósticos visuales en tiempo real.

---

## Decisión
Se decide implementar una arquitectura de **Doble Nivel (Dual-Tier Architecture)** en la ingesta acústica:
1. **Entidad de Dominio `AcousticRigorProfile`:**
   - Define un enum `AcousticRigorPreset`: `beginner`, `balancedRehearsal`, `studioRecording`, `noisyStage`, `conservatoryMastery`, y `custom`.
   - Cada preset encapsula una configuración cohesiva de parámetros acústicos:
     - Claridad armónica mínima ($c_{\text{min}} \in [0.65, 0.92]$).
     - Tolerancia de desviación tonal ($\Delta_{\text{cents}} \in [15.0, 50.0]$).
     - Ventanas de estabilidad temporal ($N_{\text{frames}} \in [1, 3]$).
     - Factor multiplicador de Noise Gate ($\text{multiplier} \in [0.7\times, 2.0\times]$).
2. **Conmutador de Interfaz de Usuario:**
   - **Vista Rápida / Presets (Para Todo Público):** Tarjetas táctiles elegantes con descripción pedagógica y contexto de uso para activación con un solo toque.
   - **Vista Avanzada / Paramétrica (Para Técnicos):** Sliders independientes y switches para afinar milimétricamente cada constante de DSP.
3. **Sincronización In-Process y Persistencia:**
   - Transmisión atómica al Isolate de DSP a través de `InstrumentAcousticFilterConfig` y `MicrophoneCalibrationProfile`.
   - Guardado automático en el almacenamiento local JSON del usuario.

---

## Consecuencias

### Positivas:
- **Ergonomía universal:** Atiende fluidamente tanto al estudiante principiante que no comprende de decibeles ni de cents, como al ingeniero de audio que necesita micro-control.
- **Rendimiento determinista:** Todos los cálculos se resuelven en Pure Dart sin dependencias externas ni sobrecoste de CPU.
- **Transparencia acústica:** El usuario puede comprobar en el medidor VU y en tiempo real el efecto de sus ajustes.

### Neutras / Mitigaciones:
- Si el usuario modifica valores en la vista avanzada, el preset conmuta automáticamente a `custom`, indicando claramente que se está empleando una calibración manual especializada.
