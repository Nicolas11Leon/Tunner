# Documento Técnico: Personalización Acústica Microtonal, Desafinación por Tecla/Cuerda y Emulador de Estrofas

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ARCH-2026-0049`
- **Título Oficial:** Motor de Desafinación Microtonal por Tecla/Cuerda, Personalización Tímbrica Completa y Teclado Emulador de Estrofas Musicales
- **Estado:** Approved
- **Fecha de Creación:** 2026-11-07
- **Última Modificación:** 2026-11-07
- **Fase Asociada:** Fase 4 (Estudio de Producción y Emulación Acústica Universal)
- **Autor / Revisor Principal:** Equipo de Arquitectura Tunner & Creador del Proyecto

---

## 1. Resumen Ejecutivo (Executive Summary)

Este documento especifica el sistema integral de personalización acústica y luthería virtual de **Tunner**. Se provee al usuario la capacidad de alterar en tiempo real la física tímbrica de cualquier instrumento, ajustar el temperamento y la referencia de concierto ($A_4$), inducir **desafinaciones microtonales deliberadas por cuerda o tecla** ($\Delta c \in [-100, +100]\text{ cents}$) para recrear efectos de época (como pianos Honky-Tonk, afinaciones estiradas de Railsback o afinaciones abiertas de guitarra), y reproducir notas individuales o **estrofas musicales completas** a través de un **Teclado Emulador Universal Polifónico**.

---

## 2. Fundamento Teórico y Fórmulas Matemáticas

### 2.1 Cálculo Microtonal Compuesto de Frecuencia
La frecuencia de cualquier nota emitida $f(n)$ combina tres variables fundamentales:
1. La frecuencia base en temperamento igual $f_{\text{12-EDO}}(n)$:
   $$f_{\text{12-EDO}}(n) = f_{\text{ref}} \cdot 2^{\frac{n - 69}{12}}$$
2. La desviación histórica del temperamento musical activo $\Delta c_{\text{temp}}(n \bmod 12)$ en cents.
3. La desviación microtonal deliberada por cuerda o tecla $\Delta c_{\text{custom}}(n)$ en cents.

La frecuencia acústica física final es:
$$f_{\text{final}}(n) = f_{\text{ref}} \cdot 2^{\frac{n - 69}{12} + \frac{\Delta c_{\text{temp}}(n \bmod 12) + \Delta c_{\text{custom}}(n)}{1200}}$$

### 2.2 Modelado de Inharmonicidad y Pianos Desafinados (Honky-Tonk)
En pianos reales, las tres cuerdas de un unísono nunca vibran a frecuencias idénticas; se produce un batimento (*chorus acústico*) característico:
$$f_{\text{batimento}} = |f_1 - f_2|$$
Permitiendo al usuario configurar un factor de desafinación unísono $\sigma_{\text{detune}}$ que genera un timbre orgánico y vivo.

---

## 3. Especificación Funcional

- **REQ-CUSTOM-01 (Afinación por Cuerda):** En instrumentos de cuerda (Guitarra, Bajo, Violín, Cello, Ukelele), el usuario puede ajustar la desviación en cents de cada cuerda independientemente.
- **REQ-CUSTOM-02 (Desafinación por Tecla):** En instrumentos cromáticos (Pianos, Órganos, Marimbas), el usuario puede alterar notas individuales de la escala (ej. cuartos de tono $\pm 50\text{ cents}$).
- **REQ-CUSTOM-03 (Presets Canónicos de Desafinación):**
  - *Standard Concert:* $\Delta c = 0.0\text{ cents}$ en todas las notas.
  - *Railsback Stretch:* Graves sutilmente más bajos (hasta $-15\text{ cents}$) y agudos más altos (hasta $+25\text{ cents}$).
  - *Honky-Tonk Bar:* Desafinación alternada de $\pm 8\text{ cents}$ para emular piano de taberna.
  - *Maqam Bayati:* Notas 3ª y 7ª bajadas $-50\text{ cents}$ (cuarto de tono microtonal oriental).
  - *12-String Shimmer:* Desfase de $\pm 6\text{ cents}$ emulando cuerdas pareadas.
- **REQ-EMULATOR-01 (Teclado Maestro Universal):** Teclado cromático interactivo con selector de octava ($C_1 \dots C_8$), sensibilidad de velocidad y disparo de síntesis instantánea.
- **REQ-EMULATOR-02 (Secuenciador de Estrofas):** Reproducción de frases melódicas estructuradas con indicación visual de nota activa, tempo ajustable (40 a 240 BPM) y transporte.

---

## 4. Arquitectura Clean Architecture

### Capa de Dominio (`lib/features/instrument/domain/`)
- `PerNoteDetuningProfile`: Mapa inmutable de offsets en cents por nota o cuerda con presets canónicos.
- `InstrumentCustomizationProfile`: Agregado que combina timbre, temperamento, $A_4$ y desafinaciones.
- `MusicalPhraseEntity`: Secuencia de eventos melódicos estructurados (`MusicalPhraseNote`) para estrofas.

### Capa de Datos (`lib/features/instrument/data/`)
- `ProceduralInstrumentSynthesizer`: Cálculo de formas de onda considerando el offset en cents por nota.

### Capa de Presentación (`lib/features/instrument/presentation/`)
- `InstrumentCustomizationModal`: Panel de luthería con sliders de cents, armónicos y temperamentos.
- `UniversalMasterKeyboardWidget`: Teclado polifónico y reproductor de estrofas.

---

## 5. Criterios de Aceptación (Definition of Done)
1. Desafinación por tecla/cuerda matemáticamente exacta ($\le 0.01\text{ Hz}$ de error de redondeo).
2. Teclado emulador y reproductor de estrofas con latencia de síntesis $\le 10\text{ ms}$.
3. Cobertura de pruebas unitarias $\ge 90\%$.
4. `flutter analyze` con 0 errores y 0 advertencias.
