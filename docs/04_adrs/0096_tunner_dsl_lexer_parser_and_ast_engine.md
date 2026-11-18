# Registro de Decisión de Arquitectura (ADR) 0096: Motor de Lenguaje Específico de Dominio (Tunner DSL): Lexer, Parser Recursivo Descendente y AST

---

## Metadatos

- **ID del ADR:** `ADR-0096`
- **Título:** Arquitectura del Motor Tunner DSL mediante Tokenizador Manual, Analizador Sintáctico Descendente Recursivo y Nodos AST Inmutables
- **Estado:** `Approved`
- **Fecha:** `2026-11-18`
- **Fase Asociada:** `Fase 6`
- **Autor Principal:** `Nicolas Leon (Mantenedor Principal) / Antigravity Engine`
- **Caso de Uso Relacionado:** [Caso de Uso 107](../02_use_cases/107_uc_tunner_dsl_lexer_parser_and_ast_engine.md)
- **Plan Relacionado:** [Plan Épica 6.2](../05_implementation_plans/plan_tunner_dsl_lexer_parser_and_ast_engine.md)
- **Issue Asociado:** [#34](https://github.com/Nicolas11Leon/Tunner/issues/34)

---

## 1. Contexto

La automatización de parámetros de estudio, la orquestación de macros de ruteo de hardware y la composición procedimental en vivo (*Live Coding*) requieren un lenguaje declarativo conciso que pueda ejecutarse en tiempo real sin latencia perceptible.

Existen dos aproximaciones clásicas para construir un DSL en aplicaciones Dart:
1. **Generadores de parsers externos (e.g. ANTLR o macros complejos):** Generan código redundante, introducen dependencias externas y dificultan la depuración en plataformas embebidas o móviles.
2. **Parser Descendente Recursivo Manual en Dart Puro (Recursive Descent Parser):** Ofrece determinismo absoluto, tiempo de ejecución $O(N)$ lineal, diagnósticos de error exactos con línea y columna, cero dependencias añadidas y consumo nulo de memoria en reposo.

---

## 2. Decisión

Se adopta un **Analizador Sintáctico Descendente Recursivo (Recursive Descent Parser)** implementado 100% en Dart puro dentro de `lib/core/dsl/domain/`:

1. **Estructura Modular del Módulo DSL (`lib/core/dsl/domain/`):**
   - `tunner_dsl_token.dart`: Modelo inmutable de tokens con tipo (`TunnerDslTokenType`), lexema, posición en código fuente (línea, columna) y valor tipado opcional.
   - `tunner_dsl_lexer.dart`: Escáner de caracteres en un solo pase que tokeniza palabras clave, identificadores `@target`, números, cadenas y operadores.
   - `tunner_ast_node.dart`: Jerarquía de nodos de sintaxis abstracta inmutables (`ProgramNode`, `TempoStatementNode`, `ChannelDeclNode`, `ConnectStatementNode`, `SetParamStatementNode`, `NoteStatementNode`, `ChordStatementNode`, `RestStatementNode`, `TransportStatementNode`).
   - `tunner_dsl_diagnostic.dart`: Entidad de error de sintaxis y diagnóstico pedagógico.
   - `tunner_dsl_parser.dart`: Analizador sintáctico descendente recursivo con recuperación de errores en modo pánico (*panic mode synchronization*) para capturar múltiples errores sin colapsar.

2. **Garantías de Desempeño:**
   - Tiempo de análisis léxico y sintáctico inferior a 2 milisegundos para scripts de hasta 500 líneas.
   - Cero asignaciones parásitas de memoria en audio loops.

---

## 3. Consecuencias

### Positivas
- **Determinismo y Seguridad:** Los scripts con errores son rechazados limpiamente sin interrumpir el motor de audio ni la interfaz gráfica.
- **Portabilidad Absoluta:** Al estar en Dart puro sin dependencias externas, funciona de manera idéntica en Linux, macOS, Windows, Web, iOS y Android.
- **Base para Live Coding:** Proporciona los cimientos estructurales para el evaluador del Micro-Kernel de la Épica 6.3 y el panel REPL de la Épica 6.4.

### Negativas / Mitigaciones
- **Mantenimiento Manual de la Gramática:** Nuevas sintaxis deben añadirse en el Lexer y Parser manualmente.  
  *Mitigación:* La gramática se mantiene formalmente documentada en EBNF en el Caso de Uso 107 y cada nueva regla cuenta con pruebas unitarias dedicadas.
