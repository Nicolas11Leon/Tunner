# Plan de Implementación: Formato Canónico (.tunner), Contenedor de Proyecto Universal y Serialización Lossless

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE6-CANONICAL-CONTAINER-2026-0095`
- **Título de la Implementación:** Especificación y Motor del Formato Canónico (.tunner), Manifiesto Criptográfico SHA-256 y Serialización Lossless
- **Fase del Proyecto:** Fase 6 (Ecosistema de Plataforma Autónoma y Contenedor Canónico)
- **Estado:** Completado
- **ADR Relacionado:** [ADR 0095](../04_adrs/0095_canonical_tunner_project_container_and_lossless_serialization.md)
- **Documento Funcional Base:** [Caso de Uso 106](../02_use_cases/106_uc_canonical_tunner_project_container_and_lossless_serialization.md)
- **Issue Asociado:** [#33](https://github.com/Nicolas11Leon/Tunner/issues/33)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Implementar un sistema de serialización y empaquetado atómico para proyectos musicales completos de **Tunner** en un contenedor estándar `.tunner`, preservando sin pérdida el estado de la notación musical, la matriz de dispositivos de hardware, los presets del sintetizador polifónico, el estado de la consola DJ y las pistas de audio PCM, con comprobación criptográfica SHA-256.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Entidades de dominio inmutables en `lib/core/packaging/domain/`: `TunnerProjectManifestEntity`, `TunnerProjectPackageEntity`, `ITunnerPackageCodec`, y `TunnerPackageCorruptedException`.
  - Servicio de codificación/decodificación en `lib/core/packaging/infrastructure/tunner_package_codec_service.dart`.
  - Integración en `TunerViewModel` (`exportCurrentProjectToTunner`, `importProjectFromTunnerBytes`).
  - Comando `/project export`, `/project import`, `/project info` en `TunnerOsKernel`.
  - Pruebas unitarias de empaquetado, verificación de hashes e integración con la suite completa.
- **Excluido (Out-of-Scope):**
  - Sincronización automática con almacenamiento en la nube privada o pública (se mantiene estrictamente *Offline-First*).
  - Intérprete DSL (se abordará en la Épica 6.2 e Issue #34).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal estable oficial.
  - Paquete `archive`: `^4.5.2` (ya presente en dependencias directas de `pubspec.yaml`).
- **Riesgo Tecnológico:**
  - Cero dependencias nativas o externas nuevas: Operación 100% en Dart puro con cálculo de hashes y manipulación de streams en memoria.
  - Cero bucles de espera activa: El empaquetado y descompresión opera de forma síncrona en memoria para paquetes pequeños/medianos o en micro-pausas asíncronas para archivos grandes.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [x] Definir `TunnerProjectManifestEntity` con serialización JSON, control de versión (`1.0.0`), metadatos (`bpm`, `timeSignature`, `sampleRate`) y mapa de firmas `fileHashes`.
- [x] Definir `TunnerProjectPackageEntity` como agregado raíz inmutable del proyecto completo.
- [x] Definir contrato `ITunnerPackageCodec` y excepción tipada `TunnerPackageCorruptedException`.
- [x] Pruebas unitarias de dominio para entidades y validación de manifiesto.

### Paso 2: Capa de Infraestructura / Datos (Servicio de Codificación y Hash SHA-256)
- [x] Implementar `TunnerPackageCodecService` en `lib/core/packaging/infrastructure/`:
  - Algoritmo de cálculo de hash criptográfico SHA-256 para `Uint8List`.
  - Compresión DEFLATE en formato ZIP utilizando `archive`.
  - Ensamblado de archivos (`manifest.json`, `routing_matrix.json`, `notation/score.json`, `instruments/synth_preset.json`, `dj_workstation/session.json`, `audio_vault/stems/*`).
  - Verificación rigurosa de integridad hash por hash durante la decodificación.
- [x] Pruebas unitarias de codificación, decodificación y detección de alteraciones maliciosas o accidentales.

### Paso 3: Capa de Aplicación, ViewModel y CLI
- [x] Conectar `TunnerPackageCodecService` con `TunerViewModel`:
  - Métodos para exportar el proyecto actual a bytes `.tunner`.
  - Métodos para importar un proyecto desde bytes `.tunner` y restaurar reactivamente partitura, matriz y presets de sintetizador.
- [x] Extender `TunnerOsKernel` con comandos de consola `/project info`, `/project export`, `/project import`.
- [x] Pruebas de integración del ViewModel y comandos CLI.

### Paso 4: Pruebas, Verificación y Limpieza
- [x] Ejecutar `flutter analyze --no-fatal-infos` (0 advertencias).
- [x] Ejecutar la suite completa de pruebas unitarias y de widgets (`flutter test`).
- [x] Validar que no se hayan introducido emojis en el código, comentarios ni documentación.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit `4d78b63` en `main`.
- **Mitigación Inmediata:** Si el servicio de paquetes experimenta alguna excepción en entornos específicos, los métodos existentes de persistencia JSON local y exportación de MusicXML/MIDI continúan intactos.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](../../AGENTS.md).
- [ ] Cero busy-waiting loops.
- [ ] 100% de pruebas unitarias pasando.
- [ ] Documentación canónica completa (Caso de Uso 106, ADR 0095 y este Plan archivados).
- [ ] Pull Request formal creado en GitHub con vinculación al Issue #33.
