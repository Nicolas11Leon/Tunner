# Plan de Implementación: Ola 6 - Empaquetado Multiplataforma, Permisos Nativos y Compuerta Final v1.0.0

## Metadatos del Plan
- **ID del Plan:** `PLAN-PRE-V1-WAVE6-2026-006`
- **Título de la Implementación:** Empaquetado Multiplataforma, Permisos Nativos y Compuerta Final Pre-v1.0.0
- **Fase del Proyecto:** Fase 4 / Hardening Pre-v1.0.0
- **Estado:** Aprobado
- **ADR Relacionado:** [`0120_pre_v1_multiplatform_packaging_native_permissions_and_final_gate.md`](../04_adrs/0120_pre_v1_multiplatform_packaging_native_permissions_and_final_gate.md)
- **Documento Funcional Base:** [`131_uc_pre_v1_multiplatform_packaging_native_permissions_and_final_gate.md`](../02_use_cases/131_uc_pre_v1_multiplatform_packaging_native_permissions_and_final_gate.md)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Configurar el empaquetado y compilación cruzada de `libtunner_dsp`, declarar permisos requeridos de audio y archivos en macOS/iOS, purgar dependencias huérfanas en `pubspec.yaml`, configurar el Application ID canónico `org.tunner.studio` y certificar la compuerta final de QA con cero advertencias y 100% de tests aprobados.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Purgar `pitch_detector_dart` de `pubspec.yaml`.
  - Configurar permisos de micrófono y sandbox en `macos/Runner/Info.plist`, `DebugProfile.entitlements` y `Release.entitlements`.
  - Configurar CMake/Gradle de compilación de `libtunner_dsp` en `linux/CMakeLists.txt`, `windows/CMakeLists.txt` y `android/app/build.gradle.kts`.
  - Verificar enlaces de FFI para iOS/macOS (`DynamicLibrary.process()`).
  - Actualizar `web/manifest.json` y metadatos de aplicación.
  - Ejecutar script de verificación y prueba final de compuerta v1.0.0.
- **Excluido (Out-of-Scope):**
  - No mergear directamente a `main` (sólo Nicolas11Leon lo hará).
  - No añadir features nuevas fuera de las contempladas en el plan de endurecimiento.

---

## 2. Plan Paso a Paso de Ejecución

### Paso 1: Dependencias y Pubspec
- [ ] Eliminar `pitch_detector_dart` de `pubspec.yaml` y ejecutar `flutter pub get`.

### Paso 2: Permisos de macOS / iOS
- [ ] Añadir `NSMicrophoneUsageDescription` a `macos/Runner/Info.plist`.
- [ ] Añadir `com.apple.security.device.audio-input` y `com.apple.security.files.user-selected.read-write` a los entitlements de macOS.

### Paso 3: Configuración de Compilación Nativa (CMake / Gradle)
- [ ] Revisar y asegurar `native/dsp/` y la compilación compartida en `linux/CMakeLists.txt` y `windows/CMakeLists.txt`.
- [ ] Revisar configuración NDK en Android.

### Paso 4: Identificador de Aplicación Canónico y Web Manifest
- [ ] Verificar `org.tunner.studio` en manifests y configuraciones de plataforma.
- [ ] Verificar `web/manifest.json`.

### Paso 5: Compuerta Final de Calidad
- [ ] Ejecutar `flutter analyze --no-fatal-infos` (debe retornar 0 issues).
- [ ] Ejecutar `flutter test` (100% de la suite pasando).
- [ ] Documentar resultados de auditoría en artefacto final.
