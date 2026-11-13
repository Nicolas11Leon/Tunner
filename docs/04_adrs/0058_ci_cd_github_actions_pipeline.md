# ADR 0058: Arquitectura de Pipeline de Integracion Continua (CI) en GitHub Actions y Enlace de Cobertura con SonarQube Cloud

## Estado
Aprobado (Approved) - 2026-11-11

## Contexto
El proyecto Tunner ha escalado a más de 567 pruebas automatizadas, 63 casos de uso y múltiples subsistemas de audio digital, DSP y pedagogía musical. Aunque las pruebas se ejecutan localmente con éxito, en GitHub los Pull Requests no contaban con un runner automatizado de CI que ejecutase las pruebas y calculase la cobertura de código en cada pull request y push. Como consecuencia directa:
1. SonarQube Cloud reportaba "0.0% Coverage on New Code" debido a que no existía un paso de compilación que produjera el archivo `coverage/lcov.info`.
2. Las revisiones de código no podían apoyarse en checks automatizados del sistema antes de autorizar el merge.
3. Se requería automatizar de forma determinista la ejecución de `flutter analyze` y `flutter test --coverage` en la nube.

## Decision
1. **Creación del Workflow Canónico de GitHub Actions:**
   - Crear el archivo `.github/workflows/ci.yml`.
   - Utilizar el runner oficial `ubuntu-latest`.
   - Implementar el paso `subosito/flutter-action@v2` fijando el canal `stable` y habilitando el caché de SDK y dependencias para acelerar el pipeline.
   - Ejecutar en secuencia determinista:
     1. `flutter pub get`
     2. `flutter analyze`
     3. `flutter test --coverage`
2. **Generación y Preservación de Reportes de Cobertura:**
   - Guardar el archivo `coverage/lcov.info` como artefacto del pipeline mediante `actions/upload-artifact@v4`.
3. **Configuración de SonarQube Cloud:**
   - Crear el archivo maestro de propiedades `sonar-project.properties` en la raíz del repositorio, especificando `sonar.projectKey=Nicolas11Leon_Tunner`, `sonar.organization=nicolas11leon`, `sonar.sources=lib`, `sonar.tests=test` y la ruta del informe de cobertura `sonar.dart.coverage.reportPaths=coverage/lcov.info`.
   - Integrar el paso de análisis de SonarCloud en el workflow condicionado a la disponibilidad de `SONAR_TOKEN`.

## Consecuencias

### Positivas
- **Garantía Continua de Calidad:** Cada commit y pull request es validado automáticamente en un entorno limpio sin intervención manual.
- **Métricas Reales en SonarQube Cloud:** El cálculo de cobertura de código reflejará el porcentaje real de la base de código (más del 85% promedio en dominio y lógica de negocio).
- **Protección de Ramas Efectiva:** Los administradores y colaboradores pueden verificar con un solo vistazo si una rama cumple con la Definition of Done antes de su integración a `main`.

### Negativas / Mitigaciones
- **Consumo de Minutos de GitHub Actions:** Cada ejecución del workflow consume aproximadamente 2 minutos de tiempo de cómputo en runners de GitHub.
  *Mitigación:* Se implementa caché inteligente para el SDK de Flutter y el directorio `.pub-cache`, reduciendo las descargas redundantes en ejecuciones subsecuentes.
