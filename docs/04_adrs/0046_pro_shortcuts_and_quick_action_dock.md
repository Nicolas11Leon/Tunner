# ADR 0046: Sistema Unificado de UX Ergonómica, Atajos Globales y Command Palette Spotlight

- **Estado:** Accepted
- **Fecha:** 2026-11-07
- **Fase:** Fase 4 & Global
- **Autor:** Tunner UX/UI & Engineering Core Team

---

## 1. Contexto

A pesar de contar con motores de procesamiento DSP de nivel conservatorio (precisión $\pm 0.1$ cents, detección MPM/NSDF, sintetizadores WAV ADSR, temperamentos históricos y 454 pruebas unitarias), la experiencia de usuario (UX) puede sentirse fragmentada o requerir demasiados toques para operaciones cotidianas de práctica instrumental (iniciar reproducción, grabar una frase para evaluarse, ingresar tempo por pulso o cambiar de herramienta). Las aplicaciones de pago más exitosas en producción musical y educación se diferencian por una accesibilidad inmediata y fluida.

---

## 2. Decisión

Se implementa una arquitectura de interacción de tres niveles en la capa de presentación de Tunner:

1. **`QuickActionDockWidget` (Dock Flotante Ergonómico):**
   - Integrado en `MainAppShell`, posicionado justo sobre la barra de navegación.
   - Contiene los controles de mayor frecuencia de uso: Play/Pause maestro, Grabación rápida con indicador LED palpitante, Botón de Tap Tempo interactivo con cálculo de jitter rítmico, y botón de acceso directo a la Command Palette.
   - Posibilidad de colapso a un mini-pill mediante un toque para no obstaculizar la vista.

2. **`GlobalAppShortcutsWrapper` (Atajos de Teclado y Controladores Hardware):**
   - Integrado mediante la API nativa de Flutter `Focus`, `Shortcuts` y `Actions`.
   - Mapeo directo:
     - `LogicalKeyboardKey.space`: Alterna Play/Pause del transporte maestro y metrónomo.
     - `LogicalKeyboardKey.keyR`: Alterna grabación de toma en vivo.
     - `LogicalKeyboardKey.keyT`: Tap tempo inmediato.
     - `LogicalKeyboardKey.keyA`: Salto directo a afinador estroboscópico.
     - `LogicalKeyboardKey.digit1` a `digit5`: Navegación directa entre pestañas del shell.
     - `LogicalKeyboardKey.keyK` (con `meta` o `control`): Abre la Command Palette.
     - `LogicalKeyboardKey.slash` (con `shift`, `?`): Abre la tarjeta modal de ayuda de atajos.

3. **`ProCommandPaletteModal` (Buscador Spotlight con Acciones Rápidas):**
   - Diálogo modal con input enfocado automáticamente y lista filtrada en caliente ($< 16\text{ ms}$).
   - Soporte para acciones rápidas ("Iniciar Metrónomo a 120 BPM", "Cambiar a Guitarra Eléctrica", "Afinar en 432 Hz", "Crear Ejercicio").

---

## 3. Consecuencias

### Positivas:
- **Ergonomía de Grado Profesional:** El usuario puede practicar sin soltar el instrumento con una mano y tocar un botón gigante con el pulgar o presionar un pedal Bluetooth/teclado.
- **Paridad con Aplicaciones Comerciales:** Se eleva la percepción de calidad del producto al estándar de las DAWs y suites educativas profesionales.
- **Cero Bloqueo de UI:** Todas las animaciones y cálculos de tempo corren en 60/120 FPS sin tocar hilos pesados de audio.

### Negativas / Mitigaciones:
- **Espacio en Pantalla en Teléfonos Pequeños:** El dock puede colapsarse tocando un botón de chevron discreto para ceder el 100% de la altura al pentagrama o afinador.
