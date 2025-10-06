import 'package:flutter/material.dart';

class RecordingState extends ChangeNotifier {
  bool _isRecording = false; // 앱 시작 시 대기 상태
  int _bufferDuration = 10; // 기본 10초 (테스트용)
  final List<Map<String, dynamic>> _savedFiles = [];

  // Getters
  bool get isRecording => _isRecording;
  int get bufferDuration => _bufferDuration;
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
    if (_isRecording) {
      return '녹음 중';
    } else {
      return '대기 중';
    }
  }

  // Get status color
  Color get statusColor {
    if (_isRecording) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}
