import 'package:flutter/material.dart';
import '../domain/app_tool_item.dart';

IconData _resolveToolIcon(String iconKey) {
  switch (iconKey) {
    case 'album':
      return Icons.album;
    case 'av_timer':
      return Icons.av_timer;
    case 'compare_arrows':
      return Icons.compare_arrows;
    case 'edit_note':
      return Icons.edit_note;
    case 'fiber_manual_record':
      return Icons.fiber_manual_record;
    case 'file_upload':
      return Icons.file_upload;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'graphic_eq':
      return Icons.graphic_eq;
    case 'history_edu':
      return Icons.history_edu;
    case 'library_music':
      return Icons.library_music;
    case 'menu_book':
      return Icons.menu_book;
    case 'mic':
      return Icons.mic;
    case 'mic_external_on':
      return Icons.mic_external_on;
    case 'mic_external_on_outlined':
      return Icons.mic_external_on_outlined;
    case 'music_note':
      return Icons.music_note;
    case 'piano':
      return Icons.piano;
    case 'picture_as_pdf':
      return Icons.picture_as_pdf;
    case 'school':
      return Icons.school;
    case 'science':
      return Icons.science;
    case 'settings':
      return Icons.settings;
    case 'touch_app':
      return Icons.touch_app;
    case 'waves':
      return Icons.waves;
    case 'tune':
    default:
      return Icons.tune;
  }
}

/// Extensión de presentación para resolver el icono Material de [AppToolCategory].
extension AppToolCategoryUiExt on AppToolCategory {
  IconData get icon => _resolveToolIcon(iconKey);
}

/// Extensión de presentación para resolver el icono Material de [AppToolItem].
extension AppToolItemUiExt on AppToolItem {
  IconData get icon => _resolveToolIcon(iconKey);
}
