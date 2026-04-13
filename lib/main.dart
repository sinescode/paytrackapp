// lib/main.dart

import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/permission_service.dart';
import 'services/telegram_service.dart';
import 'screens/overview_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PermissionService.requestStoragePermission();
  await StorageService().init();

  // Hydrate TelegramService singleton from saved prefs so that botToken
  // is always ready — even before the user visits Settings.
  final cfg = StorageService().loadConfig();
  TelegramService().botToken        = cfg.botToken;
  TelegramService().adminUsername   = cfg.adminUsername;
  TelegramService().captionTemplate = cfg.captionTemplate;

  runApp(const PayTrackApp());
}

class PayTrackApp extends StatelessWidget {
  const PayTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PayTrack',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      darkTheme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: const OverviewScreen(),
    );
  }
}
