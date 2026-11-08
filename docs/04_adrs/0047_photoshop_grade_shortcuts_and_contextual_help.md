# ADR 0047: Adopción del Estándar de Teclado Photoshop y Ayuda Contextual Universal ("?")

- **Estado:** Accepted
- **Fecha:** 2026-11-07
- **Fase:** Fase 4 & Global
- **Autor:** Tunner UX/UI & Engineering Core Team

---

## 1. Contexto

El software creativo líder en productividad (Adobe Photoshop, Blender, Logic Pro, Ableton Live) debe su éxito a dos factores:
1. **Flujo de trabajo de memoria muscular:** Toda herramienta cuenta con una letra de acceso directo (`V` selección, `M` metrónomo, `B` pincel/tap tempo, `Z` zoom, etc.).
2. **Descubrimiento asistido:** Ninguna herramienta es una caja negra; cada botón expone un glifo `?` o tooltip enriquecido que educa al usuario sobre su propósito, fórmula acústica y su combinación de teclas.

En Tunner, los usuarios músicos necesitan cambiar entre afinador, metrónomo, dron armónico, autotune, partitura y lecciones en milisegundos sin soltar su instrumento ni distraerse buscando botones pequeños.

---

## 2. Decisión

1. **Mapeo de Atajos Estilo Suite Creativa:**
   - Asignar teclas directas nemotécnicas para las 10 herramientas principales (`A`, `M`, `S`, `R`, `D`, `V`, `F`, `C`, `L`, `K`).
   - Asignar controles incrementales: `[` y `]` para tempo $\pm 1$ BPM, `Shift + [` y `Shift + ]` para tempo $\pm 5$ BPM.
   - Atajos de calibración: `Alt + Flecha Arriba/Abajo` para frecuencia de concierto $A_4$ en Hz.
   - Atajo de pánico/silencio: `0` silencia todas las fuentes generadoras.
2. **Componente Reutilizable `ContextualHelpBadge`:**
   - Icono `?` estandarizado, discreto y estilizado con la paleta de Tunner.
   - Apertura de `ContextualHelpSheet` con 4 campos: Título, Explicación Acústica/Pedagógica, Fórmulas/Tips y Atajos de Teclado aplicables.

---

## 3. Consecuencias

### Positivas:
- **Velocidad Extrema:** Productividad idéntica a programas de edición profesional de escritorio.
- **Auto-Aprendizaje Continuo:** El usuario no requiere manuales externos; la app se auto-explica mediante los botones `?`.
- **Accesibilidad Total:** Funciona de igual forma en móviles mediante toques y en tablets/escritorio con teclado o pedales.
