# Template: Implementation Plan (Plantilla Plan de Implementación)

Este documento define la estructura obligatoria que debe redactarse y validarse antes de ejecutar cualquier cambio significativo en el código fuente de **Tunner**.

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-[FASE]-[COMPONENTE]-[AÑO]-[ID]`
- **Título de la Implementación:** `[Título conciso y formal]`
- **Fase del Proyecto:** `[Fase 1 | Fase 2 | Fase 3 | Fase 4]`
- **Estado:** `[Propuesto | Aprobado | En Progreso | Completado | Descartado]`
- **ADR Relacionado:** `[Enlace al ADR correspondiente en docs/04_adrs/ o N/A]`
- **Documento Funcional Base:** `[Enlace al documento técnico en docs/]`

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
*¿Qué cambio exacto se va a introducir en el software y qué valor medible aportará a la plataforma?*

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Lista de componentes que serán modificados o creados.
- **Excluido (Out-of-Scope):**
  - Qué aspectos NO se tocarán en esta iteración para no inflar el alcance.

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x` (o versión estable más reciente).
  - Flutter SDK: Versión estable del canal oficial.
  - Dependencias de audio / plugins: Justificación de cada paquete y verificación de soporte multiplataforma.
- **Riesgo Tecnológico:**
  - ¿Introduce dependencias nativas o FFI? (Si/No).
  - ¿Afecta el rendimiento del bucle principal de Flutter?

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Capa de Dominio (Modelos Matemáticos y Entidades Puras)
- [ ] Definición de contratos, interfaces abstractas e inmutabilidad.
- [ ] Implementación de fórmulas matemáticas documentadas sin números mágicos.
- [ ] Pruebas unitarias de dominio previas a la integración.

### Paso 2: Capa de Infraestructura / Datos (Servicios y Hardware)
- [ ] Implementación o refactorización de servicios de audio / reloj.
- [ ] Eliminación de cuellos de botella (busy-waiting, bucles infinitos).
- [ ] Comunicación asíncrona segura entre Isolates y el hilo principal.

### Paso 3: Capa de Presentación (ViewModels y UI Canvas)
- [ ] Conexión del ViewModel con los contratos de dominio.
- [ ] Pintura reactiva en CustomPainter a 60/120 FPS sin bloqueos.
- [ ] Feedback visual estético, limpio y profesional.

### Paso 4: Pruebas, Verificación y Limpieza
- [ ] Ejecución de `flutter analyze` (cero advertencias de linter).
- [ ] Ejecución de `flutter test` con reporte de cobertura.
- [ ] Benchmarking de uso de CPU y memoria en reposo y bajo carga.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

*Si el cambio introduce inestabilidad acústica, fugas de memoria o caídas de FPS que no puedan resolverse inmediatamente, ¿cuál es el plan exacto para restaurar el estado estable anterior?*

- **Punto de Restauración Git:** Hash o commit base previo.
- **Mitigación Inmediata:** Desactivación mediante feature flag o reversión del commit.

---

## 5. Criterios de Aceptación (Definition of Done)

Para que este plan se considere completado y listo para merge:
- [ ] Código adherido estrictamente a las reglas de [AGENTS.md](AGENTS.md).
- [ ] Cero busy-waiting loops en Isolates y subprocesos.
- [ ] Pruebas unitarias pasando al 100%.
- [ ] Documentación técnica y ADR redactados o actualizados.
- [ ] Aprobación explícita del creador/mantenedor principal.
