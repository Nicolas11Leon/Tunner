# ADR 0009: Calibración Dinámica de Afinación de Concierto A4 y Arquitectura de Persistencia Local Offline Atómica

---

## Estado
**Aprobado (Approved)**

## Fecha
2026-10-26

## Contexto y Planteamiento del Problema
1. **Calibración de Afinación:** Históricamente, el código de Tunner asumía la constante $A_4 = 440.0\text{ Hz}$ hardcodeada en el método `NoteEntity.fromFrequency()`. Para músicos clásicos, orquestas europeas (442–444 Hz) e intérpretes de música antigua (415 Hz), esta limitación impedía el uso profesional del afinador.
2. **Persistencia Local:** Hasta la fecha, los temas personalizados creados en el editor HEX, el historial de reportes pedagógicos de sesiones y la lista de grabaciones residían exclusivamente en la memoria RAM del `TunerViewModel`. Al reiniciar la aplicación, estos datos se perdían.
3. **Restricción de No-Dependencia y Robustez en Tests:** La inclusión de paquetes como `shared_preferences` o `sqflite` con inicializaciones de canal nativo prematuras puede quebrar los tests unitarios en la máquina virtual de Dart (tal como se experimentó con `audioplayers` y `record`). Se requería una solución que fuera 100% testeable en Dart puro sin dependencias de plugins de plataforma durante pruebas unitarias.

---

## Decisión Arquitectónica

1. **Parametrización Matemática de Concierto:**
   - Se actualiza la signatura de `NoteEntity.fromFrequency(double freq, {double a4Ref = 440.0})` para hacer explícita la frecuencia de referencia.
   - Se incorpora a `TunerViewModel` la propiedad `double referencePitch` (restringida a $[415.0, 466.0]\text{ Hz}$, con valor por defecto $440.0$).
   - Todos los cálculos de cents, afinador de aguja y afinador estroboscópico se computan dinámicamente con base en esta referencia.

2. **Capa de Dominio de Persistencia (`lib/features/persistence/domain/`):**
   - Se define la entidad inmutable `AppUserSettingsEntity` que consolida las configuraciones del usuario, temas custom, historial de práctica y grabaciones.
   - Se define el contrato formal `ILocalPersistenceService` con métodos asíncronos `Future<AppUserSettingsEntity> loadSettings()` y `Future<void> saveSettings(AppUserSettingsEntity settings)`.

3. **Capa de Infraestructura (`lib/features/persistence/data/`):**
   - Se implementa `JsonLocalPersistenceService` utilizando el sistema de archivos local (`dart:io` `File`).
   - Se utiliza una estrategia de escritura atómica mediante archivo temporal (`.tmp`) y renombrado atómico (`renameSync` / `rename`) para garantizar resistencia ante cortes de energía o cierres intempestivos.
   - Para permitir tests unitarios puros y deterministas, el servicio recibe un proveedor de ruta opcional `Future<String> Function()? documentsPathProvider`. En tests de Dart VM se inyecta un directorio en memoria o temporal, evitando llamar a canales de plataforma.

4. **Interfaz de Usuario:**
   - Se crea el componente `ConcertPitchSelectorModal` con pastillas rápidas para $432\text{ Hz}$, $440\text{ Hz}$, $442\text{ Hz}$ y $444\text{ Hz}$ junto a un control deslizante de ajuste fino.
   - Se añade un chip interactivo en el `TunerScreen` que muestra la afinación actual y permite abrir el modal en 1 toque.

---

## Consecuencias

### Positivas
- **Flexibilidad Acústica Total:** Soporte universal para orquestas sinfónicas, ensambles de metales, música de cámara y música histórica.
- **Continuidad de Usuario:** Los temas diseñados, las sesiones de práctica y las grabaciones se mantienen intactos entre reinicios de la aplicación.
- **Resistencia y Testabilidad:** El subsistema de persistencia no depende de plugins de Flutter en tiempo de test unitario.
- **Offline-First:** Cero requerimientos de conexión de red, nubes externas o bases de datos remotas.

### Negativas / Mitigaciones
- El archivo de configuración puede crecer si el historial de práctica acumula cientos de sesiones.  
  *Mitigación:* Se implementa un límite canónico de las últimas 50 sesiones en el historial serializado para mantener tiempos de I/O en sub-milisegundos.
