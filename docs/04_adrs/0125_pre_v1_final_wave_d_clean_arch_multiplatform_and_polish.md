# ADR-0125: Endurecimiento Pre-v1.0.0 Ola D (Multiplataforma Web/FFI, Clean Architecture y Pulido v1.0.0)

- **Estado:** Aceptado
- **Fecha:** 2026-11-19
- **Issue Relacionado:** #95
- **Caso de Uso:** UC-136

## Contexto
Para lanzar `v1.0.0` desde `qa` hacia `main`, el proyecto requiere soporte de compilacion real en Web (`flutter build web`), carga robusta de `libtunner_dsp` en iOS y binarios empaquetados de escritorio, eliminacion de identificadores plantilla `com.example.tunner`, limpieza de dependencias no usadas y correccion de violaciones de Clean Architecture en `domain/` y `core/`.

## Decision
1. **Soporte Web mediante Importaciones Condicionales:** Desacoplar los puntos de entrada que importan `dart:ffi` y `dart:io` usando `if (dart.library.ffi)` / `if (dart.library.io)` con implementaciones stub seguras en Web para que `flutter build web` compile sin errores manteniendo el rendimiento nativo en Desktop/Mobile.
2. **Resolucion FFI Nativa:** En `NativeDspFfiBridge`, usar `DynamicLibrary.process()` en iOS y sondear la carpeta de `Platform.resolvedExecutable` en Linux/Windows/macOS antes de recurrir a rutas relativas. Corregir `PUBLIC_HEADER DESTINATION` en `native/dsp/CMakeLists.txt`.
3. **Empaquetado y Metadatos `v1.0.0`:** Actualizar `com.example.tunner` a `org.tunner.studio`, titulos de ventana en Linux/Windows/Web a `Tunner`, remover `cupertino_icons` y `permission_handler` de `pubspec.yaml`, y corregir textos `v2.29.0` -> `v1.0.0` y telemetria de latencia realista.
4. **Clean Architecture:** Remover `dart:typed_data` / `flutter/foundation.dart` / dependencias de `data/` en capas `domain/` y eliminar dependencias `Core -> Features` donde existan puertos de dominio disponibles.

## Consecuencias
- **Positivas:** Compilacion verificada en Web y Linux, empaquetado consistente en todas las plataformas, menor tamano de binario sin fuentes de iconos no usadas, y arquitectura limpia lista para `v1.0.0`.
- **Riesgos mitigados:** Fallos de carga FFI en binarios instalados fuera de la raiz del repositorio y rechazo de tiendas por bundle ID `com.example.*`.
