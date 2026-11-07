# Template: Documentation Standard (Plantilla Documentación)

## Metadatos del Documento

- **ID del Documento:** `DOC-UIUX-2026-051`
- **Título Oficial:** `Matriz Integral de Atajos de Grado Photoshop y Sistema Universal de Ayuda Contextual (?) para Tunner`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-07`
- **Última Modificación:** `2026-11-07`
- **Fase Asociada:** `Fase 4 & Global`
- **Autor / Revisor Principal:** `Tunner UX/UI & Engineering Core Team`

---

## 1. Resumen Ejecutivo (Executive Summary)

Las suites creativas profesionales líderes en el mundo (Adobe Photoshop, Ableton Live, Logic Pro, Blender) se fundamentan en dos pilares indiscutibles:
1. **Atajos para cada herramienta individual:** Cada función, dial o modo cuenta con una tecla nemotécnica rápida (`V`, `M`, `L`, `B`, `Z`, `E`, `D`, etc.) y modificadores (`Ctrl/Cmd`, `Shift`, `Alt`), permitiendo alternar y ajustar herramientas sin levantar la mano del teclado o instrumento.
2. **Ayuda Contextual Universal ("?"):** Cada componente, selector, dial de afinación, ventana de tempo o botón de control expone un botón de ayuda contextual interactivo (`?`) que despliega una tarjeta explicativa con el fundamento pedagógico, acústico y el atajo rápido asociado.

El presente documento define la taxonomía de más de 30 atajos profesionales estructurados por dominios de interacción y el componente de ayuda contextual universal `ContextualHelpBadge`.

---

## 2. Taxonomía de Atajos de Grado Photoshop

### 2.1 Herramientas Principales (Single-Key Direct Select)
- **`A` / `T` (Afinador / Tuner):** Activa o enfoca el afinador estroboscópico de ultra-precisión.
- **`M` (Metrónomo / Metronome):** Activa o conmuta el metrónomo determinista.
- **`S` (Partitura / Score):** Enfoca el pentagrama interactivo en vivo.
- **`R` (Grabador / Record):** Inicia/detiene toma de auto-escucha.
- **`D` (Dron / Drone):** Alterna el dron armónico de oído en la nota tónica.
- **`V` (Vocal Autotune):** Alterna el corrector de tono vocal DSP en tiempo real.
- **`F` (FFT Espectro):** Despliega el espectrograma y análisis armónico.
- **`C` (Acordes / Chords):** Activa el analizador polifónico de acordes.
- **`L` (Lecciones / Lessons):** Abre el catálogo de ejercicios pedagógicos.
- **`K` (Teclado Maestro / Keyboard):** Despliega el emulador cromático de instrumento.

### 2.2 Transporte y Reproducción
- **`Espacio` (Space):** Play / Pause global maestro.
- **`Shift + Espacio`:** Rebobinar al compás inicial y reproducir.
- **`[` / `]`:** Decrementar / Incrementar tempo en $\pm 1$ BPM.
- **`Shift + [` / `Shift + ]`:** Decrementar / Incrementar tempo en $\pm 5$ BPM.
- **`B` (Tap Tempo):** Pulsar tempo al compás de la música.

### 2.3 Afinación y Calibración Acústica
- **`Alt + Flecha Arriba` / `Alt + Flecha Abajo`:** Subir / Bajar tono de concierto $A_4$ ($\pm 1\text{ Hz}$).
- **`P` (Preset de Sesión):** Ciclar entre presets (Calentamiento, Partitura, Producción, Libre).
- **`0` (Silencio Total / Panic Mute):** Corta todos los sintetizadores, drones y streams de audio de inmediato.

### 2.4 Navegación y Modales
- **`Cmd/Ctrl + K`:** Abrir Command Palette Spotlight.
- **`Cmd/Ctrl + I`:** Abrir Selector de Instrumento Universal.
- **`Cmd/Ctrl + T`:** Abrir Selector de Temperamento Histórico.
- **`?` (`Shift + /`):** Abrir Cheat Sheet completo de atajos.
- **`Esc`:** Cerrar cualquier modal o colapsar HUDs secundarios.

---

## 3. Especificación del Sistema de Ayuda Contextual ("?")

### 3.1 Contrato del `ContextualHelpBadge`
Cada herramienta cuenta con una insignia sutil `?` que:
1. Al pulsarla, abre un bottom sheet o popover no intrusivo (`ContextualHelpSheet`).
2. Muestra:
   - **Nombre de la herramienta y categoría.**
   - **Fundamento musical o acústico.**
   - **Consejo pedagógico de práctica.**
   - **Atajos de teclado asignados a la herramienta.**
