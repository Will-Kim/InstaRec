import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
// FFmpeg removed due to iOS compatibility issues
// import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter/return_code.dart';

// Circular Buffer for audio data
class CircularBuffer {
  final Uint8List _buffer;
  int _writePos = 0;
  int _readPos = 0;
  bool _isFull = false;
  final int _sampleRate = 44100;
  final int _bytesPerSample = 2; // 16-bit = 2 bytes
  
  CircularBuffer(int maxDurationSeconds) 
    : _buffer = Uint8List(maxDurationSeconds * 44100 * 2); // 30MB for 300 seconds
  
  // Write audio data to buffer
  void write(Uint8List data) {
    for (int i = 0; i < data.length; i++) {
      _buffer[_writePos] = data[i];
      _writePos = (_writePos + 1) % _buffer.length;
      
      if (_writePos == _readPos) {
        _isFull = true;
        _readPos = (_readPos + 1) % _buffer.length;
      }
    }
  }
  
  // Read N seconds of audio data (최근 N초를 역순으로 읽기)
  Uint8List readSeconds(int seconds) {
    final bytesToRead = seconds * _sampleRate * _bytesPerSample;
    
    // 사용 가능한 데이터 계산
    int availableBytes;
    if (_isFull) {
      availableBytes = _buffer.length;
    } else {
      availableBytes = _writePos;
    }

    // 충분한 데이터가 없으면 사용 가능한 만큼만 읽기
    final actualBytesToRead = availableBytes < bytesToRead ? availableBytes : bytesToRead;

    // 데이터가 하나도 없으면 빈 배열 반환
    if (actualBytesToRead == 0) {
      return Uint8List(0);
    }
    
    final result = Uint8List(actualBytesToRead);
    
    // writePos에서 역순으로 N초만큼 읽기
    int readPos = _writePos;
    
    for (int i = 0; i < actualBytesToRead; i++) {
      // 역순으로 이동
      readPos = (readPos - 1 + _buffer.length) % _buffer.length;
      // 결과는 정순으로 저장 (최신 데이터가 뒤에 오도록)
      result[actualBytesToRead - 1 - i] = _buffer[readPos];
    }
    
    return result;
  }
  
  // Get current buffer status
  Map<String, dynamic> getStatus() {
    return {
      'writePos': _writePos,
      'readPos': _readPos,
      'isFull': _isFull,
      'bufferSize': _buffer.length,
      'availableSeconds': _isFull ? _buffer.length ~/ (_sampleRate * _bytesPerSample) : _writePos ~/ (_sampleRate * _bytesPerSample),
    };
  }
}

class AudioService {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  Timer? _recordingTimer;
  String? _currentRecordingPath;

  int _lastReadFileSize = 0; // 마지막으로 읽은 파일 크기
  static const int _wavHeaderSize = 44; // WAV 헤더 크기
  
  // Callback for state updates
  Function()? _onStateChanged;
  
  // Buffer duration setting
  int _bufferDuration = 10; // 초 단위 (테스트용)
  
  // Circular buffer system
  CircularBuffer? _circularBuffer;

  // Recording state
  bool _isRecording = false;
  bool _isCapturing = false;
  String? _captureStartTime;

  // Getters
  bool get isRecording => _isRecording;
  bool get isCapturing => _isCapturing;
  String? get captureStartTime => _captureStartTime;
  int get bufferDuration => _bufferDuration;

  // Initialize audio service
  Future<void> initialize({Function()? onStateChanged}) async {
    await _audioRecorder.openRecorder();
    if (!await _audioRecorder.isEncoderSupported(Codec.defaultCodec)) {
      throw Exception('오디오 인코더를 지원하지 않습니다');
    }
    
    
    // Set state change callback
    _onStateChanged = onStateChanged;
  }

  // Get accessible storage directory for saving files
  Future<Directory> _getAccessibleDirectory() async {
    if (Platform.isIOS) {
      // iOS: Use Documents directory that's accessible via Files app
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(path.join(directory.path, 'recordings'));
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      return recordingsDir;
    } else {
      // Android: Use external storage
      final directory = await getExternalStorageDirectory();
      final recordingsDir = Directory(path.join(directory!.path, 'InstaRec', 'recordings'));
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      return recordingsDir;
    }
  }

  // Get playable directory for audio playback
  Future<Directory> _getPlayableDirectory() async {
    if (Platform.isIOS) {
      // iOS: Use temporary directory for playback
      final directory = await getTemporaryDirectory();
      final playableDir = Directory(path.join(directory.path, 'playable_recordings'));
      if (!await playableDir.exists()) {
        await playableDir.create(recursive: true);
      }
      return playableDir;
    } else {
      // Android: Use the same accessible directory
      return await _getAccessibleDirectory();
    }
  }

  // Copy file to playable location
  Future<String> copyToPlayableLocation(String originalPath) async {
    if (Platform.isAndroid) {
      return originalPath; // Android doesn't need copying
    }
    
    final playableDir = await _getPlayableDirectory();
    final fileName = path.basename(originalPath);
    final playablePath = path.join(playableDir.path, fileName);
    
    final originalFile = File(originalPath);
    if (await originalFile.exists()) {
      await originalFile.copy(playablePath);
    }
    
    return playablePath;
  }

  // Start continuous recording
  Future<void> startContinuousRecording() async {
    if (_isRecording) return;

    try {
      final recordingsDir = await _getAccessibleDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = path.join(
        recordingsDir.path,
        'continuous_recording_$timestamp.wav'
      );


      // Start recording
      await _audioRecorder.startRecorder(
        toFile: _currentRecordingPath!,
        codec: Codec.pcm16WAV,
        sampleRate: 44100,
      );

      _isRecording = true;
      _onStateChanged?.call();

      // Start real-time audio streaming to circular buffer
      _startRealTimeAudioStreaming();

      if (kDebugMode) {
        print('🎤 연속 녹음 시작: $_currentRecordingPath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 녹음 시작 실패: $e');
      }
      rethrow;
    }
  }

  // Stop continuous recording
  Future<void> stopContinuousRecording() async {
    if (!_isRecording) return;

    try {
      await _audioRecorder.stopRecorder();
      _recordingTimer?.cancel();
      _isRecording = false;
      _onStateChanged?.call();
      if (kDebugMode) {
        print('🛑 연속 녹음 중지');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 녹음 중지 실패: $e');
      }
      rethrow;
    }
  }

  // Start capture (save buffer + new recording)
  Future<void> startCapture() async {
    if (_isCapturing) return;

    _isCapturing = true;
    _captureStartTime = DateTime.now().toIso8601String();

    // _lastReadFileSize 업데이트
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (file.existsSync()) {
        _lastReadFileSize = file.lengthSync();
      }
    }
    
    // Initialize circular buffer
    _circularBuffer = CircularBuffer(300);
    
    _onStateChanged?.call();
    if (kDebugMode) {
      print('📸 캡처 시작 - Circular Buffer 활성화');
    }
  }

  // Stop capture and save file
  Future<Map<String, dynamic>> stopCapture() async {
    if (!_isCapturing) return {};

    try {
      _isCapturing = false;
      
      // Generate output filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final recordingsDir = await _getAccessibleDirectory();
      final wavPath = path.join(recordingsDir.path, 'capture_$timestamp.wav');

      // Save buffered audio data
      await _saveCircularBufferAudio(wavPath);

      final fileInfo = {
        'wavPath': wavPath,
        'timestamp': timestamp,
        'captureStartTime': _captureStartTime,
        'captureEndTime': DateTime.now().toIso8601String(),
        'bufferDuration': _bufferDuration,
        'fileName': 'capture_$timestamp.wav',
        'fileSize': await File(wavPath).length(),
      };

      _captureStartTime = null;
      _onStateChanged?.call();
      if (kDebugMode) {
        print('💾 캡처 완료: $wavPath');
      }
      
      return fileInfo;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 캡처 저장 실패: $e');
      }
      rethrow;
    }
  }

  // Get all saved files
  Future<List<Map<String, dynamic>>> getSavedFiles() async {
    try {
      final recordingsDir = await _getAccessibleDirectory();
      final files = <Map<String, dynamic>>[];
      
      if (await recordingsDir.exists()) {
        final fileList = await recordingsDir.list().toList();
        for (final file in fileList) {
          if (file is File && file.path.endsWith('.wav')) {
            final stat = await file.stat();
            files.add({
              'wavPath': file.path,
              'fileName': path.basename(file.path),
              'timestamp': stat.modified.millisecondsSinceEpoch,
              'fileSize': stat.size,
              'modifiedTime': stat.modified.toIso8601String(),
            });
          }
        }
      }
      
      // Sort by timestamp (newest first)
      files.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
      return files;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 파일 목록 조회 실패: $e');
      }
      return [];
    }
  }

  // Delete file
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) {
          print('🗑️ 파일 삭제 완료: $filePath');
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 파일 삭제 실패: $e');
      }
      return false;
    }
  }

  // Share file
  Future<void> shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: 'InstaRec 녹음 파일');
    } catch (e) {
      if (kDebugMode) {
        print('❌ 파일 공유 실패: $e');
      }
      rethrow;
    }
  }

  // MP3 conversion removed - using WAV only for now

  // Start real-time audio streaming to circular buffer
  void _startRealTimeAudioStreaming() {
    // Start collecting audio data immediately
    _startAudioDataCollection();
  }

  // Start collecting audio data from recorder
  void _startAudioDataCollection() {
    // Use a timer to periodically collect audio data
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _collectAudioData();
    });
  }

  // Collect audio data from recorder and write to circular buffer
  void _collectAudioData() {
    if (!_isRecording || _circularBuffer == null) return;
    
    try {
      // Read audio data from continuous recording file
      _readAudioFromContinuousFile();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 오디오 데이터 수집 실패: $e');
      }
    }
  }

  // Read audio data from continuous recording file (temporary solution)
  void _readAudioFromContinuousFile() {
    if (_currentRecordingPath == null) return;
    
    try {
      final file = File(_currentRecordingPath!);
      if (!file.existsSync()) return;
      
      final currentFileSize = file.lengthSync();
      
      // 새로운 데이터가 없으면 스킵
      if (currentFileSize <= _lastReadFileSize) return;
      
      // 읽을 시작 위치 계산 (헤더 건너뛰기)
      final startPos = _lastReadFileSize == 0 
          ? _wavHeaderSize  // 처음 읽을 때는 헤더 건너뛰기
          : _lastReadFileSize;
      
      // 새로운 데이터만 읽기
      final bytes = file.readAsBytesSync();
      final newData = bytes.sublist(startPos, currentFileSize);
      
      // Circular buffer에 쓰기
      if (newData.isNotEmpty) {
        _circularBuffer!.write(Uint8List.fromList(newData));
        _lastReadFileSize = currentFileSize;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 오디오 데이터 읽기 실패: $e');
      }
    }
  }

  // Save circular buffer audio data to file
  Future<void> _saveCircularBufferAudio(String filePath) async {
    if (_circularBuffer == null) {
      // Fallback to continuous recording file if no buffer data
      if (_currentRecordingPath != null && await File(_currentRecordingPath!).exists()) {
        final sourceFile = File(_currentRecordingPath!);
        await sourceFile.copy(filePath);
        return;
      } else {
        throw Exception('저장할 오디오 데이터가 없습니다');
      }
    }
    
    // Read N seconds of audio data from circular buffer
    final audioData = _circularBuffer!.readSeconds(_bufferDuration);
    
    // 데이터가 없을 때만 예외 처리
    if (audioData.isEmpty) {
      throw Exception('버퍼에 오디오 데이터가 없습니다');
    }
    
    // Create WAV file from audio data
    await _createWavFile(audioData, filePath);
    
    // 실제 저장된 시간 계산해서 로그 출력
    final actualSeconds = audioData.length / (_circularBuffer!._sampleRate * _circularBuffer!._bytesPerSample);
    if (kDebugMode) {
      print('💾 Circular Buffer 저장 완료: ${audioData.length} bytes (${actualSeconds.toStringAsFixed(1)}초 / 요청: $_bufferDuration초)');
    }
  }

  // Create WAV file from audio data
  Future<void> _createWavFile(Uint8List audioData, String filePath) async {
    // Create WAV header
    final wavHeader = _createWavHeader(audioData.length);
    
    // Write file
    final file = File(filePath);
    final sink = file.openWrite();
    
    // Write header
    sink.add(wavHeader);
    
    // Write audio data
    sink.add(audioData);
    
    await sink.close();
  }

  // Create WAV file header
  Uint8List _createWavHeader(int dataSize) {
    final header = ByteData(44);
    final sampleRate = 44100;
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, 36 + dataSize, Endian.little); // File size - 8
    
    // WAVE format
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little);  // Audio format (PCM)
    header.setUint16(22, 1, Endian.little);  // Number of channels
    header.setUint32(24, sampleRate, Endian.little); // Sample rate
    header.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    header.setUint16(32, 2, Endian.little);  // Block align
    header.setUint16(34, 16, Endian.little); // Bits per sample
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little); // Data size
    
    return header.buffer.asUint8List();
  }


  // Set buffer duration
  void setBufferDuration(int duration) {
    if (duration >= 10 && duration <= 300) {
      _bufferDuration = duration;
    }
  }

  // Get buffer status
  Map<String, dynamic> getBufferStatus() {
    return {
      'bufferDuration': _bufferDuration,
      'isRecording': _isRecording,
    };
  }

  // Dispose resources
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.closeRecorder();
  }
}
