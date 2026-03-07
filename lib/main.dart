// lib/main.dart

import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/permission_service.dart';
import 'screens/overview_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PermissionService.requestStoragePermission();
  await StorageService().init();
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
      home: const OverviewScreen(),
    );
  }
}
