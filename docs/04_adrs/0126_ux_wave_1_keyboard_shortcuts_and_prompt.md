# ADR 0126: Estandarizacion de Atajos de Teclado, Gestion de Foco y Prompt Bar

## Estado
Aprobado

## Contexto
Durante las pruebas de usabilidad forenses en entornos de escritorio Linux, se identificaron fricciones severas de interaccion:
1. Al interactuar con botones de la interfaz, el foco de Flutter permanece retenido por el widget, provocando que presionar `Space` (destinado a iniciar o detener el transporte del metronomo) reactive el ultimo boton pulsado.
2. La Paleta de Comandos (`Ctrl+K` / `ProCommandPaletteModal`) exigia hacer clic con el raton sobre las opciones resultantes, careciendo de soporte de flechas direccionales (`Up`/`Down`) y `Enter` para confirmar.
3. Varios atajos canónicos anunciados en la documentacion (`Ctrl+S`, `Ctrl+O`, `Ctrl+N`, `Ctrl+B`, `Ctrl+Shift+D`, `F1..F6`, `Alt+1..6`, `F12`, `?`) no se encontraban registrados en `activeShortcuts` o diferian segun el modo de ejecucion.
4. En `StudioCommandPromptBar`, ingresar argumentos separados por espacio (e.g. `/bpm 140`) provocaba un desajuste en el filtrado por cadena exacta que vaciaba las sugerencias y ejecutaba una salida a terminal no deseada.
5. Modales interactivos de ritmo (`TapTempoModal`) y de practica musical (`UniversalMasterKeyboardWidget`, `ScoreEditorModal`) no recibian pulsaciones de teclado fisico para registrar taps o emitir notas.

## Decision
1. **Paleta de Comandos Accesible por Teclado:** Incorporar un `Focus` con `onKeyEvent` en `ProCommandPaletteModal` que capture `arrowDown`, `arrowUp`, `enter` y `escape`, manteniendo un indice `_selectedIndex` sincronizado con la lista filtrada y aplicando resaltado tematico.
2. **Expansion del Catalogo de la Paleta:** Incorporar los comandos de acceso directo a todas las areas del estudio (Inicio, Afinador, Metronomo, Aprender, Rack Modular, Partituras, Consola DJ, Boveda Multimedia, Configuraciones, Salto a Tarea).
3. **Registro Exhaustivo de Atajos en `MainAppShell`:** Registrar en `activeShortcuts` las combinaciones `Ctrl+S`, `Ctrl+O`, `Ctrl+N`, `Ctrl+B`, `Ctrl+Shift+D`, `F1..F6`, `Alt+1..6`, `F12` y `?` (Slash + Shift), asegurando que el modo DJ mantenga operativas las funciones criticas de conmutacion de pestañas sin interferir con los controles de mezcla.
4. **Desacoplamiento de Foco en Transporte Global:** Reforzar `_GuardedShortcutAction` para verificar que el foco actual no pertenezca a un campo de texto editable y asegurar que las acciones de transporte reciban prioridad determinista.
5. **Correccion de Argumentos en Prompt Bar:** Modificar `_applySuggestionFilter` y `_submitCurrentText` en `StudioCommandPromptBar` para procesar el token principal del comando (`tokens.first`) de forma agnostica a los parametros posteriores, ejecutando el callback asociado directamente sin activar la bandera de apertura del terminal.
6. **Entrada de Teclado en Modales:**
   - `TapTempoModal`: Responder a pulsaciones de `T`, `Space` y `Enter` para computar intervalos de tempo.
   - `UniversalMasterKeyboardWidget`: Mapear teclas de la fila media e intermedia (`A, W, S, E, D, F, T, G, Y, H, U, J, K`) a semitonos de la escala cromatica.
   - `ScoreEditorModal`: Manejar flechas direccionales y Enter para posicionamiento e insercion rapida.

## Consecuencias
- **Positivas:** Flujo de trabajo acelerado para usuarios de escritorio conforme a estandares de software de produccion de audio profesional (DAWs). Eliminacion de interrupciones visuales por apertura accidental de terminales.
- **Negativas / Mitigaciones:** Requiere verificacion estricta para asegurar que campos de texto (`TextField`, `EditableText`) consuman sus propios eventos sin disparar atajos globales mientras el usuario escribe.
