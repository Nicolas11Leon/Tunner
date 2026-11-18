# Registro de Decisión de Arquitectura (ADR) 0102: Evaluación de Estabilidad Vocal y Generador Vectorial de Certificados PDF

---

## Metadatos

- **ID del ADR:** `ADR-0102`
- **Título:** Evaluador de Estabilidad Fonatoria (Jitter, Shimmer, Vibrato) y Generador Canónico de Certificados PDF Sellados con SHA-256 en Dart Puro
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 8`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 113](../02_use_cases/113_uc_vocal_evaluation_and_pdf_certificates.md)
- **Plan Relacionado:** [Plan Épica 8.2](../05_implementation_plans/plan_vocal_evaluation_and_pdf_certificates.md)
- **Issue Asociado:** [#40](https://github.com/Nicolas11Leon/Tunner/issues/40)

---

## 1. Contexto

La evaluación pedagógica del canto y la afinación vocal requiere ir más allá de la simple detección del tono instantáneo. En conservatorios e instituciones de canto lírico y contemporáneo, los criterios de maestría vocal demandan:
1. **Estabilidad Perturbativa:** Medición clínica de Jitter (variabilidad de frecuencia fundamental) y Shimmer (variabilidad de amplitud fonatoria).
2. **Control de Vibrato:** Detección de la tasa de oscilación (fisiológicamente óptima en 4.5 - 7.0 Hz) y su profundidad o extensión en cents.
3. **Certificación Formal Inmutable:** Generación de un reporte formal en formato PDF estándar que certifique los resultados del estudiante y garantice su autenticidad mediante firma digital SHA-256.

Restricciones no negociables:
- **Clean Architecture:** Capa de dominio pura en `lib/features/pedagogy/domain/` sin dependencias de Flutter UI, widgets ni plugins de renderizado nativo.
- **Formato PDF ISO 32000-1 / PDF-1.4:** El archivo PDF debe ser generado de manera autónoma en Dart puro (flujo binario con tablas de referencias cruzadas xref, objetos indirectos y fuentes estándar).
- **Rendimiento Máximo:** Generación del certificado en menos de 50 ms.

---

## 2. Decisión

Se decide implementar:

1. **`VocalStabilityEvaluator` (`lib/features/pedagogy/domain/vocal_stability_evaluator.dart`):**
   - Análisis de fotogramas de frecuencia y amplitud.
   - Cálculo de Jitter relativo ciclo a ciclo: $\text{Jitter}(\%) = \frac{\sum |T_i - T_{i+1}| / (N-1)}{\sum T_i / N} \times 100$.
   - Cálculo de Shimmer relativo: $\text{Shimmer}(\%) = \frac{\sum |A_i - A_{i+1}| / (N-1)}{\sum A_i / N} \times 100$.
   - Análisis de vibrato por paso por cero espectral y cálculo de cents pico a valle.
   - Score compuesto $S_{\text{vocal}} \in [0, 100]$ ponderando afinación (40%), estabilidad de pitch/jitter (25%), estabilidad de volumen/shimmer (20%) y coherencia de vibrato (15%).

2. **`PedagogicalCertificatePdfGenerator` (`lib/features/pedagogy/domain/pedagogical_certificate_pdf_generator.dart`):**
   - Ensamblador vectorial de sintaxis PDF-1.4 en Dart puro (emisión de `Catalog`, `Pages`, `Page`, `Font`, `Contents`, `trailer` y tabla `xref`).
   - Sello criptográfico SHA-256 generado con el paquete `crypto` existente, codificado en hexadecimal en el pie de página para verificación de integridad.

3. **Integración con Terminal Tunner OS:**
   - Comando `vocal` en `TunnerOsKernel` (`vocal eval <target_hz>`, `vocal cert <nombre_estudiante> [target_hz]`).

---

## 3. Consecuencias

### Positivas
- **Independencia Total de Plataforma:** Funciona idénticamente en Linux, macOS, Windows, Android, iOS y Web sin necesitar un visor de PDF ni componentes de impresión del sistema operativo.
- **Seguridad y Confianza Académica:** El sello digital SHA-256 permite a conservatorios validar si un certificado ha sido alterado.
- **Rigor Acústico Profesional:** Provee métricas estándar de laboratorios de foniatría y acústica vocal.
