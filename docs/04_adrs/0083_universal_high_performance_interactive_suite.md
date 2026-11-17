# ADR 0083: Suite Interactiva Universal de Alto Rendimiento

- **Estado:** Aceptado
- **Fecha:** 2026-11-16
- **Contexto:** Experiencia de Usuario Táctil, Pruebas Manuales, Física Acústica y Ergonomía
- **Fase:** Fase 1 / Consolidación Universal (Beta Ready)

---

## 1. Contexto

Durante las pruebas manuales de la estación de trabajo y consola DJ, se identificó la oportunidad de elevar la fidelidad táctil, acústica y visual:
1. Los vúmetros reflejaban niveles de ganancia estáticos en lugar de oscilar con la balística analógica de los transitorios rítmicos del audio.
2. Los archivos semilla en disco (`~/Documents/TunnerProjects`) utilizaban cabeceras mínimas que no emitían tonos musicales si el usuario los abría en reproductores externos.
3. La interacción con teclado requería memorizar teclas en lugar de disponer de un HUD directo a la vista.
4. Para evaluar el funcionamiento simultáneo de todos los subsistemas (loops, beat jump, crossfader, sincronización, sampler) se requería una secuencia coreografiada automatizada (Showcase 15s).

---

## 2. Decisión

Se implementan las siguientes capacidades ergonómicas y físicas:
1. **Física de Vúmetro Rítmico:** Incorporar la ecuación de fase de compás y decaimiento exponencial balístico en `DjVerticalChannelStrip` y paneles de mezcla.
2. **Sembrado de Audio Real en Disco:** Generar proceduralmente archivos WAV PCM de 16 bits válidos con tonos puros y ritmos bailables (`Toma_Acustica_440Hz.wav` y `Loop_Club_Groove_124BPM.wav`) directamente en `LocalDiskStudioFileSystemRepository`.
3. **HUD Flotante de Atajos:** Integrar una barra superior de acceso rápido y guía nemotécnica en `DjStudioWorkstationView`.
4. **Carga Rápida de Géneros en Cabecera de Deck:** Menú directo de 1 clic para cargar estilos musicales predefinidos en Deck A y Deck B.
5. **Showcase Automático de 15 Segundos:** Rutina asíncrona cancelable en `DjConsoleViewModel` que dispara una coreografía de prueba integral en vivo.

---

## 3. Consecuencias

### Positivas
- Máxima inmediatez y satisfacción en pruebas manuales tanto para novatos como para DJs avanzados.
- Coherencia acústica real en el sistema de archivos del sistema operativo.
- El vúmetro proporciona retroalimentación visual realista a 60 FPS sin sobrecargar la CPU.
- El showcase permite verificar instantáneamente regresiones operativas en presentaciones en vivo o demos.

### Negativas / Mitigaciones
- Los temporizadores de la rutina Showcase deben ser deterministas y limpiarse con seguridad al destruirse el widget o ViewModel.
  *Mitigación:* Se implementa un método `cancelShowcaseRoutine()` invocado explícitamente en `dispose()`.
