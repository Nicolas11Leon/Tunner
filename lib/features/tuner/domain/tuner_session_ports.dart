import '../../chord_analyzer/domain/chord_entity.dart';
import '../../chord_analyzer/domain/polyphonic_pitch_entity.dart';
import '../../guided_lessons/domain/guided_lesson_entity.dart';
import '../../instrument/domain/instrument_profile_entity.dart';
import '../../sheet_music/domain/score_tree.dart';

/// Puerto segregado (ISP) para sesiones de lecciones guiadas.
abstract class IGuidedLessonSessionPort {
  bool get isRecording;
  double get frequency;
  double get cents;
  String get noteName;
  InstrumentProfileEntity get activeInstrument;
  bool get hasActiveGuidedLesson;
  GuidedLessonProgressEntity? get activeLessonProgress;

  Future<void> toggleRecording();
  void startGuidedLesson(GuidedLessonEntity lesson);
  void cancelGuidedLesson();
  void jumpToLessonStep(int stepIndex);
  void playReferenceTone([String noteName]);
}

/// Puerto segregado (ISP) para el analizador polifónico de acordes.
abstract class IChordAnalyzerSessionPort {
  bool get isRecording;
  bool get isChordRecognitionActive;
  ChordEntity get recognizedChord;
  List<double> get activeChromaVector;
  PolyphonicMultiToneAnalysisResult get polyphonicAnalysisResult;

  Future<void> toggleRecording();
  void toggleChordRecognition();
}

/// Puerto segregado (ISP) para el editor interactivo de partituras.
abstract class IScoreEditorSessionPort {
  List<HierarchicalNote> get currentMeasureNotes;
  int get currentMeasureIndex;
  bool get canUndoScoreEdit;
  bool get canRedoScoreEdit;

  void insertOrUpdateScoreNote({
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required String noteName,
    bool playAudibleFeedback = true,
  });
  void insertScoreChordNotes({
    required int measureIndex,
    required int startTick,
    required int durationTicks,
    required List<String> noteNames,
    bool playAudibleFeedback = true,
  });
  void deleteScoreNote({
    required int measureIndex,
    required int startTick,
  });
  void undoScoreEdit();
  void redoScoreEdit();
  void addScoreMeasure();
  void removeScoreMeasure(int measureIndex);
  String exportActiveScoreToMusicXml();
  String exportActiveScoreToAbc();
}
