// lib/services/data_service.dart

import 'dart:io';
import 'package:csv/csv.dart';  // This stays the same
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

  // ── Rate snapshot ───────────────────────────────────────────────────────
  //
  // Writes the resolved pricePerOk into the 'Rate' column of a CSV row so
  // that future reloads use the frozen value instead of re-running tier lookup.
  // If the 'Rate' column doesn't exist yet, it is appended to every row.
  //
  // Parameters:
  //   file      – the CSV File being written back
  //   rowIndex  – 1-based index of the data row inside [allRows]
  //   rateColIdx – current index of the Rate column (-1 if absent)
  //   rate      – the resolved pricePerOk to save
  //   allRows   – all parsed rows (header at index 0)
  void _snapshotRate(
    File file,
    int rowIndex,
    int rateColIdx,
    double rate,
    List<List<dynamic>> allRows,
  ) {
    try {
      if (rateColIdx == -1) {
        // Add 'Rate' header and fill every data row with its current value.
        // We only have the rate for this one row right now — other rows will
        // be filled on their own first-load pass.  Set them to '' so they
        // trigger tier lookup on next reload.
        allRows[0].add('Rate');
        for (int i = 1; i < allRows.length; i++) {
          allRows[i].add(i == rowIndex ? rate.toString() : '');
        }
      } else {
        // Column already exists — just update this row.
        allRows[rowIndex][rateColIdx] = rate.toString();
      }

      // Re-encode the entire file.
      final buffer = StringBuffer();
      for (final row in allRows) {
        buffer.writeln(row.map((cell) {
          final s = cell.toString();
          // Quote cells that contain commas, quotes, or newlines.
          if (s.contains(',') || s.contains('"') || s.contains('\n')) {
            return '"${s.replaceAll('"', '""')}"';
          }
          return s;
        }).join(','));
      }
      file.writeAsStringSync(buffer.toString());
    } catch (_) {
      // Snapshot is best-effort — a write failure must never crash the UI.
    }
  }

  // ── CSV parsing ─────────────────────────────────────────────────────────

  List<CsvEntry> parseCsvFile(File file, AppConfig config) {
    final rows = <CsvEntry>[];
    try {
      final content = file.readAsStringSync();
      
      // FIX: Use csv.decode() instead of CsvToListConverter for v7 API
      // The v7 API automatically detects line endings, so no need for eol parameter
      final lines = csv.decode(content);
      
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

        // ── Price resolution (priority order) ────────────────────────────
        // 1. Use the Rate already written in the CSV row (frozen at import).
        //    This prevents tier price changes from retroactively affecting
        //    historical entries.
        // 2. Only fall back to live tier lookup when Rate is absent/zero
        //    (e.g., a freshly dropped file that has never been priced).
        // 3. After a successful tier lookup, write the Rate back into the CSV
        //    so future reloads use the frozen value (see _snapshotRate below).

        final savedRateStr = iRate >= 0 ? row[iRate].toString().trim() : '';
        final savedRate = double.tryParse(savedRateStr) ?? 0.0;

        double pricePerOk;
        double total;

        if (savedRate > 0.0) {
          // ✅ Rate already frozen in file — use it directly.
          pricePerOk = savedRate;
          total = okCount * savedRate;
        } else {
          // 🔍 No saved rate — resolve from current tier definitions.
          (pricePerOk, total) = calculateTotal(okCount, config, userId);

          // Persist the resolved rate back into the CSV so it is frozen
          // from this point forward (won't change when tiers are edited).
          if (pricePerOk > 0.0) {
            _snapshotRate(file, i, iRate, pricePerOk, lines);
          }
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
