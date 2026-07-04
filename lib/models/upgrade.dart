import 'dart:math' as math;

import '../core/constants.dart';
import 'enums.dart';

/// Een netwerk-upgrade met zijn huidige level. Immutable.
///
/// Regels: GDD 7.1. Kosten volgen basis x groeifactor^level
/// (Upgrades-tab: level 1 kost de basisprijs).
class Upgrade {
  const Upgrade({required this.id, this.level = 0});

  final UpgradeId id;
  final int level;

  double get basePrice => switch (id) {
    // Vervallen slot: niet meer koopbaar (maxLevel 0).
    UpgradeId.cassettes => 0,
    UpgradeId.ibns => kIbnsUpgradeBasePrice,
    UpgradeId.citRoute => kCitRouteUpgradeBasePrice,
  };

  double get growthFactor => switch (id) {
    UpgradeId.cassettes => 1,
    UpgradeId.ibns => kIbnsUpgradeGrowth,
    UpgradeId.citRoute => kCitRouteUpgradeGrowth,
  };

  int get maxLevel => switch (id) {
    UpgradeId.cassettes => 0,
    UpgradeId.ibns => kIbnsUpgradeMaxLevel,
    UpgradeId.citRoute => kCitRouteUpgradeMaxLevel,
  };

  bool get isMaxed => level >= maxLevel;

  /// Kosten van het volgende level.
  double get nextLevelCost => basePrice * math.pow(growthFactor, level);

  Upgrade copyWith({int? level}) => Upgrade(id: id, level: level ?? this.level);
}
