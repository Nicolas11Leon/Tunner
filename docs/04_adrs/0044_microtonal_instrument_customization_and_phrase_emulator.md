# ADR 0044: Personalización Acústica Tímbrica, Desafinación Microtonal por Cuerda/Tecla y Emulador de Estrofas

---

## Estado
**Aprobado (Approved)**

---

## Contexto
El motor de instrumentos universales de Tunner (ADR 0043) proporciona un catálogo canónico categorizado bajo la taxonomía Hornbostel-Sachs y mapeo General MIDI con síntesis procedural ADSR. No obstante, en la práctica musical real de conservatorio y producción:
1. **Instrumentos no son perfectamente temperados:** Los pianos de concierto aplican *afinación estirada* (Curva de Railsback) para compensar la inharmonicidad física de las cuerdas; los pianos de blues/ragtime utilizan afinación desigual (*Honky-Tonk*); las guitarras a menudo requieren micro-ajustes por cuerda (ej. compensar la tensión en la 3ª cuerda Sol); y tradiciones no occidentales emplean microtonalismo (maqamat árabes con cuartos de tono).
2. **Evaluación tímbrica activa:** Los músicos necesitan escuchar cómo responde el instrumento al interpretar una nota aislada o una **estrofa melódica completa**, sin verse forzados a grabar tomas externas antes de calibrar.

---

## Decisión Arquitectónica

Se decide diseñar e implementar:

### 1. Entidad de Desafinación Microtonal por Nota (`PerNoteDetuningProfile`)
- Mapea un offset microtonal en cents $\Delta c \in [-100.0, +100.0]$ indexado por:
  - Nota MIDI cromática ($0 \dots 127$) para instrumentos de teclado/viento/láminas.
  - Índice de cuerda ($0 \dots N-1$) para instrumentos de cuerdas pulsadas o frotadas.
- La frecuencia física en Hertz resultante se calcula mediante la fórmula exponencial acústica:
  $$f_{\text{ajustada}} = f_0 \cdot 2^{\frac{\Delta c + \Delta c_{\text{temperamento}}}{1200}}$$
  Donde $f_0$ es la frecuencia pura en temperamento igual basada en el tono de concierto $A_4$.

### 2. Entidad de Personalización de Instrumento (`InstrumentCustomizationProfile`)
- Encapsula:
  - Modificadores de ADSR (multiplicador de tiempo de ataque y sostenimiento).
  - Escala de armónicos ($H_1 \dots H_8$).
  - Perfil de microtonalismo y desafinación por cuerda/tecla.
  - Tono de concierto $A_4$ ($415\text{ a }466\text{ Hz}$).
  - Sistema de temperamento musical activo (`MusicalTemperament`).

### 3. Modelo y Secuenciador de Frases / Estrofas Musicales (`MusicalPhraseEntity`)
- Entidad de dominio pura que contiene una secuencia rítmico-melódica de eventos:
  $$E_k = \langle \text{midiNote}, \text{durationMs}, \text{velocity}, \text{articulation} \rangle$$
- Colección canónica de estrofas predefinidas: *Arpegio Mayor Clásico*, *Preludio Barroco*, *Frase Pentatónica Andina*, *Línea de Bajo Funk*, *Cadencia Vocal Lírica*, y soporte para secuencias definidas por el usuario.

### 4. Teclado Emulador Universal Polifónico (`UniversalMasterKeyboardWidget`)
- Interfaz táctil de alto rendimiento capaz de transponer octavas ($C_1 \dots C_8$), disparar síntesis en tiempo real con las micro-desafinaciones activas y reproducir estrofas completas con barra de progreso.

---

## Consecuencias

### Positivas
- **Máximo control acústico y luthería virtual:** Permite emular desde pianos honky-tonk desafinados hasta guitarras con afinaciones abiertas y escalas microtonales no occidentales.
- **Herramienta pedagógica y auditiva de élite:** El usuario puede probar de oído cómo se escucha una obra o estrofa en cualquier instrumento antes de interpretarla.
- **Cálculo determinista en memoria:** Las operaciones se ejecutan en tiempo $O(1)$ sin asignaciones de memoria dinámicas en el hilo de reproducción.

### Negativas / Mitigaciones
- **Complejidad de interfaz en pantallas compactas:** Se mitiga diseñando selectores colapsables con pestañas limpias (*Tono*, *Afinación por Cuerda*, *Teclado/Estrofas*).
