# ADR-0018: Arquitectura de Experiencia Dual Progresiva (Modo Esencial vs. Modo Pro)

- **Estado:** Aprobado
- **Fecha:** 2026-10-27
- **Autor:** Nicolas Leon / Antigravity Engine
- **Área:** Experiencia de Usuario (UX), Arquitectura de Presentación y Persistencia

---

## Contexto

A medida que Tunner ha incorporado capacidades de nivel conservatorio (partituras SMuFL vectoriales, edición, consolas multicanal de stems, análisis espectral de armónicos FFT, estimador MPM y transcripción de micrófono), la pantalla principal corría el riesgo de sobrecargar cognitivamente a usuarios que únicamente desean una herramienta de afinación inmediata, rápida y sin distracciones.

---

## Decisión

1. **Modelo de Visualización Dual (`AppDisplayMode`):**
   Definir en el dominio de configuración `AppDisplayMode`:
   - `essential`: Vista minimalista enfocada en la nota gigante, frecuencia en Hertz, tolerancia visual en cents y aguja estroboscópica virtual de alta precisión.
   - `conservatoryPro`: Estación acústica completa con atril de partitura SMuFL interactivo, consola de stems, grabador y herramientas avanzadas.
2. **Conmutación Instantánea sin Recarga de Estado:**
   La conmutación entre modos es puramente declarativa en el árbol de widgets de Flutter a 60 FPS, sin detener el motor de audio, metrónomo ni aislamientos de hilos.
3. **Persistencia Atómica Offline:**
   La preferencia de modo de visualización se guarda automáticamente en `tunner_settings.json` mediante escritura atómica `.tmp + rename`.

---

## Consecuencias

### Positivas
- Resuelve la paradoja del software potente: máxima simplicidad para el usuario que busca inmediatez y máxima profundidad para el músico profesional.
- Cero impacto en el rendimiento o consumo de batería.
- Interfaz intuitiva y de alto contraste estético.
