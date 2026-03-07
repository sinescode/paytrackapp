// lib/services/data_service.dart

import 'dart:io';
import 'package:csv/csv.dart';
import '../models/csv_entry.dart';
import '../models/tier_model.dart';
import 'storage_service.dart';

class DataService {
  final StorageService _storage;

  DataService(this._storage);

  // ── Tier calculation ────────────────────────────────────────────────────

  (double pricePerOk, double total) calculateTotal(
      int okCount, AppConfig config, String? userId) {
    List<UserTier> tiers;
    if (userId != null && config.userTiers.containsKey(userId)) {
      tiers = config.userTiers[userId]!;
    } else {
      tiers = config.globalTiers;
    }
    if (tiers.isEmpty) return (0.0, 0.0);
    for (final tier in tiers) {
      if (okCount >= tier.minOk && okCount <= tier.maxOk) {
        return (tier.pricePerOk, okCount * tier.pricePerOk);
      }
    }
    return (0.0, 0.0);
  }

  // ── CSV parsing ─────────────────────────────────────────────────────────

  List<CsvEntry> parseCsvFile(File file, AppConfig config) {
    final rows = <CsvEntry>[];
    try {
      final content = file.readAsStringSync();
      final lines = CsvToListConverter(eol: '\n').convert(content);
      if (lines.isEmpty) return rows;

      // Find header indices
      final headers =
          lines.first.map((e) => e.toString().trim()).toList();
      int idx(String name) => headers.indexOf(name);

      final iUserId = idx('User ID');
      final iUsername = idx('Username');
      final iOkCount = idx('OK Count');
      final iRate = idx('Rate');
      final iBkash = idx('Bkash');
      final iRocket = idx('Rocket');
      final iPaidStatus = idx('Paid Status');

      final filename = file.path.split('/').last;

      for (int i = 1; i < lines.length; i++) {
        final row = lines[i];
        if (row.length <= iOkCount) continue;
        final userId = iUserId >= 0 ? row[iUserId].toString().trim() : '';
        final username = iUsername >= 0 ? row[iUsername].toString().trim() : '';
        final okStr = iOkCount >= 0 ? row[iOkCount].toString().trim() : '';
        final okCount = int.tryParse(okStr) ?? -1;
        if (okCount < 0) continue;

        final paidStatus = iPaidStatus >= 0 ? row[iPaidStatus].toString().trim().toLowerCase() : '';
        final bkash = iBkash >= 0 ? row[iBkash].toString().trim() : 'Not Provided';
        final rocket = iRocket >= 0 ? row[iRocket].toString().trim() : 'Not Provided';

        var (pricePerOk, total) = calculateTotal(okCount, config, userId);

        if (pricePerOk == 0.0 && total == 0.0) {
          final rateStr = iRate >= 0 ? row[iRate].toString().trim() : '';
          final rate = double.tryParse(rateStr) ?? 0.0;
          pricePerOk = rate;
          total = okCount * rate;
        }

        rows.add(CsvEntry(
          filename: filename,
          userId: userId,
          username: username,
          okCount: okCount,
          pricePerOk: pricePerOk,
          total: total,
          bkash: bkash.isEmpty ? 'Not Provided' : bkash,
          rocket: rocket.isEmpty ? 'Not Provided' : rocket,
          paidStatus: paidStatus,
        ));
      }
    } catch (_) {}
    return rows;
  }

  List<CsvEntry> loadAllData() {
    final config = _storage.loadConfig();
    final all = <CsvEntry>[];
    for (final file in _storage.getCsvFiles()) {
      all.addAll(parseCsvFile(file, config));
    }
    return all;
  }

  // ── User aggregation ─────────────────────────────────────────────────────

  double getNetPending(List<CsvEntry> data, String userId,
      Map<String, double>? balances) {
    balances ??= _storage.loadBalances();
    final entriesTotal =
        data.where((e) => e.userId == userId).fold(0.0, (s, e) => s + e.total);
    final balance = balances[userId] ?? 0.0;
    return entriesTotal + balance;
  }

  List<UserSummary> buildUserSummaries() {
    final data = loadAllData();
    final config = _storage.loadConfig();
    final balances = _storage.loadBalances();

    final allIds = <String>{
      ...data.map((e) => e.userId),
      ...balances.keys,
    };

    return allIds.map((uid) {
      final name = config.customNames[uid];
      return UserSummary(
        userId: uid,
        displayName: name != null && name.isNotEmpty ? name : uid,
        pending: getNetPending(data, uid, balances),
      );
    }).toList()
      ..sort((a, b) => b.pending.compareTo(a.pending));
  }

  List<Map<String, dynamic>> getUserEntries(
      List<CsvEntry> data, String userId) {
    return data
        .where((e) => e.userId == userId)
        .map((e) => {
              'date': e.date,
              'filename': e.filename,
              'ok_count': e.okCount,
              'price_per_ok': e.pricePerOk,
              'total': e.total,
              'bkash': e.bkash,
              'rocket': e.rocket,
            })
        .toList()
      ..sort((a, b) => (a['filename'] as String).compareTo(b['filename'] as String));
  }
}
