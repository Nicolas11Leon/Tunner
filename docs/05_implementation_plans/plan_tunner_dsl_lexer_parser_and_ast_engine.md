# Plan de Implementación: Motor de Lenguaje Específico de Dominio (Tunner DSL): Lexer, Parser Recursivo Descendente y AST

---

## Metadatos del Plan

- **ID del Plan:** `PLAN-FASE6-DSL-PARSER-2026-0096`
- **Título de la Implementación:** Motor de Lenguaje Específico de Dominio (Tunner DSL): Tokenizador, Analizador Sintáctico Descendente Recursivo y Árbol de Sintaxis Abstracta (AST)
- **Fase del Proyecto:** Fase 6 (Ecosistema de Plataforma Autónoma y Lenguaje DSL)
- **Estado:** En Progreso
- **ADR Relacionado:** [ADR 0096](../04_adrs/0096_tunner_dsl_lexer_parser_and_ast_engine.md)
- **Documento Funcional Base:** [Caso de Uso 107](../02_use_cases/107_uc_tunner_dsl_lexer_parser_and_ast_engine.md)
- **Issue Asociado:** [#34](https://github.com/Nicolas11Leon/Tunner/issues/34)

---

## 1. Alcance y Objetivos de la Implementación

### 1.1 Objetivo Primario
Construir en Dart puro el motor léxico, sintáctico y de representación en árbol (AST) del lenguaje declarativo **Tunner DSL**, permitiendo transformar cadenas de texto con instrucciones de tempo, canales, conexiones, notas, acordes, silencios y modulación de parámetros en nodos estructurados e inmutables listos para su posterior evaluación en el micro-kernel.

### 1.2 Límites del Alcance (Scope Boundaries)
- **Incluido (In-Scope):**
  - Modelos inmutables en `lib/core/dsl/domain/`: `TunnerDslToken`, `TunnerDslTokenType`, `TunnerDslDiagnostic`.
  - Nodos AST inmutables en `lib/core/dsl/domain/tunner_ast_node.dart`.
  - Escáner léxico `TunnerDslLexer` con seguimiento de línea y columna.
  - Analizador sintáctico descendente recursivo `TunnerDslParser` con recuperación por sincronización ante errores.
  - Resultado estructurado `TunnerDslParseResult`.
  - Suite de pruebas unitarias exhaustivas con scripts válidos, erróneos y casos límite.
- **Excluido (Out-of-Scope):**
  - Evaluador de efectos físicos y bus de audio (asignado a la Épica 6.3 e Issue #35).
  - Widget de terminal interactiva con resaltado de sintaxis en UI (asignado a la Épica 6.4 e Issue #36).

---

## 2. Análisis de Dependencias y Tecnologías

- **Versiones de Librerías / SDKs:**
  - Dart SDK: `^3.11.x`
  - Flutter SDK: Canal oficial estable.
  - Cero dependencias externas adicionales: 100% Pure Dart determinista.
- **Riesgo Tecnológico:**
  - Cero dependencias nativas o llamadas de red.
  - Algoritmo de tokenizado y parsing en un único pase de complejidad lineal $O(N)$ con tiempo de ejecución $< 2\text{ ms}$.

---

## 3. Plan Paso a Paso de Ejecución (Step-by-Step Roadmap)

### Paso 1: Definición de Tokens y Diagnósticos (`lib/core/dsl/domain/`)
- [ ] Definir `TunnerDslTokenType` con todos los símbolos gramaticales, palabras clave y literales.
- [ ] Implementar `TunnerDslToken` inmutable con lexema, valor y coordenadas de texto (línea, columna).
- [ ] Implementar `TunnerDslDiagnostic` con nivel de severidad (error, warning) y mensaje didáctico.

### Paso 2: Escáner Léxico (`TunnerDslLexer`)
- [ ] Implementar `TunnerDslLexer.tokenize(String source)` con soporte para:
  - Palabras clave (`channel`, `connect`, `set`, `note`, `chord`, `rest`, `tempo`, `play`, `pause`, `stop`).
  - Identificadores con prefijo `@` (`@synth.out`, `@master.gain`).
  - Literales numéricos enteros y decimales con signo (`120`, `-3.5`, `0.75`).
  - Literales de cadena entre comillas dobles o simples.
  - Fracciones métricas (`1/4`, `1/8`, `1/2`, `4/4`).
  - Operadores `->`, `=`, `[`, `]`, `.`, `,`, `;`.
  - Comentarios de una sola línea (`// ...`).

### Paso 3: Jerarquía de Nodos del Árbol de Sintaxis Abstracta (AST)
- [ ] Implementar `TunnerAstNode` y sus subclases inmutables:
  - `ProgramNode`: Colección de sentencias ejecutables.
  - `TempoStatementNode`: Modificación de tempo en BPM.
  - `ChannelDeclNode`: Declaración de canal virtual.
  - `ConnectStatementNode`: Enrutamiento de fuente hacia destino.
  - `SetParamStatementNode`: Modulación de parámetro de hardware.
  - `NoteStatementNode`: Disparo de nota musical individual con altura y duración fraccional.
  - `ChordStatementNode`: Disparo de acorde polifónico con lista de notas y duración.
  - `RestStatementNode`: Silencio musical de duración fraccional.
  - `TransportStatementNode`: Control de transporte (`play`, `pause`, `stop`).

### Paso 4: Analizador Sintáctico Descendente Recursivo (`TunnerDslParser`)
- [ ] Implementar `TunnerDslParser.parse(List<TunnerDslToken> tokens)`:
  - Consumo de tokens con coincidencia esperada (`consume`, `match`, `peek`).
  - Rutinas de análisis para cada sentencia gramatical.
  - Sincronización en modo pánico tras encontrar punto y coma `;` para recopilar múltiples errores.
  - Retorno de `TunnerDslParseResult(program, diagnostics)`.

### Paso 5: Suite de Pruebas Unitarias y Verificación
- [ ] Desarrollar `test/core/dsl/tunner_dsl_lexer_test.dart`:
  - Tokenización de todas las palabras clave, números, @identificadores y comentarios.
- [ ] Desarrollar `test/core/dsl/tunner_dsl_parser_test.dart`:
  - Parsing de scripts de ruteo, tempo, notas, acordes y parámetros.
  - Detección precisa de errores sintácticos y coordenadas de línea/columna.
- [ ] Verificación con `flutter analyze --no-fatal-infos` (0 advertencias).
- [ ] Ejecución de suite de pruebas unitarias.

---

## 4. Estrategia de Rollback (Plan de Contingencia)

- **Punto de Restauración Git:** Commit de la rama `qa` (`bf0ce95`).
- **Aislamiento Modular:** El módulo DSL vive en `lib/core/dsl/` y es 100% desacoplado de las vistas y del reproductor principal.

---

## 5. Criterios de Aceptación (Definition of Done)

- [ ] Código adherido estrictamente a las directrices de [AGENTS.md](../../AGENTS.md) (Pure Dart, cero busy-waiting, cero emojis).
- [ ] Cobertura de pruebas unitarias $\ge 95\%$ en el analizador léxico y sintáctico.
- [ ] 0 errores y 0 advertencias en análisis estático.
- [ ] Pull Request formal creado en GitHub con base en la rama `qa`.
