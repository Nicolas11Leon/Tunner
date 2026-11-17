# Especificación Técnica: Pro Studio Dashboard Hub y Terminal Tunner OS CLI

## Metadatos del Documento
- **ID del Documento:** `DOC-STUDIO-HUB-CLI-2026-03`
- **Título Oficial:** Especificación de Alta Densidad para el Dashboard y Terminal de Comandos Integrada
- **Estado:** Aprobado
- **Fecha de Creación:** 2026-11-17
- **Última Modificación:** 2026-11-17
- **Fase Asociada:** Fase 1 / Experiencia de Estudio & Interoperabilidad
- **Autor / Revisor Principal:** Tunner Core Architecture Team

---

## 1. Resumen Ejecutivo
Este documento formaliza la especificación técnica de la interfaz de alta fidelidad del Dashboard Principal y el intérprete interactivo de comandos `TunnerOsKernel`. Se detallan la distribución matemática de columnas en el viewport, la gramática formal del lenguaje CLI de Tunner OS y las estructuras de datos requeridas para la telemetría en tiempo real y la gestión del historial de terminal.

---

## 2. Contexto del Problema y Justificación Teórica

### 2.1 Planteamiento del Problema
Los monitores de escritorio modernos operan comúnmente a resoluciones de 1080p, 1440p o 4K ($\ge 1920\times 1080\text{ px}$). Renderizar una lista vertical monofilar desperdicia más del $55\%$ del ancho de pantalla y obliga al usuario a desplazarse innecesariamente. Asimismo, la ausencia de una consola de comandos centralizada restringe a los usuarios avanzados que buscan operar la estación de audio sin recurrir constantemente al cursor del ratón.

### 2.2 Fundamento Teórico y Gramática Formal de Comandos
La terminal Tunner OS implementa un analizador léxico de descenso recursivo simplificado con gramática en forma Backus-Naur (BNF):

```bnf
<command>     ::= <domain> [ <action> ] [ <parameters> ]
<domain>      ::= "tuner" | "dj" | "io" | "fs" | "dsp" | "theme" | "help" | "clear"
<action>      ::= "run" | "load" | "play" | "pause" | "stop" | "bpm" | "list" | "set" | "cat" | "status"
<parameters>  ::= <string_literal> | <identifier> | <number> | <parameters> <parameters>
```

---

## 3. Especificación Funcional Detallada

### 3.1 Gramática de Comandos Soportados
1. **Dominio `tuner`:**
   - `tuner run [tuner|lessons|rack|library|dj]`: Navega de forma inmediata a la pestaña correspondiente.
2. **Dominio `dj`:**
   - `dj load <A|B> <titulo>`: Carga la pista o síntesis indicada en el Deck seleccionado.
   - `dj play <A|B>`: Inicia o reanuda la reproducción.
   - `dj pause <A|B>`: Pausa determinista del Deck.
   - `dj bpm <A|B> <valor>`: Ajusta el tempo en BPM.
   - `dj crossfader <valor>`: Modula la posición entre $[-1.0, 1.0]$.
3. **Dominio `io`:**
   - `io list`: Muestra la lista de interfaces de audio de entrada detectadas.
   - `io set-input <id>`: Conmuta la interfaz física activa.
4. **Dominio `fs`:**
   - `fs ls`: Lista los archivos del proyecto actual.
   - `fs cat <nombre>`: Muestra el contenido o metadatos del archivo.
5. **Dominio `dsp`:**
   - `dsp status`: Emite un reporte de la salud del motor (sample rate, latencia, tamaño de buffer, estado de hilos).
6. **Dominio `theme`:**
   - `theme set <nombre>`: Aplica una skin del catálogo de estudio (Tokyo Cyberpunk, etc.).

### 3.2 Reglas del Viewport del Dashboard
- **Ancho $< 950\text{ px}$:** Layout en 1 columna vertical con espaciado ergonómico de $12\text{ px}$.
- **Ancho $\ge 950\text{ px}$:** Layout en 2 columnas con tarjetas de ancho uniforme calculado mediante:
  $$\text{CardWidth} = \frac{\text{ViewportWidth} - \text{PaddingHorizontal} \times 2 - \text{ColumnGap}}{2}$$
