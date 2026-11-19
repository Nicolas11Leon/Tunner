import 'package:flutter/widgets.dart';
import '../domain/studio_dock_zone.dart';

/// Descriptor de presentación para un módulo o herramienta desacoplable y arrastrable.
class StudioDockablePanelEntity {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final StudioDockZone currentZone;
  final bool isClosable;
  final bool isDetachable;
  final Widget Function(BuildContext context)? builder;

  const StudioDockablePanelEntity({
    required this.id,
    required this.title,
    this.subtitle = '',
    required this.icon,
    this.currentZone = StudioDockZone.center,
    this.isClosable = true,
    this.isDetachable = true,
    this.builder,
  });

  StudioDockablePanelEntity copyWith({
    String? id,
    String? title,
    String? subtitle,
    IconData? icon,
    StudioDockZone? currentZone,
    bool? isClosable,
    bool? isDetachable,
    Widget Function(BuildContext context)? builder,
  }) {
    return StudioDockablePanelEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      icon: icon ?? this.icon,
      currentZone: currentZone ?? this.currentZone,
      isClosable: isClosable ?? this.isClosable,
      isDetachable: isDetachable ?? this.isDetachable,
      builder: builder ?? this.builder,
    );
  }
}
