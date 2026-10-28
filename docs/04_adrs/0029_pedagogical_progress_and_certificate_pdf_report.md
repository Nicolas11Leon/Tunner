# ADR 0029: Generador de Reportes y Certificados de Progreso Pedagógico en PDF Vectorial (ISO 32000-1)

## Estado
Aprobado

## Contexto
El aprendizaje musical riguroso y la práctica deliberada requieren cerrar el ciclo formativo con documentación tangible y formal. Hasta el momento, Tunner contaba con una suite integral de métricas en tiempo real (afinador estroboscópico, desviaciones en cents, detector de armónicos FFT, métricas de jitter en tap tempo y comparador multi-pista), pero carecía de una capacidad para compilar y emitir un reporte formal exportable o certificado de aprovechamiento pedagógico.

Para resolver esta necesidad sin comprometer las reglas no negociables de la Constitución del proyecto ([AGENTS.md](../../AGENTS.md)), se requería:
1. Una generación de documentos PDF 100% offline, en Pure Dart, sin depender de bibliotecas nativas, webviews pesados ni microservicios externos.
2. Renderizado gráfico vectorial de alta precisión matemática para graficar curvas de micro-entonación en cents, bandas de conservatorio ($\pm 5$ y $\pm 15$ cents) e histogramas de armónicos.
3. Emisión de un Certificado de Logro de Conservatorio con diseño ornamental geométrico y código criptográfico/simbólico de autenticación.
4. Total desacoplamiento entre el modelo de datos de la sesión (`PedagogicalSessionData`), la configuración (`PedagogicalReportConfig`) y el compilador de bajo nivel (`PedagogicalReportPdfGenerator`).

## Decisión
1. **Compilador Vectorial Pure Dart ISO 32000-1:**
   - Diseñar `PedagogicalReportPdfGenerator` que construya objetos binarios PDF 1.4 de manera nativa mediante sintaxis PostScript/PDF (`q`, `Q`, `m`, `l`, `re`, `w`, `RG`, `rg`, `S`, `f`, `BT`, `ET`, `Tf`, `Tm`, `Tj`), integrando una tabla de referencias cruzadas (`xref`), catálogo raíz (`Catalog`) y árbol jerárquico de páginas (`Pages`).
2. **Estructura Documental Modular:**
   - **Página 1 (Reporte Analítico):** Encabezado con datos institucionales, tarjetas de indicadores clave (KPIs), gráfico cartesiano de entonación continua, distribución armónica de 8 parciales y cuadro de recomendaciones didácticas.
   - **Página 2 (Certificado Formal de Conservatorio):** Orla ornamental vectorial de doble trazo en coordenadas absolutas de página, tipografía caligráfica, acreditación del nivel alcanzado y sello de verificación.
3. **Desacoplamiento Limpio en Capa de Dominio:**
   - Ubicar `PedagogicalReportConfig`, `PedagogicalSessionData` y `PedagogicalReportPdfGenerator` en `lib/features/pedagogy_report/domain/` como componentes puros de Dart, independientes de widgets de Flutter.
4. **Capa de Presentación e Integración:**
   - Crear `PedagogicalReportModal` en `lib/features/pedagogy_report/presentation/` que permita previsualizar métricas, personalizar nombres de estudiante e institución, alternar componentes y descargar o compartir el archivo exportado.
   - Enlazar con `TunerViewModel` para poblar de forma transparente los datos reales de la sesión en vivo.

## Consecuencias

### Positivas
- 100% independiente de internet y dependencias externas de renderizado (0 MB adicionales de dependencias nativas).
- Alta fidelidad visual para impresión física o archivo digital con un peso de archivo mínimo ($15\text{ KB} - 40\text{ KB}$).
- Validez pedagógica inmediata para conservatorios, profesores particulares e instituciones educativas.

### Negativas / Mitigaciones
- La generación manual de sintaxis PDF exige cálculo trigonométrico y geométrico manual para primitivas de dibujo y flujo de texto.
  *Mitigación:* Se encapsulan funciones auxiliares de dibujo vectorial (rectángulos redondeados, curvas de bézier, barras, líneas y bloques tipográficos) dentro del generador de dominio con cobertura de pruebas unitarias exhaustiva.
