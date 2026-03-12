// lib/services/storage_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tier_model.dart';

const _kConfigKey = 'paytrack_config';
const _kBalancesKey = 'paytrack_balances';
const _kAppDir = '/storage/emulated/0/Paytrackapp';
const _kConfigDir = '$_kAppDir/Config';
const _kCsvDir = '$_kAppDir/CSV';
const _kConfigExportFile = '$_kConfigDir/Config.json';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _ensureDirectories();
  }

  Future<void> _ensureDirectories() async {
    try {
      await Directory(_kConfigDir).create(recursive: true);
      await Directory(_kCsvDir).create(recursive: true);
    } catch (_) {}
  }

  // ── Config ──────────────────────────────────────────────────────────────

  AppConfig loadConfig() {
    final raw = _prefs.getString(_kConfigKey);
    if (raw == null) return AppConfig();
    try {
      return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppConfig();
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    await _prefs.setString(_kConfigKey, jsonEncode(config.toJson()));
    await _autoExport();
  }

  // ── Balances ────────────────────────────────────────────────────────────

  Map<String, double> loadBalances() {
    final raw = _prefs.getString(_kBalancesKey);
    if (raw == null) return {};
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveBalances(Map<String, double> balances) async {
    await _prefs.setString(_kBalancesKey, jsonEncode(balances));
    await _autoExport();
  }

  Future<void> updateBalance(String userId, double amount) async {
    final balances = loadBalances();
    balances[userId] = (balances[userId] ?? 0.0) + amount;
    await saveBalances(balances); // saveBalances already auto-exports
  }

  // ── CSV files ────────────────────────────────────────────────────────────

  List<File> getCsvFiles() {
    final dir = Directory(_kCsvDir);
    if (!dir.existsSync()) return [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.csv'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  // ── Internal auto-export (silent, no return value) ───────────────────────

  Future<void> _autoExport() async {
    try {
      await exportConfig();
    } catch (_) {
      // Never crash the caller on export failure
    }
  }

  // ── Export config to /storage/0/Paytrackapp/Config/Config.json ──────────

  Future<String> exportConfig() async {
    final config = loadConfig();
    final balances = loadBalances();
    final export = {
      'config': config.toJson(),
      'balances': balances,
    };
    final file = File(_kConfigExportFile);
    await file.writeAsString(jsonEncode(export), flush: true);
    return _kConfigExportFile;
  }

  // ── Import config from /storage/0/Paytrackapp/Config/Config.json ────────

  Future<bool> importConfig() async {
    final file = File(_kConfigExportFile);
    if (!file.existsSync()) return false;
    try {
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data.containsKey('config')) {
        final cfg = AppConfig.fromJson(data['config'] as Map<String, dynamic>);
        await _prefs.setString(_kConfigKey, jsonEncode(cfg.toJson()));
      }
      if (data.containsKey('balances')) {
        final bal = (data['balances'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        await _prefs.setString(_kBalancesKey, jsonEncode(bal));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Import config from a user-picked file path
  Future<bool> importConfigFromFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    try {
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data.containsKey('config')) {
        final cfg = AppConfig.fromJson(data['config'] as Map<String, dynamic>);
        await _prefs.setString(_kConfigKey, jsonEncode(cfg.toJson()));
      }
      if (data.containsKey('balances')) {
        final bal = (data['balances'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        await _prefs.setString(_kBalancesKey, jsonEncode(bal));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  String get csvDir => _kCsvDir;
  String get configDir => _kConfigDir;
  String get configExportPath => _kConfigExportFile;
}
