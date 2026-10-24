# DOC-ESTETICA-2026-004: Motor de Estética Prémium, Temas Visuales y Selector Dinámico de Compases

---

## Metadatos del Documento

- **ID del Documento:** `DOC-ESTETICA-2026-004`
- **Título Oficial:** `Especificación Técnica del Motor de Estética Prémium y Selector Interactivo de Métrica de Compás`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-10-24`
- **Última Modificación:** `2026-10-24`
- **Fase Asociada:** `Fase 2`
- **Autor / Revisor Principal:** `Tunner Engineering & Nicolas Leon`

---

## 1. Resumen Ejecutivo (Executive Summary)

El presente documento define la arquitectura y el sistema de temas visuales prémium de **Tunner**, respondiendo a la exigencia de una experiencia de usuario del más alto nivel estético de la industria musical. Proporciona una suite de 4 paletas estéticas completas (*Obsidian Studio, Vintage Parchment, Neon Stage, OLED Pure Black*) aplicadas de forma consistente a toda la aplicación (fondo, pentagrama, figuras musicales, playhead, afinador estroboscópico y botones), junto con un **Selector de Métrica de Compás Libre** que permite alternar o forzar cualquier compás ($4/4, 3/4, 2/4, 6/8, 9/8, 12/8, 5/4$) en tiempo real sin recargar la aplicación ni desincronizar el reloj del metrónomo.

---

## 2. Paletas Estéticas y Fundamentación de Diseño

1. **Obsidian Studio:** Dark mode acústico profesional para salas de estudio y ensayo (fondos profundos `#0D0D12`, acentos `#00E676` y oro).
2. **Vintage Parchment:** Inspiración de partitura clásica en papiro/pergamino de conservatorio (`#F4ECD8` con líneas sepia y tinta de imprenta).
3. **Neon Stage:** Alto contraste escénico para directos o ambientes oscuros con violeta, cian neón y magenta eléctrico.
4. **OLED Pure Black:** Negro absoluto (`#000000`) para máxima eficiencia de batería en pantallas OLED y nitidez quirúrgica.

---

## 3. Selector de Métrica de Compás Libre

Permite a los usuarios y estudiantes cambiar el compás de cualquier ejercicio a través de un panel accesible desde la barra superior:
- Métricas simples: $2/4, 3/4, 4/4$.
- Métricas compuestas: $6/8, 9/8, 12/8$.
- Métricas complejas/irregulares: $5/4$.
- Recálculo determinista de subdivisiones:
  $$\text{totalTicks} = \text{numerador} \times \left(\frac{16}{\text{denominador}}\right)$$
