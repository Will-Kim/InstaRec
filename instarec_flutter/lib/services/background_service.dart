import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:volume_controller/volume_controller.dart';

class BackgroundService {
  
  // Volume button listeners
  static StreamSubscription? _volumeUpSubscription;
  static StreamSubscription? _volumeDownSubscription;
  
  // Callback functions
  static Function()? _onVolumeUpPressed;
  static Function()? _onVolumeDownPressed;

  // Initialize background service
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'instarec_channel',
        initialNotificationTitle: 'InstaRec',
        initialNotificationContent: '백그라운드에서 녹음 중...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  // Start background service
  static Future<void> startService() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  // Stop background service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
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

  // Background service entry point
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Start volume button listeners
    startVolumeButtonListeners();

    // Keep service running
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "InstaRec",
            content: "백그라운드에서 녹음 중... ${DateTime.now()}",
          );
        }
      }

      // Send data to UI
      service.invoke('update', {
        "current_date": DateTime.now().toIso8601String(),
        "device": "Android",
      });
    });
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  // Dispose resources
  static void dispose() {
    stopVolumeButtonListeners();
  }
}

// Global function for service initialization
Future<void> initializeService() async {
  BackgroundService.initializeService();
}
