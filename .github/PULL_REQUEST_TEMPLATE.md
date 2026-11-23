### Descripcion del Pull Request

*Explica de forma concisa el objetivo de este Pull Request, el problema que resuelve y las decisiones tecnicas adoptadas.*

---

### Vinculacion de Issues y Casos de Uso

- **Issue Relacionado:** Closes #
- **Caso de Uso / ADR:** Enlace al documento en `docs/` (si aplica)

---

### Lista de Comprobacion de Calidad (Checklist Obligatoria)

Antes de solicitar la revision, confirma el cumplimiento de cada uno de los principios innegociables de Tunner:

- [ ] **Rama de Destino Correcta:** Este Pull Request apunta exclusivamente a la rama **`qa`** (NUNCA a `main`).
- [ ] **Clean Architecture:** La capa de dominio (`domain/`) permanece en Dart puro, sin dependencias de Flutter UI ni paquetes de terceros.
- [ ] **Sin Bucles de Espera Activa:** Cero bucles infinitos o polling intensivo (Zero Busy-Waiting).
- [ ] **Pruebas Automatizadas:** Se han incluido o actualizado pruebas unitarias/integracion y `flutter test` pasa al 100%.
- [ ] **Analisis Estatico Limpio:** `flutter analyze --no-fatal-infos` reporta 0 issues y 0 advertencias.
- [ ] **Politica de Cero Emojis:** Ni el codigo, ni los comentarios, ni los commits, ni este PR contienen emojis.

---

### Nota de Gobernanza y Aprobacion

> [!IMPORTANT]
> **Control y Aprobacion Exclusiva del Mantenedor:**  
> La revision, solicitud de cambios, aprobacion y fusion de este Pull Request, asi como la actualizacion del tablero de tareas, es potestad reservada exclusivamente para el Mantenedor Principal ([@Nicolas11Leon](https://github.com/Nicolas11Leon)).
