# ADR 0056: Arquitectura de Puertos de Hardware, Permisos y Arbitraje de Senales (PortPermissionBroker)

## Estado
Aprobado (Approved) - 2026-11-11

## Contexto
Tunner integra múltiples herramientas concurrentes que interactúan con transductores físicos del dispositivo (micrófono, altavoces, auriculares, interfaces USB y controladores MIDI). Esta multiplicidad de actores genera dos problemas arquitectónicos críticos:
1. **Riesgo de Bucle Acústico (Feedback / Acople):** Si un módulo reproduce sonido en tiempo real mientras el micrófono está abierto en los altavoces del dispositivo, se produce realimentación acústica que ensordece al usuario y falsea la detección de tono.
2. **Degeneración del Tono por Filtros Telefónicos del OS:** La captura estándar de micrófono aplica cancelación de eco y supresión de ruido diseñadas para telefonía humana, lo que destruye los sobretonos armónicos $H_1\dots H_8$ de instrumentos musicales.
3. **Contienda en el DAC de Salida:** Múltiples generadores (metrónomo, sintetizador SoundFont SF2, dron armónico y reproductor de práctica) pueden colisionar si no existe un árbitro central con limitador de seguridad a $0\text{ dBFS}$.

## Decision
1. **Creación de la Entidad de Dominio `PortPermissionBroker`:**
   - Ubicada en `lib/features/modular_rack/domain/port_permission_broker.dart`.
   - Modela de forma pura las reglas de autorización para:
     - Permisos de lectura compartida (*Broadcast Read*) para streams PCM y eventos de tono.
     - Permisos condicionales de emisión (*Safe Output Authorization*): exige que haya auriculares o interfaces externas conectadas para habilitar el retorno de monitoreo en vivo.
     - Modo de silencio exclusivo durante la calibración de piso de ruido.
2. **Definición de Modelos de Transductores (`HardwareAudioEndpoint`):**
   - Ubicada en `lib/features/tuner/domain/hardware_audio_endpoint.dart`.
   - Modela puertos de entrada y salida con tipado estricto (`builtInMic`, `usbAudioInterface`, `wiredHeadphones`, etc.) y banderas de soporte para captura sin procesar (`supportsRawCapture`).
3. **Políticas de Bypass DSP en la Capa de Infraestructura:**
   - En Android, configurar el servicio de captura con `AudioSource.UNPROCESSED` (o `VOICE_RECOGNITION` como fallback compatible).
   - En iOS/macOS, solicitar `AVAudioSessionModeMeasurement` para apagar el ecualizador y compresor del sistema operativo.
4. **Integración con el Bus Modular `SignalBus`:**
   - Cada enlace entre puertos de módulos pasa por la validación de `PortPermissionBroker.canAuthorizeConnection()`, rechazando enlaces que violen las políticas de seguridad acústica.

## Consecuencias

### Positivas
- **Fidelidad Acústica Inalterada:** La captura en modo crudo preserva los armónicos $H_1\dots H_8$ y los micro-ataques instrumentales.
- **Seguridad Auditiva Garantizada:** Cero riesgo de retroalimentación acústica destructiva por altavoces.
- **Arquitectura Limpia y Desacoplada:** El `PortPermissionBroker` opera en Dart puro sin acoplamiento a Flutter.

### Negativas / Mitigaciones
- **Dispositivos antiguos sin soporte de `UNPROCESSED`:**
  *Mitigación:* Se implementa un fallback automático hacia `AudioSource.MIC` estándar cuando la plataforma no soporte el modo no procesado.
