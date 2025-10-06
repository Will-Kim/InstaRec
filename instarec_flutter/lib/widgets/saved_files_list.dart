import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/recording_state.dart';
import '../services/audio_service.dart';

class SavedFilesList extends StatefulWidget {
  const SavedFilesList({super.key});

  @override
  State<SavedFilesList> createState() => _SavedFilesListState();
}

class _SavedFilesListState extends State<SavedFilesList> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlaying;
  bool _isLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playFile(String filePath) async {
    try {
      if (_currentlyPlaying == filePath) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlaying = null;
        });
      } else {
        await _audioPlayer.stop();
        
        // iOS에서는 Documents 폴더 파일을 직접 재생할 수 없으므로 임시 폴더로 복사
        final audioService = AudioService();
        final playablePath = await audioService.copyToPlayableLocation(filePath);
        
        await _audioPlayer.play(DeviceFileSource(playablePath));
        setState(() {
          _currentlyPlaying = filePath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('재생 실패: $e')),
        );
      }
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Copy file to playable location for sharing
      final audioService = AudioService();
      final shareablePath = await audioService.copyToPlayableLocation(filePath);
      await audioService.shareFile(shareablePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공유 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteFile(String filePath, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('파일 삭제'),
        content: const Text('이 파일을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });
        
        final audioService = AudioService();
        final success = await audioService.deleteFile(filePath);
        
        if (success) {
          if (mounted) {
            final recordingState = Provider.of<RecordingState>(context, listen: false);
            recordingState.removeFile(index);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일이 삭제되었습니다')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('파일 삭제에 실패했습니다')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingState>(
      builder: (context, recordingState, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '저장된 파일:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : recordingState.savedFiles.isEmpty
                    ? const Text('저장된 파일이 없습니다.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recordingState.savedFiles.length,
                        itemBuilder: (context, index) {
                          final file = recordingState.savedFiles[index];
                          final fileName = file['fileName'] ?? file['wavPath']?.split('/').last ?? 'Unknown';
                          final timestamp = DateTime.fromMillisecondsSinceEpoch(file['timestamp']).toLocal();
                          final fileSize = file['fileSize'] ?? 0;
                          final isPlaying = _currentlyPlaying == file['wavPath'];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              fileName,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                            if (fileSize > 0)
                                              Text(
                                                _formatFileSize(fileSize),
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                                            onPressed: () => _playFile(file['wavPath']),
                                            tooltip: isPlaying ? '정지' : '재생',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.share),
                                            onPressed: () => _shareFile(file['wavPath']),
                                            tooltip: '공유',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            onPressed: () => _deleteFile(file['wavPath'], index),
                                            tooltip: '삭제',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        );
      },
    );
  }
}