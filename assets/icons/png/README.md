# Tunner Custom Icon Assets (PNG Optimizado -> Migración Progresiva a SVG)

Coloca tus archivos PNG optimizados en esta carpeta usando exactamente los nombres canónicos del catálogo (`StudioIconCatalog`):

- **Formato recomendado:** PNG-8/PNG-24 optimizado con canal alfa (fondo transparente), `64x64 px` o `96x96 px`.
- **Resolución progresiva:** Si un archivo `<nombre>.png` existe aquí, `StudioIcon` lo renderizará automáticamente en lugar del icono genérico de Material. Cuando más adelante agregues su versión `.svg` en `assets/icons/svg/`, tendrá prioridad sobre el PNG sin modificar la interfaz.

## Lista de nombres de archivo (`<id>.png`)

### A. Módulos del Estudio (14)
- `module_tuner.png`
- `module_drone.png`
- `module_metronome.png`
- `module_rack.png`
- `module_patchbay.png`
- `module_dj_console.png`
- `module_score_sheet.png`
- `module_score_editor.png`
- `module_piano_roll.png`
- `module_spectrogram.png`
- `module_chord_analyzer.png`
- `module_recorder.png`
- `module_autotune.png`
- `module_pedagogy.png`

### B. Transporte, Audio y Hardware DSP (11)
- `transport_play.png`
- `transport_pause.png`
- `transport_stop.png`
- `transport_record.png`
- `transport_rewind.png`
- `transport_forward.png`
- `transport_loop.png`
- `audio_mic_on.png`
- `audio_mic_off.png`
- `audio_volume_on.png`
- `audio_headphones.png`

### C. Archivos, Formatos e Importación/Exportación (9)
- `file_folder.png`
- `file_new.png`
- `file_open.png`
- `file_save.png`
- `file_export_pdf.png`
- `file_musicxml_midi.png`
- `file_wav_audio.png`
- `file_preset.png`
- `tool_terminal.png`

### D. Shell, Ventanas y Controles de Interfaz (10)
- `ui_search.png`
- `ui_settings.png`
- `ui_automations.png`
- `ui_customizations.png`
- `ui_workspace_layout.png`
- `ui_sidebar_toggle.png`
- `ui_lock.png`
- `ui_power.png`
- `ui_add_remove.png`
- `ui_close_confirm.png`
