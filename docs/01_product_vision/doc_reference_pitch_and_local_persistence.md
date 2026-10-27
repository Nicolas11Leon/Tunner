# Especificación Técnica: Calibración del Tono de Referencia A4 & Subsistema de Persistencia Local Offline

---

## Metadatos del Documento

- **ID del Documento:** `DOC-PITCH-PERSIST-2026-001`
- **Título Oficial:** `Especificación de Calibración de Afinación de Concierto A4 y Motor de Persistencia Local Offline Atómica`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-10-26`
- **Última Modificación:** `2026-10-26`
- **Fase Asociada:** `Fase 4 (Estudio de Práctica & Integración Universal)`
- **Autor / Revisor Principal:** `Equipo de Ingeniería Acústica & Antigravity Lead Architect`

---

## 1. Resumen Ejecutivo (Executive Summary)

El presente documento formaliza la arquitectura matemática y el subsistema de infraestructura para resolver dos necesidades críticas de precisión acústica y experiencia de usuario en **Tunner**:
1. **Calibración Dinámica de Concierto ($A_4$):** Desacoplar el valor estático de $440.0\text{ Hz}$ para soportar afinaciones sinfónicas europeas ($442\text{ Hz}$ y $444\text{ Hz}$), afinación científica/Verdi ($432\text{ Hz}$) y afinación histórica barroca ($415\text{ Hz}$), calculando la desviación en cents en tiempo real contra la referencia seleccionada.
2. **Persistencia Local Offline Atómica:** Almacenar de forma no volátil y 100% desconectada de la red (local-first) las preferencias del usuario, la calibración de concierto, la paleta cromática activa, los temas personalizados creados en el editor HEX y el historial de sesiones de práctica pedagógica y grabaciones.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Tradicionalmente, las aplicaciones comerciales de afinador asumen de forma inmutable $A_4 = 440.0\text{ Hz}$. Sin embargo:
- Las orquestas sinfónicas en Austria, Alemania y Suiza afinan estándar a $442.0\text{ Hz}$ o $443.0\text{ Hz}$ para mayor brillo en maderas y cuerdas.
- Ensembles de música antigua y barroca interpretan con afinaciones de $A_4 = 415.0\text{ Hz}$ (un semitono abajo respecto a 440 Hz) o $430.0\text{ Hz}$ (clásico temprano).
- Al cerrar la aplicación, perder los temas diseñados por el estudiante o las calificaciones acumuladas degrada el valor pedagógico continuo.

### 2.2 Fundamento Teórico y Fórmulas Matemáticas

#### 2.2.1 Número de Nota MIDI Fraccionario con Referencia Parametrizable
Sea $f \in \mathbb{R}^+$ la frecuencia fundamental detectada por el algoritmo YIN en Hz, y sea $f_{\text{ref}} \in [415.0, 466.0]$ la frecuencia de concierto asignada al tono La4 ($A_4$). El número de nota MIDI continuo $m(f, f_{\text{ref}})$ viene dado por:

$$m(f, f_{\text{ref}}) = 12 \cdot \log_2\left(\frac{f}{f_{\text{ref}}}\right) + 69$$

#### 2.2.2 Desviación en Cents
La nota nominal más cercana $M \in \mathbb{Z}$ es el entero más próximo:

$$M = \text{round}(m(f, f_{\text{ref}}))$$

La desviación en cents $c(f, f_{\text{ref}})$ representa la diferencia respecto al temperamento igual:

$$c(f, f_{\text{ref}}) = (m(f, f_{\text{ref}}) - M) \cdot 100$$

Con rango acotado $c \in [-50.0, +50.0]\text{ cents}$.

#### 2.2.3 Escritura Atómica No Volátil (Atomic File Storage)
Para garantizar integridad sin riesgo de corrupción por cortes de energía o cierres forzados, la serialización JSON se ejecuta escribiendo primero en un archivo temporal `tunner_data.json.tmp` seguido de una operación de renombrado atómico (`renameSync` / `rename`) garantizada a nivel del sistema de archivos POSIX.

---

## 3. Especificación Funcional Detallada

### 3.1 Requerimientos Funcionales
- **REQ-01 (Rango de Calibración):** El usuario podrá configurar $A_4$ en un rango continuo de $415.0\text{ Hz}$ a $466.0\text{ Hz}$ con precisión de décimas de hercio ($0.1\text{ Hz}$), disponiendo de accesos directos (*presets*) para $432\text{ Hz}$, $440\text{ Hz}$, $442\text{ Hz}$ y $444\text{ Hz}$.
- **REQ-02 (Recálculo Reactivo Inmediato):** Toda nota detectada por el micrófono recalculará su nombre de nota y su aguja estroboscópica/de cents de acuerdo con el $A_4$ activo sin reiniciar el Isolate de audio.
- **REQ-03 (Persistencia de Temas y Configuraciones):** Las paletas personalizadas creadas en el editor HEX y la selección de tema activo deben guardarse automáticamente en disco y restaurarse al iniciar.
- **REQ-04 (Persistencia de Historial de Práctica):** Los reportes pedagógicos de sesiones completadas y las rutas de grabaciones deben preservarse entre ciclos de vida de la aplicación.
- **REQ-05 (Zero Busy-Waiting & Zero Cloud):** La persistencia debe operar de manera 100% asíncrona, en disco local, sin bloquear el hilo principal de la interfaz de usuario ni depender de APIs externas.

---

## 4. Diseño Técnico y Arquitectura de la Solución

```
lib/
├── features/
│   ├── persistence/
│   │   ├── domain/
│   │   │   ├── app_user_settings_entity.dart
│   │   │   └── i_local_persistence_service.dart
│   │   └── data/
│   │       └── json_local_persistence_service.dart
│   ├── tuner/
│   │   ├── domain/
│   │   │   └── note_entity.dart  <-- (fromFrequency ahora admite a4Ref)
│   │   └── presentation/
│   │       └── concert_pitch_selector_modal.dart
```

### 4.1 Capa de Dominio (Domain Layer)
- `NoteEntity.fromFrequency(double freq, {double a4Ref = 440.0})`: Refactorización para admitir la frecuencia base de referencia de concierto.
- `AppUserSettingsEntity`: Objeto de valor inmutable que encapsula:
  - `referencePitch` (double)
  - `selectedThemeId` (String)
  - `selectedInstrumentId` (String)
  - `bpm` (int)
  - `customPalettes` (List<TunnerThemePalette>)
  - `sessionHistory` (List<PracticeReportEntity>)
  - `recordingHistory` (List<PracticeRecordingEntity>)
- `ILocalPersistenceService`: Interfaz pura Dart que define los contratos `loadSettings()` y `saveSettings(AppUserSettingsEntity settings)`.

### 4.2 Capa de Infraestructura (Data Layer)
- `JsonLocalPersistenceService`: Implementa `ILocalPersistenceService` leyendo y escribiendo en el directorio de documentos provisto por `path_provider` con estrategia de escritura atómica temporal. Inyecta proveedor de ruta abstracto para testabilidad pura en Dart VM sin plugins.

### 4.3 Capa de Presentación (Presentation Layer)
- `ConcertPitchSelectorModal`: Modal accesible desde el afinador para conmutar rápidamente la afinación de concierto ($A_4$).
- Chip interactivo en la cabecera del afinador indicando el tono activo (e.g., `A4 = 440 Hz` o `A4 = 442 Hz`) con toque directo para calibración.
