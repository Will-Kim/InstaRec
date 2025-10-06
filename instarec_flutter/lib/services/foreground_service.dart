import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:volume_controller/volume_controller.dart';

class ForegroundService {
  
  // Volume button listeners
  static StreamSubscription? _volumeUpSubscription;
  static StreamSubscription? _volumeDownSubscription;
  
  // Callback functions
  static Function()? _onVolumeUpPressed;
  static Function()? _onVolumeDownPressed;

  // Initialize foreground service
  static Future<void> initializeService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'instarec_channel',
        channelName: 'InstaRec Recording',
        channelDescription: 'InstaRec 백그라운드 녹음 서비스',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  // Start foreground service
  static Future<ServiceRequestResult> startService() async {
    return await FlutterForegroundTask.startService(
      notificationTitle: 'InstaRec',
      notificationText: '백그라운드에서 녹음 중...',
      callback: startCallback,
    );
  }

  // Stop foreground service
  static Future<ServiceRequestResult> stopService() async {
    return await FlutterForegroundTask.stopService();
  }

  // Set volume button callbacks
  static void setVolumeButtonCallbacks({
    Function()? onVolumeUp,
    Function()? onVolumeDown,
  }) {
    _onVolumeUpPressed = onVolumeUp;
    _onVolumeDownPressed = onVolumeDown;
  }

  // Start volume button listeners
  static void startVolumeButtonListeners() {
    // Volume up listener
    _volumeUpSubscription = VolumeController().listener((volume) {
      // Volume up detection logic
      if (_onVolumeUpPressed != null) {
        _onVolumeUpPressed!();
      }
    });

    // Volume down listener  
    _volumeDownSubscription = VolumeController().listener((volume) {
      // Volume down detection logic
      if (_onVolumeDownPressed != null) {
        _onVolumeDownPressed!();
      }
    });
  }

  // Stop volume button listeners
  static void stopVolumeButtonListeners() {
    _volumeUpSubscription?.cancel();
    _volumeDownSubscription?.cancel();
    _volumeUpSubscription = null;
    _volumeDownSubscription = null;
  }

  // Dispose resources
  static void dispose() {
    stopVolumeButtonListeners();
  }
}

// Foreground task callback
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(InstaRecTaskHandler());
}

// Task handler class
class InstaRecTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Start volume button listeners
    ForegroundService.startVolumeButtonListeners();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Update notification
    FlutterForegroundTask.updateService(
      notificationTitle: 'InstaRec',
      notificationText: '백그라운드에서 녹음 중... ${timestamp.toString().substring(11, 19)}',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Clean up
    ForegroundService.stopVolumeButtonListeners();
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button press
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    // Launch app when notification is pressed
    FlutterForegroundTask.launchApp();
  }
}
