# Plan de Implementacion: Pipeline de Integracion Continua (CI) en GitHub Actions y Enlace con SonarQube Cloud

## Metadatos del Plan

- **ID del Plan:** `PLAN-GLOBAL-CI-SONAR-2026-062`
- **Título de la Implementación:** Configuración del Flujo de Calidad Automatizado en GitHub Actions y Sincronización de Cobertura con SonarQube Cloud
- **Fase del Proyecto:** Global / Infraestructura y Calidad
- **Estado:** Aprobado
- **ADR Relacionado:** [ADR 0058: Arquitectura de Pipeline de Integración Continua (CI) en GitHub Actions y Enlace de Cobertura con SonarQube Cloud](../04_adrs/0058_ci_cd_github_actions_pipeline.md)
- **Documento Funcional Base:** [DOC-ARCH-2026-064](../01_product_vision/doc_ci_cd_github_actions_pipeline.md) y [UC-64](../02_use_cases/64_uc_ci_cd_github_actions_pipeline.md)

---

## 1. Alcance y Objetivos de la Implementacion

### 1.1 Objetivo Primario
Implementar la infraestructura de integración continua oficial del repositorio Tunner en GitHub, integrando análisis estático, ejecución de las más de 567 pruebas automatizadas con generación de reportes de cobertura LCOV y configuración del puente hacia SonarQube Cloud.

### 1.2 Limites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Creación del directorio `.github/workflows/` y el archivo maestro `ci.yml`.
  - Configuración de disparadores para pull requests y pushes en ramas de trabajo.
  - Generación de artefactos de cobertura (`coverage/lcov.info`).
  - Creación de `sonar-project.properties` para configuración estandarizada de SonarQube Cloud.
  - Actualización de `README.md` y documentación del repositorio.
- **Excluido (Out-of-Scope):**
  - Despliegue continuo a tiendas de aplicaciones (Play Store, App Store) en esta iteración.

---

## 2. Analisis de Dependencias y Tecnologias

- **GitHub Actions Runners:** `ubuntu-latest`
- **Flutter Action:** `subosito/flutter-action@v2` (soporte LTS canal `stable`)
- **Checkout Action:** `actions/checkout@v4` con `fetch-depth: 0`
- **Artifacts Action:** `actions/upload-artifact@v4`
- **SonarCloud Scanner Action:** `SonarSource/sonarqube-scan-action@master`

---

## 3. Plan Paso a Paso de Ejecucion (Step-by-Step Roadmap)

### Paso 1: Configuración de SonarQube Cloud
- [ ] Crear archivo `sonar-project.properties` en la raíz del proyecto indicando proyecto, organización, fuentes y ruta a `coverage/lcov.info`.

### Paso 2: Construcción del Workflow de GitHub Actions
- [ ] Crear `.github/workflows/ci.yml`.
- [ ] Configurar jobs `analyze-and-test` con pasos de checkout, setup flutter, pub get, analyze, test y upload artifact.
- [ ] Incluir paso opcional y tolerante para SonarCloud Scan.

### Paso 3: Verificación Local y Sintáctica
- [ ] Validar sintaxis YAML.
- [ ] Actualizar contador de métricas y documentación en `README.md`.
- [ ] Realizar commit y push de la rama `feature/github-actions-ci-cd-pipeline`.
- [ ] Publicar PR en GitHub y verificar que el workflow comience a ejecutarse en la nube.

---

## 4. Criterios de Aceptacion y Definition of Done (DoD)

1. Archivos `.github/workflows/ci.yml` y `sonar-project.properties` válidos y presentes en el repositorio.
2. Cero emojis en archivos de configuración, código y documentación.
3. El pipeline se dispara y ejecuta exitosamente ante eventos de pull request.
4. Documentación formal enlazada en el repositorio.
