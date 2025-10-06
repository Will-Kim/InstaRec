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
            if (_audioService!.isCapturing) {
              recordingState.startCapture();
            } else {
              recordingState.stopCapture();
            }
          }
        },
      );

      // Load saved settings
      await _loadSettings();

      // Start continuous recording
      await _audioService!.startContinuousRecording();

      // Start initial capture (actual buffering)
      await _audioService!.startCapture();

      // Set initial capturing state
      if (mounted) {
        final recordingState = Provider.of<RecordingState>(context, listen: false);
        recordingState.startCapture();
      }

      // Start background service
      await BackgroundService.startService();

      // Set up volume button callbacks
      BackgroundService.setVolumeButtonCallbacks(
        onVolumeUp: _toggleCapture,
        onVolumeDown: _toggleCapture,
      );

      setState(() {
        _isInitialized = true;
      });

      if (kDebugMode) {
        print('✅ InstaRec 앱 초기화 완료');
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


  Future<void> _toggleCapture() async {
    if (!_isInitialized || _audioService == null) return;

    final recordingState = Provider.of<RecordingState>(context, listen: false);
    
    try {
      if (recordingState.isCapturing) {
        // Stop capture and save file
        final fileInfo = await _audioService!.stopCapture();
        if (fileInfo.isNotEmpty) {
          recordingState.addSavedFile(fileInfo);
        }
        recordingState.stopCapture();
      } else {
        // Start capture
        await _audioService!.startCapture();
        recordingState.startCapture();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 캡처 토글 실패: $e');
      }
      _showErrorDialog('캡처 실패', e.toString());
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
        title: const Text('InstaRec'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Consumer<RecordingState>(
            builder: (context, recordingState, child) {
              return IconButton(
                icon: Icon(
                  recordingState.isCapturing ? Icons.stop : Icons.fiber_manual_record,
                  color: recordingState.statusColor,
                ),
                onPressed: _toggleCapture,
                tooltip: recordingState.isCapturing ? '캡처 중지' : '캡처 시작',
              );
            },
          ),
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
                  
                  const SizedBox(height: 24),
                  
                  // Capture button
                  Consumer<RecordingState>(
                    builder: (context, recordingState, child) {
                      return ElevatedButton.icon(
                        onPressed: _toggleCapture,
                        icon: Icon(
                          recordingState.isCapturing ? Icons.stop : Icons.fiber_manual_record,
                          size: 32,
                        ),
                        label: Text(
                          recordingState.isCapturing ? '캡처 중지' : '캡처 시작',
                          style: const TextStyle(fontSize: 18),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: recordingState.statusColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      );
                    },
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
