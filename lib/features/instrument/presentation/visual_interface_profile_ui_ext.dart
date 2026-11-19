import 'package:flutter/material.dart';
import '../domain/visual_interface_profile.dart';

/// Extensión de presentación para convertir los códigos ARGB32 de [VisualInterfaceProfile]
/// en objetos [Color] de Flutter UI.
extension VisualInterfaceProfileUiExt on VisualInterfaceProfile {
  Color get primaryAccentColor => Color(primaryAccentHex);
  Color get secondaryAccentColor => Color(secondaryAccentHex);
  Color get surfaceColor => Color(surfaceHex);
}
