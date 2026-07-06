import 'dart:math';

import '../core/constants.dart';
import '../models/atm.dart';
import '../models/cassette.dart';
import '../models/cit_van.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/mechanic.dart';
import 'feedback.dart';

/// De tick-engine voert de volledige spellogica uit, een tick per seconde.
///
/// De engine is deterministisch testbaar: de [Random] is injecteerbaar en
/// alle tijd loopt via de tick-teller in [GameState], niet via de wandklok.
/// Elke methode is puur: state in, nieuwe state uit.
///
/// Sinds het wachtrijmodel (Ontwerper dd 2026-07-04) verlopen transacties
/// in micro-fases ([TransactionPhase]): klanten komen aan op basis van het
/// drukteprofiel, sluiten aan in de rij (of lopen door als die vol staat)
/// en de voorste klant doorloopt kaart -> verwerking -> shutter ->
/// afronding. Pas bij de afronding wordt de opname of storting financieel
/// en fysiek (cassette) afgehandeld.
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
  /// 1. spelklok en eventtimers, 2. de CIT-vloot, 3. per automaat
  /// slijtage, storingen, aanloop en transactiefases, 4. CIT-planner,
  /// 5. float-rente.
  GameState tick(GameState state) {
    var s = state.copyWith(tick: state.tick + 1);
    s = _advanceEvents(s);
    s = _advanceFleet(s);
    s = _advanceMechanics(s);
    for (final atm in s.atms) {
      s = _tickAtm(s, s.atmById(atm.id));
    }
    s = _autoDispatch(s);
    s = _dispatchMechanics(s);
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
          activeEvent: active.copyWith(
            secondsRemaining: active.secondsRemaining - 1,
          ),
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
        // Verdediging in lagen (Ontwerper dd 2026-07-04): IBNS slaat af en
        // keert verzekering uit; anders kan de kastbeveiliging van het
        // level de aanval zelf afslaan (lobby's zijn daar buiten
        // openingstijden kwetsbaarder in); anders gaat de hele automaat
        // een reparatiecyclus offline (alle cassettes in storing), zonder
        // kosten (GDD 6).
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
        final blockRoll = random.nextDouble();
        if (blockRoll < target.securityBlockChanceAt(s.hourOfDay)) {
          return s;
        }
        if (target.isBroken) {
          return s;
        }
        return s.withAtm(
          target.copyWith(
            cassettes: [
              for (final c in target.cassettes)
                c.copyWith(
                  repairSecondsRemaining: s.repairDurationSeconds.toDouble(),
                ),
            ],
            queueLength: 0,
            clearTransaction: true,
          ),
        );
      case GameEventType.powerOutage:
        // Een automaat 20 seconden offline, geen kosten; de rij loopt weg.
        final candidates = s.atms.where((a) => a.isOperational).toList();
        if (candidates.isEmpty) {
          return s;
        }
        final target = candidates[random.nextInt(candidates.length)];
        return s.withAtm(
          target.copyWith(
            outageSecondsRemaining: kPowerOutageDurationSeconds.toDouble(),
            queueLength: 0,
            clearTransaction: true,
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
  // CIT-vloot (Ontwerper dd 2026-07-04).
  // ---------------------------------------------------------------------

  /// Laat elke wagen die onderweg is een tick vorderen. Fases: heenreis,
  /// dan [kServicingDurationTicks] ticks vullen en repareren (alle
  /// cassettes vol en 100% staat), dan de terugreis; pas daarna is de
  /// wagen weer inzetbaar.
  GameState _advanceFleet(GameState s) {
    for (final vanId in [for (final v in s.citVans) v.id]) {
      final van = s.citVans.firstWhere((v) => v.id == vanId);
      if (van.isIdle) {
        continue;
      }
      final remaining = van.ticksRemaining - 1;
      if (remaining > 0) {
        s = s.withVan(van.copyWith(ticksRemaining: remaining));
        continue;
      }
      switch (van.status) {
        case CitVanStatus.transitToAtm:
          s = s.withVan(
            van.copyWith(
              status: CitVanStatus.servicing,
              ticksRemaining: kServicingDurationTicks,
            ),
          );
        case CitVanStatus.servicing:
          final target = s.atms
              .where((a) => a.id == van.targetAtmId)
              .firstOrNull;
          if (target != null) {
            s = s.withAtm(target.serviced());
            _emit(FeedbackType.serviced, 0, atmId: target.id);
            s = _progressRefillGoal(s);
          }
          final returnTicks = target == null
              ? 1
              : s.travelTicksTo(target.location);
          s = s.withVan(
            van.copyWith(
              status: CitVanStatus.returning,
              ticksRemaining: returnTicks,
            ),
          );
        case CitVanStatus.returning:
          s = s.withVan(
            van.copyWith(
              status: CitVanStatus.idle,
              ticksRemaining: 0,
              clearTarget: true,
            ),
          );
        case CitVanStatus.idle:
          break;
      }
    }
    return s;
  }

  // ---------------------------------------------------------------------
  // Monteursploeg (Ontwerper dd 2026-07-06): het aanrijdsysteem.
  // ---------------------------------------------------------------------

  /// Laat elke monteur die onderweg is een tick vorderen: heenreis, dan
  /// repareren ter plaatse ([GameState.repairDurationSeconds]; korter met
  /// monteur Sven in dienst), dan de terugreis. Bij het afronden zijn
  /// alle cassettes in storing van die automaat gerepareerd (staat 100%,
  /// inhoud blijft - geld brengen is CIT-werk).
  GameState _advanceMechanics(GameState s) {
    for (final mechanicId in [for (final m in s.mechanics) m.id]) {
      final mechanic = s.mechanics.firstWhere((m) => m.id == mechanicId);
      if (mechanic.isIdle) {
        continue;
      }
      final remaining = mechanic.ticksRemaining - 1;
      if (remaining > 0) {
        s = s.withMechanic(mechanic.copyWith(ticksRemaining: remaining));
        continue;
      }
      switch (mechanic.status) {
        case CitVanStatus.transitToAtm:
          s = s.withMechanic(
            mechanic.copyWith(
              status: CitVanStatus.servicing,
              ticksRemaining: s.repairDurationSeconds,
            ),
          );
        case CitVanStatus.servicing:
          final target = s.atms
              .where((a) => a.id == mechanic.targetAtmId)
              .firstOrNull;
          if (target != null) {
            s = s.withAtm(target.repaired());
          }
          final returnTicks = target == null
              ? 1
              : s.travelTicksTo(target.location);
          s = s.withMechanic(
            mechanic.copyWith(
              status: CitVanStatus.returning,
              ticksRemaining: returnTicks,
            ),
          );
        case CitVanStatus.returning:
          s = s.withMechanic(
            mechanic.copyWith(
              status: CitVanStatus.idle,
              ticksRemaining: 0,
              clearTarget: true,
            ),
          );
        case CitVanStatus.idle:
          break;
      }
    }
    return s;
  }

  /// Stuurt vrije monteurs automatisch naar de oudste onbediende storing.
  /// De aanrijkosten (nood-trip, gedempt door beveiligingslevel en IBNS)
  /// worden bij vertrek in rekening gebracht; een nood-trip komt er ook
  /// als de kas leeg is (het saldo klemt op nul).
  GameState _dispatchMechanics(GameState s) {
    final ibnsLevel = s.upgradeLevel(UpgradeId.ibns);
    for (final mechanicId in [for (final m in s.mechanics) m.id]) {
      final mechanic = s.mechanics.firstWhere((m) => m.id == mechanicId);
      if (!mechanic.isIdle) {
        continue;
      }
      final target = s.atms
          .where((a) => a.hasBrokenCassette && !s.hasMechanicEnRouteTo(a.id))
          .firstOrNull;
      if (target == null) {
        return s;
      }
      final callout =
          target.calloutCost * (1 - kIbnsCalloutDiscountPerLevel * ibnsLevel);
      s = _chargeUpTo(s, callout);
      s = s.withMechanic(
        mechanic.copyWith(
          status: CitVanStatus.transitToAtm,
          targetAtmId: target.id,
          ticksRemaining: s.travelTicksTo(target.location),
        ),
      );
    }
    return s;
  }

  // ---------------------------------------------------------------------
  // Per automaat: slijtage, storingen, aanloop en transactiefases.
  // ---------------------------------------------------------------------

  GameState _tickAtm(GameState s, Atm atm) {
    // Storingen wachten op de monteur (aanrijdsysteem, Ontwerper dd
    // 2026-07-06): cassettes repareren zichzelf niet meer. Volledig in
    // storing betekent dat de rij wegloopt en er niets gebeurt tot de
    // monteur ter plaatse is; met een deels werkende kast draait de rest
    // gewoon door.
    if (atm.isBroken) {
      return s.withAtm(atm.copyWith(queueLength: 0, clearTransaction: true));
    }
    // Stroomstoring: gepauzeerd, geen slijtage, aanloop of transacties.
    if (atm.isPausedByOutage) {
      return s.withAtm(
        atm.copyWith(
          outageSecondsRemaining: max(0, atm.outageSecondsRemaining - 1),
        ),
      );
    }

    // Slijtage op de actieve cassette (de volste), vertraagd door IBNS
    // (GDD 4) en door de mechanische betrouwbaarheid van het level.
    final ibnsLevel = s.upgradeLevel(UpgradeId.ibns);
    final activeIndex = atm.activeCassetteIndex;
    final activeCassette = atm.cassettes[activeIndex];
    atm = atm.withCassette(
      activeIndex,
      activeCassette.copyWith(
        condition: max(
          0,
          activeCassette.condition -
              kWearPerSecond *
                  atm.wearFactor *
                  (1 - kIbnsWearReductionPerLevel * ibnsLevel),
        ),
      ),
    );

    // Bij staat nul vliegt die ene cassette in storing en wacht hij op de
    // monteur; de overige cassettes draaien door. De aanrijkosten worden
    // pas in rekening gebracht wanneer de monteur vertrekt. Maximaal een
    // storing per tick.
    final failingIndex = atm.cassettes.indexWhere(
      (c) => !c.isBroken && c.condition <= 0,
    );
    if (failingIndex >= 0) {
      return s.withAtm(
        atm.withCassette(
          failingIndex,
          atm.cassettes[failingIndex].copyWith(
            repairSecondsRemaining: s.repairDurationSeconds.toDouble(),
          ),
        ),
      );
    }

    // Aanloop: kans per tick op een nieuwe klant, gestuurd door het
    // drukteprofiel, events, openingstijden (lobby) en de werkende
    // cassettefractie. Bij een volle rij loopt de klant ongeduldig door.
    final hourFactor = atm.isLobbyClosedAt(s.hourOfDay)
        ? kLobbyClosedArrivalFactor
        : 1.0;
    final busyFactor =
        kBusyProfiles[atm.location]!.factorAt(s.hourOfDay) *
        _eventBusyMultiplier(s, atm) *
        hourFactor;
    final arrivalChance =
        min(kTransactionChancePerSecond * busyFactor, kTransactionChanceCap) *
        atm.workingFraction;
    if (random.nextDouble() < arrivalChance) {
      atm = atm.queueLength < atm.queueCapacity
          ? atm.copyWith(queueLength: atm.queueLength + 1)
          : atm.copyWith(lostCustomers: atm.lostCustomers + 1);
    }

    // Transactiefases: start de volgende klant of laat de lopende
    // transactie een tick vorderen.
    final result = _advanceTransaction(s, atm);
    s = result.$1;
    atm = result.$2;

    // Geduld (Ontwerper dd 2026-07-06): hoe langer de rij, hoe groter de
    // kans dat er iemand afhaakt. Zo pendelt de rij mee met de drukte in
    // plaats van permanent vol te staan.
    if (atm.queueLength > 0 &&
        random.nextDouble() < atm.queueLength * kQueueImpatienceChance) {
      atm = atm.copyWith(
        queueLength: atm.queueLength - 1,
        lostCustomers: atm.lostCustomers + 1,
      );
    }

    return s.withAtm(atm);
  }

  /// Start of vordert de transactie van de voorste klant. Elke fase duurt
  /// zijn volle aantal ticks; bij het aflopen van de afrondingsfase wordt
  /// de transactie financieel en fysiek afgehandeld en stapt meteen de
  /// volgende klant naar voren.
  (GameState, Atm) _advanceTransaction(GameState s, Atm atm) {
    final tx = atm.transaction;
    if (tx == null) {
      return (s, _startNextCustomer(atm));
    }
    final remaining = tx.ticksRemaining - 1;
    if (remaining > 0) {
      return (
        s,
        atm.copyWith(transaction: tx.copyWith(ticksRemaining: remaining)),
      );
    }
    switch (tx.phase) {
      case TransactionPhase.cardPresented:
        return (
          s,
          atm.copyWith(
            transaction: tx.copyWith(
              phase: TransactionPhase.processing,
              ticksRemaining: atm.processingTicks,
            ),
          ),
        );
      case TransactionPhase.processing:
        return (
          s,
          atm.copyWith(
            transaction: tx.copyWith(
              phase: TransactionPhase.shutterAction,
              ticksRemaining: 1,
            ),
          ),
        );
      case TransactionPhase.shutterAction:
        return (
          s,
          atm.copyWith(
            transaction: tx.copyWith(
              phase: TransactionPhase.finishing,
              ticksRemaining: 1,
            ),
          ),
        );
      case TransactionPhase.finishing:
        final resolved = tx.isDeposit
            ? _resolveDeposit(s, atm)
            : _resolveWithdrawal(s, atm);
        s = resolved.$1;
        atm = resolved.$2.copyWith(clearTransaction: true);
        return (s, _startNextCustomer(atm));
    }
  }

  /// Laat de voorste wachtende klant een transactie beginnen; op een
  /// recycler bepaalt de kansverdeling of het een storting wordt.
  Atm _startNextCustomer(Atm atm) {
    if (atm.queueLength <= 0) {
      return atm;
    }
    final isDeposit =
        atm.isRecycler && random.nextDouble() < kRecyclerDepositShare;
    return atm.copyWith(
      queueLength: atm.queueLength - 1,
      transaction: AtmTransaction(
        phase: TransactionPhase.cardPresented,
        ticksRemaining: 1,
        isDeposit: isDeposit,
      ),
    );
  }

  /// Rondt een opname af: cassette-drain, inkomen met alle multipliers,
  /// DCC-kans en de klemloopkans van het mechaniek.
  (GameState, Atm) _resolveWithdrawal(GameState s, Atm atm) {
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
    // Onvoldoende biljetten in de werkende cassettes: de klant vangt bot
    // en loopt weg zonder opname.
    final drainedAtm = atm.drained(notesNeeded);
    if (drainedAtm == null) {
      return (s, atm.copyWith(lostCustomers: atm.lostCustomers + 1));
    }

    // Opbrengst = basisinkomen (functionaliteit) x klanttevredenheid
    // (level) x spreiding x banktarief x netwerkmultipliers.
    final spread =
        kIncomeSpreadMin +
        random.nextDouble() * (kIncomeSpreadMax - kIncomeSpreadMin);
    final bankRate = s.bank(_pickBank(s)).effectiveRate;
    var income =
        atm.baseIncome *
        atm.levelIncomeMultiplier *
        spread *
        bankRate *
        s.incomeMultiplier;

    _emit(FeedbackType.income, income, atmId: atm.id);

    // DCC-bonus voor toeristen (GDD 3.1, Parameters!B20 tot B22).
    final dccChance = atm.isTouristLocation
        ? kDccChanceTourist
        : kDccChanceNormal;
    if (random.nextDouble() < dccChance) {
      income += kDccBonusEur;
      _emit(FeedbackType.dcc, kDccBonusEur, atmId: atm.id);
    }

    s = _credit(s, income);
    var updated = drainedAtm.copyWith(
      lifetimeEarned: atm.lifetimeEarned + income,
    );
    // Deze opname trekt de voorraad leeg: meld dat aan de UI en audio.
    if (updated.availableNotes == 0) {
      _emit(FeedbackType.cassetteEmpty, 0, atmId: atm.id);
    }
    updated = _rollForJam(updated);
    return (s, updated);
  }

  /// Rondt een storting af: fee-inkomen, biljetten de leegste werkende
  /// cassette in en de (hogere) klemloopkans van de invoer.
  (GameState, Atm) _resolveDeposit(GameState s, Atm atm) {
    final notes =
        kDepositNotesMin +
        random.nextInt(kDepositNotesMax - kDepositNotesMin + 1);
    final income =
        kRecyclerDepositFee * atm.levelIncomeMultiplier * s.incomeMultiplier;
    _emit(FeedbackType.recycling, income, atmId: atm.id);
    s = _credit(s, income);

    var targetIndex = -1;
    var fewestNotes = kCassetteCapacityUnits + 1;
    for (var i = 0; i < atm.cassettes.length; i++) {
      final c = atm.cassettes[i];
      if (!c.isBroken && c.notes < fewestNotes) {
        targetIndex = i;
        fewestNotes = c.notes;
      }
    }
    final target = atm.cassettes[targetIndex];
    var updated = atm
        .withCassette(
          targetIndex,
          target.copyWith(
            notes: min(kCassetteCapacityUnits, target.notes + notes),
            condition: max(0, target.condition - kRecyclerWearPerDeposit),
          ),
        )
        .copyWith(lifetimeEarned: atm.lifetimeEarned + income);
    updated = _rollForJam(updated);
    return (s, updated);
  }

  /// Mechanische klemloop (Ontwerper dd 2026-07-04): per afgeronde
  /// transactie een kleine, level-gedempte kans dat de actieve cassette
  /// vastloopt. De reparatie is gratis (monteursbezoek zit in het
  /// servicecontract); alleen de uitvaltijd doet pijn.
  Atm _rollForJam(Atm atm) {
    if (random.nextDouble() >= atm.jamChance) {
      return atm;
    }
    final index = atm.activeCassetteIndex;
    if (index < 0) {
      return atm;
    }
    return atm.withCassette(
      index,
      atm.cassettes[index].copyWith(
        repairSecondsRemaining: kRepairDurationSeconds.toDouble(),
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

  // ---------------------------------------------------------------------
  // Netwerkbrede kosten en personeel.
  // ---------------------------------------------------------------------

  /// Float-rente over de cashwaarde in alle cassettes; kan het saldo nooit
  /// negatief maken (GDD 3.2 tabel Kosten).
  GameState _applyFloatInterest(GameState s) {
    final interest = s.totalFloatValue * kFloatInterestPerSecond;
    return s.copyWith(balance: max(0, s.balance - interest));
  }

  /// CIT-planner Fatima stuurt automatisch een wagen onder 15% voorraad,
  /// als er een wagen vrij is en het saldo de rit dekt (GDD 7.2).
  GameState _autoDispatch(GameState s) {
    if (!s.hasStaff(StaffId.citPlanner)) {
      return s;
    }
    for (final atm in s.atms) {
      if (atm.availableNotes < atm.capacity * kCitPlannerRefillThreshold) {
        s = requestService(s, atm.id);
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

  /// Servicing: stuurt een vrije CIT-wagen naar de automaat tegen het
  /// rittarief (GDD 3.2). De wagen reist [GameState.travelTicksTo] ticks,
  /// vult en repareert dan [kServicingDurationTicks] ticks lang alle
  /// cassettes, en reist terug; pas daarna is hij weer inzetbaar
  /// (Ontwerper dd 2026-07-04). De afgeronde servicing telt mee voor het
  /// bijvuldoel (GDD 9.2).
  GameState requestService(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    if (s.hasVanEnRouteTo(atmId)) {
      return s;
    }
    final needsService =
        atm.availableNotes < atm.capacity ||
        atm.hasBrokenCassette ||
        atm.cassettes.any((c) => !c.isBroken && c.condition < 1.0);
    if (!needsService) {
      return s;
    }
    final van = s.idleVan;
    final cost = s.citTripCost;
    if (van == null || s.balance < cost) {
      return s;
    }
    return s
        .copyWith(balance: s.balance - cost)
        .withVan(
          van.copyWith(
            status: CitVanStatus.transitToAtm,
            targetAtmId: atmId,
            ticksRemaining: s.travelTicksTo(atm.location),
          ),
        );
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

  /// Koopt en configureert een nieuwe automaat op de gegeven locatie
  /// (Ontwerper dd 2026-07-04): behuizing en functionaliteit bepalen de
  /// meerprijs bovenop [GameState.nextAtmPrice]. De Nationale Bank kan de
  /// zone geblokkeerd hebben (spreidingswet).
  GameState buyAtm(
    GameState s,
    LocationType location, {
    AtmHousing housing = AtmHousing.lobby,
    AtmFunction function = AtmFunction.dispenser,
  }) {
    final price =
        s.nextAtmPrice +
        (housing == AtmHousing.ttw ? kTtwHousingPremium : 0) +
        (function == AtmFunction.recycler ? kRecyclerFunctionPremium : 0);
    if (s.balance < price ||
        s.atms.length >= s.locationSlots ||
        s.isZoneBlocked(kLocationZone[location]!)) {
      return s;
    }
    final nextId = s.atms.isEmpty ? 0 : s.atms.map((a) => a.id).reduce(max) + 1;
    return s.copyWith(
      balance: s.balance - price,
      atms: [
        ...s.atms,
        Atm.fresh(
          id: nextId,
          location: location,
          housing: housing,
          function: function,
        ),
      ],
    );
  }

  /// Koopt een extra cassetteslot voor een automaat, tot
  /// [kMaxCassettesPerAtm]. De cassette wordt leeg geleverd; een CIT-rit
  /// vult hem (Ontwerper dd 2026-07-04).
  GameState buyCassette(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    if (atm.cassettes.length >= kMaxCassettesPerAtm ||
        s.balance < kExtraCassettePrice) {
      return s;
    }
    // Vaste denominatie-configuratie 10/20/50/50/50; na de eerste
    // prestige is het vijfde slot een 100 EUR-cassette (Ontwerper dd
    // 2026-07-06).
    final slotIndex = atm.cassettes.length;
    final denomination =
        slotIndex == kMaxCassettesPerAtm - 1 && s.hundredEuroNoteActive
        ? kPrestigeFifthSlotDenomination
        : kCassetteDenominations[slotIndex];
    return s
        .copyWith(balance: s.balance - kExtraCassettePrice)
        .withAtm(
          atm.copyWith(
            cassettes: [
              ...atm.cassettes,
              Cassette.empty(denomination: denomination),
            ],
          ),
        );
  }

  /// Koopt een extra CIT-geldwagen, exponentieel duurder per wagen, tot
  /// [kMaxCitVans] (Ontwerper dd 2026-07-04).
  GameState buyCitVan(GameState s) {
    final price = s.nextCitVanPrice;
    if (s.citVans.length >= kMaxCitVans || s.balance < price) {
      return s;
    }
    final nextId = s.citVans.map((v) => v.id).reduce(max) + 1;
    return s.copyWith(
      balance: s.balance - price,
      citVans: [
        ...s.citVans,
        CitVan(id: nextId),
      ],
    );
  }

  /// Stelt een extra servicemonteur aan, exponentieel duurder per
  /// monteur, tot [kMaxMechanics] (Ontwerper dd 2026-07-06).
  GameState buyMechanic(GameState s) {
    final price = s.nextMechanicPrice;
    if (s.mechanics.length >= kMaxMechanics || s.balance < price) {
      return s;
    }
    final nextId = s.mechanics.map((m) => m.id).reduce(max) + 1;
    return s.copyWith(
      balance: s.balance - price,
      mechanics: [
        ...s.mechanics,
        ServiceMechanic(id: nextId),
      ],
    );
  }

  /// Upgrade een automaat naar het volgende level (1 tot 5, Ontwerper dd
  /// 2026-07-04): sneller, betrouwbaarder, langere rij, veiliger en een
  /// hogere klanttevredenheids-multiplier. Cassettes en inhoud blijven.
  GameState upgradeAtm(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    final cost = atm.nextLevelCost;
    if (cost == null || s.balance < cost) {
      return s;
    }
    return s
        .copyWith(balance: s.balance - cost)
        .withAtm(atm.copyWith(level: atm.level + 1));
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

  /// Meehelpen met een reparatie: elke tik versnelt alle lopende
  /// cassettereparaties van deze automaat 3 seconden (GDD 4).
  GameState tapRepair(GameState s, int atmId) {
    // Meehelpen kan alleen als de monteur ter plaatse aan het repareren
    // is (aanrijdsysteem, Ontwerper dd 2026-07-06): elke tik versnelt de
    // klus 3 seconden en kan hem afronden.
    final mechanic = s.mechanicRepairingAt(atmId);
    if (mechanic == null) {
      return s;
    }
    final remaining = mechanic.ticksRemaining - kRepairTapSpeedupSeconds;
    if (remaining > 0) {
      return s.withMechanic(mechanic.copyWith(ticksRemaining: remaining));
    }
    final atm = s.atmById(atmId);
    s = s.withAtm(atm.repaired());
    return s.withMechanic(
      mechanic.copyWith(
        status: CitVanStatus.returning,
        ticksRemaining: s.travelTicksTo(atm.location),
      ),
    );
  }

  /// Gratis preventief onderhoud, beschikbaar zodra een werkende cassette
  /// onder 90% staat zit; zet alle werkende cassettes terug op 100%
  /// (GDD 4).
  GameState preventiveMaintenance(GameState s, int atmId) {
    final atm = s.atmById(atmId);
    if (!atm.isOperational ||
        atm.condition >= kPreventiveMaintenanceThreshold) {
      return s;
    }
    return s.withAtm(
      atm.copyWith(
        cassettes: [
          for (final c in atm.cassettes)
            c.isBroken ? c : c.copyWith(condition: 1.0),
        ],
      ),
    );
  }

  /// Prestige: vanaf 25.000 totaal verdiend het netwerk verkopen voor een
  /// permanente inkomensbonus. Volledige reset (ook de CIT-vloot); alleen
  /// bankcontractlevels en het prestigelevel blijven behouden (GDD 9.3).
  /// De dubbele tikbevestiging is een UI-verantwoordelijkheid.
  GameState prestige(GameState s) {
    if (s.totalEarned < kPrestigeThreshold) {
      return s;
    }
    final fresh = GameState.initial(nextEventInSeconds: _nextEventInterval());
    return fresh.copyWith(
      prestigeLevel: s.prestigeLevel + 1,
      banks: [
        for (final b in fresh.banks)
          b.copyWith(contractLevel: s.bank(b.id).contractLevel),
      ],
    );
  }
}
