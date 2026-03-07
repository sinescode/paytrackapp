// lib/models/tier_model.dart

class TierDefinition {
  final String name;
  final int minOk;
  final int maxOk;
  final double pricePerOk;

  TierDefinition({
    required this.name,
    required this.minOk,
    required this.maxOk,
    required this.pricePerOk,
  });

  factory TierDefinition.fromJson(Map<String, dynamic> j) => TierDefinition(
        name: j['name'] ?? '',
        minOk: (j['min_ok'] as num).toInt(),
        maxOk: (j['max_ok'] as num).toInt(),
        pricePerOk: (j['price_per_ok'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'min_ok': minOk,
        'max_ok': maxOk,
        'price_per_ok': pricePerOk,
      };
}

class UserTier {
  final int minOk;
  final int maxOk;
  final double pricePerOk;

  UserTier({required this.minOk, required this.maxOk, required this.pricePerOk});

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

class AppConfig {
  Map<String, String> customNames;
  List<UserTier> globalTiers;
  Map<String, List<UserTier>> userTiers;
  List<TierDefinition> tierDefinitions;

  AppConfig({
    Map<String, String>? customNames,
    List<UserTier>? globalTiers,
    Map<String, List<UserTier>>? userTiers,
    List<TierDefinition>? tierDefinitions,
  })  : customNames = customNames ?? {},
        globalTiers = globalTiers ?? [],
        userTiers = userTiers ?? {},
        tierDefinitions = tierDefinitions ?? [];

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final customNames = <String, String>{};
    (j['custom_names'] as Map<String, dynamic>? ?? {}).forEach((k, v) {
      customNames[k] = v.toString();
    });

    final globalTiers = <UserTier>[];
    for (final t in (j['global_tiers'] as List? ?? [])) {
      globalTiers.add(UserTier.fromJson(t as Map<String, dynamic>));
    }

    final userTiers = <String, List<UserTier>>{};
    (j['user_tiers'] as Map<String, dynamic>? ?? {}).forEach((uid, tList) {
      userTiers[uid] = (tList as List)
          .map((t) => UserTier.fromJson(t as Map<String, dynamic>))
          .toList();
    });

    final tierDefs = <TierDefinition>[];
    for (final t in (j['tier_definitions'] as List? ?? [])) {
      tierDefs.add(TierDefinition.fromJson(t as Map<String, dynamic>));
    }

    return AppConfig(
      customNames: customNames,
      globalTiers: globalTiers,
      userTiers: userTiers,
      tierDefinitions: tierDefs,
    );
  }

  Map<String, dynamic> toJson() => {
        'custom_names': customNames,
        'global_tiers': globalTiers.map((t) => t.toJson()).toList(),
        'user_tiers': userTiers.map((k, v) => MapEntry(k, v.map((t) => t.toJson()).toList())),
        'tier_definitions': tierDefinitions.map((t) => t.toJson()).toList(),
      };

  AppConfig copyWith({
    Map<String, String>? customNames,
    List<UserTier>? globalTiers,
    Map<String, List<UserTier>>? userTiers,
    List<TierDefinition>? tierDefinitions,
  }) =>
      AppConfig(
        customNames: customNames ?? Map.from(this.customNames),
        globalTiers: globalTiers ?? List.from(this.globalTiers),
        userTiers: userTiers ?? Map.from(this.userTiers),
        tierDefinitions: tierDefinitions ?? List.from(this.tierDefinitions),
      );
}
