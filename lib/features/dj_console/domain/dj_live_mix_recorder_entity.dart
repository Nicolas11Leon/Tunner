import 'dart:typed_data';

/// Pure Dart entity managing the state and sample accumulation of a live DJ mix recording.
class DjLiveMixRecorderEntity {
  final bool isRecording;
  final int startTimeMs;
  final int durationMs;
  final List<Float32List> recordedChunks;

  const DjLiveMixRecorderEntity({
    this.isRecording = false,
    this.startTimeMs = 0,
    this.durationMs = 0,
    this.recordedChunks = const [],
  });

  /// Total number of recorded chunks.
  int get totalChunks => recordedChunks.length;

  /// Total duration in seconds.
  int get durationSeconds => durationMs ~/ 1000;

  /// Total number of accumulated audio samples across all chunks.
  int get totalRecordedSamples {
    int total = 0;
    for (final chunk in recordedChunks) {
      total += chunk.length;
    }
    return total;
  }

  /// Alias for totalRecordedSamples.
  int get totalSampleCount => totalRecordedSamples;

  /// Flattens all captured chunks into a single unified Float32List buffer.
  Float32List consolidateBuffer() {
    final total = totalRecordedSamples;
    final consolidated = Float32List(total);
    int offset = 0;
    for (final chunk in recordedChunks) {
      consolidated.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return consolidated;
  }

  /// Alias for consolidateBuffer.
  Float32List consolidateChunks() => consolidateBuffer();

  DjLiveMixRecorderEntity start(int nowMs) {
    return DjLiveMixRecorderEntity(
      isRecording: true,
      startTimeMs: nowMs,
      durationMs: 0,
      recordedChunks: [],
    );
  }

  DjLiveMixRecorderEntity appendChunk(Float32List chunk, int nowMs) {
    if (!isRecording) return this;
    final updated = List<Float32List>.from(recordedChunks)..add(chunk);
    final elapsed = nowMs > startTimeMs ? nowMs - startTimeMs : 0;
    return DjLiveMixRecorderEntity(
      isRecording: true,
      startTimeMs: startTimeMs,
      durationMs: elapsed,
      recordedChunks: updated,
    );
  }

  DjLiveMixRecorderEntity stop() {
    return DjLiveMixRecorderEntity(
      isRecording: false,
      startTimeMs: startTimeMs,
      durationMs: durationMs,
      recordedChunks: recordedChunks,
    );
  }

  DjLiveMixRecorderEntity clear() {
    return const DjLiveMixRecorderEntity();
  }
}
