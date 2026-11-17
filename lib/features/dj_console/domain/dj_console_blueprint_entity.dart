import 'dj_action.dart';
import 'dj_hardware_skin_entity.dart';
import 'dj_keymap_profile_entity.dart';
import 'dj_skin_zone_entity.dart';

/// Especificación canónica y serializable de una consola DJ física para emulación por archivo.
///
/// Permite definir cualquier modelo de consola (Pioneer, Denon, Traktor, Roland, Numark, etc.)
/// con sus dimensiones físicas, zonas interactivas vectoriales y asignaciones de teclado QWERTY.
class DjConsoleBlueprintEntity {
  final String id;
  final String name;
  final String manufacturer;
  final String version;
  final String description;
  final double aspectRatio;
  final int chassisColor;
  final int accentColor;
  final List<DjSkinZoneEntity> zones;
  final Map<String, DjAction> keyBindings;

  const DjConsoleBlueprintEntity({
    required this.id,
    required this.name,
    required this.manufacturer,
    this.version = '1.0.0',
    this.description = '',
    this.aspectRatio = 16.0 / 9.0,
    this.chassisColor = 0xFF141722,
    this.accentColor = 0xFF00E5FF,
    required this.zones,
    this.keyBindings = const {},
  });

  /// Convierte el plano a la entidad de renderizado [DjHardwareSkinEntity].
  DjHardwareSkinEntity toHardwareSkin() {
    return DjHardwareSkinEntity(
      id: id,
      name: name,
      manufacturer: manufacturer,
      aspectRatio: aspectRatio,
      chassisColor: chassisColor,
      accentColor: accentColor,
      zones: zones,
    );
  }

  /// Genera el perfil de mapeo de teclado [DjKeymapProfileEntity] asociado a este plano.
  DjKeymapProfileEntity toKeymapProfile() {
    return DjKeymapProfileEntity(
      id: 'keymap_$id',
      name: '$name (Teclado)',
      keyBindings: keyBindings,
    );
  }

  /// Crea un plano a partir de una [DjHardwareSkinEntity] existente y un perfil de teclado opcional.
  factory DjConsoleBlueprintEntity.fromHardwareSkin(
    DjHardwareSkinEntity skin, {
    DjKeymapProfileEntity? keymapProfile,
    String description = '',
  }) {
    final bindings = <String, DjAction>{};
    if (keymapProfile != null) {
      bindings.addAll(keymapProfile.keyBindings);
    }
    return DjConsoleBlueprintEntity(
      id: skin.id,
      name: skin.name,
      manufacturer: skin.manufacturer,
      aspectRatio: skin.aspectRatio,
      chassisColor: skin.chassisColor,
      accentColor: skin.accentColor,
      zones: skin.zones,
      keyBindings: bindings,
      description: description,
    );
  }

  DjConsoleBlueprintEntity copyWith({
    String? id,
    String? name,
    String? manufacturer,
    String? version,
    String? description,
    double? aspectRatio,
    int? chassisColor,
    int? accentColor,
    List<DjSkinZoneEntity>? zones,
    Map<String, DjAction>? keyBindings,
  }) {
    return DjConsoleBlueprintEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      version: version ?? this.version,
      description: description ?? this.description,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      chassisColor: chassisColor ?? this.chassisColor,
      accentColor: accentColor ?? this.accentColor,
      zones: zones ?? this.zones,
      keyBindings: keyBindings ?? this.keyBindings,
    );
  }

  Map<String, dynamic> toJson() => {
        'format': 'tunner.djconsole',
        'formatVersion': '1.0.0',
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
        'version': version,
        'description': description,
        'aspectRatio': aspectRatio,
        'chassisColor': chassisColor,
        'accentColor': accentColor,
        'zones': zones.map((z) => z.toJson()).toList(),
        'keyBindings': keyBindings.map((key, action) => MapEntry(key, action.name)),
      };

  factory DjConsoleBlueprintEntity.fromJson(Map<String, dynamic> json) {
    final rawZones = (json['zones'] as List<dynamic>?) ?? [];
    final zonesList = rawZones
        .map((z) => DjSkinZoneEntity.fromJson(z as Map<String, dynamic>))
        .toList();

    final rawBindings = (json['keyBindings'] as Map<String, dynamic>?) ?? {};
    final bindings = <String, DjAction>{};
    for (final entry in rawBindings.entries) {
      try {
        final action = DjAction.values.byName(entry.value.toString());
        bindings[entry.key] = action;
      } catch (_) {
        // Ignorar acciones no reconocidas de forma segura
      }
    }

    return DjConsoleBlueprintEntity(
      id: json['id'] as String? ?? 'custom_console',
      name: json['name'] as String? ?? 'Consola Personalizada',
      manufacturer: json['manufacturer'] as String? ?? 'Generico',
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? (16.0 / 9.0),
      chassisColor: json['chassisColor'] as int? ?? 0xFF141722,
      accentColor: json['accentColor'] as int? ?? 0xFF00E5FF,
      zones: zonesList,
      keyBindings: bindings,
    );
  }
}
