import 'dart:async';
import '../domain/i_studio_master_capture_service.dart';

/// Implementación en memoria de [IStudioMasterCaptureService] diseñada para tests unitarios rápidos.
class MemoryStudioMasterCaptureService implements IStudioMasterCaptureService {
  bool _isCapturing = false;
  String? _destinationPath;
  int _appendedSampleCount = 0;
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();

  int get appendedSampleCount => _appendedSampleCount;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Duration get elapsedDuration => Duration.zero;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Future<void> startCapture({
    required String destinationPath,
    int sampleRate = 44100,
    int channels = 2,
  }) async {
    _isCapturing = true;
    _destinationPath = destinationPath;
    _appendedSampleCount = 0;
  }

  @override
  void appendStereoSamples(List<double> left, List<double> right) {
    if (_isCapturing) {
      _appendedSampleCount += left.length;
    }
  }

  @override
  Future<String?> stopCapture() async {
    _isCapturing = false;
    final path = _destinationPath;
    _destinationPath = null;
    return path;
  }

  @override
  void dispose() {
    _durationController.close();
  }
}
