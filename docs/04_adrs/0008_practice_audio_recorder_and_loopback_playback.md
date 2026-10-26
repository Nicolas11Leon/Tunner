# ADR 0008: Arquitectura de Grabación Local de Práctica y Auto-Escucha (Audio Loopback)

---

## Metadatos del ADR

- **Número:** `0008`
- **Título:** `Implementación de Grabadora de Práctica Local y Reproductor de Auto-Escucha con Audio Loopback`
- **Estado:** `Aprobado`
- **Fecha:** `2026-10-26`
- **Autor / Revisor Principal:** `Nicolas Leon & Antigravity AI`
- **Módulos Afectados:** `lib/features/practice_recorder/`, `lib/features/tuner_viewmodel.dart`, `lib/features/tuner_screen.dart`, `lib/features/practice_evaluator/presentation/practice_report_modal.dart`

---

## 1. Contexto (Context)

La plataforma **Tunner** ofrece analítica visual de afinación ($F_0$ en cents), metrónomo compensado de alta precisión y evaluación cuantitativa en 4 dimensiones. Sin embargo, para que un estudiante de música en conservatorio logre un desarrollo técnico completo, la retroalimentación visual debe complementarse con la auto-escucha auditiva (*loopback critical listening*). Durante la ejecución, el cerebro del músico está sobrecargado procesando la digitación y la lectura, lo cual distorsiona la auto-percepción de la afinación y el ritmo.

Se requiere una funcionalidad en la que el usuario pueda grabar sus tomas de estudio de forma local, offline y con calidad de audio cristalina, reproduciéndolas inmediatamente después para comparar lo que escuchó el sistema con lo que perciben sus oídos.

---

## 2. Decisión Arquitectónica (Decision)

1. **Desacoplamiento Estricto con Clean Architecture (Feature-First):**  
   Se crea el módulo `lib/features/practice_recorder/` con:
   - Capa de Dominio pura: `practice_recording_entity.dart`, `i_practice_recorder_service.dart`, `i_audio_playback_service.dart`. Cero dependencias de Flutter UI ni plugins externos en las entidades.
   - Capa de Infraestructura / Datos: `practice_recorder_service.dart` implementando la captura con el paquete `record` (mismo motor de captura optimizado ya validado en el detector de tono) y `audio_playback_service.dart` implementando la reproducción con `audioplayers`.
   - Inversión de Dependencias (DIP): `TunerViewModel` recibe `IPracticeRecorderService` e `IAudioPlaybackService` en su constructor, facilitando mocking y pruebas unitarias deterministas sin tocar hardware real.

2. **Formato de Archivo Local y Muestreo de Onda:**  
   - Se utiliza codificación AAC LC / M4A (o WAV PCM según plataforma), almacenada en el directorio local de la aplicación provisto por `path_provider`.
   - Se extraen muestras de amplitud a intervalos regulares ($100\text{ ms}$) durante la grabación para construir la curva normalizada de la forma de onda (`waveformPeaks`), permitiendo un scrubber interactivo ultra fluido en la UI.

3. **Reproductor Integrado y Multi-Velocidad:**  
   - El reproductor de auto-escucha soporta velocidades variables ($0.75\times$, $1.0\times$, $1.25\times$), vital para que el instrumentista audite pasajes rápidos y articulaciones complejas.
   - La grabación se enlaza opcionalmente con el reporte analítico (`PracticeReportModal`), unificando la métrica visual con el audio físico.

---

## 3. Consecuencias (Consequences)

### 3.1 Consecuencias Positivas
- **Alineación 100% con AGENTS.md:** Monolito modular, 100% offline, cero llamadas de red y consumo determinista de memoria.
- **Testabilidad Exhaustiva:** Tanto el servicio de grabación como el de reproducción son interfaces abstractas, permitiendo probar `TunerViewModel` al 100% sin inicializar dispositivos de audio del sistema operativo.
- **Experiencia de Usuario Inmersiva:** El alumno puede alternar entre tocar, grabar y escuchar en un solo clic, aumentando la retención pedagógica.

### 3.2 Riesgos Mitigados y Compromisos
- **Espacio en Disco:** El uso de codificación comprimida AAC a 128 kbps produce archivos de apenas $\approx 1\text{ MB}$ por minuto, evitando llenar el almacenamiento del dispositivo.
- **Permisos del Sistema Operativo:** Se reutiliza el flujo de permisos de micrófono ya gestionado en la app, evitando fricciones de permisos duplicadas.
