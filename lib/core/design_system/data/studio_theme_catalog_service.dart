import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/studio_theme_skin_entity.dart';
import '../studio_theme_provider.dart';

/// Servicio de catálogo y gestión de estéticas / skins descargables de estudio.
/// Permite conmutar temas en tiempo real, importar paquetes .tntheme y exportar configuraciones.
class StudioThemeCatalogService extends ChangeNotifier {
  static final StudioThemeCatalogService _instance = StudioThemeCatalogService._internal();
  factory StudioThemeCatalogService({StudioThemeController? controller}) {
    if (controller != null) {
      _instance._controller = controller;
    }
    return _instance;
  }

  StudioThemeCatalogService._internal() {
    _skins = List<StudioThemeSkinEntity>.from(StudioThemeSkinEntity.defaultCatalog);
    _activeSkin = StudioThemeSkinEntity.obsidianPro;
  }

  StudioThemeController? _controller;
  late List<StudioThemeSkinEntity> _skins;
  late StudioThemeSkinEntity _activeSkin;

  List<StudioThemeSkinEntity> get availableSkins => List.unmodifiable(_skins);
  StudioThemeSkinEntity get activeSkin => _activeSkin;

  void bindController(StudioThemeController controller) {
    _controller = controller;
    _controller?.setTokens(_activeSkin.toDesignTokens());
  }

  /// Selecciona y activa una estética del catálogo por su ID.
  void selectSkin(String skinId) {
    final match = _skins.firstWhere(
      (s) => s.id == skinId,
      orElse: () => StudioThemeSkinEntity.obsidianPro,
    );
    _activeSkin = match;
    _controller?.setTokens(match.toDesignTokens());
    notifyListeners();
  }

  /// Exporta la estética indicada en formato JSON (.tntheme).
  String exportThemeToJson(String skinId) {
    final match = _skins.firstWhere(
      (s) => s.id == skinId,
      orElse: () => _activeSkin,
    );
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(match.toJson());
  }

  /// Importa una nueva estética desde una cadena JSON (.tntheme).
  StudioThemeSkinEntity importThemeFromJson(String jsonString) {
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      final skin = StudioThemeSkinEntity.fromJson(map);

      // Si ya existe una skin con este ID, reemplazarla; sino agregarla
      final existingIndex = _skins.indexWhere((s) => s.id == skin.id);
      if (existingIndex >= 0) {
        _skins[existingIndex] = skin;
      } else {
        _skins.add(skin);
      }

      selectSkin(skin.id);
      return skin;
    } catch (e) {
      throw FormatException('El archivo de estética no es un paquete .tntheme válido: $e');
    }
  }

  /// Reinicia el catálogo a las 5 estéticas canónicas predeterminadas.
  void resetToDefaults() {
    _skins = List<StudioThemeSkinEntity>.from(StudioThemeSkinEntity.defaultCatalog);
    selectSkin(StudioThemeSkinEntity.obsidianPro.id);
  }
}
