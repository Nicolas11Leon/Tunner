import 'dart:convert';
import '../../../core/theme/tunner_theme.dart';
import '../../practice_evaluator/domain/practice_report_entity.dart';
import '../../practice_recorder/domain/practice_recording_entity.dart';
import '../../pedagogy_profiles/domain/learner_profile_entity.dart';
import '../../workspaces/domain/workspace_type.dart';
import '../../tuner/domain/microphone_calibration_models.dart';
import '../../tuner/domain/acoustic_rigor_profile.dart';
import '../../tuner/domain/tuning_preset_entity.dart';
import '../../song_library/domain/song_package_entity.dart';

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
  final String selectedTemperamentId;
  final int temperamentRootKey;
  final List<TunnerThemePalette> customPalettes;
  final List<PracticeReportEntity> sessionHistory;
  final List<PracticeRecordingEntity> recordingHistory;
  final List<TuningPresetEntity> tuningPresets;
  final List<SongPackage> workspaceScores;
  final LearnerProfileEntity learnerProfile;
  final WorkspaceType activeWorkspace;
  final MicrophoneCalibrationProfile micCalibrationProfile;
  final AcousticRigorProfile acousticRigorProfile;
  final String dspEngineName;
  final int targetRenderFps;
  final double centsPrecision;
  final WorkspaceConfigurationEntity? workspaceConfiguration;

  const AppUserSettingsEntity({
    this.referencePitch = 440.0,
    this.selectedThemeId = 'obsidian_studio',
    this.selectedInstrumentId = 'flute',
    this.bpm = 68,
    this.isSmartWaitEnabled = false,
    this.displayMode = AppDisplayMode.conservatoryPro,
    this.selectedTemperamentId = 'equal',
    this.temperamentRootKey = 0,
    this.customPalettes = const [],
    this.sessionHistory = const [],
    this.recordingHistory = const [],
    this.tuningPresets = const [],
    this.workspaceScores = const [],
    this.activeWorkspace = WorkspaceType.learning,
    this.micCalibrationProfile = const MicrophoneCalibrationProfile(),
    this.acousticRigorProfile = const AcousticRigorProfile(),
    this.dspEngineName = 'Tartini DSP 2.1',
    this.targetRenderFps = 60,
    this.centsPrecision = 0.1,
    this.workspaceConfiguration,
    this.learnerProfile = const LearnerProfileEntity(
      type: LearnerProfileType.adultDeliberate,
      title: 'Modo Adulto (Práctica Deliberada)',
      description: 'Diseño andragógico centrado en la resolución de problemas.',
      centsTolerance: 10.0,
      feedbackStyle: FeedbackStyle.constructiveBiomechanical,
      visualDensity: VisualDensityLevel.focusedAndragogic,
      enableSmartWait: true,
      enableScaffoldingFadeOut: false,
    ),
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
    String? selectedTemperamentId,
    int? temperamentRootKey,
    List<TunnerThemePalette>? customPalettes,
    List<PracticeReportEntity>? sessionHistory,
    List<PracticeRecordingEntity>? recordingHistory,
    List<TuningPresetEntity>? tuningPresets,
    List<SongPackage>? workspaceScores,
    LearnerProfileEntity? learnerProfile,
    WorkspaceType? activeWorkspace,
    MicrophoneCalibrationProfile? micCalibrationProfile,
    AcousticRigorProfile? acousticRigorProfile,
    String? dspEngineName,
    int? targetRenderFps,
    double? centsPrecision,
    WorkspaceConfigurationEntity? workspaceConfiguration,
  }) {
    return AppUserSettingsEntity(
      referencePitch: referencePitch ?? this.referencePitch,
      selectedThemeId: selectedThemeId ?? this.selectedThemeId,
      selectedInstrumentId: selectedInstrumentId ?? this.selectedInstrumentId,
      bpm: bpm ?? this.bpm,
      isSmartWaitEnabled: isSmartWaitEnabled ?? this.isSmartWaitEnabled,
      displayMode: displayMode ?? this.displayMode,
      selectedTemperamentId: selectedTemperamentId ?? this.selectedTemperamentId,
      temperamentRootKey: temperamentRootKey ?? this.temperamentRootKey,
      customPalettes: customPalettes ?? this.customPalettes,
      sessionHistory: sessionHistory ?? this.sessionHistory,
      recordingHistory: recordingHistory ?? this.recordingHistory,
      tuningPresets: tuningPresets ?? this.tuningPresets,
      workspaceScores: workspaceScores ?? this.workspaceScores,
      learnerProfile: learnerProfile ?? this.learnerProfile,
      activeWorkspace: activeWorkspace ?? this.activeWorkspace,
      micCalibrationProfile: micCalibrationProfile ?? this.micCalibrationProfile,
      acousticRigorProfile: acousticRigorProfile ?? this.acousticRigorProfile,
      dspEngineName: dspEngineName ?? this.dspEngineName,
      targetRenderFps: targetRenderFps ?? this.targetRenderFps,
      centsPrecision: centsPrecision ?? this.centsPrecision,
      workspaceConfiguration: workspaceConfiguration ?? this.workspaceConfiguration,
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
      'selectedTemperamentId': selectedTemperamentId,
      'temperamentRootKey': temperamentRootKey,
      'customPalettes': customPalettes.map((p) => p.toJson()).toList(),
      // Conservar las 50 sesiones mas recientes
      'sessionHistory': (sessionHistory.length > 50
              ? sessionHistory.sublist(sessionHistory.length - 50)
              : sessionHistory)
          .map((s) => s.toMap())
          .toList(),
      // Conservar las 50 grabaciones mas recientes (insertadas en indice 0)
      'recordingHistory': recordingHistory.take(50).map((r) => r.toMap()).toList(),
      'tuningPresets': tuningPresets.map((t) => t.toMap()).toList(),
      'workspaceScores': workspaceScores.map((s) => s.toMap()).toList(),
      'learnerProfile': learnerProfile.toJson(),
      'activeWorkspace': activeWorkspace.serializedKey,
      'micCalibrationProfile': micCalibrationProfile.toJson(),
      'acousticRigorProfile': acousticRigorProfile.toJson(),
      'dspEngineName': dspEngineName,
      'targetRenderFps': targetRenderFps,
      'centsPrecision': centsPrecision,
      if (workspaceConfiguration != null)
        'workspaceConfiguration': workspaceConfiguration!.toMap(),
    };
  }

  factory AppUserSettingsEntity.fromMap(
    Map<String, dynamic> map, {
    void Function(String message)? onCorruptEntry,
  }) {
    final rawCustom = map['customPalettes'] as List<dynamic>? ?? [];
    final customPalettes = <TunnerThemePalette>[];
    for (final item in rawCustom) {
      if (item is Map<String, dynamic>) {
        try {
          customPalettes.add(TunnerThemePalette.fromJson(item));
        } catch (e) {
          onCorruptEntry?.call('Paleta corrupta omitida: $e');
        }
      }
    }

    final rawSessions = map['sessionHistory'] as List<dynamic>? ?? [];
    final sessionHistory = <PracticeReportEntity>[];
    for (final item in rawSessions) {
      if (item is Map<String, dynamic>) {
        try {
          sessionHistory.add(PracticeReportEntity.fromMap(item));
        } catch (e) {
          onCorruptEntry?.call('Sesion de practica corrupta omitida: $e');
        }
      }
    }

    final rawRecordings = map['recordingHistory'] as List<dynamic>? ?? [];
    final recordingHistory = <PracticeRecordingEntity>[];
    for (final item in rawRecordings) {
      if (item is Map<String, dynamic>) {
        try {
          recordingHistory.add(PracticeRecordingEntity.fromMap(item));
        } catch (e) {
          onCorruptEntry?.call('Grabacion corrupta omitida: $e');
        }
      }
    }

    final rawPresets = map['tuningPresets'] as List<dynamic>? ?? [];
    final tuningPresets = <TuningPresetEntity>[];
    for (final item in rawPresets) {
      if (item is Map<String, dynamic>) {
        try {
          tuningPresets.add(TuningPresetEntity.fromMap(item));
        } catch (e) {
          onCorruptEntry?.call('Preset de afinacion corrupto omitido: $e');
        }
      }
    }

    final rawScores = map['workspaceScores'] as List<dynamic>? ?? [];
    final workspaceScores = <SongPackage>[];
    for (final item in rawScores) {
      if (item is Map<String, dynamic>) {
        try {
          workspaceScores.add(SongPackage.fromMap(item));
        } catch (e) {
          onCorruptEntry?.call('Partitura corrupta omitida: $e');
        }
      }
    }

    final rawProfile = map['learnerProfile'] as Map<String, dynamic>?;
    final learnerProfile = rawProfile != null
        ? LearnerProfileEntity.fromJson(rawProfile)
        : LearnerProfileEntity.adult();

    final rawWorkspace = map['activeWorkspace'] as String?;
    final activeWorkspace = WorkspaceType.fromSerializedKey(rawWorkspace);

    final rawMicProfile = map['micCalibrationProfile'] as Map<String, dynamic>?;
    final micCalibrationProfile = rawMicProfile != null
        ? MicrophoneCalibrationProfile.fromJson(rawMicProfile)
        : const MicrophoneCalibrationProfile();

    final rawRigorProfile = map['acousticRigorProfile'] as Map<String, dynamic>?;
    final acousticRigorProfile = rawRigorProfile != null
        ? AcousticRigorProfile.fromJson(rawRigorProfile)
        : const AcousticRigorProfile();

    final rawWorkspaceConfig = map['workspaceConfiguration'] as Map<String, dynamic>?;
    final workspaceConfiguration = rawWorkspaceConfig != null
        ? WorkspaceConfigurationEntity.fromMap(rawWorkspaceConfig)
        : null;

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
      selectedTemperamentId: map['selectedTemperamentId'] as String? ?? 'equal',
      temperamentRootKey: (map['temperamentRootKey'] as num?)?.toInt() ?? 0,
      customPalettes: customPalettes,
      sessionHistory: sessionHistory,
      recordingHistory: recordingHistory,
      tuningPresets: tuningPresets,
      workspaceScores: workspaceScores,
      learnerProfile: learnerProfile,
      activeWorkspace: activeWorkspace,
      micCalibrationProfile: micCalibrationProfile,
      acousticRigorProfile: acousticRigorProfile,
      dspEngineName: map['dspEngineName'] as String? ?? 'Tartini DSP 2.1',
      targetRenderFps: (map['targetRenderFps'] as num?)?.toInt() ?? 60,
      centsPrecision: (map['centsPrecision'] as num?)?.toDouble() ?? 0.1,
      workspaceConfiguration: workspaceConfiguration,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AppUserSettingsEntity.fromJson(String source) =>
      AppUserSettingsEntity.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
