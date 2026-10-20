# Implementation Plan: Pure Sine Tone Reference Generator & Ear Training

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE1-SINE-TONE-SYNTH-2026-004`
- **Título de la Implementación:** `Generador Sintetizado de Tono de Referencia Senoidal Puro con Envolvente Anti-Pop`
- **Fase del Proyecto:** `Fase 1`
- **Estado:** `Aprobado`
- **ADR Relacionado:** `docs/04_adrs/0001_in_process_isolate_clock_and_dsp_pipeline.md`
- **Documento Funcional Base:** `docs/02_use_cases/05_uc_audio_reference_tone.md`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Dotar a la plataforma de una capacidad de salida auditiva inmediata para entrenamiento de oído musical (*Ear Training*):
1. **Síntesis Matemática Local de Ondas Senoidales Puras:** Generar buffers de audio PCM16 en memoria local calculados mediante la fórmula:
   $$x[n] = A[n] \cdot \sin\left(\frac{2\pi f_0 n}{f_s}\right)$$
   con $f_s = 44100\text{ Hz}$ y $16\text{ bits}$.
2. **Envolvente Anti-Pop (Smooth Attack / Release):** Aplicar una rampa de amplitud suave de $10\text{ ms}$ al iniciar y al cortar el sonido, eliminando totalmente los chasquidos acústicos por discontinuidad de fase.
3. **Reproducción de Referencia:** Permitir que al seleccionar una nota (o pulsar un botón de afinación de referencia como $A_4 = 440\text{ Hz}$), el usuario escuche el tono exacto para entrenar su memoria auditiva antes de cantar o soplar.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - **Dominio:** Extender `NoteEntity` con un generador de frecuencia exacta a partir del nombre de la nota musical.
  - **Datos / Infraestructura:** Creación de `lib/data/tone_generator_service.dart` que genere la secuencia de bytes PCM / WAV sintética y la reproduzca localmente sin depender de servidores ni red.
  - **Presentación:** Botón de referencia de afinación acústica en `TunerScreen` e integración con `TunerViewModel`.
- **Excluido (Out-of-Scope):**
  - Carga de bancos de sonido SoundFont SF2 pesados (reservado para la Fase 3).
  - Efectos de modulación de audio (reverb/delay).

---

## 2. Análisis de Dependencias y Tecnologías

- **Dart SDK:** `^3.11.5`.
- **Flutter SDK:** Canal estable.
- **Audio Output:** Generación in-memory de cabecera RIFF/WAV estándar de 44.1 kHz, 16-bit mono.
- **Riesgo Tecnológico:** **Nulo**. No se añaden librerías pesadas ni microservicios. Se calcula matemáticamente el buffer de audio en memoria RAM local en menos de $2\text{ ms}$.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Pure Dart)
- [ ] Incorporar en `NoteEntity` la función matemática `frequencyForNoteName(String noteName, {int octave, double a4Ref})`.
- [ ] Agregar pruebas unitarias en `test/domain/note_entity_test.dart` para verificar la conversión bidireccional entre nombres y frecuencias.

### Paso 2: Capa de Infraestructura / Datos (Servicio de Síntesis PCM)
- [ ] Crear `lib/data/tone_generator_service.dart`:
  - Ensamblador de encabezado canónico WAV RIFF en memoria.
  - Generador de muestras senoidales de 16 bits con rampa lineal de envolvente de 441 muestras ($10\text{ ms}$) al inicio y al final.
  - Gestión del ciclo de vida del buffer para evitar consumo residual de memoria.

### Paso 3: Capa de Presentación (ViewModel & UI)
- [ ] En `TunerViewModel`: Añadir métodos `playReferenceTone()` y `stopReferenceTone()`.
- [ ] En `TunerScreen`: Agregar botón de reproducción del tono de referencia junto al afinador estroboscópico.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecutar `flutter analyze` (0 errores).
- [ ] Ejecutar `flutter test` (100% pasando).
- [ ] Commit y sincronización con GitHub en la rama `main`.

---

## 4. Estrategia de Rollback

- Revertir el commit base en caso de conflicto con el reproductor de plataforma.
- Hash de restauración: `8c1ea0c`.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Síntesis matemática sin artefactos ni chasquidos (*pops/clicks*).
- [ ] Latencia de generación de buffer $< 5\text{ ms}$.
- [ ] Pruebas unitarias de frecuencia y síntesis pasando.
- [ ] Documentación y plan sincronizados en `main`.
