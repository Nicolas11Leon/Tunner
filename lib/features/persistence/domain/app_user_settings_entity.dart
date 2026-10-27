import 'dart:convert';
import '../../../core/theme/tunner_theme.dart';
import '../../practice_evaluator/domain/practice_report_entity.dart';
import '../../practice_recorder/domain/practice_recording_entity.dart';

/// Modo de experiencia de interfaz de usuario.
enum AppDisplayMode {
  /// Modo Esencial: limpio, minimalista, enfocado en la nota gigante, tolerancia visual y estroboscopio.
  essential,

  /// Modo Conservatorio Pro: atril de partitura SMuFL, stems, espectrograma, editor y analítica completa.
  conservatoryPro,
}

/// Entidad inmutable de dominio que agrupa todas las preferencias, calibraciones,
/// temas personalizados e historial persistible del usuario de Tunner.
class AppUserSettingsEntity {
  final double referencePitch;
  final String selectedThemeId;
  final String selectedInstrumentId;
  final int bpm;
  final bool isSmartWaitEnabled;
  final AppDisplayMode displayMode;
  final List<TunnerThemePalette> customPalettes;
  final List<PracticeReportEntity> sessionHistory;
  final List<PracticeRecordingEntity> recordingHistory;

  const AppUserSettingsEntity({
    this.referencePitch = 440.0,
    this.selectedThemeId = 'obsidian_studio',
    this.selectedInstrumentId = 'flute',
    this.bpm = 68,
    this.isSmartWaitEnabled = false,
    this.displayMode = AppDisplayMode.conservatoryPro,
    this.customPalettes = const [],
    this.sessionHistory = const [],
    this.recordingHistory = const [],
  });

  /// Configuración por defecto estándar de conservatorio.
  static const AppUserSettingsEntity defaultSettings = AppUserSettingsEntity();

  AppUserSettingsEntity copyWith({
    double? referencePitch,
    String? selectedThemeId,
    String? selectedInstrumentId,
    int? bpm,
    bool? isSmartWaitEnabled,
    AppDisplayMode? displayMode,
    List<TunnerThemePalette>? customPalettes,
    List<PracticeReportEntity>? sessionHistory,
    List<PracticeRecordingEntity>? recordingHistory,
  }) {
    return AppUserSettingsEntity(
      referencePitch: referencePitch ?? this.referencePitch,
      selectedThemeId: selectedThemeId ?? this.selectedThemeId,
      selectedInstrumentId: selectedInstrumentId ?? this.selectedInstrumentId,
      bpm: bpm ?? this.bpm,
      isSmartWaitEnabled: isSmartWaitEnabled ?? this.isSmartWaitEnabled,
      displayMode: displayMode ?? this.displayMode,
      customPalettes: customPalettes ?? this.customPalettes,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      recordingHistory: recordingHistory ?? this.recordingHistory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referencePitch': referencePitch,
      'selectedThemeId': selectedThemeId,
      'selectedInstrumentId': selectedInstrumentId,
      'bpm': bpm,
      'isSmartWaitEnabled': isSmartWaitEnabled,
      'displayMode': displayMode.name,
      'customPalettes': customPalettes.map((p) => p.toJson()).toList(),
      // Limitar a las últimas 50 sesiones para evitar sobrecarga de I/O
      'sessionHistory': sessionHistory.take(50).map((s) => s.toMap()).toList(),
      // Limitar a las últimas 50 grabaciones
      'recordingHistory': recordingHistory.take(50).map((r) => r.toMap()).toList(),
    };
  }

  factory AppUserSettingsEntity.fromMap(Map<String, dynamic> map) {
    final rawCustom = map['customPalettes'] as List<dynamic>? ?? [];
    final customPalettes = rawCustom
        .map((item) => TunnerThemePalette.fromJson(item as Map<String, dynamic>))
        .toList();

    final rawSessions = map['sessionHistory'] as List<dynamic>? ?? [];
    final sessionHistory = rawSessions
        .map((item) => PracticeReportEntity.fromMap(item as Map<String, dynamic>))
        .toList();

    final rawRecordings = map['recordingHistory'] as List<dynamic>? ?? [];
    final recordingHistory = rawRecordings
        .map((item) => PracticeRecordingEntity.fromMap(item as Map<String, dynamic>))
        .toList();

    return AppUserSettingsEntity(
      referencePitch: (map['referencePitch'] as num?)?.toDouble() ?? 440.0,
      selectedThemeId: map['selectedThemeId'] as String? ?? 'obsidian_studio',
      selectedInstrumentId: map['selectedInstrumentId'] as String? ?? 'flute',
      bpm: map['bpm'] as int? ?? 68,
      isSmartWaitEnabled: map['isSmartWaitEnabled'] as bool? ?? false,
      displayMode: AppDisplayMode.values.firstWhere(
        (d) => d.name == map['displayMode'],
        orElse: () => AppDisplayMode.conservatoryPro,
      ),
      customPalettes: customPalettes,
      sessionHistory: sessionHistory,
      recordingHistory: recordingHistory,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AppUserSettingsEntity.fromJson(String source) =>
      AppUserSettingsEntity.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
