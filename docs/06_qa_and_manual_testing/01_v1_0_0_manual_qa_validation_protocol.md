# Protocolo Oficial de Pruebas Manuales de Campo y Aceptación de Usuario: Tunner v1.0.0

---

## Metadatos del Protocolo

- **ID del Documento:** `QA-MANUAL-PROTOCOL-V1.0.0`
- **Título Oficial:** `Protocolo de Validación Manual de Campo en Hardware Real para Aprobación de Release v1.0.0`
- **Fase del Proyecto:** `Pre-Release Final Gate / Release Candidate v1.0.0`
- **Evaluador Responsable:** `@Nicolas11Leon (Mantenedor Principal)`
- **Rama Evaluada:** `qa` (Commit base `0ff8697` y posteriores)
- **Estado de Pruebas Automatizadas:** `1,154 / 1,154 pruebas en verde (100% pass)`
- **Analizador Estático:** `0 advertencias / 0 errores`

---

## 1. Objetivo y Metodología

El presente protocolo define la **batería de 10 escenarios de prueba manual de campo** que el Mantenedor Principal debe ejecutar sobre hardware real (dispositivo físico Linux, macOS, Android o Windows) antes de efectuar el merge soberano a la rama `main` y publicar la etiqueta oficial `v1.0.0`.

Cada escenario evalúa aspectos que escapan a los entornos de emulación y pruebas automatizadas (sensibilidad acústica del micrófono físico, coherencia táctil y auditiva, ausencia de sobrecalentamiento/CPU spikes, fluidez de 60/120 FPS y fidelidad del timbre acústico).

---

## 2. Preparación del Entorno de Prueba

Ejecutar en la terminal de la máquina física:
```bash
# 1. Asegurar sincronizacion con la rama qa
git checkout qa
git pull origin qa

# 2. Descargar dependencias
flutter pub get

# 3. Lanzar la aplicacion en el dispositivo fisico deseado:
flutter run -d linux      # Para Linux Desktop
# o:
flutter run -d macos      # Para macOS
# o:
flutter run -d android    # Para telefono Android conectado por USB
# o:
flutter run -d windows    # Para Windows
```

---

## 3. Matriz de los 10 Escenarios de Prueba Manual de Campo

### Escenario 1: Captura Acústica de Micrófono, Permisos y Calibración A4
- **Objetivo:** Verificar que el sistema solicita adecuadamente los permisos del sistema operativo y procesa el flujo PCM sin cuelgues ni saturación.
- **Pasos:**
  1. Abrir la aplicación por primera vez (o tras revocar permisos de micrófono).
  2. Verificar que se despliega la solicitud de permiso del sistema con la descripción oficial ("Tunner Studio requiere acceso al microfono...").
  3. Aceptar el permiso y dirigirse a la barra de herramientas superior.
  4. Modificar la frecuencia de concierto $A_4$ de 440 Hz a 442 Hz y luego a 432 Hz.
- **Criterio de Aceptación:**
  - El micrófono captura la señal en vivo sin crashear.
  - El cambio de $A_4$ recalibra instantáneamente la escala de frecuencias en todos los módulos de la aplicación.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 2: Afinador Estroboscópico Virtual y Estimación de Tono MPM
- **Objetivo:** Validar la precisión de respuesta del estimador McLeod Pitch Method (MPM) y la aguja de cents en tiempo real.
- **Pasos:**
  1. Emitir una nota acústica estable (mediante voz o instrumento físico, ej. La 440 Hz o Mi 329.6 Hz).
  2. Observar la detección de la nota en el visor central: nombre en español e inglés (La4 / A4), frecuencia en Hz y desviación en cents ($\pm \text{cents}$).
  3. Tocar una nota grave (ej. Mi 82.4 Hz o Re 73.4 Hz de una guitarra/bajo).
- **Criterio de Aceptación:**
  - Cero saltos erráticos de octava en notas sostenidas.
  - La aguja reacciona en menos de 10 ms con animación fluida a 60 FPS.
  - La visualización estroboscópica se congela cuando la desviación es exactamente $0.0\text{ cents}$.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 3: Reloj Maestro de Estudio, Metrónomo Acústico y Tap Tempo
- **Objetivo:** Verificar la precisión rítmica sin deriva temporal ni bucles de espera activa (zero busy-waiting).
- **Pasos:**
  1. Activar el metrónomo desde la consola de transporte presionando la barra espaciadora (`Espacio`) o el botón Play.
  2. Cambiar el compás de 4/4 a 3/4 y 6/8.
  3. Modificar el tempo de 120 BPM a 180 BPM en reproducción.
  4. Presionar rítmicamente el botón **TAP** (o presionar la tecla `T`) 4 veces a un tempo deseado.
- **Criterio de Aceptación:**
  - El primer clic se emite instantáneamente en $t=0$ con acento claro.
  - El clic en 6/8 respeta los acentos de compás compuesto.
  - El cálculo de Tap Tempo responde inmediatamente desde 20 hasta 300 BPM.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 4: Transcripción en Vivo de Micrófono a Pentagrama SMuFL
- **Objetivo:** Confirmar la conversión de audio acústico en figuras musicales vectoriales sobre el pentagrama.
- **Pasos:**
  1. Ingresar al módulo de Transcripción / Partitura.
  2. Iniciar la grabación de transcripción.
  3. Cantar o tocar una melodía sencilla de 4 notas (ej. Do - Re - Mi - Fa en negras).
  4. Detener la transcripción.
- **Criterio de Aceptación:**
  - Las notas aparecen ordenadas en sus respectivas alturas y figuras rítmicas cuantizadas.
  - El renderizado vectorial SMuFL dibuja cabezas, plicas y líneas adicionales nítidas sin artefactos gráficos.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 5: Sintetizador SoundFont SF2 y Polifonía Táctil
- **Objetivo:** Validar la reproducción audible de instrumentos virtuales en memoria sin dependencias de red.
- **Pasos:**
  1. Abrir el módulo de Sintetizador / Teclado Virtual.
  2. Tocar un acorde de 3 notas simultáneas (ej. Do Mayor: C4 - E4 - G4) en la pantalla o mediante el teclado físico.
  3. Seleccionar diferentes presets de instrumentos (Piano acústico, Cuerdas, Flauta).
  4. Probar notas largas y notas staccato rápidas.
- **Criterio de Aceptación:**
  - Las 3 notas del acorde suenan limpias simultáneamente (sin corte de voces en el PolyphonicVoicePool).
  - La envolvente ADSR corta el sonido limpiamente al levantar el dedo (sin clicks DC ni cuelgues de buffer).
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 6: Suite Vocal, Auto-Tune TD-PSOLA y Grabación de Toma
- **Objetivo:** Verificar el procesamiento y afinación vocal en tiempo real.
- **Pasos:**
  1. Abrir la Suite Vocal / Auto-Tune.
  2. Grabar una toma vocal de 5 segundos desafinando deliberadamente respecto a una escala (ej. Do Mayor).
  3. Activar el botón de corrección de tono en modo suave y luego en modo rápido (*Hard Tune*).
  4. Reproducir la toma afinada resultante.
- **Criterio de Aceptación:**
  - El archivo resultante reproduce la voz corregida con los formantes preservados y sin artefactos metálicos extremos.
  - El gráfico de tono muestra la curva de pitch original y la cuantizada sobre la escala.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 7: Consola DJ Virtual, Ecualizador de 3 Bandas y Grabación de Mix
- **Objetivo:** Comprobar la reproducción en paralelo de los Decks A y B, el crossfader y la exportación de audio.
- **Pasos:**
  1. Cargar dos archivos de audio locales en el Deck A y en el Deck B.
  2. Iniciar reproducción en ambos decks.
  3. Mover el Crossfader de izquierda a derecha.
  4. Manipular las perillas de ecualización (Low, Mid, High) del Deck A.
  5. Iniciar la grabación de la mezcla (`REC`), dejar correr 10 segundos y detener la grabación.
- **Criterio de Aceptación:**
  - La mezcla de ambos canales es audible en estéreo.
  - Las perillas cortan y realzan las frecuencias indicadas mediante filtros biquad en tiempo real.
  - El archivo WAV generado en disco contiene el audio real de la mezcla y se reproduce perfectamente.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 8: Patchbay Matricial y Ruteo de Señales
- **Objetivo:** Validar la conexión flexible de módulos de estudio sin fugas de memoria.
- **Pasos:**
  1. Abrir el modal de Enrutamiento Matricial (Patchbay).
  2. Conectar la salida del Sintetizador a la entrada de la Master Console.
  3. Ajustar el fader de ganancia del cable virtual y alternar el botón de Mute.
- **Criterio de Aceptación:**
  - La matriz refleja visualmente la conexión por cable.
  - El audio se silencia al activar Mute y se atenúa al deslizar la ganancia.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 9: Roundtrip de Proyectos `.tunner`, MusicXML, MIDI y Exportación PDF
- **Objetivo:** Garantizar la integridad total de datos y la interoperabilidad estándar de la industria.
- **Pasos:**
  1. Crear un proyecto con una partitura de 2 compases y guardarlo como `Proyecto_Prueba.tunner`.
  2. Exportar la partitura en los formatos: `Partitura.pdf`, `Partitura.musicxml` y `Partitura.mid`.
  3. Cerrar la aplicación por completo y volver a abrirla.
  4. Cargar el archivo `Proyecto_Prueba.tunner` guardado anteriormente.
  5. Abrir el archivo `Partitura.pdf` con un visor externo de PDF del sistema operativo.
- **Criterio de Aceptación:**
  - El proyecto `.tunner` se restaura al 100% con compases, notas y tempo intactos.
  - El PDF exportado dibuja el pentagrama vectorial con tipografía SMuFL nítida y sin cajas negras.
  - El archivo MusicXML y MIDI son válidos y legibles por DAWs y editores externos (MuseScore, Sibelius, Logic Pro).
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

### Escenario 10: Sistema de Diseño Atómico, Atajos DAW y Ergonomía Visual
- **Objetivo:** Verificar la fluidez de interfaz, la conmutación de temas y el comportamiento de atajos de teclado.
- **Pasos:**
  1. Abrir el selector de temas y alternar entre los estilos de interfaz (Pro Studio Dark, Tokyo Cyberpunk, High Contrast).
  2. Utilizar el comando rápido `J` para abrir el navegador instantáneo de tareas de práctica (TTC).
  3. Enfocar un campo de texto (ej. nombre de proyecto) y presionar teclas de atajo como `Espacio` o `T`.
- **Criterio de Aceptación:**
  - La interfaz conmuta de tema instantáneamente sin parpadeos ni repintados innecesarios.
  - Al escribir en un campo de texto, los atajos globales se suprimen correctamente para no disparar acciones indeseadas.
  - Cero presencia de emojis en toda la aplicación.
- **Resultado:** `[ ] Aprobado | [ ] Observaciones: _________`

---

## 4. Certificación Final de Release para el Mantenedor

Una vez completados satisfactoriamente los 10 escenarios anteriores:

- [ ] Todos los escenarios completados con estado **Aprobado**.
- [ ] Latencia y consumo de CPU dentro de los parámetros esperados (sub-10ms, < 15% CPU promedio).
- [ ] Bitácora Maestra actualizada con firma de aprobación.
- [ ] Proceder a ejecutar el merge soberano de `qa` hacia `main`:

```bash
git checkout main
git pull origin main
git merge qa --no-ff -m "Release v1.0.0: Consolidated Core Architecture (Phases 1-8)"
git tag -a v1.0.0 -m "Tunner v1.0.0: Consolidated Core DAW & Acoustic Engine"
git push origin main
git push origin v1.0.0
```
