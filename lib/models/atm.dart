import '../core/constants.dart';
import 'enums.dart';

/// Een geplaatste geldautomaat. Immutable; wijzigingen gaan via [copyWith].
///
/// Regels: GDD 3.3 (tiers), GDD 4 (slijtage en storingen), GDD 5 (locatie
/// en drukteprofiel).
class Atm {
  const Atm({
    required this.id,
    required this.tier,
    required this.location,
    required this.notesInCassette,
    required this.condition,
    this.repairSecondsRemaining = 0,
    this.outageSecondsRemaining = 0,
    this.lifetimeEarned = 0,
  });

  /// Nieuwe automaat zoals hij geplaatst wordt: volle cassette, staat 100%.
  factory Atm.fresh({
    required int id,
    required LocationType location,
    AtmTier tier = AtmTier.lobbyBasic,
    int cassetteUpgradeLevel = 0,
  }) {
    return Atm(
      id: id,
      tier: tier,
      location: location,
      notesInCassette: capacityFor(tier, cassetteUpgradeLevel),
      condition: 1.0,
    );
  }

  final int id;
  final AtmTier tier;
  final LocationType location;

  /// Aantal biljetten in de cassette.
  final int notesInCassette;

  /// Staat-balk van 0,0 tot 1,0. Bij nul valt de automaat uit (GDD 4).
  final double condition;

  /// Resterende reparatietijd in seconden; groter dan nul betekent uitval.
  final double repairSecondsRemaining;

  /// Resterende stroomstoringstijd in seconden (event, GDD 6).
  final double outageSecondsRemaining;

  /// Totaal verdiend door deze automaat, voor het schermpje op de kast.
  final double lifetimeEarned;

  bool get isBroken => repairSecondsRemaining > 0;

  bool get isPausedByOutage => outageSecondsRemaining > 0;

  /// Operationeel: niet in reparatie en niet gepauzeerd door een event.
  bool get isOperational => !isBroken && !isPausedByOutage;

  bool get isTouristLocation => kTouristLocations.contains(location);

  /// Cassettecapaciteit voor deze tier bij het gegeven cassette-upgradelevel.
  /// Capaciteitsbonus is additief per level (GDD 7.1, +40% per level).
  static int capacityFor(AtmTier tier, int cassetteUpgradeLevel) {
    final base = kTierCapacity[tier.index];
    return (base * (1 + kCassetteCapacityBonusPerLevel * cassetteUpgradeLevel))
        .round();
  }

  int capacity(int cassetteUpgradeLevel) =>
      capacityFor(tier, cassetteUpgradeLevel);

  /// Inkomen per transactie voor deze tier, voor multipliers.
  double get incomePerTransaction => kTierIncomePerTransaction[tier.index];

  Atm copyWith({
    AtmTier? tier,
    int? notesInCassette,
    double? condition,
    double? repairSecondsRemaining,
    double? outageSecondsRemaining,
    double? lifetimeEarned,
  }) {
    return Atm(
      id: id,
      tier: tier ?? this.tier,
      location: location,
      notesInCassette: notesInCassette ?? this.notesInCassette,
      condition: condition ?? this.condition,
      repairSecondsRemaining:
          repairSecondsRemaining ?? this.repairSecondsRemaining,
      outageSecondsRemaining:
          outageSecondsRemaining ?? this.outageSecondsRemaining,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
    );
  }
}
