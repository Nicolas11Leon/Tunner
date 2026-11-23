import 'dart:typed_data';

import '../core/file_system/domain/i_workspace_seed_provider.dart';
import '../features/dj_console/domain/dj_audio_processor.dart';
import '../features/instrument/domain/procedural_instrument_synthesizer.dart';
import '../features/instrument/domain/universal_instrument_definition.dart';

/// Adaptador de aplicación que genera los archivos WAV semilla del workspace usando los motores de features.
class StudioWorkspaceSeedProvider implements IWorkspaceSeedProvider {
  const StudioWorkspaceSeedProvider();

  @override
  Future<Map<String, Uint8List>> buildSeedBinaryFiles() async {
    final a4Samples = ProceduralInstrumentSynthesizer.synthesizeNote(
      instrument: UniversalInstrumentDefinition.fluteConcert,
      frequencyHz: 440.0,
      durationSeconds: 2.5,
    );
    final a4WavBytes = ProceduralInstrumentSynthesizer.floatBufferToWavBytes(a4Samples);

    final grooveSamples = DjAudioProcessor().generateDemoGroove(
      bpm: 124.0,
      frequencyHz: 55.0,
      durationMs: 7740,
    );
    final grooveWavBytes = ProceduralInstrumentSynthesizer.floatBufferToWavBytes(grooveSamples);

    return <String, Uint8List>{
      'Tomas de Audio & WAV/Toma_Acustica_440Hz.wav': a4WavBytes,
      'Tomas de Audio & WAV/Loop_Club_Groove_124BPM.wav': grooveWavBytes,
    };
  }
}
