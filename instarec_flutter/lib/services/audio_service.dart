import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

// Circular Buffer for audio data
class CircularBuffer {
  final Uint8List _buffer;
  int _writePos = 0;
  int _readPos = 0;
  bool _isFull = false;
  final int _sampleRate = 44100;
  final int _bytesPerSample = 2; // 16-bit = 2 bytes
  
  CircularBuffer(int maxDurationSeconds) 
    : _buffer = Uint8List(maxDurationSeconds * 44100 * 2);
  
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
  
  // Read N seconds of audio data (최근 N초)
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
      'availableSeconds': _isFull 
          ? _buffer.length ~/ (_sampleRate * _bytesPerSample) 
          : _writePos ~/ (_sampleRate * _bytesPerSample),
    };
  }
}

class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  
  // Callback for state updates
  Function()? _onStateChanged;
  
  // Buffer duration setting (default)
  int _bufferDuration = 10;
  
  // Circular buffer system
  CircularBuffer? _circularBuffer;

  // Recording state
  bool _isRecording = false;

  // Getters
  bool get isRecording => _isRecording;
  int get bufferDuration => _bufferDuration;

  // Initialize audio service
  Future<void> initialize({Function()? onStateChanged}) async {
    if (await _audioRecorder.hasPermission()) {
      _onStateChanged = onStateChanged;
    } else {
      throw Exception('마이크 권한이 없습니다');
    }
  }

  // Get accessible storage directory for saving files
  Future<Directory> _getAccessibleDirectory() async {
    if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(path.join(directory.path, 'recordings'));
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      return recordingsDir;
    } else {
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
      final directory = await getTemporaryDirectory();
      final playableDir = Directory(path.join(directory.path, 'playable_recordings'));
      if (!await playableDir.exists()) {
        await playableDir.create(recursive: true);
      }
      return playableDir;
    } else {
      return await _getAccessibleDirectory();
    }
  }

  // Copy file to playable location
  Future<String> copyToPlayableLocation(String originalPath) async {
    if (Platform.isAndroid) {
      return originalPath;
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

  // Start continuous recording with circular buffer
  Future<void> startContinuousRecording() async {
    if (_isRecording) return;

    try {
      _circularBuffer = CircularBuffer(300);
      
      // 스트림으로 PCM 데이터 받기
      final stream = await _audioRecorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
        ),
      );

      // 스트림 데이터를 CircularBuffer에 쓰기
      _audioStreamSubscription = stream.listen((data) {
        _circularBuffer?.write(data);
      });

      _isRecording = true;
      _onStateChanged?.call();

      if (kDebugMode) {
        print('🎤 스트림 녹음 시작');
        print('📦 Circular Buffer 생성 완료 (300초 용량)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 녹음 시작 실패: $e');
      }
      rethrow;
    }
  }

  // Stop continuous recording (저장 없이 중지만)
  Future<void> stopContinuousRecording() async {
    if (!_isRecording) return;

    try {
      await _audioStreamSubscription?.cancel();
      await _audioRecorder.stop();
      
      _isRecording = false;
      _onStateChanged?.call();
      
      if (kDebugMode) {
        print('🛑 녹음 중지');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 녹음 중지 실패: $e');
      }
      rethrow;
    }
  }

  // 🆕 최근 N초를 캡처해서 파일로 저장
  Future<Map<String, dynamic>> getCapture(int seconds) async {
    if (!_isRecording) {
      throw Exception('녹음이 진행 중이 아닙니다');
    }

    if (_circularBuffer == null) {
      throw Exception('CircularBuffer가 초기화되지 않았습니다');
    }

    try {
      // Generate output filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final recordingsDir = await _getAccessibleDirectory();
      final wavPath = path.join(recordingsDir.path, 'capture_$timestamp.wav');

      // Read N seconds of audio data from circular buffer
      final audioData = _circularBuffer!.readSeconds(seconds);
      
      if (audioData.isEmpty) {
        throw Exception('버퍼에 오디오 데이터가 없습니다');
      }
      
      // Create WAV file from audio data
      await _createWavFile(audioData, wavPath);
      
      // 실제 저장된 시간 계산
      final actualSeconds = audioData.length / (_circularBuffer!._sampleRate * _circularBuffer!._bytesPerSample);
      
      final fileInfo = {
        'wavPath': wavPath,
        'timestamp': timestamp,
        'captureTime': DateTime.now().toIso8601String(),
        'requestedSeconds': seconds,
        'actualSeconds': actualSeconds,
        'fileName': 'capture_$timestamp.wav',
        'fileSize': await File(wavPath).length(),
      };

      if (kDebugMode) {
        print('💾 캡처 완료: $wavPath');
        print('📊 요청: ${seconds}초 / 실제: ${actualSeconds.toStringAsFixed(1)}초');
      }
      
      return fileInfo;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 캡처 저장 실패: $e');
      }
      rethrow;
    }
  }

  // 🔄 기존 함수들 (하위 호환성 유지)
  @Deprecated('Use getCapture(seconds) instead')
  Future<void> startCapture() async {
    // 이제는 아무 동작 안 함 (CircularBuffer가 항상 활성화되어 있으므로)
    if (kDebugMode) {
      print('⚠️ startCapture()는 더 이상 필요하지 않습니다. getCapture(N)을 사용하세요.');
    }
  }

  @Deprecated('Use getCapture(seconds) instead')
  Future<Map<String, dynamic>> stopCapture() async {
    // getCapture()를 호출하도록 리다이렉트
    return await getCapture(_bufferDuration);
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


  // Create WAV file from audio data
  Future<void> _createWavFile(Uint8List audioData, String filePath) async {
    final wavHeader = _createWavHeader(audioData.length);
    
    final file = File(filePath);
    final sink = file.openWrite();
    
    sink.add(wavHeader);
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
    header.setUint32(4, 36 + dataSize, Endian.little);
    
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
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    return header.buffer.asUint8List();
  }

  // Set buffer duration (default value for backward compatibility)
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
      'circularBufferStatus': _circularBuffer?.getStatus(),
    };
  }

  // Dispose resources
  void dispose() {
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
  }
}