// lib/services/storage_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tier_model.dart';

const _kConfigKey      = 'paytrack_config';
const _kBalancesKey    = 'paytrack_balances';
const _kBotTokenKey    = 'paytrack_bot_token';
const _kAdminUserKey   = 'paytrack_admin_username';
const _kCaptionTplKey  = 'paytrack_caption_template';

const _kAppDir         = '/storage/emulated/0/Paytrackapp';
const _kConfigDir      = '$_kAppDir/Config';
const _kCsvDir         = '$_kAppDir/CSV';
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

  // ── Config (tier defs + assignments + names + balances) ──────────────────

  AppConfig loadConfig() {
    // Load the structural JSON
    AppConfig cfg;
    final raw = _prefs.getString(_kConfigKey);
    if (raw == null) {
      cfg = AppConfig();
    } else {
      try {
        cfg = AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        cfg = AppConfig();
      }
    }

    // Overlay prefs-only fields (token, admin, template)
    return cfg.copyWith(
      botToken:        _prefs.getString(_kBotTokenKey)   ?? '',
      adminUsername:   _prefs.getString(_kAdminUserKey)  ?? 'turja_un',
      captionTemplate: _prefs.getString(_kCaptionTplKey) ??
          AppConfig.defaultCaptionTemplate,
    );
  }

  Future<void> saveConfig(AppConfig config) async {
    // Structural data → JSON key
    await _prefs.setString(_kConfigKey, jsonEncode(config.toJson()));

    // Prefs-only fields → separate keys (never land in Config.json)
    await _prefs.setString(_kBotTokenKey,   config.botToken);
    await _prefs.setString(_kAdminUserKey,  config.adminUsername);
    await _prefs.setString(_kCaptionTplKey, config.captionTemplate);

    await _autoExport();
  }

  // ── Balances ─────────────────────────────────────────────────────────────

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
    await saveBalances(balances);
  }

  // ── CSV files ─────────────────────────────────────────────────────────────

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

  // ── Auto-export (silent) ──────────────────────────────────────────────────

  Future<void> _autoExport() async {
    try {
      await exportConfig();
    } catch (_) {}
  }

  // ── Export to /storage/0/Paytrackapp/Config/Config.json ──────────────────
  // NOTE: botToken / adminUsername / captionTemplate are NOT written here.

  Future<String> exportConfig() async {
    final config   = loadConfig();
    final balances = loadBalances();
    final export   = {
      'config':   config.toJson()['config'],   // tier_defs, user_tiers, names
      'balances': balances,
    };
    final file = File(_kConfigExportFile);
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(export),
        flush: true);
    return _kConfigExportFile;
  }

  // ── Import from Config.json ───────────────────────────────────────────────

  Future<bool> importConfig() async {
    final file = File(_kConfigExportFile);
    if (!file.existsSync()) return false;
    return _applyImport(await file.readAsString());
  }

  Future<bool> importConfigFromFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    try {
      return _applyImport(await file.readAsString());
    } catch (_) {
      return false;
    }
  }

  Future<bool> _applyImport(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data.containsKey('config')) {
        final cfg = AppConfig.fromJson(data);
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

  String get csvDir          => _kCsvDir;
  String get configDir       => _kConfigDir;
  String get configExportPath => _kConfigExportFile;
}
