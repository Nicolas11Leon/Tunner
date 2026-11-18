# ADR 0105: Expansión de Temperamentos Históricos (Werckmeister IV, Kirnberger I y Neidhardt)

**Estado:** Aprobado  
**Fecha:** 2026-11-18  
**Contexto Técnico:** Issue #51 (Comunidad - Good First Issue)  
**Autoridad:** Mantenedor Principal (@Nicolas11Leon)  

---

## 1. Contexto

La afinación estándar contemporánea (12-EDO o Temperamento Igual) divide la octava en 12 semitonos idénticos de 100 cents ($\sqrt[12]{2}$). Si bien facilita la transposición simétrica, introduce una desafinación acústica inherente de +13.69 cents en las terceras mayores respecto a la consonancia natural pura ($5:4 = 386.31$ cents) y una compresión de -1.96 cents en las quintas puras ($3:2 = 701.96$ cents).

Para la interpretación históricamente informada de música renacentista, barroca y del clasicismo temprano, los conservatorios emplean temperamentos desiguales específicos. El motor `TemperamentEngine` en Tunner contaba con 8 sistemas iniciales (Equal, Pythagorean, Just Intonation, Meantone 1/4, Werckmeister III, Kirnberger III, Vallotti, Young II). Se identificó la necesidad de incorporar tres sistemas canónicos complementarios:
1. **Werckmeister IV (Septenarius, 1691):** Variación de Andreas Werckmeister basada en la subdivisión proporcional en 7 partes.
2. **Kirnberger I (1771):** Sistema purista de Johann Philipp Kirnberger con cuatro quintas mesotónicas y una tercera mayor C-E matemáticamente pura (5:4).
3. **Neidhardt (1724):** Temperamento circulante de Johann Georg Neidhardt ("Grosse Stadt") concebido para grandes órganos y modulación libre a través de las 24 tonalidades.

---

## 2. Derivaciones Matemáticas y Acústicas

### 2.1 Constantes Acústicas Fundamentales
- **Coma Pitagórica ($PC$):** $12 \times \text{quinta pura} - 7 \times \text{octava} = 12 \times 701.955 - 8400 = 23.460$ cents.
- **Coma Sintónica ($SC$):** $4 \times \text{quinta pura} - \text{octava} - \text{tercera pura 5:4} = 4 \times 701.955 - 1200 - 386.314 = 21.506$ cents.
- **Esquisma ($S$):** $PC - SC = 23.460 - 21.506 = 1.954$ cents.

---

### 2.2 Kirnberger I (1771)
Johann Philipp Kirnberger propuso un sistema donde la tercera mayor C-E es absolutamente consonante (5:4, 386.31 cents). Para lograrlo:
- Las quintas $C-G$ y $G-D$ son puras ($701.96$ cents).
- La quinta $A-E$ es pura ($701.96$ cents).
- Toda la coma sintónica ($SC = 21.51$ cents) se concentra en la quinta $D-A$, reduciéndola a $701.96 - 21.51 = 680.45$ cents.
- Las restantes quintas de la cadena ($E-B-F\sharp-C\sharp-G\sharp$ y $C-F-B\flat-E\flat$) son quintas puras pitagóricas ($701.96$ cents).

**Tabla de Desviaciones en Cents respecto a 12-TET (Base Do = 0):**

| Grado | Nota | Frecuencia Relativa / Intervalo | Desviación (cents) |
| :--- | :--- | :--- | :--- |
| 0 | Do (C) | 1/1 (Unísono) | 0.00 |
| 1 | Do# (C#) | Quinta pura desde F# | -7.82 |
| 2 | Re (D) | Quinta pura desde G | +3.91 |
| 3 | Mib (Eb) | Cuarta pura desde Bb | -5.87 |
| 4 | Mi (E) | Tercera pura 5:4 desde C | -13.69 |
| 5 | Fa (F) | Cuarta pura desde C | -1.96 |
| 6 | Fa# (F#) | Quinta pura desde B | -9.78 |
| 7 | Sol (G) | Quinta pura 3:2 desde C | +1.96 |
| 8 | Sol# (G#) | Quinta pura desde C# | -5.87 |
| 9 | La (A) | Cuarta pura bajo Mi (E) | -15.64 |
| 10 | Sib (Bb) | Cuarta pura desde Fa | -3.91 |
| 11 | Si (B) | Quinta pura desde Mi | -11.73 |

---

### 2.3 Werckmeister IV (Septenarius, 1691)
Werckmeister subdividió la coma pitagórica en 7 partes iguales ($PC/7 \approx 3.35$ cents) en su tratado *Musicalische Temperatur* (Capítulo 29), distribuyendo la atemperación en quintas específicas para permitir que las tonalidades con pocos sostenidos y bemoles mantengan consonancia cercana a la justa, al tiempo que las tonalidades lejanas sean perfectamente transitables.

**Tabla de Desviaciones en Cents respecto a 12-TET (Base Do = 0):**

| Grado | Nota | Desviación (cents) |
| :--- | :--- | :--- |
| 0 | Do (C) | 0.00 |
| 1 | Do# (C#) | -6.00 |
| 2 | Re (D) | -4.00 |
| 3 | Mib (Eb) | -6.00 |
| 4 | Mi (E) | -8.00 |
| 5 | Fa (F) | +2.00 |
| 6 | Fa# (F#) | -10.00 |
| 7 | Sol (G) | -4.00 |
| 8 | Sol# (G#) | -8.00 |
| 9 | La (A) | -6.00 |
| 10 | Sib (Bb) | 0.00 |
| 11 | Si (B) | -8.00 |

---

### 2.4 Neidhardt (1724, "Grosse Stadt")
Johann Georg Neidhardt diseñó temperamentos circulantes graduales. El sistema "Grosse Stadt" (para grandes ciudades y órganos de catedral) atempera las quintas diatónicas centrales en $1/6$ de coma y las adyacentes en $1/12$ de coma, manteniendo las quintas remotas puras, lo que produce una suavidad armónica sin contrastes ásperos al modular.

**Tabla de Desviaciones en Cents respecto a 12-TET (Base Do = 0):**

| Grado | Nota | Desviación (cents) |
| :--- | :--- | :--- |
| 0 | Do (C) | 0.00 |
| 1 | Do# (C#) | -7.82 |
| 2 | Re (D) | -3.91 |
| 3 | Mib (Eb) | -3.91 |
| 4 | Mi (E) | -7.82 |
| 5 | Fa (F) | +1.96 |
| 6 | Fa# (F#) | -9.78 |
| 7 | Sol (G) | -1.96 |
| 8 | Sol# (G#) | -5.87 |
| 9 | La (A) | -5.87 |
| 10 | Sib (Bb) | 0.00 |
| 11 | Si (B) | -7.82 |

---

## 3. Decisión

1. Registrar como constantes inmutables en `lib/features/tuner/domain/temperament_engine.dart` los tres nuevos sistemas:
   - `id: 'werckmeister_iv'`
   - `id: 'kirnberger_i'`
   - `id: 'neidhardt_1724'`
2. Exponer getters estáticos de acceso directo:
   - `TemperamentEngine.werckmeisterIV`
   - `TemperamentEngine.kirnbergerI`
   - `TemperamentEngine.neidhardt1724`
3. La colección `allTemperaments` se amplía de 8 a 11 elementos inmutables, propagándose automáticamente al selector de UI y al ViewModel sin requerir cambios estructurales adicionales.

---

## 4. Consecuencias

### Positivas
- **Fidelidad Histórica de Conservatorio:** Permite a organistas y clavecinistas afinar instrumentos según los tres sistemas fundamentales de la literatura de J.S. Bach, Buxtehude y Kirnberger.
- **Rendimiento Inalterado:** Los 11 temperamentos se evalúan en tiempo constante $O(1)$ sin asignaciones de memoria dinámicas en el lazo crítico de procesamiento de audio.
- **Compatibilidad Total:** El selector de tónica (`rootKey`) traslada circularmente las desviaciones de los nuevos temperamentos de forma inmediata.
