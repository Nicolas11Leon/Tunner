# Guía de Contribución para Tunner (Contributing Guide)

¡Bienvenido a la comunidad de **Tunner**!

Tunner es una estación de trabajo acústica, de síntesis procedural, notación musical y pedagogía de código abierto diseñada para transformar y democratizar la educación y la producción musical con precisión de conservatorio.

Tanto si eres **músico, educador, ingeniero de DSP, desarrollador Flutter, especialista en C++/Rust o diseñador de experiencias**, tu perspectiva y talento son fundamentales para construir el software musical libre más avanzado y riguroso del mundo.

---

## 1. Filosofía y Principios Innegociables

Antes de escribir tu primera línea de código, te pedimos familiarizarte con nuestra constitución técnica descrita en [AGENTS.md](AGENTS.md). En Tunner nos regimos por principios de ingeniería estrictos:

1. **100% Offline-First:**  
   Todo el procesamiento de señales, síntesis, afinación, edición de partituras y analítica pedagógica debe ejecutarse **localmente en el dispositivo del usuario**. Prohibida cualquier dependencia de red, telemetría o servicios en la nube.
2. **Clean Architecture Disciplinada:**  
   * **Capa de Dominio (`lib/*/domain/`):** Dart puro. Cero dependencias de Flutter, widgets, paquetes externos de UI o plugins de plataforma. Alberga entidades matemáticas, modelos musicales y algoritmos puros.
   * **Capa de Datos e Infraestructura (`lib/*/data/`):** Implementaciones concretas, decodificación de archivos binarios (SF2, MIDI, MusicXML), persistencia atómica y streams de micrófono.
   * **Capa de Presentación (`lib/*/presentation/`):** Widgets reactivos de Flutter, ViewModels, CustomPainters y layouts adaptativos. La UI jamás accede al hardware ni a los códecs directamente.
3. **Disciplina de Audio y Hardware:**  
   * **Cero bucles de espera activa (*Zero Busy-Waiting*):** Ningún hilo o Isolate puede monopolizar la CPU en bucles vacíos. Debe cederse el tiempo al sistema operativo.
   * **Latencia Sub-10ms:** Las cadenas de DSP y relojes de transporte deben minimizar el tamaño de buffers para una respuesta instantánea entre el oído y la pantalla.
4. **Calidad y Verificación Rigurosa:**  
   * Todo nuevo desarrollo debe acompañarse de pruebas unitarias o de integración.
   * La suite de pruebas debe pasar al 100% (`flutter test`).
   * Cero errores y cero advertencias en el análisis estático (`flutter analyze`).

---

## 2. ¿Cómo Puedes Colaborar?

Buscamos diversos perfiles interdisciplinarios:

### 2.1 Músicos, Compositores y Docentes
* Proponer o calibrar nuevos **temperamentos históricos** y sistemas de afinación microtonal (Maqamat, Slendro/Pelog, sistemas de entonación justa).
* Crear partituras y ejercicios pedagógicos de dominio público para el catálogo de estudio.
* Validar la respuesta tímbrica y afinación en instrumentos orquestales, folclóricos y étnicos reales.
* Proponer nuevas metodologías de entrenamiento auditivo y evaluación de ritmo.

### 2.2 Ingenieros de Audio y DSP
* Proponer y refinar algoritmos de detección de tono (variantes avanzadas de YIN, SWIPE, MPM polifónico).
* Desarrollar y optimizar filtros acústicos digitales (filtros comb, notch adaptativos para micrófonos, filtros IIR/FIR).
* Expandir el motor de síntesis de tablas de ondas (SoundFont SF2/SFZ) y modelado físico de instrumentos.

### 2.3 Desarrolladores Flutter y Dart
* Optimizar los `CustomPainter` de la notación musical SMuFL para mantener 60/120 FPS sin caídas de cuadros.
* Mejorar la accesibilidad, lectores de pantalla y navegación por teclado en escritorio.
* Implementar nuevos componentes modulares para el Rack de Estudio y la Consola Multitarea.
* Añadir soporte para nuevas plataformas o empaquetado nativo (Flatpak, AppImage, APK, macOS DMG).

### 2.4 Ingenieros de Sistemas (C++, Rust y `dart:ffi`)
* Ayudar en el diseño del futuro motor DSP nativo compilado mediante `dart:ffi` para procesamiento por bloques de ultra baja latencia ($\le 3\text{ ms}$).
* Optimizaciones SIMD para cálculo vectorial en transformadas de Fourier y autocorrelación.

### 2.5 Diseñadores, Traductores y Documentadores
* Internacionalización (i18n): Traducir la interfaz a más idiomas (inglés, francés, alemán, japonés, portugués, etc.).
* Redactar guías de estudio acústico, manuales interactivos y tutoriales para usuarios noveles.

---

## 3. Entorno de Desarrollo y Puesta en Marcha

### Requisitos
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (Canal estable `^3.11.5` o superior).
* [Dart SDK](https://dart.dev/get-dart) incluido con Flutter.
* Git.

### Configuración Inicial
```bash
# 1. Haz un fork del repositorio en GitHub y clónalo localmente
git clone https://github.com/TU_USUARIO/Tunner.git
cd Tunner

# 2. Configura el repositorio original como upstream
git remote add upstream https://github.com/Nicolas11Leon/Tunner.git

# 3. Descarga las dependencias del proyecto
flutter pub get

# 4. Verifica el estado del código con el linter oficial
flutter analyze

# 5. Ejecuta la suite de pruebas automatizadas
flutter test
```

---

## 4. Flujo Canónico de Trabajo (Git & Pull Requests)

1. **Crea una rama para tu contribución:**
   ```bash
   git checkout -b feature/nombre-descriptivo
   # o para corrección de errores:
   git checkout -b fix/descripcion-del-bug
   ```
2. **Desarrolla siguiendo Clean Architecture:**
   * Las reglas de negocio van en `lib/features/<modulo>/domain/`.
   * Los accesos I/O van en `lib/features/<modulo>/data/`.
   * Los widgets y controladores van en `lib/features/<modulo>/presentation/`.
3. **Escribe pruebas unitarias:**
   * Cada nueva entidad o caso de uso de dominio debe tener su archivo correspondiente en `test/features/<modulo>/`.
4. **Verifica antes de hacer commit:**
   ```bash
   flutter analyze   # Debe reportar 0 issues
   flutter test      # Todas las pruebas deben pasar
   ```
5. **Realiza commits atómicos y claros siguiendo Conventional Commits:**
   * `feat: add Kirnberger II temperament calculation`
   * `fix: prevent divide by zero in centroid calculation for silent audio`
   * `docs: clarify buffer size impact on MPM algorithm`
   * `test: add unit tests for SoundFont sample looping`
6. **Envía tu Pull Request:**
   * Describe de manera concisa el problema que resuelve y las decisiones técnicas tomadas.
   * Vincula el issue o caso de uso correspondiente.
   * Nos aseguraremos de revisar tu propuesta con rigor técnico y entusiasmo constructivo.

---

## 5. Ideas para Empezar ("Good First Issues")

¿Quieres empezar pero no sabes por dónde? Aquí tienes algunas ideas inmediatas y bienvenidas:

* [ ] **Añadir nuevos temperamentos históricos:** Implementar nuevos sistemas (ej. Werckmeister IV, Kirnberger I o temperamento Neidhardt) en `lib/features/tuner/domain/temperaments.dart`.
* [ ] **Ampliación de presets de instrumentos:** Añadir más instrumentos étnicos y tradicionales en `UniversalInstrumentCatalog` respetando la taxonomía Hornbostel-Sachs.
* [ ] **Mejoras de accesibilidad visual:** Agregar temas de alto contraste y compatibilidad con modos monocromáticos para daltonismo en `TunnerThemePalette`.
* [ ] **Internacionalización (i18n):** Modularizar las cadenas de texto de las pantallas en archivos `arb` para soporte multilingüe.
* [ ] **Benchmarks de rendimiento:** Escribir benchmarks en Dart para medir los nanosegundos por muestra consumidos por los algoritmos MPM y NSDF.

---

## 6. Código de Conducta y Respeto Mutuo

En el proyecto Tunner creemos en una colaboración basada en:
* **Rigor científico y honestidad intelectual.**
* **Respeto, empatía e inclusión** hacia personas de todos los niveles de experiencia, orígenes y disciplinas (tanto músicos sin formación en código como programadores sin formación musical).
* **Crítica constructiva centrada en el código y la arquitectura**, nunca en las personas.

---

## 7. Contacto y Comunicación

Para preguntas técnicas, propuestas de diseño o dudas sobre la arquitectura:
* **Creador y Arquitecto Principal:** Nicolás León ([@Nicolas11Leon](https://github.com/Nicolas11Leon)).
* **Issues de GitHub:** Utiliza los templates de Issues en el repositorio para reportar bugs o debatir nuevas funcionalidades.

¡Gracias por ser parte del futuro del software musical libre!
