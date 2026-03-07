// lib/services/permission_service.dart

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestStoragePermission() async {
    // Android 13+ uses granular permissions
    if (Platform.isAndroid) {
      final sdk = await _getAndroidSdk();
      if (sdk >= 33) {
        final photos = await Permission.photos.request();
        // For /storage/emulated/0 access we need MANAGE_EXTERNAL_STORAGE
        final manage = await Permission.manageExternalStorage.request();
        return manage.isGranted;
      } else if (sdk >= 30) {
        final manage = await Permission.manageExternalStorage.request();
        return manage.isGranted;
      } else {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    }
    return true;
  }

  static Future<int> _getAndroidSdk() async {
    // Check SDK version via permission handler
    if (await Permission.manageExternalStorage.isGranted) return 30;
    if (await Permission.storage.status.isGranted) return 28;
    return 30; // assume modern by default
  }

  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;
    final manage = await Permission.manageExternalStorage.status;
    if (manage.isGranted) return true;
    final storage = await Permission.storage.status;
    return storage.isGranted;
  }
}
