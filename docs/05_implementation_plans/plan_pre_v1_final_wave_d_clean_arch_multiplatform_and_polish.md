# Plan de Implementacion: Ola Final D Pre-v1.0.0 (#95)

## Objetivo
Cerrar todos los hallazgos de la Ola D (S0-13, S0-14, S1-12, S2-15 a S2-18, S3-01 a S3-08) y certificar la Release Candidate `v1.0.0` en `qa`.

## Lotes de Trabajo
1. **Lote D1 — FFI Nativo, CMake y Soporte Web (`flutter build web`):**
   - `NativeDspFfiBridge`: iOS `DynamicLibrary.process()`, desktop `Platform.resolvedExecutable` sibling lookup, stub Web via `if (dart.library.ffi)`.
   - `native/dsp/CMakeLists.txt`: agregar `PUBLIC_HEADER DESTINATION include`.
   - Importaciones condicionales para `dart:io` / `dart:isolate` donde bloqueen `flutter build web --no-pub`.
2. **Lote D2 — Empaquetado Multiplataforma, `pubspec.yaml` y Textos `v1.0.0`:**
   - `pubspec.yaml`: remover `cupertino_icons` y `permission_handler`.
   - Android (`build.gradle.kts`, `MainActivity.kt`), iOS/macOS (`project.pbxproj`), Linux (`my_application.cc`), Windows (`main.cpp`), Web (`web/index.html`): unificar `org.tunner.studio` y titulo `Tunner`.
   - `studio_desktop_app_shell.dart`, `tunner_os_terminal_drawer.dart`, `CONTRIBUTING.md`, `RELEASE_NOTES_v1.0.md`: `v1.0.0` y telemetria consistente.
3. **Lote D3 — Clean Architecture (`domain/` y `core/`):**
   - Corregir violaciones en `universal_media_io_service.dart`, `app_user_settings_entity.dart`, `i_studio_workspace_file_system.dart`, `i_studio_patchbay_routing_service.dart`, `studio_patchbay_routing_service.dart`.
   - Reducir acoplamientos `Core -> Features` en `tunner_os_kernel.dart` y `local_disk_studio_file_system_repository.dart`.
4. **Lote D4 — Verificacion Integral y PR hacia `qa`:**
   - `flutter analyze --no-fatal-infos` (0 issues).
   - `flutter build web --no-pub` (exit 0).
   - `flutter build linux --debug --no-pub` (exit 0).
   - `flutter test --no-pub` (100% pass).
   - PR y squash-merge hacia `qa`, cierre de Issue #95.
