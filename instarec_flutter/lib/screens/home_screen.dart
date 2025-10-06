import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recording_state.dart';
import '../services/audio_service.dart';
import '../services/background_service.dart';
import '../widgets/recording_indicator.dart';
import '../widgets/buffer_settings.dart';
import '../widgets/saved_files_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _recordingAnimationController;
  
  AudioService? _audioService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupAnimations();
  }

  void _setupAnimations() {
    _recordingAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _recordingAnimationController.repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    try {
      // Initialize audio service
      _audioService = AudioService();
      await _audioService!.initialize(
        onStateChanged: () {
          if (mounted) {
            final recordingState = Provider.of<RecordingState>(context, listen: false);
            recordingState.setIsRecording(_audioService!.isRecording);
          }
        },
      );

      // Load saved settings
      await _loadSettings();

      // Start background service
      await BackgroundService.startService();

      // Set up volume button callbacks
      BackgroundService.setVolumeButtonCallbacks(
        onVolumeUp: _saveCapture,
        onVolumeDown: _saveCapture,
      );

      // 앱 시작 시 자동으로 녹음 시작
      await _startRecording();

      setState(() {
        _isInitialized = true;
      });

      // 앱이 완전히 로딩된 후 시작 버튼 자동 실행
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startRecording();
      });

      if (kDebugMode) {
        print('✅ InstaRec 앱 초기화 완료 - 자동 녹음 시작');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 앱 초기화 실패: $e');
      }
      _showErrorDialog('초기화 실패', e.toString());
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bufferDuration = prefs.getInt('buffer_duration') ?? 10;
    
    if (!mounted) return;
    
    final recordingState = Provider.of<RecordingState>(context, listen: false);
    recordingState.setBufferDuration(bufferDuration);
    
    if (_audioService != null) {
      _audioService!.setBufferDuration(bufferDuration);
    }
  }


  // 시작 버튼 - 연속 녹음 시작
  Future<void> _startRecording() async {
    if (!_isInitialized || _audioService == null) return;

    try {
      await _audioService!.startContinuousRecording();
      if (mounted) {
        final recordingState = Provider.of<RecordingState>(context, listen: false);
        recordingState.startRecording();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 녹음 시작 실패: $e');
      }
      _showErrorDialog('녹음 시작 실패', e.toString());
    }
  }

  // 중지 버튼 - 녹음 중지 (저장 없이)
  Future<void> _stopRecording() async {
    if (!_isInitialized || _audioService == null) return;

    try {
      await _audioService!.stopContinuousRecording();
      if (mounted) {
        final recordingState = Provider.of<RecordingState>(context, listen: false);
        recordingState.stopRecording();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 녹음 중지 실패: $e');
      }
      _showErrorDialog('녹음 중지 실패', e.toString());
    }
  }

  // 저장 버튼 - 최근 N초 저장
  Future<void> _saveCapture() async {
    if (!_isInitialized || _audioService == null) return;

    final recordingState = Provider.of<RecordingState>(context, listen: false);
    
    if (!recordingState.isRecording) {
      _showErrorDialog('저장 실패', '녹음이 진행 중이 아닙니다.');
      return;
    }

    try {
      final result = await _audioService!.getCapture(recordingState.bufferDuration);
      if (result.isNotEmpty) {
        recordingState.addSavedFile(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${recordingState.bufferDuration}초 오디오가 저장되었습니다')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 저장 실패: $e');
      }
      _showErrorDialog('저장 실패', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recordingAnimationController.dispose();
    _audioService?.dispose();
    BackgroundService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<RecordingState>(
          builder: (context, recordingState, child) {
            return Text('InstaRec - ${recordingState.recordingStatusText}');
          },
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<RecordingState>(
            builder: (context, recordingState, child) {
              return Icon(
                recordingState.isRecording ? Icons.fiber_manual_record : Icons.stop,
                color: recordingState.statusColor,
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isInitialized
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Recording status indicator
                  const RecordingIndicator(),
                  
                  const SizedBox(height: 24),
                  
                  // Buffer settings
                  const BufferSettings(),
                  
                  const SizedBox(height: 32),
                  
                  // Save button (큰 버튼)
                  Consumer<RecordingState>(
                    builder: (context, recordingState, child) {
                      return ElevatedButton.icon(
                        onPressed: recordingState.isRecording ? _saveCapture : null,
                        icon: const Icon(Icons.save, size: 32),
                        label: const Text(
                          '저장',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: recordingState.isRecording ? Colors.blue : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Start/Stop buttons (나란히)
                  Row(
                    children: [
                      // Start button
                      Expanded(
                        child: Consumer<RecordingState>(
                          builder: (context, recordingState, child) {
                            return ElevatedButton.icon(
                              onPressed: recordingState.isRecording ? null : _startRecording,
                              icon: const Icon(Icons.play_arrow, size: 24),
                              label: const Text(
                                '시작',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: recordingState.isRecording ? Colors.grey : Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Stop button
                      Expanded(
                        child: Consumer<RecordingState>(
                          builder: (context, recordingState, child) {
                            return ElevatedButton.icon(
                              onPressed: recordingState.isRecording ? _stopRecording : null,
                              icon: const Icon(Icons.stop, size: 24),
                              label: const Text(
                                '중지',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: recordingState.isRecording ? Colors.red : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Saved files list
                  const SavedFilesList(),
                ],
              ),
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('앱을 초기화하는 중...'),
                ],
              ),
            ),
    );
  }
}
