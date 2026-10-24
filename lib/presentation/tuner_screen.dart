import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tuner_viewmodel.dart';
import '../domain/score_entity.dart';
import '../domain/score_tree.dart';
import 'theme/tunner_theme.dart';
import 'widgets/strobe_tuner_widget.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  void _showCustomizationModal(BuildContext context, TunerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: viewModel.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final palette = viewModel.currentPalette;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "PERSONALIZACIÓN DE ESTUDIO",
                        style: TextStyle(
                          color: palette.primaryAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. Selector de Tema Visual
                  Text("Tema y Estética", style: TextStyle(color: palette.textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TunnerThemePalette.allPalettes.map((p) {
                      final isSelected = viewModel.themeMode == p.mode;
                      return ChoiceChip(
                        label: Text(p.displayName),
                        selected: isSelected,
                        selectedColor: p.primaryAccent.withValues(alpha: 0.3),
                        backgroundColor: p.staffBackground,
                        labelStyle: TextStyle(
                          color: isSelected ? p.primaryAccent : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? p.primaryAccent : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                        onSelected: (val) {
                          if (val) {
                            viewModel.setThemeMode(p.mode);
                            setModalState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 2. Selector de Métrica de Compás Libre
                  Text("Métrica de Compás", style: TextStyle(color: palette.textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TimeSignature.standardSignatures.map((sig) {
                      final isSelected = viewModel.currentMeasureTimeSignature == sig;
                      return ActionChip(
                        avatar: Icon(Icons.timer_outlined, size: 16, color: isSelected ? palette.primaryAccent : palette.textMutedColor),
                        label: Text(sig.toString()),
                        backgroundColor: isSelected ? palette.primaryAccent.withValues(alpha: 0.2) : Colors.white10,
                        labelStyle: TextStyle(
                          color: isSelected ? palette.primaryAccent : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: isSelected ? palette.primaryAccent : Colors.white12,
                        ),
                        onPressed: () {
                          viewModel.setCustomTimeSignature(sig);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMixerModal(BuildContext context, TunerViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: viewModel.currentPalette.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final palette = viewModel.currentPalette;
            final mixer = viewModel.mixerConsole;
            final allTracks = [mixer.metronomeTrack, ...mixer.stems];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.equalizer, color: palette.primaryAccent, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "CONSOLA MEZCLADORA (STEMS)",
                            style: TextStyle(
                              color: palette.primaryAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: palette.textMutedColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Balance independiente de metrónomo y pistas de acompañamiento",
                    style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                  ),
                  const SizedBox(height: 16),

                  // Faders de cada canal / stem
                  ...allTracks.map((track) {
                    final isMetro = track.id == "metronome";
                    final iconData = isMetro
                        ? Icons.timer_outlined
                        : (track.instrumentIcon == "mic"
                            ? Icons.mic
                            : (track.instrumentIcon == "piano" ? Icons.piano : Icons.music_note));

                    final effectiveGain = track.getEffectiveGain(hasAnySolo: mixer.hasAnySolo);
                    final isEffectivelySilenced = effectiveGain == 0.0 && track.volume > 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: palette.staffBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: track.isSolo
                              ? palette.secondaryAccent
                              : (track.isMuted ? palette.errorPitchColor.withValues(alpha: 0.4) : Colors.white10),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(iconData, color: isMetro ? palette.primaryAccent : palette.textColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    track.title,
                                    style: TextStyle(
                                      color: isEffectivelySilenced ? palette.textMutedColor : palette.textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: isEffectivelySilenced ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  // Botón MUTE (M)
                                  GestureDetector(
                                    onTap: () {
                                      viewModel.toggleTrackMute(track.id);
                                      setModalState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: track.isMuted ? palette.errorPitchColor : Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "M",
                                        style: TextStyle(
                                          color: track.isMuted ? Colors.white : palette.textMutedColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Botón SOLO (S)
                                  GestureDetector(
                                    onTap: () {
                                      viewModel.toggleTrackSolo(track.id);
                                      setModalState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: track.isSolo ? palette.secondaryAccent : Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        "S",
                                        style: TextStyle(
                                          color: track.isSolo ? Colors.black : palette.textMutedColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 38,
                                    child: Text(
                                      "${(track.volume * 100).round()}%",
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: isMetro ? palette.primaryAccent : palette.textColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: track.volume,
                              min: 0.0,
                              max: 1.0,
                              activeColor: isMetro ? palette.primaryAccent : palette.secondaryAccent,
                              inactiveColor: Colors.white10,
                              onChanged: (val) {
                                viewModel.setTrackVolume(track.id, val);
                                setModalState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();
    final palette = viewModel.currentPalette;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          "Estudio de Flauta Interactivo",
          style: TextStyle(fontWeight: FontWeight.w300, color: palette.textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.equalizer, color: palette.secondaryAccent),
            tooltip: "Consola Mezcladora de Pistas (Stems)",
            onPressed: () => _showMixerModal(context, viewModel),
          ),
          IconButton(
            icon: Icon(Icons.tune, color: palette.primaryAccent),
            tooltip: "Personalización Estética y Compás",
            onPressed: () => _showCustomizationModal(context, viewModel),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: viewModel.selectedSongIndex,
                      dropdownColor: palette.cardBackground,
                      icon: Icon(Icons.music_note, color: palette.textMutedColor),
                      style: TextStyle(color: palette.textColor, fontSize: 16, fontWeight: FontWeight.w500),
                      items: List.generate(viewModel.playlist.length, (index) {
                        return DropdownMenuItem(
                          value: index, 
                          child: Text(
                            viewModel.playlist[index].title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                      onChanged: (val) => val != null ? viewModel.selectSong(val) : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(Icons.remove_circle_outline, color: palette.textMutedColor, size: 20),
                          onPressed: () => viewModel.decrementBpm(1),
                          tooltip: "-1 BPM",
                        ),
                        Text(
                          "${viewModel.bpm}",
                          style: TextStyle(
                            color: palette.primaryAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text("BPM", style: TextStyle(color: palette.textMutedColor, fontSize: 11, fontWeight: FontWeight.w600)),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: Icon(Icons.add_circle_outline, color: palette.textMutedColor, size: 20),
                          onPressed: () => viewModel.incrementBpm(1),
                          tooltip: "+1 BPM",
                        ),
                      ],
                    ),
                    Text(
                      viewModel.currentTempoMark.italianName.toUpperCase(),
                      style: TextStyle(
                        color: palette.secondaryAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Slider(
            value: viewModel.bpm.toDouble(),
            min: 20,
            max: 300,
            activeColor: palette.primaryAccent,
            inactiveColor: palette.staffLinesColor.withValues(alpha: 0.3),
            onChanged: (val) => viewModel.updateBpm(val.round()),
          ),
          const SizedBox(height: 6),

          // Selector de Compases (Navegación Multi-Compás)
          if (viewModel.totalMeasures > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.skip_previous, color: palette.textMutedColor, size: 20),
                    onPressed: () => viewModel.previousMeasure(),
                    tooltip: "Compás Anterior",
                  ),
                  Text(
                    "Compás ${viewModel.currentMeasureIndex + 1} de ${viewModel.totalMeasures}  (${viewModel.currentMeasureTimeSignature})",
                    style: TextStyle(color: palette.textColor, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, color: palette.textMutedColor, size: 20),
                    onPressed: () => viewModel.nextMeasure(),
                    tooltip: "Siguiente Compás",
                  ),
                ],
              ),
            ),

          // LIENZO GRÁFICO DE LA PARTITURA REAL (Adaptado a la Paleta de Estética)
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: palette.staffBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.staffLinesColor.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: RealSheetMusicPainter(
                    currentSubTick: viewModel.currentSubTick,
                    notes: viewModel.currentMeasureNotes,
                    history: viewModel.measureHistory,
                    liveNote: viewModel.noteName,
                    liveCents: viewModel.cents,
                    isCountingIn: viewModel.isCountingIn,
                    countInBeat: viewModel.countInBeat,
                    timeSignature: viewModel.currentMeasureTimeSignature,
                    measureIndex: viewModel.currentMeasureIndex,
                    totalMeasures: viewModel.totalMeasures,
                    palette: palette,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AFINADOR ESTROBOSCÓPICO VIRTUAL DE ALTA PRECISIÓN (UC-04)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: StrobeTunerWidget(
              cents: viewModel.cents,
              frequency: viewModel.frequency,
              noteName: viewModel.noteName,
              isRecording: viewModel.isRecording,
              onPlayReferenceTone: () => viewModel.playReferenceTone("La4"),
            ),
          ),
          const SizedBox(height: 24),

          // BOTONES DE ACCIÓN
          Padding(
            padding: const EdgeInsets.only(bottom: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton.extended(
                  onPressed: viewModel.toggleRecording,
                  backgroundColor: viewModel.isRecording ? palette.errorPitchColor.withValues(alpha: 0.2) : palette.cardBackground,
                  elevation: 0,
                  icon: Icon(viewModel.isRecording ? Icons.mic_off : Icons.mic, color: viewModel.isRecording ? palette.errorPitchColor : palette.textColor),
                  label: Text(viewModel.isRecording ? "Apagar" : "Micro", style: TextStyle(color: viewModel.isRecording ? palette.errorPitchColor : palette.textColor)),
                ),
                FloatingActionButton.extended(
                  onPressed: viewModel.startSongWithCountIn,
                  backgroundColor: viewModel.isMetronomePlaying ? palette.secondaryAccent : palette.primaryAccent,
                  elevation: 5,
                  icon: const Icon(Icons.play_arrow, color: Colors.black),
                  label: Text(
                    viewModel.isMetronomePlaying ? "Detener" : "Practicar",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// MOTOR GRÁFICO DE PARTITURA CLÁSICA CON PALETAS ESTÉTICAS
// =========================================================================
class RealSheetMusicPainter extends CustomPainter {
  final int currentSubTick;
  final List<SongNote> notes;
  final Map<int, PlayedRecord> history;
  final String liveNote;
  final double liveCents;
  final bool isCountingIn;
  final int countInBeat;
  final TimeSignature timeSignature;
  final int measureIndex;
  final int totalMeasures;
  final TunnerThemePalette palette;

  RealSheetMusicPainter({
    required this.currentSubTick,
    required this.notes,
    required this.history,
    required this.liveNote,
    required this.liveCents,
    required this.isCountingIn,
    required this.countInBeat,
    this.timeSignature = TimeSignature.commonTime44,
    this.measureIndex = 0,
    this.totalMeasures = 1,
    this.palette = TunnerThemePalette.obsidianStudio,
  });

  int _getNoteStep(String note) {
    if (note.isEmpty || note == "--") return -100;
    String raw = note.replaceAll(RegExp(r'[0-9#]'), '').toLowerCase();
    int octave = int.tryParse(note.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;
    
    int step = 0;
    switch (raw) {
      case "do": step = 0; break;
      case "re": step = 1; break;
      case "mi": step = 2; break; // Línea inferior
      case "fa": step = 3; break;
      case "sol": step = 4; break;
      case "la": step = 5; break;
      case "si": step = 6; break; // Tercera línea (Centro)
      default: step = 0;
    }
    step += (octave - 4) * 7;
    return step;
  }

  void _drawUnicodeText(Canvas canvas, String text, double x, double y, double size, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontFamily: 'serif')),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x - (textPainter.width / 2), y - (textPainter.height / 2)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = palette.staffLinesColor..strokeWidth = 2.0;
    
    final double leftMargin = 75.0;
    final double rightMargin = 20.0;
    final double playAreaWidth = size.width - leftMargin - rightMargin;
    final int totalMeasureTicks = timeSignature.totalTicks;
    final double stepWidth = playAreaWidth / totalMeasureTicks; 
    final double staffSpacing = size.height / 14;
    final double centerY = size.height / 2;
    
    double baseMi4Y = centerY + (staffSpacing * 2); 
    double topStaffY = baseMi4Y - (4 * staffSpacing);

    // 1. Dibujar el Pentagrama (5 líneas equidistantes)
    for (int i = 0; i < 5; i++) {
      double y = baseMi4Y - (i * staffSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Barra divisoria o final de compás (Barline)
    final double barX = size.width - rightMargin;
    if (measureIndex == totalMeasures - 1) {
      canvas.drawLine(Offset(barX - 6, topStaffY), Offset(barX - 6, baseMi4Y), linePaint..strokeWidth = 2.0);
      canvas.drawLine(Offset(barX, topStaffY), Offset(barX, baseMi4Y), linePaint..strokeWidth = 5.0);
    } else {
      canvas.drawLine(Offset(barX, topStaffY), Offset(barX, baseMi4Y), linePaint..strokeWidth = 3.0);
    }

    // Numeración del compás sobre la barra inicial
    _drawUnicodeText(canvas, "${measureIndex + 1}", leftMargin - 15, topStaffY - 14, 16, palette.textMutedColor);

    // 2. Dibujar la Clave de Sol (𝄞)
    _drawUnicodeText(canvas, "𝄞", 25, centerY + (staffSpacing * 0.5), 100, palette.musicalSymbolsColor);

    // Indicador numérico de Métrica / Compás (e.g. 4/4, 3/4, 6/8)
    _drawUnicodeText(canvas, "${timeSignature.numerator}", 55, centerY - (staffSpacing * 0.8), 24, palette.musicalSymbolsColor);
    _drawUnicodeText(canvas, "${timeSignature.denominator}", 55, centerY + (staffSpacing * 0.8), 24, palette.musicalSymbolsColor);

    // Conteo de entrada gigante
    if (isCountingIn) {
      final textPainter = TextPainter(
        text: TextSpan(text: "$countInBeat", style: TextStyle(color: palette.secondaryAccent, fontSize: 120, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return; 
    }

    // 3. Dibujar las Figuras Musicales de la Partitura
    final targetPaintFill = Paint()..color = palette.musicalSymbolsColor..style = PaintingStyle.fill;
    final targetPaintStroke = Paint()..color = palette.musicalSymbolsColor..style = PaintingStyle.stroke..strokeWidth = 3;

    for (var note in notes) {
      double startX = leftMargin + (note.startTick * stepWidth);
      double noteCenterX = startX + (stepWidth / 2);

      if (note.isRest) {
        String restSymbol = "";
        if (note.durationTicks >= 16) {
          restSymbol = "𝄻"; // Redonda
        } else if (note.durationTicks >= 8) {
          restSymbol = "𝄼"; // Blanca
        } else if (note.durationTicks >= 4) {
          restSymbol = "𝄽"; // Negra
        } else if (note.durationTicks >= 2) {
          restSymbol = "𝄾"; // Corchea
        } else {
          restSymbol = "𝄿"; // Semicorchea
        }
        
        _drawUnicodeText(canvas, restSymbol, noteCenterX, centerY, 55, palette.musicalSymbolsColor);
      } else {
        int step = _getNoteStep(note.noteName);
        double noteY = baseMi4Y - ((step - 2) * (staffSpacing / 2));
        
        bool isFilled = note.durationTicks <= 4;
        bool hasStem = note.durationTicks < 16;
        bool stemGoesDown = step >= 6; 
        
        // Cabeza de la nota
        canvas.save();
        canvas.translate(noteCenterX, noteY);
        canvas.rotate(-0.2); 
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 22, height: 16), isFilled ? targetPaintFill : targetPaintStroke);
        canvas.restore();

        // Plica (Stem)
        if (hasStem) {
          double stemX = stemGoesDown ? noteCenterX - 9 : noteCenterX + 9;
          double stemYStart = noteY;
          double stemYEnd = stemGoesDown ? noteY + (staffSpacing * 3.5) : noteY - (staffSpacing * 3.5);
          
          canvas.drawLine(Offset(stemX, stemYStart), Offset(stemX, stemYEnd), targetPaintFill..strokeWidth = 3.0);
          
          // Corchetes (Flags)
          if (note.durationTicks <= 2) { 
            double flagHeight = stemGoesDown ? -25 : 25;
            canvas.drawPath(
              Path()..moveTo(stemX, stemYEnd)..quadraticBezierTo(stemX + 15, stemYEnd + flagHeight/2, stemX + 5, stemYEnd + flagHeight),
              targetPaintStroke..strokeWidth = 3.0
            );
            if (note.durationTicks == 1) {
              double offset2 = stemGoesDown ? -10 : 10;
              canvas.drawPath(
                Path()..moveTo(stemX, stemYEnd - offset2)..quadraticBezierTo(stemX + 15, stemYEnd - offset2 + flagHeight/2, stemX + 5, stemYEnd - offset2 + flagHeight),
                targetPaintStroke..strokeWidth = 3.0
              );
            }
          }
        }
        
        // Líneas adicionales
        if (step <= 0 || step >= 12) {
          canvas.drawLine(Offset(noteCenterX - 18, noteY), Offset(noteCenterX + 18, noteY), targetPaintFill..strokeWidth = 2.0);
        }
      }
    }

    // 4. Cursor de Tiempo Analítico (Playhead con color de la paleta)
    if (currentSubTick >= 0) {
      final cursorPaint = Paint()..color = palette.playheadColor.withValues(alpha: 0.2);
      canvas.drawRect(Rect.fromLTWH(leftMargin + (currentSubTick * stepWidth), 0, stepWidth, size.height), cursorPaint);
    }

    // 5. Historial Dinámico de Colores
    history.forEach((tick, record) {
      double recordX = leftMargin + (tick * stepWidth) + (stepWidth / 2);
      
      if (record.isRest) {
        final p = Paint()..color = record.isCorrect ? palette.correctPitchColor.withValues(alpha: 0.5) : palette.errorPitchColor.withValues(alpha: 0.5);
        canvas.drawCircle(Offset(recordX, size.height - 20), 5, p);
      } else {
        int playedStep = _getNoteStep(record.noteName);
        if (playedStep > -100) {
          double playedY = baseMi4Y - ((playedStep - 2) * (staffSpacing / 2));
          Color dotColor = record.isCorrect ? (record.cents.abs() <= 15 ? palette.correctPitchColor : palette.warningPitchColor) : palette.errorPitchColor;
          
          final p = Paint()..color = dotColor..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
          canvas.drawCircle(Offset(recordX, playedY), 10, p);
        }
      }
    });

    // 6. Efecto de "Esfera Flotante" para la afinación en tiempo real
    if (currentSubTick >= 0 && liveNote != "--") {
      int liveStep = _getNoteStep(liveNote);
      if (liveStep > -100) {
        double currentX = leftMargin + (currentSubTick * stepWidth) + (stepWidth / 2);
        double liveY = baseMi4Y - ((liveStep - 2) * (staffSpacing / 2));
        liveY -= (liveCents / 50.0) * (staffSpacing / 4);

        Color liveColor = (liveCents.abs() <= 15) ? palette.correctPitchColor : palette.warningPitchColor;

        final livePaint = Paint()
          ..color = liveColor.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(currentX, liveY), 14, livePaint);
        canvas.drawCircle(Offset(currentX, liveY), 6, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant RealSheetMusicPainter oldDelegate) {
    return oldDelegate.currentSubTick != currentSubTick ||
        oldDelegate.liveNote != liveNote ||
        oldDelegate.liveCents != liveCents ||
        oldDelegate.isCountingIn != isCountingIn ||
        oldDelegate.countInBeat != countInBeat ||
        oldDelegate.measureIndex != measureIndex ||
        oldDelegate.timeSignature != timeSignature ||
        oldDelegate.palette != palette ||
        oldDelegate.notes != notes ||
        oldDelegate.history.length != history.length;
  }
}