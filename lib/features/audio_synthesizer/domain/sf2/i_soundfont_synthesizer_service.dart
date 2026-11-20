import 'dart:typed_data';
import 'sf2_models.dart';
import 'tunner_acoustic_soundfont_bank.dart';

/// Contrato abstracto de dominio para la síntesis instrumental con SoundFont SF2.
abstract class ISoundFontSynthesizerService {
  Sf2SoundFont get activeSoundFont;
  int get activePatch;
  List<Sf2Preset> get availablePresets;

  void loadSoundFontFromBytes(Uint8List sf2Bytes);
  void resetToEssentialsBank();
  void selectPatch(int patch);
  Uint8List synthesizeNoteWav({
    required int midiPitch,
    double durationSeconds = 1.0,
    int velocity = 100,
    int sampleRate = 44100,
  });
}

/// Implementación No-Op para entornos de prueba desacoplados sin síntesis SF2.
class NoOpSoundFontSynthesizerService implements ISoundFontSynthesizerService {
  const NoOpSoundFontSynthesizerService();

  @override
  Sf2SoundFont get activeSoundFont => TunnerAcousticSoundFontBank.buildAcousticEssentialsBank();

  @override
  int get activePatch => 0;

  @override
  List<Sf2Preset> get availablePresets => const [];

  @override
  void loadSoundFontFromBytes(Uint8List sf2Bytes) {}

  @override
  void resetToEssentialsBank() {}

  @override
  void selectPatch(int patch) {}

  @override
  Uint8List synthesizeNoteWav({
    required int midiPitch,
    double durationSeconds = 1.0,
    int velocity = 100,
    int sampleRate = 44100,
  }) =>
      Uint8List(44);
}
