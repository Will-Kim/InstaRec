import 'package:flutter/material.dart';

class RecordingState extends ChangeNotifier {
  bool _isRecording = true; // 앱 시작과 동시에 녹음 시작
  bool _isCapturing = true; // 앱 시작과 동시에 캡처 시작
  int _bufferDuration = 10; // 기본 10초 (테스트용)
  String? _captureStartTime;
  final List<Map<String, dynamic>> _savedFiles = [];

  // Getters
  bool get isRecording => _isRecording;
  bool get isCapturing => _isCapturing;
  int get bufferDuration => _bufferDuration;
  String? get captureStartTime => _captureStartTime;
  List<Map<String, dynamic>> get savedFiles => _savedFiles;

  // Recording state management
  void startRecording() {
    _isRecording = true;
    notifyListeners();
  }

  void stopRecording() {
    _isRecording = false;
    notifyListeners();
  }

  void setIsRecording(bool value) {
    _isRecording = value;
    notifyListeners();
  }

  // Capture state management
  void startCapture() {
    _isCapturing = true;
    _captureStartTime = DateTime.now().toIso8601String();
    notifyListeners();
  }

  void stopCapture() {
    _isCapturing = false;
    _captureStartTime = null;
    notifyListeners();
  }

  // Buffer duration management
  void setBufferDuration(int duration) {
    if (duration >= 10 && duration <= 300) {
      _bufferDuration = duration;
      notifyListeners();
    }
  }

  // File management
  void addSavedFile(Map<String, dynamic> fileInfo) {
    _savedFiles.insert(0, fileInfo); // 최신 파일을 맨 위에 추가
    notifyListeners();
  }

  void clearSavedFiles() {
    _savedFiles.clear();
    notifyListeners();
  }

  void removeFile(int index) {
    if (index >= 0 && index < _savedFiles.length) {
      _savedFiles.removeAt(index);
      notifyListeners();
    }
  }

  // Get recording status text
  String get recordingStatusText {
    if (_isCapturing) {
      return '캡처 중...';
    } else if (_isRecording) {
      return '녹음 중';
    } else {
      return '정지됨';
    }
  }

  // Get status color
  Color get statusColor {
    if (_isCapturing) {
      return Colors.orange;
    } else if (_isRecording) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}
