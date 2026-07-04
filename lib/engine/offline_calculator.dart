import 'dart:math';

import '../core/constants.dart';
import '../models/atm.dart';
import '../models/cassette.dart';
import '../models/enums.dart';
import '../models/game_state.dart';

/// Resultaat van de offline-doorrekening, voor logging en later UI.
class OfflineResult {
  const OfflineResult({
    required this.state,
    required this.simulatedSeconds,
    required this.income,
  });

  final GameState state;

  /// Doorgerekende seconden, na de cap van 1 uur (Parameters!B14).
  final double simulatedSeconds;

  /// Bijgeschreven offline-inkomen in EUR.
  final double income;
}

/// Deterministische offline-doorrekening (GDD 9.4).
///
/// De speler krijgt 50% van het normale inkomen over de afwezige tijd (75%
/// met regiomanager), maximaal 1 uur, begrensd door cassette-inhoud en
/// slijtage die ook offline doorlopen. Er wordt met verwachtingswaarden
/// gerekend, met per automaat het etmaalgemiddelde van zijn drukteprofiel
/// (Ontwerper dd 2026-07-02).
///
/// Multi-cassette en CIT-vloot (Ontwerper dd 2026-07-04): de werkende
/// cassettes worden als een voorraad- en slijtagebudget doorgerekend en
/// daarna volste-eerst teruggeschreven (nooit een staatsverbetering);
/// cassettes in storing lopen alleen hun reparatietimer af en verdienen
/// offline niet mee. Wagens die onderweg waren ronden hun rit offline af;
/// het bijvuldoel is een actief-spelen-doel en vordert offline niet.
class OfflineCalculator {
  const OfflineCalculator();

  OfflineResult apply(GameState state, Duration elapsed) {
    final seconds = min(
      elapsed.inMilliseconds / Duration.millisecondsPerSecond,
      kOfflineCapHours * Duration.secondsPerHour.toDouble(),
    );
    if (seconds <= 0) {
      return OfflineResult(state: state, simulatedSeconds: 0, income: 0);
    }

    var s = _advanceFleet(state, seconds.floor());

    final offlineFactor = s.hasStaff(StaffId.regionalManager)
        ? kOfflineIncomeFactorRegionalManager
        : kOfflineIncomeFactor;
    final ibnsLevel = s.upgradeLevel(UpgradeId.ibns);
    final bankRate = s.weightedBankRate;

    var totalIncome = 0.0;
    for (final atm in s.atms) {
      final result = _runAtm(
        s,
        atm,
        seconds,
        ibnsLevel: ibnsLevel,
        bankRate: bankRate,
        offlineFactor: offlineFactor,
      );
      totalIncome += result.$2;
      s = s.withAtm(result.$1);
    }

    // Offline-inkomen telt mee als verdiend en kan dus mijlpalen passeren;
    // de bonussen daarvan keert de eerstvolgende tick uit via de engine.
    s = s.copyWith(
      balance: s.balance + totalIncome,
      totalEarned: s.totalEarned + totalIncome,
    );
    return OfflineResult(
      state: s,
      simulatedSeconds: seconds,
      income: totalIncome,
    );
  }

  /// Rondt lopende CIT-ritten offline af: haalt de wagen zijn servicing
  /// binnen de offline-tijd, dan worden de cassettes voor de doorrekening
  /// alvast gevuld en gerepareerd; anders schuift zijn fase-timer op.
  GameState _advanceFleet(GameState s, int ticks) {
    for (final vanId in [for (final v in s.citVans) v.id]) {
      final van = s.citVans.firstWhere((v) => v.id == vanId);
      if (van.isIdle) {
        continue;
      }
      final target = s.atms.where((a) => a.id == van.targetAtmId).firstOrNull;
      final returnTicks = target == null ? 1 : s.travelTicksTo(target.location);
      // Resterende ticks tot de servicing is toegepast, per fase.
      final untilServiced = switch (van.status) {
        CitVanStatus.transitToAtm =>
          van.ticksRemaining + kServicingDurationTicks,
        CitVanStatus.servicing => van.ticksRemaining,
        _ => 0,
      };
      if (van.status == CitVanStatus.returning) {
        s = s.withVan(
          ticks >= van.ticksRemaining
              ? van.copyWith(
                  status: CitVanStatus.idle,
                  ticksRemaining: 0,
                  clearTarget: true,
                )
              : van.copyWith(ticksRemaining: van.ticksRemaining - ticks),
        );
        continue;
      }
      if (ticks < untilServiced) {
        // De servicing haalt het niet binnen de offline-tijd: alleen de
        // fase-timer opschuiven.
        final inTransit =
            van.status == CitVanStatus.transitToAtm &&
            ticks < van.ticksRemaining;
        s = s.withVan(
          inTransit
              ? van.copyWith(ticksRemaining: van.ticksRemaining - ticks)
              : van.copyWith(
                  status: CitVanStatus.servicing,
                  ticksRemaining: untilServiced - ticks,
                ),
        );
        continue;
      }
      // Servicing afgerond: vullen, repareren en terugreizen.
      if (target != null) {
        s = s.withAtm(target.serviced());
      }
      final afterService = ticks - untilServiced;
      s = s.withVan(
        afterService >= returnTicks
            ? van.copyWith(
                status: CitVanStatus.idle,
                ticksRemaining: 0,
                clearTarget: true,
              )
            : van.copyWith(
                status: CitVanStatus.returning,
                ticksRemaining: returnTicks - afterService,
              ),
      );
    }
    return s;
  }

  /// Rekent een automaat deterministisch door en geeft de nieuwe automaat
  /// plus het (al met de offline-factor geschaalde) inkomen terug.
  (Atm, double) _runAtm(
    GameState s,
    Atm atm,
    double seconds, {
    required int ibnsLevel,
    required double bankRate,
    required double offlineFactor,
  }) {
    // Cassettes in storing lopen alleen hun reparatietimer af; klaar
    // betekent staat 100% met behoud van inhoud. Ze verdienen offline
    // niet mee (vereenvoudiging aan de voorspelbare kant).
    var updated = atm.copyWith(
      cassettes: [
        for (final c in atm.cassettes)
          !c.isBroken
              ? c
              : c.repairSecondsRemaining > seconds
              ? c.copyWith(
                  repairSecondsRemaining: c.repairSecondsRemaining - seconds,
                )
              : c.copyWith(repairSecondsRemaining: 0, condition: 1.0),
      ],
    );

    // Verdienen doen alleen de cassettes die bij vertrek al werkten.
    final workingIndexes = [
      for (var i = 0; i < atm.cassettes.length; i++)
        if (!atm.cassettes[i].isBroken) i,
    ];
    if (workingIndexes.isEmpty) {
      return (updated, 0);
    }

    // Stroomstoring loopt eerst af; de resterende tijd verdient mee.
    var remaining = seconds;
    if (atm.isPausedByOutage) {
      if (atm.outageSecondsRemaining >= remaining) {
        return (
          updated.copyWith(
            outageSecondsRemaining: atm.outageSecondsRemaining - remaining,
          ),
          0,
        );
      }
      remaining -= atm.outageSecondsRemaining;
      updated = updated.copyWith(outageSecondsRemaining: 0);
    }

    final profile = kBusyProfiles[atm.location]!;
    final txPerSecond = min(
      kTransactionChancePerSecond * profile.dayAverage,
      kTransactionChanceCap,
    );

    // Verwachte cassette-drain per seconde, inclusief het 100 euro biljet.
    var drainPerSecond = txPerSecond * kAvgNotesPerTransaction;
    if (s.hundredEuroNoteActive) {
      drainPerSecond *= kHundredEuroNoteDrainMultiplier;
    }

    // Recyclers krijgen offline ook stortingen: verwachte aanvulling en
    // extra slijtage (GDD 3.1 en 4).
    var refillPerSecond = 0.0;
    var depositWearPerSecond = 0.0;
    var depositFeePerSecond = 0.0;
    if (atm.tier.isRecycler) {
      const avgDepositNotes = (kDepositNotesMin + kDepositNotesMax) / 2;
      refillPerSecond = kDepositChancePerSecond * avgDepositNotes;
      depositWearPerSecond = kDepositChancePerSecond * kRecyclerWearPerDeposit;
      depositFeePerSecond = kDepositChancePerSecond * kDepositFeeEur;
    }

    final wearPerSecond =
        kWearPerSecond * (1 - kIbnsWearReductionPerLevel * ibnsLevel) +
        depositWearPerSecond;

    // Voorraad- en slijtagebudget over de werkende cassettes: de engine
    // slijt een cassette tegelijk (de volste), dus offline is de som van
    // de staten het budget tot alles versleten is.
    var availableNotes = 0;
    var conditionBudget = 0.0;
    for (final i in workingIndexes) {
      availableNotes += atm.cassettes[i].notes;
      conditionBudget += atm.cassettes[i].condition;
    }

    // Verdientijd: begrensd door voorraad en slijtage (GDD 9.4).
    final netDrainPerSecond = drainPerSecond - refillPerSecond;
    final secondsUntilEmpty = netDrainPerSecond > 0
        ? availableNotes / netDrainPerSecond
        : double.infinity;
    final secondsUntilWorn = wearPerSecond > 0
        ? conditionBudget / wearPerSecond
        : double.infinity;
    final earningSeconds = min(
      remaining,
      min(secondsUntilEmpty, secondsUntilWorn),
    );

    // Verwacht inkomen per transactie: tierinkomen x gemiddelde spreiding x
    // gewogen banktarief x multipliers, plus de DCC-verwachting (GDD 3.1).
    final dccChance = atm.isTouristLocation
        ? kDccChanceTourist
        : kDccChanceNormal;
    final incomePerTx =
        atm.incomePerTransaction *
            kIncomeSpreadAvg *
            bankRate *
            s.incomeMultiplier +
        dccChance * kDccBonusEur;
    final rawIncome =
        txPerSecond * earningSeconds * incomePerTx +
        depositFeePerSecond * earningSeconds;
    final income = rawIncome * offlineFactor;

    // Slijtage loopt de volledige (gecapte) offline-tijd door zolang er
    // budget is; op nul stopt het verdienen en handelt de eerstvolgende
    // online tick de storing af (GDD 4 en 9.4).
    final wearSeconds = min(remaining, secondsUntilWorn);
    final drainedNotes = (netDrainPerSecond * earningSeconds).clamp(
      -availableNotes.toDouble(),
      availableNotes.toDouble(),
    );
    final totalWear = wearPerSecond * wearSeconds;

    updated = _applyToWorkingCassettes(
      updated,
      workingIndexes,
      drainedNotes: drainedNotes,
      totalWear: totalWear,
    );
    return (
      updated.copyWith(lifetimeEarned: atm.lifetimeEarned + income),
      income,
    );
  }

  /// Schrijft de aggregaat-drain en -slijtage terug naar de losse
  /// cassettes, volste-eerst (zoals de engine de actieve cassette kiest).
  /// Een netto-aanvulling (recycler) vult juist de leegste eerst. De staat
  /// van een cassette kan hier nooit stijgen.
  Atm _applyToWorkingCassettes(
    Atm atm,
    List<int> workingIndexes, {
    required double drainedNotes,
    required double totalWear,
  }) {
    final cassettes = [...atm.cassettes];

    // Drain (of aanvulling) verdelen. Afronden in het nadeel van de
    // voorraad (zoals de oude vloer op de eindstand): een gedeeltelijk
    // getrokken biljet is weg, een gedeeltelijk gestort biljet telt niet.
    var notesLeft = drainedNotes >= 0
        ? drainedNotes.ceil()
        : -(-drainedNotes).floor();
    final drainOrder = [...workingIndexes]
      ..sort((a, b) => cassettes[b].notes.compareTo(cassettes[a].notes));
    if (notesLeft >= 0) {
      for (final i in drainOrder) {
        if (notesLeft <= 0) {
          break;
        }
        final take = min(cassettes[i].notes, notesLeft);
        cassettes[i] = cassettes[i].copyWith(notes: cassettes[i].notes - take);
        notesLeft -= take;
      }
    } else {
      var refill = -notesLeft;
      final fillOrder = [...workingIndexes]
        ..sort((a, b) => cassettes[a].notes.compareTo(cassettes[b].notes));
      for (final i in fillOrder) {
        if (refill <= 0) {
          break;
        }
        final add = min(kCassetteCapacityUnits - cassettes[i].notes, refill);
        cassettes[i] = cassettes[i].copyWith(notes: cassettes[i].notes + add);
        refill -= add;
      }
    }

    // Slijtage verdelen, volste-eerst; nooit onder nul per cassette.
    var wearLeft = totalWear;
    final wearOrder = [...workingIndexes]
      ..sort((a, b) => cassettes[b].notes.compareTo(cassettes[a].notes));
    for (final i in wearOrder) {
      if (wearLeft <= 0) {
        break;
      }
      final absorb = min(cassettes[i].condition, wearLeft);
      cassettes[i] = cassettes[i].copyWith(
        condition: max(0, cassettes[i].condition - absorb),
      );
      wearLeft -= absorb;
    }

    return atm.copyWith(cassettes: List<Cassette>.unmodifiable(cassettes));
  }
}
