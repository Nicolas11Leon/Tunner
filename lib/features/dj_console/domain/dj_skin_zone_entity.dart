import 'dj_action.dart';

/// Control category on physical DJ hardware.
enum DjControlType {
  button,
  pad,
  knob,
  fader,
  jogWheel,
}

/// Normalized interactive zone on a physical DJ console skin.
///
/// Coordinates (x, y, width, height) are normalized in range [0.0, 1.0]
/// relative to the full hardware console dimensions.
class DjSkinZoneEntity {
  final String id;
  final String label;
  final String? deckId;
  final DjControlType controlType;
  final DjAction action;
  final double normalizedX;
  final double normalizedY;
  final double normalizedWidth;
  final double normalizedHeight;
  final int ledColor; // 32-bit ARGB color
  final bool isLedLit;

  const DjSkinZoneEntity({
    required this.id,
    required this.label,
    this.deckId,
    required this.controlType,
    required this.action,
    required this.normalizedX,
    required this.normalizedY,
    required this.normalizedWidth,
    required this.normalizedHeight,
    this.ledColor = 0xFF00E676,
    this.isLedLit = false,
  });

  /// Checks if a normalized point (nx, ny) falls inside this zone.
  bool containsNormalized(double nx, double ny) {
    return nx >= normalizedX &&
        nx <= (normalizedX + normalizedWidth) &&
        ny >= normalizedY &&
        ny <= (normalizedY + normalizedHeight);
  }

  DjSkinZoneEntity copyWith({
    String? id,
    String? label,
    String? deckId,
    DjControlType? controlType,
    DjAction? action,
    double? normalizedX,
    double? normalizedY,
    double? normalizedWidth,
    double? normalizedHeight,
    int? ledColor,
    bool? isLedLit,
  }) {
    return DjSkinZoneEntity(
      id: id ?? this.id,
      label: label ?? this.label,
      deckId: deckId ?? this.deckId,
      controlType: controlType ?? this.controlType,
      action: action ?? this.action,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      normalizedWidth: normalizedWidth ?? this.normalizedWidth,
      normalizedHeight: normalizedHeight ?? this.normalizedHeight,
      ledColor: ledColor ?? this.ledColor,
      isLedLit: isLedLit ?? this.isLedLit,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'deckId': deckId,
        'controlType': controlType.name,
        'action': action.name,
        'normalizedX': normalizedX,
        'normalizedY': normalizedY,
        'normalizedWidth': normalizedWidth,
        'normalizedHeight': normalizedHeight,
        'ledColor': ledColor,
      };

  factory DjSkinZoneEntity.fromJson(Map<String, dynamic> json) {
    return DjSkinZoneEntity(
      id: json['id'] as String,
      label: json['label'] as String,
      deckId: json['deckId'] as String?,
      controlType: DjControlType.values.firstWhere(
        (t) => t.name == json['controlType'],
        orElse: () => DjControlType.button,
      ),
      action: DjAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => DjAction.deckAPlayPause,
      ),
      normalizedX: (json['normalizedX'] as num).toDouble(),
      normalizedY: (json['normalizedY'] as num).toDouble(),
      normalizedWidth: (json['normalizedWidth'] as num).toDouble(),
      normalizedHeight: (json['normalizedHeight'] as num).toDouble(),
      ledColor: json['ledColor'] as int? ?? 0xFF00E676,
    );
  }
}
