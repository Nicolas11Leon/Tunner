# ADR 0121: Protocolo de Certificación de Release Oficial v1.0.0, Validación Manual en Dispositivo y Gobernanza de Lanzamiento

## Estado
Aceptado

## Contexto
Tras la culminación exitosa de las 6 Olas del Plan de Endurecimiento Pre-v1.0.0 (`PLAN-PRE-V1-FEATURE-HARDENING-2026-002`, PRs `#84` a `#89`), la rama `qa` de Tunner ha alcanzado una cobertura de 1,154 pruebas automatizadas con 0 fallos y 0 issues de analizador estático.
Para formalizar la transición desde el estado de Release Candidate (RC) hacia la versión de producción oficial **v1.0.0**, es imperativo:
1. Establecer un protocolo formal de pruebas manuales de campo que el Mantenedor Principal (@Nicolas11Leon) pueda ejecutar en hardware acústico real (micrófonos físicos, tarjetas de sonido externas, pantallas táctiles y teclado).
2. Documentar de forma rigurosa e inmutable la bitácora maestra de aseguramiento de calidad cubriendo los 131 casos de uso históricos y contemporáneos.
3. Actualizar la totalidad de la documentación de cara al público (`README.md`, `release_notes_v1.0.0.md`) reflejando la arquitectura final, sin dejar métricas obsoletas ni cabos sueltos.
4. Preservar la regla cardinal de gobernanza: la rama `main` es intocable salvo por acción soberana del Creador (@Nicolas11Leon).

## Decisión
1. **Adopción de la Batería Manual de 10 Escenarios de Campo:**
   - Formalizar en `docs/06_qa_and_manual_testing/01_v1_0_0_manual_qa_validation_protocol.md` una matriz paso a paso con criterios de aceptación acústica, visual y de I/O para ejecución en hardware real.
2. **Actualización de la Bitácora Maestra:**
   - Expandir `docs/06_qa_and_manual_testing/bitacora_maestra_pruebas_manuales.md` con los 131 Casos de Uso del sistema, 120 ADRs y las 1,154 pruebas automatizadas.
3. **Consolidación de Release Notes v1.0.0:**
   - Detallar en `docs/07_releases/release_notes_v1.0.0.md` la totalidad de las 6 Olas de endurecimiento, los módulos acústicos reales, la aceleración FFI nativa y el identificador canónico `org.tunner.studio`.
4. **Sincronización del `README.md`:**
   - Actualizar insignias de tests a 1,154 Passing, conteos de arquitectura y guías de ejecución.
5. **Gobernanza GitFlow:**
   - Todas las actualizaciones documentales se integran en `qa` mediante Pull Request con squash merge. La fusión a `main` y creación del tag `v1.0.0` permanece bajo control manual exclusivo de `@Nicolas11Leon`.

## Consecuencias
- El creador y la comunidad cuentan con una guía cristalina, reproducible y verificable para certificar la estabilidad de la plataforma en cualquier máquina.
- La versión v1.0.0 nace con una base documental de grado industrial, sin contradicciones en métricas ni descripciones obsoletas.
- Cumplimiento estricto y riguroso de la Constitución del proyecto ([`AGENTS.md`](file:///home/nicomania11/Proyectos~/Escritorio/TUNER/tunner/AGENTS.md)).
