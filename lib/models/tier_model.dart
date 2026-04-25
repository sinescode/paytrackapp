// lib/models/tier_model.dart

import 'dart:convert';

// ── Tier Definition ───────────────────────────────────────────────────────────
//
// JSON (inside config.tier_definitions):
// { "id": 3, "name": "PR 3", "min_ok": 1000, "max_ok": 99999, "price_per_ok": 4.1 }

class TierDefinition {
  final int id;
  final String name;
  final int minOk;
  final int maxOk;
  final double pricePerOk;

  TierDefinition({
    required this.id,
    required this.name,
    required this.minOk,
    required this.maxOk,
    required this.pricePerOk,
  });

  factory TierDefinition.fromJson(Map<String, dynamic> j) => TierDefinition(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString() ?? '',
        minOk: (j['min_ok'] as num).toInt(),
        maxOk: (j['max_ok'] as num).toInt(),
        pricePerOk: (j['price_per_ok'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'min_ok': minOk,
        'max_ok': maxOk,
        'price_per_ok': pricePerOk,
      };

  TierDefinition copyWith({
    int? id,
    String? name,
    int? minOk,
    int? maxOk,
    double? pricePerOk,
  }) =>
      TierDefinition(
        id: id ?? this.id,
        name: name ?? this.name,
        minOk: minOk ?? this.minOk,
        maxOk: maxOk ?? this.maxOk,
        pricePerOk: pricePerOk ?? this.pricePerOk,
      );

  @override
  String toString() =>
      'TierDefinition(id:$id, name:$name, min:$minOk, max:$maxOk, price:$pricePerOk)';
}

// ── UserTier — resolved lightweight view used by CardGenerator etc. ───────────
//
// NOT stored in JSON. Built at runtime from the int-ID list in user_tiers.

class UserTier {
  final int minOk;
  final int maxOk;
  final double pricePerOk;

  UserTier({
    required this.minOk,
    required this.maxOk,
    required this.pricePerOk,
  });

  factory UserTier.fromJson(Map<String, dynamic> j) => UserTier(
        minOk: (j['min_ok'] as num).toInt(),
        maxOk: (j['max_ok'] as num).toInt(),
        pricePerOk: (j['price_per_ok'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'min_ok': minOk,
        'max_ok': maxOk,
        'price_per_ok': pricePerOk,
      };
}

// ── AppConfig ─────────────────────────────────────────────────────────────────
//
// On-disk JSON shape (Config.json):
// {
//   "config": {
//     "tier_definitions": [
//       { "id": 3, "name": "PR 3", "min_ok": 1000, "max_ok": 99999, "price_per_ok": 4.1 },
//       ...
//     ],
//     "user_tiers": {
//       "5247038532": [1, 2, 3],   ← list of tier-definition IDs
//       ...
//     },
//     "custom_names": { "8274064877": "Sahriya", ... }
//   },
//   "balances": { "8274064877": -924.7, ... }
// }
//
// botToken / adminUsername / captionTemplate are stored ONLY in SharedPreferences
// (via StorageService) and are NEVER written to Config.json.

class AppConfig {
  // ── Prefs-only fields (never exported to file) ────────────────────────────
  final String botToken;
  final String adminUsername;

  /// Telegram caption template. Placeholders: {user_id}  {date}  {admin}
  final String captionTemplate;

  // ── Exported fields ───────────────────────────────────────────────────────
  final List<TierDefinition> tierDefinitions;

  /// Per-user ordered list of tier IDs — mirrors JSON user_tiers exactly.
  final Map<String, List<int>> userTierIds;

  final Map<String, String> customNames;

  /// Per-user balance (negative = credit owed to user).
  final Map<String, double> balances;

  /// Frozen tier prices per CSV filename.
  /// Written once the first time a CSV file is seen. Never overwritten.
  /// Shape: { "2025-01.csv": { tierId: pricePerOk, ... }, ... }
  final Map<String, Map<int, double>> csvTierSnapshots;

  // ── Default caption template ──────────────────────────────────────────────
  static const String defaultCaptionTemplate =
      '🧾 <b>Payment Receipt</b>\n\n'
      '👤 <b>User ID:</b> <code>{user_id}</code>\n'
      '📅 <b>Date:</b> {date}\n\n'
      '📨 Please <b>forward this message</b> to admin for payment verification.\n'
      '👨‍💼 <b>Admin:</b> @{admin}';

  AppConfig({
    this.botToken = '',
    this.adminUsername = 'turja_un',
    String? captionTemplate,
    List<TierDefinition>? tierDefinitions,
    Map<String, List<int>>? userTierIds,
    Map<String, String>? customNames,
    Map<String, double>? balances,
    Map<String, Map<int, double>>? csvTierSnapshots,
  })  : captionTemplate = captionTemplate ?? AppConfig.defaultCaptionTemplate,
        tierDefinitions = tierDefinitions ?? [],
        userTierIds = userTierIds ?? {},
        customNames = customNames ?? {},
        balances = balances ?? {},
        csvTierSnapshots = csvTierSnapshots ?? {};

  // ── Resolve helpers ───────────────────────────────────────────────────────

  Map<int, TierDefinition> get _tierById =>
      {for (final t in tierDefinitions) t.id: t};

  /// Backward-compat stub — the new model has no global tiers.
  /// DataService falls back to this when a user has no assigned tiers.
  List<UserTier> get globalTiers => [];

  /// Resolved TierDefinition objects for one user (silently skips unknown IDs).
  List<TierDefinition> tiersForUser(String userId) {
    final byId = _tierById;
    return (userTierIds[userId] ?? [])
        .map((id) => byId[id])
        .whereType<TierDefinition>()
        .toList();
  }

  /// Resolved UserTier list for one user — used by legacy callers.
  List<UserTier> userTiersForUser(String userId) => tiersForUser(userId)
      .map((d) => UserTier(minOk: d.minOk, maxOk: d.maxOk, pricePerOk: d.pricePerOk))
      .toList();

  /// Resolved map of all users → UserTier list.
  Map<String, List<UserTier>> get userTiers => {
        for (final uid in userTierIds.keys) uid: userTiersForUser(uid),
      };

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Parses the full on-disk JSON.
  /// Accepts the wrapped format { "config": {...}, "balances": {...} }
  /// and falls back to a flat/legacy format { "tier_definitions": [...], ... }.
  /// botToken / adminUsername / captionTemplate are NOT read from JSON here —
  /// StorageService loads them separately from SharedPreferences.
  factory AppConfig.fromJson(Map<String, dynamic> root) {
    final bool wrapped = root.containsKey('config');
    final Map<String, dynamic> cfg =
        wrapped ? (root['config'] as Map<String, dynamic>) : root;

    // tier_definitions
    final tierDefs = <TierDefinition>[];
    for (final raw in (cfg['tier_definitions'] as List? ?? [])) {
      tierDefs.add(TierDefinition.fromJson(raw as Map<String, dynamic>));
    }

    // user_tiers → Map<userId, List<int>>
    final userTierIds = <String, List<int>>{};
    (cfg['user_tiers'] as Map<String, dynamic>? ?? {}).forEach((uid, rawList) {
      userTierIds[uid] =
          (rawList as List).map((v) => (v as num).toInt()).toList();
    });

    // custom_names
    final customNames = <String, String>{};
    (cfg['custom_names'] as Map<String, dynamic>? ?? {})
        .forEach((k, v) => customNames[k] = v.toString());

    // balances (top-level key)
    final balances = <String, double>{};
    (root['balances'] as Map<String, dynamic>? ?? {})
        .forEach((k, v) => balances[k] = (v as num).toDouble());

    // csv_tier_snapshots (inside config)
    final csvTierSnapshots = <String, Map<int, double>>{};
    (cfg['csv_tier_snapshots'] as Map<String, dynamic>? ?? {})
        .forEach((filename, rawMap) {
      final priceById = <int, double>{};
      (rawMap as Map<String, dynamic>).forEach((idStr, price) {
        final id = int.tryParse(idStr);
        if (id != null) priceById[id] = (price as num).toDouble();
      });
      csvTierSnapshots[filename] = priceById;
    });

    return AppConfig(
      tierDefinitions: tierDefs,
      userTierIds: userTierIds,
      customNames: customNames,
      balances: balances,
      csvTierSnapshots: csvTierSnapshots,
    );
  }

  factory AppConfig.fromJsonString(String src) =>
      AppConfig.fromJson(jsonDecode(src) as Map<String, dynamic>);

  /// Serialises back to the wrapped format. botToken / adminUsername /
  /// captionTemplate are intentionally excluded.
  Map<String, dynamic> toJson() => {
        'config': {
          'tier_definitions': tierDefinitions.map((t) => t.toJson()).toList(),
          'user_tiers': userTierIds.map((uid, ids) => MapEntry(uid, ids)),
          'custom_names': customNames,
          'csv_tier_snapshots': csvTierSnapshots.map(
            (filename, priceById) => MapEntry(
              filename,
              priceById.map((id, price) => MapEntry(id.toString(), price)),
            ),
          ),
        },
        'balances': balances,
      };

  String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  // ── Immutable copy ─────────────────────────────────────────────────────────

  AppConfig copyWith({
    String? botToken,
    String? adminUsername,
    String? captionTemplate,
    List<TierDefinition>? tierDefinitions,
    Map<String, List<int>>? userTierIds,
    Map<String, String>? customNames,
    Map<String, double>? balances,
    Map<String, Map<int, double>>? csvTierSnapshots,
  }) =>
      AppConfig(
        botToken: botToken ?? this.botToken,
        adminUsername: adminUsername ?? this.adminUsername,
        captionTemplate: captionTemplate ?? this.captionTemplate,
        tierDefinitions: tierDefinitions ?? List.from(this.tierDefinitions),
        userTierIds: userTierIds ??
            {
              for (final e in this.userTierIds.entries)
                e.key: List<int>.from(e.value)
            },
        customNames: customNames ?? Map.from(this.customNames),
        balances: balances ?? Map.from(this.balances),
        csvTierSnapshots: csvTierSnapshots ??
            {
              for (final e in this.csvTierSnapshots.entries)
                e.key: Map<int, double>.from(e.value)
            },
      );

  // ── Tier mutation helpers ─────────────────────────────────────────────────

  int get nextTierId => tierDefinitions.isEmpty
      ? 1
      : tierDefinitions.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;

  AppConfig upsertTier(TierDefinition def) {
    final exists = tierDefinitions.any((t) => t.id == def.id);
    final updated = exists
        ? [for (final t in tierDefinitions) t.id == def.id ? def : t]
        : [...tierDefinitions, def];
    return copyWith(tierDefinitions: updated);
  }

  AppConfig removeTier(int tierId) => copyWith(
        tierDefinitions: tierDefinitions.where((t) => t.id != tierId).toList(),
        userTierIds: userTierIds.map(
          (uid, ids) =>
              MapEntry(uid, ids.where((id) => id != tierId).toList()),
        ),
      );
}
