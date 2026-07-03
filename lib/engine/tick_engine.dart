import 'dart:math';

import '../core/constants.dart';
import '../models/atm.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import 'feedback.dart';

/// De tick-engine voert de volledige spellogica uit, een tick per seconde.
///
/// De engine is deterministisch testbaar: de [Random] is injecteerbaar en
/// alle tijd loopt via de tick-teller in [GameState], niet via de wandklok.
/// Elke methode is puur: state in, nieuwe state uit.
class TickEngine {
  TickEngine({Random? random, this.onFeedback}) : random = random ?? Random();

  final Random random;

  /// Optionele afnemer van feedback-events voor de UI (pills en
  /// muntenregen, GDD 10). Heeft geen invloed op de spellogica.
  void Function(GameFeedback event)? onFeedback;

  void _emit(FeedbackType type, double amount, {int? atmId}) {
    onFeedback?.call(GameFeedback(type, amount, atmId: atmId));
  }

  // ---------------------------------------------------------------------
  // De tick zelf.
  // ---------------------------------------------------------------------

  /// Voert een tick van een seconde uit, in deze volgorde:
  /// 1. spelklok en eventtimers, 2. per automaat slijtage, storingen,
  /// transacties en stortingen, 3. CIT-planner, 4. float-rente.
  GameState tick(GameState state) {
    var s = state.copyWith(tick: state.tick + 1);
    s = _advanceEvents(s);
    for (final atm in s.atms) {
      s = _tickAtm(s, s.atmById(atm.id));
    }
    s = _autoRefill(s);
    s = _applyFloatInterest(s);
    return s;
  }

  // ---------------------------------------------------------------------
  // Events (GDD 6).
  // ---------------------------------------------------------------------

  GameState _advanceEvents(GameState s) {
    // Lopend druktemodificerend event aftellen.
    final active = s.activeEvent;
    if (active != null) {
      if (active.secondsRemaining <= 1) {
        s = s.copyWith(clearActiveEvent: true);
      } else {
        s = s.copyWith(
          activeEvent:
              active.copyWith(secondsRemaining: active.secondsRemaining - 1),
        );
      }
    }
    // Timer naar het volgende event.
    if (s.nextEventInSeconds > 1) {
      return s.copyWith(nextEventInSeconds: s.nextEventInSeconds - 1);
    }
    s = _fireRandomEvent(s);
    return s.copyWith(nextEventInSeconds: _nextEventInterval());
  }

  int _nextEventInterval() =>
      kEventIntervalMinSeconds +
      random.nextInt(kEventIntervalMaxSeconds - kEventIntervalMinSeconds + 1);

  GameState _fireRandomEvent(GameState s) {
    final type =
        GameEventType.values[random.nextInt(GameEventType.values.length)];
    return fireEvent(s, type);
  }

  /// Voert een specifiek event uit. Publiek zodat tests events gericht
  /// kunnen afvuren; de tick kiest zelf willekeurig.
  GameState fireEvent(GameState s, GameEventType type) {
    switch (type) {
      case GameEventType.kingsday:
        // Alle automaten dubbele drukte gedurende 45 seconden.
        return s.copyWith(
          activeEvent: const ActiveEvent(
            type: GameEventType.kingsday,
            secondsRemaining: kKingsdayDurationSeconds,
          ),
        );
      case GameEventType.festival:
        // Een toeristische locatie drukte x3 gedurende 60 seconden.
        final tourist = s.atms.where((a) => a.isTouristLocation).toList();
        if (tourist.isEmpty) {
          return s;
        }
        final target = tourist[random.nextInt(tourist.length)];
        return s.copyWith(
          activeEvent: ActiveEvent(
            type: GameEventType.festival,
            secondsRemaining: kFestivalDurationSeconds,
            targetAtmId: target.id,
          ),
        );
      case GameEventType.heistAttempt:
        // Met IBNS afgeslagen plus verzekeringsuitkering; zonder IBNS gaat de
        // automaat een reparatiecyclus offline, zonder kosten (GDD 6).
        if (s.atms.isEmpty) {
          return s;
        }
        final target = s.atms[random.nextInt(s.atms.length)];
        final ibnsLevel = s.upgradeLevel(UpgradeId.ibns);
        if (ibnsLevel > 0) {
          final payout =
              kHeistInsuranceBase + kHeistInsurancePerIbnsLevel * ibnsLevel;
          _emit(FeedbackType.insurance, payout, atmId: target.id);
          return _credit(s, payout);
        }
        if (target.isBroken) {
          return s;
        }
        return s.withAtm(
          target.copyWith(
            repairSecondsRemaining: s.repairDurationSeconds.toDouble(),
          ),
        );
      case GameEventType.powerOutage:
        // Een automaat 20 seconden offline, geen kosten.
        final candidates = s.atms.where((a) => a.isOperational).toList();
        if (candidates.isEmpty) {
          return s;
        }
        final target = candidates[random.nextInt(candidates.length)];
        return s.withAtm(
          target.copyWith(
            outageSecondsRemaining: kPowerOutageDurationSeconds.toDouble(),
          ),
        );
    }
  }

  /// Druktemultiplier van het lopende event voor deze automaat.
  double _eventBusyMultiplier(GameState s, Atm atm) {
    final event = s.activeEvent;
    if (event == null) {
      return 1.0;
    }
    return switch (event.type) {
      GameEventType.kingsday => kKingsdayBusyMultiplier,
      GameEventType.festival =>
        event.targetAtmId == atm.id ? kFestivalBusyMultiplier : 1.0,
      _ => 1.0,
    };
  }

  // ---------------------------------------------------------------------
  // Per automaat (GDD 3, 4, 5).
  // ---------------------------------------------------------------------

  GameState _tickAtm(GameState s, Atm atm) {
    // Reparatie loopt af, staat komt terug op 100% (GDD 4).
    if (atm.isBroken) {
      final remaining = atm.repairSecondsRemaining - 1;
      return s.withAtm(
        remaining <= 0
            ? atm.copyWith(repairSecondsRemaining: 0, condition: 1.0)
            : atm.copyWith(repairSecondsRemaining: remaining),
      );
    }
    // Stroomstoring: gepauzeerd, geen slijtage of inkomen.
    if (atm.isPausedByOutage) {
      return s.withAtm(
        atm.copyWith(
          outageSecondsRemaining: max(0, atm.outageSecondsRemaining - 1),
        ),
      );
    }

    // Slijtage, vertraagd door IBNS (GDD 4).
    final ibnsLevel = s.upgradeLevel(UpgradeId.ibns);
    var updated = atm.copyWith(
      condition: max(
        0,
        atm.condition -
            kWearPerSecond * (1 - kIbnsWearReductionPerLevel * ibnsLevel),
      ),
    );

    // Bij staat nul: uitval, voorrijkosten en gratis reparatietimer (GDD 4).
    if (updated.condition <= 0) {
      final callout = (kBreakdownCalloutBase +
              kBreakdownCalloutPerTier * updated.tier.index) *
          (1 - kIbnsCalloutDiscountPerLevel * ibnsLevel);
      s = _chargeUpTo(s, callout);
      return s.withAtm(
        updated.copyWith(
          repairSecondsRemaining: s.repairDurationSeconds.toDouble(),
        ),
      );
    }

    // Opnametransactie (GDD 3.1).
    final busyFactor =
        kBusyProfiles[updated.location]!.factorAt(s.hourOfDay) *
            _eventBusyMultiplier(s, updated);
    final chance = min(
        kTransactionChancePerSecond * busyFactor, kTransactionChanceCap);
    if (random.nextDouble() < chance) {
      final result = _attemptTransaction(s, updated);
      s = result.$1;
      updated = result.$2;
    }

    // Storting op een recycler (GDD 3.1).
    if (updated.tier.isRecycler &&
        random.nextDouble() < kDepositChancePerSecond) {
      final result = _deposit(s, updated);
      s = result.$1;
      updated = result.$2;
    }

    return s.withAtm(updated);
  }

  (GameState, Atm) _attemptTransaction(GameState s, Atm atm) {
    // Cassette-drain: 1 of 2 biljetten, gemiddeld 1,5 (Parameters!B6). Het
    // 100 euro biljet verhoogt de verwachte drain met factor 1,4 via een
    // extra biljet met de passende kans (Parameters!B17).
    var notesNeeded = 1 + (random.nextBool() ? 1 : 0);
    if (s.hundredEuroNoteActive) {
      const extraChance =
          kAvgNotesPerTransaction * (kHundredEuroNoteDrainMultiplier - 1);
      if (random.nextDouble() < extraChance) {
        notesNeeded += 1;
      }
    }
    // Onvoldoende biljetten: de opname kan niet doorgaan.
    if (atm.notesInCassette < notesNeeded) {
      return (s, atm);
    }

    // Opbrengst = tierinkomen x spreiding x banktarief x multipliers
    // (GDD 3.1 tabel Inkomsten).
    final spread = kIncomeSpreadMin +
        random.nextDouble() * (kIncomeSpreadMax - kIncomeSpreadMin);
    final bankRate = s.bank(_pickBank(s)).effectiveRate;
    var income =
        atm.incomePerTransaction * spread * bankRate * s.incomeMultiplier;

    _emit(FeedbackType.income, income, atmId: atm.id);

    // DCC-bonus voor toeristen (GDD 3.1, Parameters!B20 tot B22).
    final dccChance =
        atm.isTouristLocation ? kDccChanceTourist : kDccChanceNormal;
    if (random.nextDouble() < dccChance) {
      income += kDccBonusEur;
      _emit(FeedbackType.dcc, kDccBonusEur, atmId: atm.id);
    }

    s = _credit(s, income);
    return (
      s,
      atm.copyWith(
        notesInCassette: atm.notesInCassette - notesNeeded,
        lifetimeEarned: atm.lifetimeEarned + income,
      ),
    );
  }

  /// Kiest de bank van deze opname, gewogen naar transactieaandeel (GDD 8).
  BankId _pickBank(GameState s) {
    final shares = s.bankShares;
    var roll = random.nextDouble();
    BankId picked = shares.keys.first;
    for (final entry in shares.entries) {
      picked = entry.key;
      roll -= entry.value;
      if (roll < 0) {
        break;
      }
    }
    return picked;
  }

  (GameState, Atm) _deposit(GameState s, Atm atm) {
    // 0,50 fee, 2 tot 6 biljetten terug de cassette in (tot de capaciteit)
    // en 0,003 extra slijtage (GDD 3.1 en 4, Parameters!B23 en B24).
    final capacity = atm.capacity(s.upgradeLevel(UpgradeId.cassettes));
    final notes = kDepositNotesMin +
        random.nextInt(kDepositNotesMax - kDepositNotesMin + 1);
    _emit(FeedbackType.recycling, kDepositFeeEur, atmId: atm.id);
    s = _credit(s, kDepositFeeEur);
    final updated = atm.copyWith(
      notesInCassette: min(capacity, atm.notesInCassette + notes),
      condition: max(0, atm.condition - kRecyclerWearPerDeposit),
      lifetimeEarned: atm.lifetimeEarned + kDepositFeeEur,
    );
    return (s, updated);
  }

  // ---------------------------------------------------------------------
  // Netwerkbrede kosten en personeel.
  // ---------------------------------------------------------------------

  /// Float-rente over de cashwaarde in alle cassettes; kan het saldo nooit
  /// negatief maken (GDD 3.2 tabel Kosten).
  GameState _applyFloatInterest(GameState s) {
    final interest = s.totalFloatValue * kFloatInterestPerSecond;
    return s.copyWith(balance: max(0, s.balance - interest));
  }

  /// CIT-planner Fatima vult automatisch bij onder 15% cassette, als het
  /// saldo de rit dekt (GDD 7.2).
  GameState _autoRefill(GameState s) {
    if (!s.hasStaff(StaffId.citPlanner)) {
      return s;
    }
    for (final atm in s.atms) {
      final capacity = atm.capacity(s.upgradeLevel(UpgradeId.cassettes));
      if (atm.notesInCassette < capacity * kCitPlannerRefillThreshold &&
          s.balance >= s.citTripCost) {
        s = refillAtm(s, atm.id);
      }
    }
    return s;
  }

  // ---------------------------------------------------------------------
  // Boekhouding: crediteren telt mee voor mijlpalen, afschrijven kan het
  // saldo nooit onder nul brengen.
  // ---------------------------------------------------------------------

  GameState _credit(GameState s, double amount) {
    s = s.copyWith(
      balance: s.balance + amount,
      totalEarned: s.totalEarned + amount,
    );
    return _claimMilestones(s);
  }

  GameState _chargeUpTo(GameState s, double amount) {
    return s.copyWith(balance: max(0, s.balance - amount));
  }

  /// Keert cashbonussen uit voor elke gepasseerde mijlpaaldrempel (GDD 9.2).
  /// Bonussen tellen zelf mee als verdiend en kunnen dus doorcascaderen.
  GameState _claimMilestones(GameState s) {
    while (s.milestonesClaimed < kMilestoneThresholds.length &&
        s.totalEarned >= kMilestoneThresholds[s.milestonesClaimed]) {
      final reward = kMilestoneRewards[s.milestonesClaimed];
      _emit(FeedbackType.milestone, reward);
      s = s.copyWith(
        balance: s.balance + reward,
        totalEarned: s.totalEarned + reward,
        milestonesClaimed: s.milestonesClaimed + 1,
      );
    }
    return s;
  }

  // ---------------------------------------------------------------------
  // Spelersacties. Elke actie geeft de nieuwe staat terug, of de
  // ongewijzigde staat als de actie niet toegestaan is.
  // ---------------------------------------------------------------------

  /// Servicing: CIT-rit vult de cassette volledig tegen het rittarief
  /// (GDD 3.2) en telt mee voor het bijvuldoel (GDD 9.2).
  GameState refillAtm(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    final capacity = atm.capacity(s.upgradeLevel(UpgradeId.cassettes));
    final cost = s.citTripCost;
    if (s.balance < cost || atm.notesInCassette >= capacity) {
      return s;
    }
    s = s
        .copyWith(balance: s.balance - cost)
        .withAtm(atm.copyWith(notesInCassette: capacity));
    return _progressRefillGoal(s);
  }

  GameState _progressRefillGoal(GameState s) {
    final progress = s.refillGoalProgress + 1;
    if (progress < s.refillGoalTarget) {
      return s.copyWith(refillGoalProgress: progress);
    }
    final reward = s.refillGoalReward;
    _emit(FeedbackType.refillGoal, reward);
    s = s.copyWith(
      refillGoalRound: s.refillGoalRound + 1,
      refillGoalProgress: 0,
    );
    return _credit(s, reward);
  }

  /// Koopt een nieuwe Lobby basic op de gegeven locatie (GDD 3.3).
  GameState buyAtm(GameState s, LocationType location) {
    final price = s.nextAtmPrice;
    if (s.balance < price || s.atms.length >= s.locationSlots) {
      return s;
    }
    final nextId =
        s.atms.isEmpty ? 0 : s.atms.map((a) => a.id).reduce(max) + 1;
    return s.copyWith(
      balance: s.balance - price,
      atms: [
        ...s.atms,
        Atm.fresh(
          id: nextId,
          location: location,
          cassetteUpgradeLevel: s.upgradeLevel(UpgradeId.cassettes),
        ),
      ],
    );
  }

  /// Upgrade een automaat naar de volgende tier (GDD 3.3, Tiers-tab).
  /// De cassette-inhoud blijft; de capaciteit groeit mee.
  GameState upgradeAtmTier(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    final next = atm.tier.next;
    if (next == null) {
      return s;
    }
    final cost = kTierUpgradeCost[next.index];
    if (s.balance < cost) {
      return s;
    }
    return s
        .copyWith(balance: s.balance - cost)
        .withAtm(atm.copyWith(tier: next));
  }

  /// Koopt het volgende level van een netwerk-upgrade (GDD 7.1).
  GameState buyUpgrade(GameState s, UpgradeId id) {
    final upgrade = s.upgrade(id);
    if (upgrade.isMaxed || s.balance < upgrade.nextLevelCost) {
      return s;
    }
    return s.copyWith(
      balance: s.balance - upgrade.nextLevelCost,
      upgrades: [
        for (final u in s.upgrades)
          u.id == id ? u.copyWith(level: u.level + 1) : u,
      ],
    );
  }

  /// Neemt een medewerker in dienst (GDD 7.2).
  GameState hireStaff(GameState s, StaffId id) {
    final member = s.staffMember(id);
    if (member.hired || s.balance < member.price) {
      return s;
    }
    return s.copyWith(
      balance: s.balance - member.price,
      staff: [
        for (final m in s.staff) m.id == id ? m.copyWith(hired: true) : m,
      ],
    );
  }

  /// Heronderhandelt een bankcontract: +0,05 tarief per level, kosten
  /// 500 x 2^level, maximaal level 5 (GDD 8).
  GameState negotiateBankContract(GameState s, BankId id) {
    final bank = s.bank(id);
    if (!bank.canNegotiate || s.balance < bank.negotiationCost) {
      return s;
    }
    return s.copyWith(
      balance: s.balance - bank.negotiationCost,
      banks: [
        for (final b in s.banks)
          b.id == id ? b.copyWith(contractLevel: b.contractLevel + 1) : b,
      ],
    );
  }

  /// Sluit de Zuiderbank aan: vanaf level Regio, voor 5.000; bestaande
  /// aandelen schalen x0,85 (GDD 8).
  GameState connectZuiderbank(GameState s) {
    final bank = s.bank(BankId.zuider);
    if (bank.connected ||
        s.playerLevel.index < PlayerLevel.regio.index ||
        s.balance < kZuiderbankUnlockCost) {
      return s;
    }
    return s.copyWith(
      balance: s.balance - kZuiderbankUnlockCost,
      banks: [
        for (final b in s.banks)
          b.id == BankId.zuider ? b.copyWith(connected: true) : b,
      ],
    );
  }

  /// Meehelpen met een reparatie: elke tik versnelt 3 seconden (GDD 4).
  GameState tapRepair(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    if (!atm.isBroken) {
      return s;
    }
    final remaining =
        atm.repairSecondsRemaining - kRepairTapSpeedupSeconds;
    return s.withAtm(
      remaining <= 0
          ? atm.copyWith(repairSecondsRemaining: 0, condition: 1.0)
          : atm.copyWith(repairSecondsRemaining: remaining),
    );
  }

  /// Gratis preventief onderhoud, beschikbaar onder 90% staat (GDD 4).
  GameState preventiveMaintenance(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    if (!atm.isOperational ||
        atm.condition >= kPreventiveMaintenanceThreshold) {
      return s;
    }
    return s.withAtm(atm.copyWith(condition: 1.0));
  }

  /// Prestige: vanaf 25.000 totaal verdiend het netwerk verkopen voor een
  /// permanente inkomensbonus. Volledige reset; alleen bankcontractlevels
  /// en het prestigelevel blijven behouden (GDD 9.3). De dubbele
  /// tikbevestiging is een UI-verantwoordelijkheid.
  GameState prestige(GameState s) {
    if (s.totalEarned < kPrestigeThreshold) {
      return s;
    }
    final fresh = GameState.initial(
      nextEventInSeconds: _nextEventInterval(),
    );
    return fresh.copyWith(
      prestigeLevel: s.prestigeLevel + 1,
      banks: [
        for (final b in fresh.banks)
          b.copyWith(contractLevel: s.bank(b.id).contractLevel),
      ],
    );
  }
}
