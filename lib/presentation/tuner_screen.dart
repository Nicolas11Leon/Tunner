import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tuner_viewmodel.dart';
import '../domain/score_entity.dart';
import 'widgets/strobe_tuner_widget.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TunerViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      appBar: AppBar(
        title: const Text("Estudio de Flauta Interactivo", style: TextStyle(fontWeight: FontWeight.w300)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: viewModel.selectedSongIndex,
                    dropdownColor: const Color(0xFF1A1A24),
                    icon: const Icon(Icons.music_note, color: Colors.white54),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                    items: List.generate(viewModel.playlist.length, (index) {
                      return DropdownMenuItem(value: index, child: Text(viewModel.playlist[index].title));
                    }),
                    onChanged: (val) => val != null ? viewModel.selectSong(val) : null,
                  ),
                ),
                Text("${viewModel.bpm} BPM", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Slider(
            value: viewModel.bpm.toDouble(),
            min: 40, max: 200,
            activeColor: Colors.greenAccent,
            inactiveColor: Colors.white10,
            onChanged: (val) => viewModel.updateBpm(val.round()),
          ),
          const SizedBox(height: 10),

          // LIENZO GRÁFICO DE LA PARTITURA REAL (Legibilidad Mejorada)
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16161D),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter: RealSheetMusicPainter(
                    currentSubTick: viewModel.currentSubTick,
                    notes: viewModel.playlist[viewModel.selectedSongIndex].notes,
                    history: viewModel.measureHistory,
                    liveNote: viewModel.noteName,
                    liveCents: viewModel.cents,
                    isCountingIn: viewModel.isCountingIn,
                    countInBeat: viewModel.countInBeat,
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
                  backgroundColor: viewModel.isRecording ? Colors.redAccent.withValues(alpha: 0.2) : const Color(0xFF232333),
                  elevation: 0,
                  icon: Icon(viewModel.isRecording ? Icons.mic_off : Icons.mic, color: viewModel.isRecording ? Colors.redAccent : Colors.white),
                  label: Text(viewModel.isRecording ? "Apagar" : "Micro", style: TextStyle(color: viewModel.isRecording ? Colors.redAccent : Colors.white)),
                ),
                FloatingActionButton.extended(
                  onPressed: viewModel.startSongWithCountIn,
                  backgroundColor: viewModel.isMetronomePlaying ? Colors.amber[700] : Colors.greenAccent[700],
                  elevation: 5,
                  icon: Icon(viewModel.isMetronomePlaying ? Icons.stop : Icons.play_arrow, color: Colors.black),
                  label: Text(viewModel.isMetronomePlaying ? "Detener" : "Practicar", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
// MOTOR GRÁFICO DE PARTITURA CLÁSICA (Con Alto Contraste)
// =========================================================================
class RealSheetMusicPainter extends CustomPainter {
  final int currentSubTick;
  final List<SongNote> notes;
  final Map<int, PlayedRecord> history;
  final String liveNote;
  final double liveCents;
  final bool isCountingIn;
  final int countInBeat;

  RealSheetMusicPainter({
    required this.currentSubTick,
    required this.notes,
    required this.history,
    required this.liveNote,
    required this.liveCents,
    required this.isCountingIn,
    required this.countInBeat,
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
    // Líneas del pentagrama ligeramente más visibles
    final linePaint = Paint()..color = const Color(0xFF4A4A5A)..strokeWidth = 2.0;
    
    final double leftMargin = 60.0;
    final double playAreaWidth = size.width - leftMargin;
    final double stepWidth = playAreaWidth / 16; 
    final double staffSpacing = size.height / 14;
    final double centerY = size.height / 2;
    
    double baseMi4Y = centerY + (staffSpacing * 2); 

    // 1. Dibujar el Pentagrama
    for (int i = 0; i < 5; i++) {
      double y = baseMi4Y - (i * staffSpacing);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // 2. Dibujar la Clave de Sol (𝄞) con mayor opacidad y tamaño
    _drawUnicodeText(canvas, "𝄞", leftMargin / 2, centerY + (staffSpacing * 0.5), 110, Colors.white60);

    // Conteo de entrada gigante
    if (isCountingIn) {
      final textPainter = TextPainter(
        text: TextSpan(text: "$countInBeat", style: const TextStyle(color: Colors.orangeAccent, fontSize: 120, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
      return; 
    }

    // 3. Dibujar las Figuras Musicales de la Partitura (BLANCO SÓLIDO)
    final targetPaintFill = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final targetPaintStroke = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3;

    for (var note in notes) {
      double startX = leftMargin + (note.startTick * stepWidth);
      double noteCenterX = startX + (stepWidth / 2);

      if (note.isRest) {
        // Silencios mucho más legibles y grandes
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
        
        _drawUnicodeText(canvas, restSymbol, noteCenterX, centerY, 55, Colors.white70);
      } else {
        int step = _getNoteStep(note.noteName);
        double noteY = baseMi4Y - ((step - 2) * (staffSpacing / 2));
        
        bool isFilled = note.durationTicks <= 4;
        bool hasStem = note.durationTicks < 16;
        bool stemGoesDown = step >= 6; 
        
        // Cabeza de la nota MUCHO más grande (22x16 en lugar de 15x11)
        canvas.save();
        canvas.translate(noteCenterX, noteY);
        canvas.rotate(-0.2); 
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 22, height: 16), isFilled ? targetPaintFill : targetPaintStroke);
        canvas.restore();

        // Plica (Stem) más gruesa
        if (hasStem) {
          double stemX = stemGoesDown ? noteCenterX - 9 : noteCenterX + 9;
          double stemYStart = noteY;
          double stemYEnd = stemGoesDown ? noteY + (staffSpacing * 3.5) : noteY - (staffSpacing * 3.5);
          
          canvas.drawLine(Offset(stemX, stemYStart), Offset(stemX, stemYEnd), targetPaintFill..strokeWidth = 3.0);
          
          // Corchetes (Flags) más marcados
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
        
        // Líneas adicionales para notas agudas/graves (más anchas y visibles)
        if (step <= 0 || step >= 12) {
          canvas.drawLine(Offset(noteCenterX - 18, noteY), Offset(noteCenterX + 18, noteY), targetPaintFill..strokeWidth = 2.0);
        }
      }
    }

    // 4. Cursor de Tiempo Analítico (Playhead)
    if (currentSubTick >= 0) {
      final cursorPaint = Paint()..color = Colors.greenAccent.withValues(alpha: 0.15);
      canvas.drawRect(Rect.fromLTWH(leftMargin + (currentSubTick * stepWidth), 0, stepWidth, size.height), cursorPaint);
    }

    // 5. Historial Dinámico de Colores
    history.forEach((tick, record) {
      double recordX = leftMargin + (tick * stepWidth) + (stepWidth / 2);
      
      if (record.isRest) {
        final p = Paint()..color = record.isCorrect ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5);
        canvas.drawCircle(Offset(recordX, size.height - 20), 5, p);
      } else {
        int playedStep = _getNoteStep(record.noteName);
        if (playedStep > -100) {
          double playedY = baseMi4Y - ((playedStep - 2) * (staffSpacing / 2));
          Color dotColor = record.isCorrect ? (record.cents.abs() <= 15 ? Colors.greenAccent : Colors.amberAccent) : Colors.redAccent;
          
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

        Color liveColor = (liveCents.abs() <= 15) ? Colors.greenAccent : Colors.amberAccent;

        final livePaint = Paint()
          ..color = liveColor.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(currentX, liveY), 14, livePaint);
        canvas.drawCircle(Offset(currentX, liveY), 6, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}