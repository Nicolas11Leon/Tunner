# ADR 0120: Empaquetado Multiplataforma, Permisos Nativos y Compuerta Final Pre-v1.0.0

## Estado
Aceptado

## Contexto
Tunner Studio es una estación de trabajo musical offline-first diseñada para funcionar en múltiples sistemas operativos: Linux, Windows, macOS, Android, iOS y Web.
Para garantizar un rendimiento de baja latencia acústica, se utiliza la biblioteca nativa C/C++ `libtunner_dsp` mediante `dart:ffi`.
Sin embargo:
1. Las configuraciones de compilación de CMake y Gradle para `libtunner_dsp` deben estar completamente enlazadas en los ejecutables de destino.
2. En macOS, los sandboxes y los permisos de micrófono (`NSMicrophoneUsageDescription`) y manipulación de archivos (`com.apple.security.files.user-selected.read-write`) deben estar explícitamente declarados en `Info.plist` y `*.entitlements`.
3. Existía en `pubspec.yaml` la dependencia huérfana `pitch_detector_dart`, la cual fue completamente reemplazada por el motor MPM de dominio propio (`mcleod_pitch_method.dart` y `libtunner_dsp`).
4. El Application ID canónico `org.tunner.studio` debe quedar unificado.

## Decisión
1. **Configuración de Compilación Nativa FFI:**
   - En Linux: `linux/CMakeLists.txt` incluye la compilación de `native/dsp/tunner_dsp.c` o enlace de `libtunner_dsp.so`.
   - En Windows: `windows/CMakeLists.txt` incluye la compilación o enlace de `tunner_dsp.dll`.
   - En Android: `android/app/build.gradle.kts` y `CMakeLists.txt` enlazan `libtunner_dsp.so` para `armeabi-v7a`, `arm64-v8a`, `x86_64`.
   - En iOS/macOS: Enlace directo mediante `DynamicLibrary.process()`.
2. **Eliminación de Dependencias Huérfanas:**
   - Purgar definitivamente `pitch_detector_dart` de `pubspec.yaml`.
3. **Permisos y Entitlements macOS:**
   - Agregar `NSMicrophoneUsageDescription` a `macos/Runner/Info.plist`.
   - Agregar `com.apple.security.device.audio-input` y `com.apple.security.files.user-selected.read-write` a `macos/Runner/DebugProfile.entitlements` y `macos/Runner/Release.entitlements`.
4. **Application ID:**
   - Establecer `org.tunner.studio` como el identificador canónico.

## Consecuencias
- Cero dependencias huérfanas en el proyecto.
- Ejecutables nativos listos para compilación en tiendas o distribución offline sin bloqueos de seguridad de macOS ni enlaces rotos de CMake.
- Verificación exhaustiva de 0 advertencias de análisis y 100% de tests unitarios y de integración aprobados.
