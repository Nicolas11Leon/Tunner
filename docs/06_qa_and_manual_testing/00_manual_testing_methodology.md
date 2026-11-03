# Metodología Canónica de Pruebas Manuales y Auditoría en Vivo: Tunner

---

## Metadatos del Documento

- **ID del Documento:** `DOC-QA-MANUAL-2026-001`
- **Título Oficial:** `Metodología Canónica de Pruebas Manuales, Protocolo de Validación Acústica y Bitácora de Campo`
- **Estado:** `Approved`
- **Fecha de Creación:** `2026-11-02`
- **Última Modificación:** `2026-11-02`
- **Fase Asociada:** `Global (Aseguramiento de Calidad y Ergonomía)`
- **Autor / Revisor Principal:** `Equipo de Arquitectura e Ingeniería de Tunner`

---

## 1. Resumen Ejecutivo (Executive Summary)

El presente documento establece el marco formal para la ejecución de pruebas manuales, verificación de campo y registro de bitácora de la plataforma **Tunner**. A diferencia de los tests automatizados que evalúan condiciones matemáticas aisladas, las pruebas manuales evalúan la coherencia audio-visual en tiempo real, la ergonomía táctil en pantalla, la respuesta en transitorios de instrumentos acústicos reales y la usabilidad pedagógica en dispositivos físicos.

---

## 2. Taxonomía y Estados de Validación

Para cada paso de prueba manual registrado en los casos de uso y en la bitácora maestra, se utilizará la siguiente convención de estados:

| Símbolo | Estado | Definición Operativa |
| :---: | :--- | :--- |
| `[ ]` | **Pendiente (To-Do)** | La prueba aún no ha sido ejecutada en el ciclo actual de validación. |
| `[x]` | **Aprobado (Pass)** | La funcionalidad cumple al 100% el resultado esperado visual, auditivo y temporal. |
| `[!]` | **Observación / Defecto** | La funcionalidad opera pero presenta anomalías visuales, latencia perceptible o desajuste acústico. Requiere nota en bitácora. |
| `[-]` | **Bloqueado (Blocked)** | La prueba no puede ejecutarse por ausencia de hardware periférico (ej. micrófono USB ausente, archivo externo inexistente). |

---

## 3. Protocolos de Verificación de Campo

### 3.1 Protocolo Acústico (Pruebas de Micrófono y Tono)
1. **Entorno de Silencio:** Iniciar las pruebas en un ambiente con ruido de fondo moderado o bajo. Observar el medidor VU y verificar que el Noise Gate no active notas fantasma.
2. **Prueba de Transitorios con Instrumento / Voz:**
   - Emitir notas staccato y legato.
   - Cantar o tocar glissandos lentos para validar el rastreo de tono continuo sin saltos erráticos de octava.
   - Probar en tesituras extremas: graves ($E_2 \approx 82.4\text{ Hz}$ de guitarra o $C_2 \approx 65.4\text{ Hz}$ de violonchelo) y agudos ($C_6 \approx 1046.5\text{ Hz}$ de flauta/soprano).
3. **Validación de Tono de Referencia:** Escuchar los timbres sintetizados (Senoidal, Clarinete, Cello, Flauta) para corroborar la ausencia de clics en bucles (*loop pops*) y distorsión armónica indeseada.

### 3.2 Protocolo de Rendimiento Visual (Rendering y Ergonomía)
1. **Fluidez de Aguja y Estroboscopio:**
   - La aguja del afinador analógico y las bandas estroboscópicas deben moverse con suavidad a 60 FPS o 120 FPS sin parpadeos (*jank* o *frame drops*).
2. **Respuesta Táctil:**
   - Los controles (tap tempo, play/pause de metrónomo, sliders de calibración) deben responder instantáneamente al toque sin demoras táctiles perceptibles ($< 50\text{ ms}$).

---

## 4. Estructura Estándar de la Sección de Pruebas Manuales en Casos de Uso

Cada documento dentro de `docs/02_use_cases/` incluye formalmente la sección:

```markdown
## N. Guía de Pruebas Manuales y Bitácora de Validación

### N.1 Precondiciones y Preparación del Entorno
- Entorno físico, instrumentos o periféricos requeridos.
- Estado inicial de la aplicación.

### N.2 Procedimiento de Ejecución Paso a Paso
1. Paso detallado con acción concreta en la pantalla o en el instrumento.
2. Acción esperada del usuario.

### N.3 Checklist de Validación Sensorial (Resultado Esperado)
- [ ] Criterio visual 1.
- [ ] Criterio auditivo 2.
- [ ] Criterio de estabilidad / fluidez 3.

### N.4 Registro de Bitácora de Ejecución
| Fecha | Tester / Músico | Dispositivo / SO | Resultado | Observaciones / Aspectos por Pulir |
| :---: | :---: | :---: | :---: | :--- |
| YYYY-MM-DD | Nombre | Modelo (ej. Android 14) | Pass/Fail | Notas de campo |
```

---

## 5. Procedimiento ante Hallazgos o Desviaciones

Cuando durante una prueba manual se identifique una discrepancia o mejora necesaria:
1. Marcar el ítem como `[!]` en el checklist del caso de uso correspondiente.
2. Registrar la fila en la tabla de bitácora detallando el comportamiento anómalo.
3. Notificar o abrir el ticket correspondiente para planificar la corrección técnica bajo la disciplina de [AGENTS.md](../../AGENTS.md).
