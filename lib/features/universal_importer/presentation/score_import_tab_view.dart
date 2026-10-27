import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../tuner_viewmodel.dart';

/// Callback para seleccionar un archivo local de forma desacoplada y testeable.
typedef FilePickerCallback = Future<({Uint8List bytes, String fileName})?> Function();

/// Vista de pestaña para la importación universal de partituras MusicXML y archivos MIDI.
class ScoreImportTabView extends StatefulWidget {
  final TunerViewModel viewModel;
  final FilePickerCallback? filePicker;

  const ScoreImportTabView({
    super.key,
    required this.viewModel,
    this.filePicker,
  });

  @override
  State<ScoreImportTabView> createState() => _ScoreImportTabViewState();
}

class _ScoreImportTabViewState extends State<ScoreImportTabView> {
  final TextEditingController _xmlTextController = TextEditingController();
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isError = false;

  // Ejemplos canónicos offline para prueba inmediata
  static const String _odeToJoyMusicXmlSample = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Himno a la Alegría (MusicXML)</work-title></work>
  <identification><creator type="composer">L. v. Beethoven</creator></identification>
  <part-list>
    <score-part id="P1"><part-name>Voz</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>4</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <sound tempo="116"/>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="2">
      <note><pitch><step>G</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="3">
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration></note>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration></note>
    </measure>
    <measure number="4">
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>6</duration></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>2</duration></note>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>8</duration></note>
    </measure>
  </part>
</score-partwise>''';

  @override
  void dispose() {
    _xmlTextController.dispose();
    super.dispose();
  }

  Future<void> _processBytes(Uint8List bytes, String fileName) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final result = await widget.viewModel.importScoreFromBytes(bytes, fileName);
      if (!mounted) return;

      if (result != null) {
        setState(() {
          _isProcessing = false;
          _statusMessage =
              "¡Importado con éxito! Formato: ${result.format} • ${result.totalMeasures} compases • ${result.totalNotes} notas.";
          _isError = false;
        });

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: widget.viewModel.currentPalette.primaryAccent,
            content: Text(
              "Partitura '${result.package.title}' cargada en el pentagrama.",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = "No fue posible decodificar el archivo. Formato no compatible.";
          _isError = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _statusMessage = "Error en el análisis: $e";
        _isError = true;
      });
    }
  }

  void _loadSampleMusicXml() {
    final bytes = Uint8List.fromList(utf8.encode(_odeToJoyMusicXmlSample));
    _processBytes(bytes, "himno_alegria.musicxml");
  }

  void _loadSampleMidi() {
    // Generación binaria sintética de un mini MIDI estándar Type 0 para prueba
    // MThd: 6 bytes, Format 0, 1 Track, 480 PPQ
    // MTrk: NoteOn (pitch 60 = Do4) -> Delta 480 -> NoteOff
    final header = [
      0x4D, 0x54, 0x68, 0x64, // MThd
      0x00, 0x00, 0x00, 0x06, // length 6
      0x00, 0x00,             // format 0
      0x00, 0x01,             // 1 track
      0x01, 0xE0,             // 480 PPQ
    ];

    final trackEvents = [
      // Delta 0, NoteOn Ch 0, Pitch 60 (Do4), Vel 90
      0x00, 0x90, 0x3C, 0x5A,
      // Delta 480 (0x83, 0x60 en VLQ), NoteOff Ch 0, Pitch 60, Vel 0
      0x83, 0x60, 0x80, 0x3C, 0x00,
      // Delta 0, NoteOn Ch 0, Pitch 64 (Mi4), Vel 90
      0x00, 0x90, 0x40, 0x5A,
      // Delta 480, NoteOff Ch 0, Pitch 64, Vel 0
      0x83, 0x60, 0x80, 0x40, 0x00,
      // Delta 0, NoteOn Ch 0, Pitch 67 (Sol4), Vel 90
      0x00, 0x90, 0x43, 0x5A,
      // Delta 960 (Blanca = 2 * 480 = 0x87, 0x40 en VLQ), NoteOff Ch 0, Pitch 67
      0x87, 0x40, 0x80, 0x43, 0x00,
      // End of Track Meta-event (FF 2F 00)
      0x00, 0xFF, 0x2F, 0x00,
    ];

    final trackLen = trackEvents.length;
    final trackHeader = [
      0x4D, 0x54, 0x72, 0x6B, // MTrk
      (trackLen >> 24) & 0xFF,
      (trackLen >> 16) & 0xFF,
      (trackLen >> 8) & 0xFF,
      trackLen & 0xFF,
    ];

    final midiBytes = Uint8List.fromList([...header, ...trackHeader, ...trackEvents]);
    _processBytes(midiBytes, "arpegio_estudio.mid");
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.viewModel.currentPalette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner explicativo
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.scaffoldBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.surfaceBorderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.file_open_outlined, color: palette.primaryAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Importador Universal Offline",
                        style: TextStyle(
                          color: palette.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Soporta partituras MusicXML (.xml, .musicxml) y archivos MIDI (.mid, .midi) sin conexión.",
                        style: TextStyle(color: palette.textMutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Selector de Archivo Nativo
          if (widget.filePicker != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.folder_open, size: 20),
              label: const Text(
                "Seleccionar Archivo Local del Dispositivo",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.secondaryAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isProcessing
                  ? null
                  : () async {
                      final picked = await widget.filePicker!();
                      if (picked != null) {
                        _processBytes(picked.bytes, picked.fileName);
                      }
                    },
            ),

          if (widget.filePicker != null) const SizedBox(height: 16),

          // Presets / Muestras de prueba con 1 toque
          Text(
            "MUESTRAS CANÓNICAS PARA PRUEBA RÁPIDA",
            style: TextStyle(
              color: palette.textMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.description, size: 16, color: palette.primaryAccent),
                  label: Text(
                    "Beethoven (MusicXML)",
                    style: TextStyle(color: palette.textColor, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.surfaceBorderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessing ? null : _loadSampleMusicXml,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.piano, size: 16, color: palette.secondaryAccent),
                  label: Text(
                    "Arpegio (MIDI)",
                    style: TextStyle(color: palette.textColor, fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.surfaceBorderColor),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isProcessing ? null : _loadSampleMidi,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Pegar código MusicXML manual
          Text(
            "O PEGAR CÓDIGO XML DIRECTO",
            style: TextStyle(
              color: palette.textMutedColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _xmlTextController,
            maxLines: 5,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: palette.textColor,
            ),
            decoration: InputDecoration(
              hintText: "Pegue aquí el contenido <score-partwise>...",
              hintStyle: TextStyle(color: palette.textMutedColor.withValues(alpha: 0.5)),
              filled: true,
              fillColor: palette.scaffoldBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.surfaceBorderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.surfaceBorderColor),
              ),
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primaryAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isProcessing
                ? null
                : () {
                    final text = _xmlTextController.text.trim();
                    if (text.isEmpty) {
                      setState(() {
                        _statusMessage = "Por favor ingrese código XML o seleccione una muestra.";
                        _isError = true;
                      });
                      return;
                    }
                    final bytes = Uint8List.fromList(utf8.encode(text));
                    _processBytes(bytes, "partitura_pegada.musicxml");
                  },
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : const Text(
                    "Decodificar y Montar en Pentagrama",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isError
                    ? palette.errorPitchColor.withValues(alpha: 0.15)
                    : palette.primaryAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isError ? palette.errorPitchColor : palette.primaryAccent,
                ),
              ),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _isError ? palette.errorPitchColor : palette.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
