import 'package:flutter/foundation.dart';
import '../../modular_rack/domain/rack_module_entity.dart';

/// Preset serializable de una herramienta modular individual de Tunner (.tnt).
@immutable
class TunnerToolPreset {
  /// Versión del esquema del preset.
  final int schemaVersion;

  /// Identificador del tipo de módulo.
  final String moduleTypeCode;

  /// Nombre o alias personalizado asignado por el usuario.
  final String customTitle;

  /// Modo de visualización preferido (compact o expanded).
  final String defaultViewMode;

  /// Estado de encendido predeterminado.
  final bool isPoweredOn;

  /// Parámetros o configuraciones específicas de la herramienta (JSON libre).
  final Map<String, dynamic> toolParameters;

  /// Timestamp de creación o guardado en microsegundos.
  final int savedAtMicros;

  const TunnerToolPreset({
    this.schemaVersion = 1,
    required this.moduleTypeCode,
    required this.customTitle,
    this.defaultViewMode = 'expanded',
    this.isPoweredOn = true,
    this.toolParameters = const {},
    required this.savedAtMicros,
  });

  /// Crea un preset a partir de una entidad de módulo activa.
  factory TunnerToolPreset.fromModule(RackModuleEntity module, {Map<String, dynamic> parameters = const {}}) {
    return TunnerToolPreset(
      schemaVersion: 1,
      moduleTypeCode: module.moduleType.code,
      customTitle: module.title,
      defaultViewMode: module.viewMode.code,
      isPoweredOn: module.isPoweredOn,
      toolParameters: parameters,
      savedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  /// Reconstruye una entidad de módulo a partir del preset.
  RackModuleEntity toModuleEntity(int orderIndex, {String? customId}) {
    final type = RackModuleType.values.firstWhere(
      (t) => t.code == moduleTypeCode,
      orElse: () => RackModuleType.strobeTuner,
    );
    final standard = RackModuleEntity.standard(type, orderIndex, customId: customId);
    return standard.copyWith(
      title: customTitle,
      viewMode: defaultViewMode == 'compact' ? ModuleViewMode.compact : ModuleViewMode.expanded,
      isPoweredOn: isPoweredOn,
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'moduleTypeCode': moduleTypeCode,
    'customTitle': customTitle,
    'defaultViewMode': defaultViewMode,
    'isPoweredOn': isPoweredOn,
    'toolParameters': toolParameters,
    'savedAtMicros': savedAtMicros,
  };

  factory TunnerToolPreset.fromJson(Map<String, dynamic> json) {
    return TunnerToolPreset(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      moduleTypeCode: json['moduleTypeCode'] as String,
      customTitle: json['customTitle'] as String,
      defaultViewMode: json['defaultViewMode'] as String? ?? 'expanded',
      isPoweredOn: json['isPoweredOn'] as bool? ?? true,
      toolParameters: (json['toolParameters'] as Map<String, dynamic>?) ?? const {},
      savedAtMicros: json['savedAtMicros'] as int? ?? 0,
    );
  }
}
