import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recording_state.dart';

class BufferSettings extends StatelessWidget {
  const BufferSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingState>(
      builder: (context, recordingState, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '버퍼 시간 설정',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                
                // Quick preset buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [10, 30, 60, 120, 300].map((duration) {
                    final isSelected = recordingState.bufferDuration == duration;
                    return FilterChip(
                      label: Text('$duration초'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          recordingState.setBufferDuration(duration);
                        }
                      },
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Custom duration input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '사용자 정의 (10-300초)',
                          border: OutlineInputBorder(),
                          suffixText: '초',
                        ),
                        onSubmitted: (value) {
                          final duration = int.tryParse(value);
                          if (duration != null && duration >= 10 && duration <= 300) {
                            recordingState.setBufferDuration(duration);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('10-300초 범위의 값을 입력해주세요'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _showCustomDurationDialog(context, recordingState);
                      },
                      child: const Text('설정'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCustomDurationDialog(BuildContext context, RecordingState recordingState) {
    final controller = TextEditingController(text: recordingState.bufferDuration.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('버퍼 시간 설정'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '초 단위 (10-300)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final duration = int.tryParse(controller.text);
              if (duration != null && duration >= 10 && duration <= 300) {
                recordingState.setBufferDuration(duration);
                Navigator.of(context).pop();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('10-300초 범위의 값을 입력해주세요'),
                  ),
                );
              }
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
