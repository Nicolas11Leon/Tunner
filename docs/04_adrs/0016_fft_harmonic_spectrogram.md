# ADR-0016: Laboratorio de Análisis de Timbre y Espectrograma de Armónicos

- **Estado:** Aprobado
- **Fecha:** 2026-10-27
- **Autor:** Nicolas Leon / Antigravity Engine
- **Área:** Acústica Musical, DSP Espectral y Visualización Vectorial

---

## Contexto

La evaluación de la afinación pura ($\pm \text{cents}$) cubre solo una dimensión de la práctica musical. Los conservatorios y solistas de élite dedican gran parte de su estudio técnico al desarrollo del "sonido" (timbre, proyección, equilibrio armónico). Sin embargo, el software libre disponible no ofrece herramientas accesibles en tiempo real para visualizar la serie armónica del instrumento de forma interactiva y pedagógica en el dispositivo del usuario.

---

## Decisión

1. **Cálculo Determinista de la Serie Armónica en Dominio Puro:**
   Crear `HarmonicSeriesAnalyzer` en `lib/features/acoustic_lab/domain/` implementado en Dart puro sin dependencias de UI.
2. **Extracción Acústica de 8 Armónicos:**
   Calcular las amplitudes exactas para los múltiplos enteros $k \cdot f_0$ ($k=1\dots 8$), correlacionándolas con la nota fundamental calculada por el algoritmo MPM.
3. **Métricas Psicoacústicas Estándar:**
   - Centroide Espectral (brillo tímbrico en Hz).
   - Distorsión Armónica Total (THD en porcentaje).
4. **Visualización Vectorial de Grado Conservatorio:**
   Implementar `HarmonicSpectrogramModal` con animaciones fluidas a 60 FPS utilizando la paleta estética activa del sistema.

---

## Consecuencias

### Positivas
- Eleva a Tunner por encima de cualquier afinador comercial estándar al ofrecer análisis timbral de conservatorio.
- Facilita a estudiantes de flauta, trompeta, canto y cuerdas el control de su embocadura y resonancia.
- Zero impacto en la batería o rendimiento general (análisis ligero acotado a la serie $1..8$).
