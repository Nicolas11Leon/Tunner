import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/instrument_customization_profile.dart';
import '../domain/musical_phrase_entity.dart';
import '../data/procedural_instrument_synthesizer.dart';
import 'instrument_customization_modal.dart';

/// Teclado Maestro Emulador Universal Polifónico y Reproductor de Estrofas.
/// Permite simular y escuchar cualquier nota, acorde o frase musical estructurada
/// en el instrumento activo con todas sus personalizaciones tímbricas y microtonales.
class UniversalMasterKeyboardWidget extends StatefulWidget {
  final InstrumentCustomizationProfile customization;
  final ValueChanged<InstrumentCustomizationProfile>? onCustomizationUpdated;
  final ValueChanged<double>? onNotePlayed; // Retorna la frecuencia en Hz ejecutada

  const UniversalMasterKeyboardWidget({
    super.key,
    required this.customization,
    this.onCustomizationUpdated,
    this.onNotePlayed,
  });

  static void show(
    BuildContext context, {
    required InstrumentCustomizationProfile customization,
    ValueChanged<InstrumentCustomizationProfile>? onUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: UniversalMasterKeyboardWidget(
          customization: customization,
          onCustomizationUpdated: onUpdated,
        ),
      ),
    );
  }

  @override
  State<UniversalMasterKeyboardWidget> createState() => _UniversalMasterKeyboardWidgetState();
}

class _UniversalMasterKeyboardWidgetState extends State<UniversalMasterKeyboardWidget> {
  late InstrumentCustomizationProfile _profile;
  int _octaveShift = 4; // C4 por defecto
  MusicalPhraseEntity _selectedPhrase = MusicalPhraseEntity.majorConcertArpeggio;
  bool _isPlayingPhrase = false;
  int? _activePlayingNote;
  Timer? _phraseTimer;

  @override
  void initState() {
    super.initState();
    _profile = widget.customization;
  }

  @override
  void didUpdateWidget(covariant UniversalMasterKeyboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customization != widget.customization) {
      _profile = widget.customization;
    }
  }

  @override
  void dispose() {
    _phraseTimer?.cancel();
    super.dispose();
  }

  void _playNote(int midiNote) {
    final freqHz = _profile.calculateFrequencyForMidiNote(midiNote);
    widget.onNotePlayed?.call(freqHz);

    // Sintetizar en memoria (ejecución offline)
    ProceduralInstrumentSynthesizer.synthesizeCustomNote(
      customization: _profile,
      frequencyHz: freqHz,
      durationSeconds: 0.8,
    );

    setState(() => _activePlayingNote = midiNote);
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _activePlayingNote == midiNote) {
        setState(() => _activePlayingNote = null);
      }
    });
  }

  void _togglePlayPhrase() {
    if (_isPlayingPhrase) {
      _phraseTimer?.cancel();
      setState(() {
        _isPlayingPhrase = false;
        _activePlayingNote = null;
      });
      return;
    }

    // Sintetizar el buffer de la estrofa completa
    ProceduralInstrumentSynthesizer.synthesizePhrase(
      customization: _profile,
      phrase: _selectedPhrase,
    );

    setState(() => _isPlayingPhrase = true);

    int noteIndex = 0;
    final secondsPerTick = 60.0 / (_selectedPhrase.defaultBpm * 4.0);

    void playNext() {
      if (!mounted || !_isPlayingPhrase) return;
      if (noteIndex >= _selectedPhrase.notes.length) {
        setState(() {
          _isPlayingPhrase = false;
          _activePlayingNote = null;
        });
        return;
      }

      final note = _selectedPhrase.notes[noteIndex];
      final noteDurationMs = (note.durationTicks * secondsPerTick * 1000).toInt();

      if (!note.isRest) {
        setState(() => _activePlayingNote = note.midiNote);
        final freqHz = _profile.calculateFrequencyForMidiNote(note.midiNote);
        widget.onNotePlayed?.call(freqHz);
      } else {
        setState(() => _activePlayingNote = null);
      }

      noteIndex++;
      _phraseTimer = Timer(Duration(milliseconds: noteDurationMs), playNext);
    }

    playNext();
  }

  @override
  Widget build(BuildContext context) {
    final instrument = _profile.instrument;
    final primaryColor = instrument.visualProfile.primaryAccentColor;
    final baseMidi = (_octaveShift + 1) * 12;

    return Container(
      height: 480,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Barra de cabecera con selector de octava y acceso a personalización
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(instrument.visualProfile.smuflGlyph, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'TECLADO MAESTRO • ${instrument.displayName.toUpperCase()}',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.tune, color: primaryColor, size: 20),
                tooltip: 'Personalizar Afinación & Timbre',
                onPressed: () {
                  InstrumentCustomizationModal.show(
                    context,
                    currentProfile: _profile,
                    onUpdated: (newProf) {
                      setState(() => _profile = newProf);
                      widget.onCustomizationUpdated?.call(newProf);
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Selector de Estrofas Musicales / Frases
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.queue_music, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MusicalPhraseEntity>(
                      value: _selectedPhrase,
                      dropdownColor: const Color(0xFF1E293B),
                      isDense: true,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      items: MusicalPhraseEntity.canonicalPhrases.map((phrase) {
                        return DropdownMenuItem(
                          value: phrase,
                          child: Text(
                            phrase.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      }).toList(),
                      onChanged: (phrase) {
                        if (phrase != null) {
                          setState(() => _selectedPhrase = phrase);
                        }
                      },
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPlayingPhrase ? const Color(0xFFEF4444) : primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  icon: Icon(_isPlayingPhrase ? Icons.stop : Icons.play_arrow, size: 16),
                  label: Text(
                    _isPlayingPhrase ? 'PARAR' : 'REPRODUCIR ESTROFA',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _togglePlayPhrase,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Barra de controles de octava (- / +)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                tooltip: 'Bajar Octava',
                onPressed: _octaveShift > 1 ? () => setState(() => _octaveShift--) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'OCTAVA: C$_octaveShift - B${_octaveShift + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 22),
                tooltip: 'Subir Octava',
                onPressed: _octaveShift < 7 ? () => setState(() => _octaveShift++) : null,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Teclado cromático polifónico interactivo (2 octavas)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const totalWhiteKeys = 14;
                final whiteKeyWidth = constraints.maxWidth / totalWhiteKeys;
                final blackKeyWidth = whiteKeyWidth * 0.65;
                final blackKeyHeight = constraints.maxHeight * 0.62;

                final whiteOffsets = [0, 2, 4, 5, 7, 9, 11];
                final whiteNames = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Si'];
                final hasBlackKeyAfter = [true, true, false, true, true, true, false];

                return Stack(
                  children: [
                    // Capa de teclas blancas
                    Row(
                      children: List.generate(totalWhiteKeys, (i) {
                        final octave = i ~/ 7;
                        final noteIdx = i % 7;
                        final midiNote = baseMidi + octave * 12 + whiteOffsets[noteIdx];
                        final isHit = _activePlayingNote == midiNote;

                        return Expanded(
                          child: GestureDetector(
                            onTapDown: (_) => _playNote(midiNote),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 60),
                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                              decoration: BoxDecoration(
                                color: isHit ? primaryColor : const Color(0xFFF8FAFC),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                border: Border.all(color: Colors.black26),
                              ),
                              alignment: Alignment.bottomCenter,
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '${whiteNames[noteIdx]}${_octaveShift + octave}',
                                style: TextStyle(
                                  color: isHit ? Colors.black : Colors.black87,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    // Capa de teclas negras
                    for (int i = 0; i < totalWhiteKeys - 1; i++)
                      if (hasBlackKeyAfter[i % 7])
                        Positioned(
                          left: (i + 1) * whiteKeyWidth - (blackKeyWidth / 2),
                          top: 0,
                          width: blackKeyWidth,
                          height: blackKeyHeight,
                          child: Builder(
                            builder: (context) {
                              final octave = i ~/ 7;
                              final noteIdx = i % 7;
                              final midiNote = baseMidi + octave * 12 + whiteOffsets[noteIdx] + 1;
                              final isHit = _activePlayingNote == midiNote;

                              return GestureDetector(
                                onTapDown: (_) => _playNote(midiNote),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 60),
                                  decoration: BoxDecoration(
                                    color: isHit ? primaryColor : const Color(0xFF0F172A),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                                    border: Border.all(color: isHit ? primaryColor : Colors.white12),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
