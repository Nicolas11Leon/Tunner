import 'package:flutter/material.dart';
import '../../../core/theme/tunner_theme.dart';

/// Modelo de información pedagógica y técnica para la ayuda contextual.
class ToolHelpItem {
  final String id;
  final String title;
  final String category;
  final String description;
  final String pedagogicalTip;
  final String? acousticFormula;
  final List<String> shortcutKeys;

  const ToolHelpItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.pedagogicalTip,
    this.acousticFormula,
    this.shortcutKeys = const [],
  });
}

/// Catálogo de ayuda contextual para todas las herramientas de Tunner.
class ToolHelpCatalog {
  static const Map<String, ToolHelpItem> items = {
    'strobe_tuner': ToolHelpItem(
      id: 'strobe_tuner',
      title: 'Afinador Estroboscópico de Ultra Precisión',
      category: 'Afinación & Acústica',
      description:
          'Utiliza el algoritmo MPM (McLeod Pitch Method) y NSDF para medir la periodicidad armónica con resolución de ±0.1 cents.',
      pedagogicalTip:
          'Mantén notas largas y con volumen constante. Deja que la aguja o el patrón estroboscópico se estabilice antes de ajustar la clavija o embocadura.',
      acousticFormula: r'cents = 1200 \cdot \log_2(f / f_{ref})',
      shortcutKeys: ['A', 'T', 'Alt + ↑', 'Alt + ↓'],
    ),
    'metronome': ToolHelpItem(
      id: 'metronome',
      title: 'Metrónomo Determinista en Isolate',
      category: 'Ritmo & Tempo',
      description:
          'Reloj de alta resolución ejecutado en un hilo Isolate de Dart dedicado, garantizando cero fluctuación (jitter < 1ms) y conteo estable.',
      pedagogicalTip:
          'Practica escalas o pasajes difíciles comenzando un 30% más lento del tempo objetivo hasta lograr sincronización perfecta.',
      acousticFormula: r'\Delta t = \frac{60}{BPM \cdot Q}',
      shortcutKeys: ['M', 'Espacio', 'B (Tap)', '[ / ] (±1 BPM)', 'Shift + [ / ] (±5 BPM)'],
    ),
    'score_notation': ToolHelpItem(
      id: 'score_notation',
      title: 'Pentagrama Interactivo SMuFL',
      category: 'Notación & Lectura',
      description:
          'Lienzo de notación musical vectorial estándar que transcribe notas en tiempo real ("Tocar y Transcribir") y guía la lectura con playhead visual.',
      pedagogicalTip:
          'Observa el color de las notas: verde indica afinación exacta, amarillo leve desviación y rojo error de tono o duración.',
      shortcutKeys: ['S', '5 (Pestaña Canciones)'],
    ),
    'practice_recorder': ToolHelpItem(
      id: 'practice_recorder',
      title: 'Grabador de Práctica & Auto-Escucha',
      category: 'Grabación & Evaluación',
      description:
          'Captura tomas de práctica con representación gráfica de forma de onda, permitiendo reproducción inmediata y comparación espectral.',
      pedagogicalTip:
          'Grabarse y escucharse a uno mismo es el método más rápido para detectar fallos de afinación y ritmo que pasan desapercibidos al tocar.',
      shortcutKeys: ['R', 'Espacio (Play/Stop)'],
    ),
    'vocal_autotune': ToolHelpItem(
      id: 'vocal_autotune',
      title: 'Corrector de Tono Vocal DSP (Autotune)',
      category: 'Procesamiento de Audio',
      description:
          'Cuantiza la frecuencia hacia la escala o temperamento configurado con control de velocidad de retune en milisegundos.',
      pedagogicalTip:
          'Úsalo como monitor de referencia para entrenar la voz a mantenerse en el centro tonal de cada nota.',
      shortcutKeys: ['V'],
    ),
    'harmonic_drone': ToolHelpItem(
      id: 'harmonic_drone',
      title: 'Dron Armónico & Afinación de Oído',
      category: 'Entrenamiento Auditivo',
      description:
          'Sintetiza quintas justas y tonos sostenidos puros para entrenar la afinación armónica por batimento (beating) en lugar de lectura visual.',
      pedagogicalTip:
          'Cuando tu nota está perfectamente afinada con el dron, el batimento u ondulación sonora desaparece por completo.',
      shortcutKeys: ['D', '0 (Mute General)'],
    ),
    'spectrogram': ToolHelpItem(
      id: 'spectrogram',
      title: 'Espectrograma FFT & Armónicos',
      category: 'Análisis Acústico',
      description:
          'Muestra la distribución de frecuencias y los sobretonos H1 a H8 mediante transformación rápida de Fourier (FFT 2048/4096 puntos).',
      pedagogicalTip:
          'Un sonido más cálido tiene armónicos pares prominentes; un sonido brillante o metálico presenta armónicos impares y sobretonos agudos.',
      shortcutKeys: ['F'],
    ),
    'chord_analyzer': ToolHelpItem(
      id: 'chord_analyzer',
      title: 'Analizador Polifónico de Acordes',
      category: 'Armonía & Análisis',
      description:
          'Detecta notas simultáneas y calcula la fundamental, tercera, quinta y tensiones de acordes mayores, menores y con séptima.',
      pedagogicalTip:
          'Toca arpegios o acordes completos para verificar la claridad armónica y la presencia de notas no deseadas.',
      shortcutKeys: ['C'],
    ),
    'guided_lessons': ToolHelpItem(
      id: 'guided_lessons',
      title: 'Tutor de Lecciones & Rushing/Dragging',
      category: 'Pedagogía Interactiva',
      description:
          'Evalúa la precisión rítmica en milisegundos indicando si tocas antes de tiempo (rushing) o retrasado (dragging).',
      pedagogicalTip:
          'Presta atención al metrónomo interior: concéntrate en coincidir con el centro del pulso.',
      shortcutKeys: ['L', '3 (Pestaña Aprender)'],
    ),
    'master_keyboard': ToolHelpItem(
      id: 'master_keyboard',
      title: 'Emulador y Teclado Maestro de Instrumentos',
      category: 'Instrumentos & Síntesis',
      description:
          'Teclado cromático universal con síntesis procedimental por instrumento, afinación microtonal individual y ejecución de estrofas/frases.',
      pedagogicalTip:
          'Usa el teclado para escuchar la afinación teórica de cualquier nota antes de reproducirla con tu instrumento físico.',
      shortcutKeys: ['K', 'Cmd/Ctrl + I (Selector de Instrumento)'],
    ),
  };

  static ToolHelpItem getItem(String id) {
    return items[id] ??
        ToolHelpItem(
          id: id,
          title: 'Herramienta de Estudio',
          category: 'Módulo de Práctica',
          description: 'Módulo interactivo del entorno de estudio de Tunner.',
          pedagogicalTip: 'Interactúa con los controles para modular el sonido.',
          shortcutKeys: const ['Espacio'],
        );
  }
}

/// Insignia interactiva con signo de interrogación ("?") para cualquier herramienta o dial.
class ContextualHelpBadge extends StatelessWidget {
  final String toolId;
  final TunnerThemePalette palette;
  final double size;

  const ContextualHelpBadge({
    super.key,
    required this.toolId,
    required this.palette,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '¿Qué hace esta herramienta? (Ayuda y atajos)',
      child: InkWell(
        key: Key('help_badge_$toolId'),
        borderRadius: BorderRadius.circular(size),
        onTap: () => ContextualHelpSheet.show(context, toolId, palette),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: palette.primaryAccent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: palette.primaryAccent.withValues(alpha: 0.4),
              width: 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '?',
            style: TextStyle(
              color: palette.primaryAccent,
              fontSize: size * 0.62,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal / Bottom Sheet con la explicación didáctica y atajos de la herramienta.
class ContextualHelpSheet extends StatelessWidget {
  final ToolHelpItem item;
  final TunnerThemePalette palette;

  const ContextualHelpSheet({
    super.key,
    required this.item,
    required this.palette,
  });

  static void show(BuildContext context, String toolId, TunnerThemePalette palette) {
    final item = ToolHelpCatalog.getItem(toolId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ContextualHelpSheet(item: item, palette: palette),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      decoration: BoxDecoration(
        color: palette.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: palette.primaryAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Píldora superior de arrastre
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: palette.textMutedColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Título y categoría
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.toUpperCase(),
                      style: TextStyle(
                        color: palette.primaryAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.title,
                      style: TextStyle(
                        color: palette.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: palette.textMutedColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(height: 1, color: palette.staffLinesColor.withValues(alpha: 0.2)),
          const SizedBox(height: 14),

          // Descripción técnica
          Text(
            item.description,
            style: TextStyle(
              color: palette.textColor.withValues(alpha: 0.9),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Consejo pedagógico
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.primaryAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: palette.primaryAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: palette.primaryAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Consejo Pedagógico:',
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.pedagogicalTip,
                        style: TextStyle(
                          color: palette.textColor,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (item.shortcutKeys.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'ATAJOS RÁPIDOS DE TECLADO:',
              style: TextStyle(
                color: palette.textMutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: item.shortcutKeys.map((keyStr) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.scaffoldBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: palette.staffLinesColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    keyStr,
                    style: TextStyle(
                      color: palette.primaryAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
