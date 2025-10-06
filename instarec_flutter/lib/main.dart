import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'services/audio_service.dart';
import 'services/foreground_service.dart';
import 'models/recording_state.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize foreground service
  await ForegroundService.initializeService();
  
  // Request permissions
  await _requestPermissions();
  
  // Keep device awake
  await WakelockPlus.enable();
  
  runApp(const InstaRecApp());
}

Future<void> _requestPermissions() async {
  // Request microphone permission
  await Permission.microphone.request();
  
  // Request storage permission for Android
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }
  
  // Request notification permission for background service
  await Permission.notification.request();
}

class InstaRecApp extends StatelessWidget {
  const InstaRecApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RecordingState()),
        Provider(create: (_) => AudioService()),
      ],
      child: MaterialApp(
        title: 'InstaRec',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}