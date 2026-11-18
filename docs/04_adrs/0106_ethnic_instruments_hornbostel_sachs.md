# ADR 0106: Presets Instrumentales Étnicos según Taxonomía Hornbostel-Sachs

**Estado:** Aprobado  
**Fecha:** 2026-11-18  
**Contexto Técnico:** Issue #52 (Comunidad - Help Wanted)  
**Autoridad:** Mantenedor Principal (@Nicolas11Leon)  

---

## 1. Contexto

La mayoría de software comercial de afinación se restringe a instrumentos de la orquesta sinfónica occidental y ensambles de música popular (guitarra, bajo, piano, batería, violín, flauta traversa, trompeta). Sin embargo, la educación musical global y la acústica contemporánea requieren soporte nativo para tradiciones organológicas ancestrales y de música del mundo.

El sistema de afinador inteligente de Tunner basa su catálogo en la taxonomía científica Hornbostel-Sachs (HS). Era imperativo incorporar instrumentos étnicos no occidentales de alta relevancia pedagógica y organológica:
- **Kora (África Occidental):** Arpa-laúd de 21 cuerdas con puente asimétrico y caja de resonancia de calabaza.
- **Sitar (India):** Laúd de mástil largo con trastes móviles de latón y cuerdas simpáticas.
- **Shakuhachi (Japón):** Flauta de bambú longitudinal de extremo soplado sin aeroducto.
- **Charango (Región Andina):** Cordófono mestizo con afinación reentrante y 5 órdenes dobles.
- **Cuatro Venezolano (Venezuela / Llanos colombo-venezolanos):** Cordófono tradicional de 4 cuerdas con afinación reentrante "Cambur Pintón".

---

## 2. Decisión Organológica y Acústica

Se definen formalmente en `lib/features/instrument/domain/universal_instrument_definition.dart` los 5 nuevos instrumentos con sus especificaciones taxonómicas y de afinación:

### 2.1 Kora de África Occidental
- **ID:** `chordophone.plucked_strings.kora_west_african`
- **Categoría HS:** `HornbostelSachsCategory.chordophone` (HS 321.3)
- **Subfamilia:** `InstrumentSubfamily.pluckedStrings`
- **Afinación Canónica (Tomora Ba / Sawuta heptatónica):** 
  - 21 cuerdas divididas entre mano izquierda (11 cuerdas) y mano derecha (10 cuerdas).
  - Rango acústico: $F_2$ (87.31 Hz) a $G_5$ (783.99 Hz), MIDI 41 a 79.
  - Notas de referencia base: `F2`, `C3`, `D3`, `E3`, `F3`, `G3`, `A3`, `Bb3`, `C4`, `D4`, `E4`, `F4`, `G4`, `A4`, `Bb4`, `C5`, `D5`, `E5`, `F5`, `G5`.

### 2.2 Sitar Clásico de la India
- **ID:** `chordophone.plucked_strings.sitar_indian`
- **Categoría HS:** `HornbostelSachsCategory.chordophone` (HS 321.321)
- **Subfamilia:** `InstrumentSubfamily.pluckedStrings`
- **Afinación Canónica (Estilo Vilayat Khan / Ravi Shankar):**
  - Cuerdas melódicas principales (Baaj, Jora, Laraj, Kharaj) y Chikari.
  - Rango acústico: $C_2$ (65.41 Hz) a $C_6$ (1046.50 Hz), MIDI 36 a 84.
  - Notas de referencia: `C2`, `G2`, `C3`, `F3`, `G3`, `C4`, `C5`.
  - Número General MIDI: 104 (Sitar).

### 2.3 Shakuhachi Tradicional Japonés
- **ID:** `aerophone.woodwind.shakuhachi_japan`
- **Categoría HS:** `HornbostelSachsCategory.aerophone` (HS 421.111.12)
- **Subfamilia:** `InstrumentSubfamily.woodwind`
- **Afinación Canónica (Talla estándar 1.8 Shaku):**
  - Escala pentatónica fundamental (Ryo / Ritsu): $D_4, F_4, G_4, A_4, C_5$.
  - Rango acústico: $D_4$ (293.66 Hz) a $D_7$ (2349.32 Hz), MIDI 62 a 98.
  - Número General MIDI: 77 (Shakuhachi).

### 2.4 Charango Andino
- **ID:** `chordophone.plucked_strings.charango_andean`
- **Categoría HS:** `HornbostelSachsCategory.chordophone` (HS 321.322)
- **Subfamilia:** `InstrumentSubfamily.pluckedStrings`
- **Afinación Reentrante Temple Natural (5 órdenes dobles):**
  - Orden 1: $E_5$ ($659.25$ Hz, MIDI 76)
  - Orden 2: $A_4$ ($440.00$ Hz, MIDI 69)
  - Orden 3: $E_5 / E_4$ ($659.25$ Hz y $329.63$ Hz, MIDI 76/64)
  - Orden 4: $C_5$ ($523.25$ Hz, MIDI 72)
  - Orden 5: $G_4$ ($392.00$ Hz, MIDI 67)
  - Rango acústico: $329.63$ Hz ($E_4$) a $2093.00$ Hz ($C_7$).

### 2.5 Cuatro Tradicional Venezolano
- **ID:** `chordophone.plucked_strings.cuatro_venezuelan`
- **Categoría HS:** `HornbostelSachsCategory.chordophone` (HS 321.322)
- **Subfamilia:** `InstrumentSubfamily.pluckedStrings`
- **Afinación Reentrante "Cambur Pintón":**
  - Cuerda 1 (Prima): $B_3$ ($246.94$ Hz, MIDI 59)
  - Cuerda 2 (Segunda): $F\sharp_4$ ($369.99$ Hz, MIDI 66)
  - Cuerda 3 (Tercera): $D_4$ ($293.66$ Hz, MIDI 62)
  - Cuerda 4 (Cuarta / Bordón): $A_3$ ($220.00$ Hz, MIDI 57)
  - Rango acústico: $220.00$ Hz ($A_3$) a $1975.53$ Hz ($B_6$).

---

## 3. Consecuencias

### Positivas
- **Inclusión Etnomusicológica:** Reconocimiento riguroso de afinaciones no lineales y microtonales en la plataforma.
- **Calibración Precisa:** El afinador inteligente reconoce notas de cuerdas octavadas y reentrantes sin presentar saltos erráticos de octava.
- **Rendimiento Inalterado:** Colecciones inmutables en memoria con búsqueda indexada sin bucles de asignación dinámica.

### Negativas / Mitigaciones
- Las cuerdas dobles con octava (Orden 3 del Charango) contienen dos frecuencias simultáneas ($E_4$ y $E_5$).
  - *Mitigación:* Se registran ambas frecuencias en la tabla de frecuencias de afinación del `AcousticRange`.
