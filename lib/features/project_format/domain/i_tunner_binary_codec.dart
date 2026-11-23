import 'dart:typed_data';
import 'tunner_project_package.dart';
import 'tunner_tool_preset.dart';

/// Contrato de dominio puro para códecs binarios de proyectos (`.tunner`)
/// y presets individuales de herramientas (`.tnt`).
abstract class ITunnerBinaryCodec {
  int get maxAllowedDecompressedBytes;

  Uint8List encodeProject(TunnerProjectPackage project);
  TunnerProjectPackage decodeProject(Uint8List bytes);

  Uint8List encodeToolPreset(TunnerToolPreset tool);
  TunnerToolPreset decodeToolPreset(Uint8List bytes);
}
