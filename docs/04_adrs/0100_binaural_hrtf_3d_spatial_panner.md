# Registro de Decisión de Arquitectura (ADR) 0100: Matriz de Paneo Binaural y Espacialización 3D para Auriculares (HRTF)

---

## Metadatos

- **ID del ADR:** `ADR-0100`
- **Título:** Motor de Espacialización Binaural 3D en Dart Puro mediante Modelo de Retardo Woodworth (ITD) y Sombra Craneal Espectral (ILD)
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 7`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 111](../02_use_cases/111_uc_binaural_hrtf_3d_spatial_panner.md)
- **Plan Relacionado:** [Plan Épica 7.2](../05_implementation_plans/plan_binaural_hrtf_3d_spatial_panner.md)
- **Issue Asociado:** [#38](https://github.com/Nicolas11Leon/Tunner/issues/38)

---

## 1. Contexto

La percepción espacial con auriculares requiere recrear las señales auditivas binaurales primarias que el cerebro humano procesa para localizar una fuente de sonido en el plano horizontal (azimut) y vertical (elevación):
1. **Diferencias Temporales (ITD):** La distancia física adicional que recorre el frente de onda para alcanzar el oído opuesto.
2. **Diferencias Espectrales y de Intensidad (ILD):** La dispersión y absorción que la masa de la cabeza ejerce sobre las frecuencias medias y agudas (> 1.5 kHz).
3. **Restricción de Recursos:** Cargar una base de datos SOFA densa de HRIRs (*Head-Related Impulse Responses*) añade cientos de megabytes y convoluciones pesadas que comprometen la meta sub-10ms en dispositivos móviles.

---

## 2. Decisión

Se adopta un **Modelo Paramétrico Estructural de HRTF Sintética** en Dart puro dentro de `lib/core/audio/domain/spatial/`:

1. **Líneas de Retardo Fraccionario e ITD de Woodworth:**
   - Retardo en muestras calculado analíticamente según la posición azimutal.
   - Búfer circular compacto de 64 muestras por oído (suficiente para retardo físico máximo de ~30 muestras a 44.1 kHz).
   - Suavizado de retardo para transiciones angulares continuas sin clics.

2. **Filtros IIR de Sombra Craneal (Head Shadow ILD):**
   - Filtro paso-bajo de un polo aplicado selectivamente sobre el oído contralateral (sombra acústica).
   - Frecuencia de corte angular:
     $$f_c(\theta) = f_{\min} + (f_{\max} - f_{\min}) \cdot \left(\frac{1 + \cos\theta}{2}\right)$$
     Donde $f_{\min} = 1500\text{ Hz}$ y $f_{\max} = 18000\text{ Hz}$.

3. **Atenuación por Distancia:**
   - Ley inversa de la distancia atenuada:
     $$\text{gain}(d) = \frac{d_{\text{ref}}}{d_{\text{ref}} + (d - d_{\text{ref}})}$$
     Con $d_{\text{ref}} = 1.0\text{ metro}$, garantizando un decaimiento natural y seguro.

---

## 3. Consecuencias

### Positivas
- **Cero Dependencias Externas:** No requiere archivos de datos SOFA externos ni llamadas nativas.
- **Rendimiento Máximo:** Procesa 1024 muestras en menos de 0.1 ms en Dart, garantizando latencia imperceptible.
- **Integración con Tunner DSL y Master Console:** Permite situar cualquier instrumento o canal mediante órdenes declarativas (ej. `set @spatial.azimuth = -45;`).
