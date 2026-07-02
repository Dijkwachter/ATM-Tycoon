import 'dart:math' as math;

import '../core/constants.dart';
import 'atm.dart';
import 'bank.dart';
import 'enums.dart';
import 'staff.dart';
import 'upgrade.dart';

/// Een lopend druktemodificerend event (Koningsdag of Festivalweekend).
/// Instant-events (plofkraak) en pauze-events (stroomstoring) werken direct
/// op de automaat en staan niet in dit model. Bron: GDD 6.
class ActiveEvent {
  const ActiveEvent({
    required this.type,
    required this.secondsRemaining,
    this.targetAtmId,
  });

  final GameEventType type;
  final int secondsRemaining;

  /// Doelautomaat voor Festivalweekend; null bij Koningsdag (netwerkbreed).
  final int? targetAtmId;

  ActiveEvent copyWith({int? secondsRemaining}) {
    return ActiveEvent(
      type: type,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      targetAtmId: targetAtmId,
    );
  }
}

/// De volledige spelstaat. Immutable; de tick-engine produceert per tick een
/// nieuwe staat via [copyWith].
class GameState {
  const GameState({
    required this.balance,
    required this.totalEarned,
    required this.atms,
    required this.banks,
    required this.upgrades,
    required this.staff,
    required this.prestigeLevel,
    required this.milestonesClaimed,
    required this.refillGoalRound,
    required this.refillGoalProgress,
    required this.tick,
    required this.nextEventInSeconds,
    this.activeEvent,
  });

  /// Startstaat: 2x Lobby basic (Simulatie!B5), volle cassettes, staat 100%,
  /// saldo 0 (Ontwerper dd 2026-07-02). De starters staan op een dag- en een
  /// nachtlocatie (GDD 5 adviseert een mix); station plus horeca middelt over
  /// het etmaal op ~1,0, consistent met Parameters!B26.
  factory GameState.initial({int nextEventInSeconds = kEventIntervalMinSeconds}) {
    return GameState(
      balance: kStartingBalance,
      totalEarned: 0,
      atms: [
        Atm.fresh(id: 0, location: LocationType.station),
        Atm.fresh(id: 1, location: LocationType.horeca),
      ],
      banks: [
        for (final id in BankId.values)
          Bank(id: id, connected: id != BankId.zuider),
      ],
      upgrades: [for (final id in UpgradeId.values) Upgrade(id: id)],
      staff: [for (final id in StaffId.values) Staff(id: id)],
      prestigeLevel: 0,
      milestonesClaimed: 0,
      refillGoalRound: 0,
      refillGoalProgress: 0,
      tick: 0,
      nextEventInSeconds: nextEventInSeconds,
    );
  }

  /// Beschikbaar saldo in EUR. Kan door het ontwerp nooit negatief worden.
  final double balance;

  /// Totaal verdiend sinds de laatste prestige; stuurt levels, mijlpalen en
  /// de prestige-drempel (GDD 9).
  final double totalEarned;

  final List<Atm> atms;
  final List<Bank> banks;
  final List<Upgrade> upgrades;
  final List<Staff> staff;

  /// Aantal keer geprestiged (GDD 9.3).
  final int prestigeLevel;

  /// Aantal reeds uitgekeerde mijlpalen, als index in [kMilestoneThresholds].
  final int milestonesClaimed;

  /// Huidige ronde van het doorlopende bijvuldoel (GDD 9.2), vanaf 0.
  final int refillGoalRound;

  /// Aantal bijvullingen in de huidige ronde.
  final int refillGoalProgress;

  /// Spelklok: aantal verstreken ticks (1 tick per echte seconde).
  final int tick;

  /// Seconden tot het volgende random event (GDD 6).
  final int nextEventInSeconds;

  final ActiveEvent? activeEvent;

  // -------------------------------------------------------------------------
  // Afgeleide waarden.
  // -------------------------------------------------------------------------

  /// Uur van de speldag: een speluur duurt [kGameHourRealSeconds] echte
  /// seconden (GDD 5).
  int get hourOfDay => (tick ~/ kGameHourRealSeconds) % kHoursPerDay;

  /// Spelerslevel op basis van totaal verdiend (GDD 9.1).
  PlayerLevel get playerLevel {
    for (var i = kLevelThresholds.length - 1; i >= 0; i--) {
      if (totalEarned >= kLevelThresholds[i]) {
        return PlayerLevel.values[i];
      }
    }
    return PlayerLevel.dorp;
  }

  /// Beschikbare locatiesloten bij het huidige level (GDD 9.1).
  int get locationSlots => kLevelLocationSlots[playerLevel.index];

  /// Permanente prestige-inkomensmultiplier (GDD 9.3).
  double get prestigeMultiplier => 1 + kPrestigeBonusPerLevel * prestigeLevel;

  /// Het 100 euro biljet is actief vanaf de eerste prestige (GDD 9.3).
  bool get hundredEuroNoteActive => prestigeLevel >= 1;

  Upgrade upgrade(UpgradeId id) => upgrades[id.index];

  int upgradeLevel(UpgradeId id) => upgrade(id).level;

  Staff staffMember(StaffId id) => staff[id.index];

  bool hasStaff(StaffId id) => staffMember(id).hired;

  Bank bank(BankId id) => banks[id.index];

  /// Effectieve transactieaandelen. Na aansluiting van de Zuiderbank schalen
  /// de bestaande aandelen met x0,85 en komt de Zuiderbank op 0,15 zodat het
  /// totaal 1,0 blijft (GDD 8).
  Map<BankId, double> get bankShares {
    final zuiderConnected = bank(BankId.zuider).connected;
    return {
      for (final b in banks)
        if (b.connected)
          b.id: b.id == BankId.zuider
              ? b.baseShare
              : b.baseShare * (zuiderConnected ? kZuiderbankShareRescale : 1.0),
    };
  }

  /// Aandeel-gewogen gemiddeld banktarief, voor de deterministische
  /// offline-berekening.
  double get weightedBankRate {
    final shares = bankShares;
    var sum = 0.0;
    for (final entry in shares.entries) {
      sum += entry.value * bank(entry.key).effectiveRate;
    }
    return sum;
  }

  /// Prijs van de volgende automaat: 400 x 1,6^(gekochte automaten); de twee
  /// starters tellen niet mee (GDD 3.3, Parameters!B28, Simulatie!B5).
  double get nextAtmPrice =>
      kAtmBasePrice *
      math.pow(kAtmPriceGrowthFactor, atms.length - kStartingAtmCount);

  /// Reparatieduur bij uitval, korter met monteur (GDD 4).
  int get repairDurationSeconds => hasStaff(StaffId.mechanic)
      ? kRepairDurationMechanicSeconds
      : kRepairDurationSeconds;

  /// Kosten van een CIT-rit na routeoptimalisatie (GDD 3.2 en 7.1).
  double get citTripCost =>
      kCitCostPerTrip *
      (1 - kCitRouteDiscountPerLevel * upgradeLevel(UpgradeId.citRoute));

  /// Doel van de huidige bijvulronde: N groeit van 3 naar 8 (GDD 9.2).
  int get refillGoalTarget => math.min(
      kRefillGoalBaseTarget + refillGoalRound, kRefillGoalMaxTarget);

  /// Beloning van de huidige bijvulronde (GDD 9.2).
  double get refillGoalReward =>
      kRefillGoalBaseReward *
      math.pow(kRefillGoalRewardGrowth, refillGoalRound);

  /// Inkomensmultiplier die op elke transactie werkt: analist, prestige en
  /// het 100 euro biljet (GDD 7.2 en 9.3).
  double get incomeMultiplier =>
      (hasStaff(StaffId.analyst) ? 1 + kAnalystIncomeBonus : 1.0) *
      prestigeMultiplier *
      (hundredEuroNoteActive ? kHundredEuroNoteIncomeMultiplier : 1.0);

  /// Totale cashwaarde in alle cassettes, voor de float-rente (GDD 3.2).
  double get totalFloatValue {
    var notes = 0;
    for (final atm in atms) {
      notes += atm.notesInCassette;
    }
    return notes * kAvgNoteValueEur;
  }

  Atm atmById(int id) => atms.firstWhere((a) => a.id == id);

  GameState copyWith({
    double? balance,
    double? totalEarned,
    List<Atm>? atms,
    List<Bank>? banks,
    List<Upgrade>? upgrades,
    List<Staff>? staff,
    int? prestigeLevel,
    int? milestonesClaimed,
    int? refillGoalRound,
    int? refillGoalProgress,
    int? tick,
    int? nextEventInSeconds,
    ActiveEvent? activeEvent,
    bool clearActiveEvent = false,
  }) {
    return GameState(
      balance: balance ?? this.balance,
      totalEarned: totalEarned ?? this.totalEarned,
      atms: atms ?? this.atms,
      banks: banks ?? this.banks,
      upgrades: upgrades ?? this.upgrades,
      staff: staff ?? this.staff,
      prestigeLevel: prestigeLevel ?? this.prestigeLevel,
      milestonesClaimed: milestonesClaimed ?? this.milestonesClaimed,
      refillGoalRound: refillGoalRound ?? this.refillGoalRound,
      refillGoalProgress: refillGoalProgress ?? this.refillGoalProgress,
      tick: tick ?? this.tick,
      nextEventInSeconds: nextEventInSeconds ?? this.nextEventInSeconds,
      activeEvent:
          clearActiveEvent ? null : (activeEvent ?? this.activeEvent),
    );
  }

  /// Vervangt een enkele automaat op basis van id.
  GameState withAtm(Atm updated) {
    return copyWith(
      atms: [for (final a in atms) a.id == updated.id ? updated : a],
    );
  }
}
