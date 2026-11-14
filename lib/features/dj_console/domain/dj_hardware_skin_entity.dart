import 'dj_action.dart';
import 'dj_skin_zone_entity.dart';

/// Represents a full procedural vector layout skin mimicking real DJ hardware.
class DjHardwareSkinEntity {
  final String id;
  final String name;
  final String manufacturer;
  final double aspectRatio;
  final int chassisColor;
  final int accentColor;
  final List<DjSkinZoneEntity> zones;

  const DjHardwareSkinEntity({
    required this.id,
    required this.name,
    required this.manufacturer,
    this.aspectRatio = 16.0 / 9.0,
    this.chassisColor = 0xFF121214,
    this.accentColor = 0xFF2979FF,
    required this.zones,
  });

  /// Finds a specific zone by unique ID.
  DjSkinZoneEntity? findZoneById(String zoneId) {
    for (final zone in zones) {
      if (zone.id == zoneId) return zone;
    }
    return null;
  }

  /// Finds the zone occupying the normalized coordinate point [nx, ny].
  DjSkinZoneEntity? findZoneAt(double nx, double ny) {
    for (final zone in zones) {
      if (zone.containsNormalized(nx, ny)) {
        return zone;
      }
    }
    return null;
  }

  /// Returns all zones tied to a given action (e.g. deckAPlayPause).
  List<DjSkinZoneEntity> findZonesByAction(DjAction action) {
    return zones.where((z) => z.action == action).toList();
  }

  /// Clones skin with updated zone LED states for active actions.
  DjHardwareSkinEntity withActiveActions(Set<DjAction> activeActions) {
    final updatedZones = zones.map((zone) {
      final isLit = activeActions.contains(zone.action);
      if (zone.isLedLit == isLit) return zone;
      return zone.copyWith(isLedLit: isLit);
    }).toList();

    return copyWith(zones: updatedZones);
  }

  DjHardwareSkinEntity copyWith({
    String? id,
    String? name,
    String? manufacturer,
    double? aspectRatio,
    int? chassisColor,
    int? accentColor,
    List<DjSkinZoneEntity>? zones,
  }) {
    return DjHardwareSkinEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      manufacturer: manufacturer ?? this.manufacturer,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      chassisColor: chassisColor ?? this.chassisColor,
      accentColor: accentColor ?? this.accentColor,
      zones: zones ?? this.zones,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'manufacturer': manufacturer,
        'aspectRatio': aspectRatio,
        'chassisColor': chassisColor,
        'accentColor': accentColor,
        'zones': zones.map((z) => z.toJson()).toList(),
      };

  factory DjHardwareSkinEntity.fromJson(Map<String, dynamic> json) {
    final rawZones = json['zones'] as List<dynamic>? ?? [];
    return DjHardwareSkinEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      manufacturer: json['manufacturer'] as String,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? (16.0 / 9.0),
      chassisColor: json['chassisColor'] as int? ?? 0xFF121214,
      accentColor: json['accentColor'] as int? ?? 0xFF2979FF,
      zones: rawZones
          .map((z) => DjSkinZoneEntity.fromJson(z as Map<String, dynamic>))
          .toList(),
    );
  }
}
