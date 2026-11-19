import 'studio_dock_zone.dart';

/// Descriptor puro de dominio para un módulo o panel desacoplable del estudio.
/// No contiene referencias a widgets ni iconos de Flutter.
class StudioPanelDescriptor {
  final String id;
  final String title;
  final String subtitle;
  final String iconKey;
  final StudioDockZone currentZone;
  final bool isClosable;
  final bool isDetachable;

  const StudioPanelDescriptor({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.iconKey = 'panel',
    this.currentZone = StudioDockZone.center,
    this.isClosable = true,
    this.isDetachable = true,
  });

  StudioPanelDescriptor copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? iconKey,
    StudioDockZone? currentZone,
    bool? isClosable,
    bool? isDetachable,
  }) {
    return StudioPanelDescriptor(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconKey: iconKey ?? this.iconKey,
      currentZone: currentZone ?? this.currentZone,
      isClosable: isClosable ?? this.isClosable,
      isDetachable: isDetachable ?? this.isDetachable,
    );
  }
}
