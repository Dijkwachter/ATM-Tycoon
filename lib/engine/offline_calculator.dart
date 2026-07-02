import 'dart:math';

import '../core/constants.dart';
import '../models/atm.dart';
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
/// (Ontwerper dd 2026-07-02): een uur offline beslaat 30 speldagen, dus de
/// dagcyclus middelt vrijwel volledig uit.
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

    final offlineFactor = state.hasStaff(StaffId.regionalManager)
        ? kOfflineIncomeFactorRegionalManager
        : kOfflineIncomeFactor;
    final ibnsLevel = state.upgradeLevel(UpgradeId.ibns);
    final cassetteLevel = state.upgradeLevel(UpgradeId.cassettes);
    final bankRate = state.weightedBankRate;

    var s = state;
    var totalIncome = 0.0;

    for (final atm in state.atms) {
      // Automaten in reparatie of stroomstoring lopen hun timer offline
      // gewoon af; wat overblijft draait daarna niet mee in het inkomen
      // (vereenvoudiging aan de veilige, gulle kant: de resterende tijd na
      // de timer wordt wel meegenomen).
      var remaining = seconds;
      var updated = atm;
      if (updated.isBroken) {
        final repairTime = updated.repairSecondsRemaining;
        if (repairTime >= remaining) {
          s = s.withAtm(updated.copyWith(
              repairSecondsRemaining: repairTime - remaining));
          continue;
        }
        remaining -= repairTime;
        updated = updated.copyWith(repairSecondsRemaining: 0, condition: 1.0);
      } else if (updated.isPausedByOutage) {
        final outage = updated.outageSecondsRemaining;
        if (outage >= remaining) {
          s = s.withAtm(
              updated.copyWith(outageSecondsRemaining: outage - remaining));
          continue;
        }
        remaining -= outage;
        updated = updated.copyWith(outageSecondsRemaining: 0);
      }

      final result = _runAtm(
        s,
        updated,
        remaining,
        ibnsLevel: ibnsLevel,
        cassetteLevel: cassetteLevel,
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

  /// Rekent een automaat deterministisch door en geeft de nieuwe automaat
  /// plus het (al met de offline-factor geschaalde) inkomen terug.
  (Atm, double) _runAtm(
    GameState s,
    Atm atm,
    double seconds, {
    required int ibnsLevel,
    required int cassetteLevel,
    required double bankRate,
    required double offlineFactor,
  }) {
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

    final wearPerSecond = kWearPerSecond *
            (1 - kIbnsWearReductionPerLevel * ibnsLevel) +
        depositWearPerSecond;

    // Verdientijd: begrensd door cassette-inhoud en slijtage (GDD 9.4).
    final netDrainPerSecond = drainPerSecond - refillPerSecond;
    final secondsUntilEmpty = netDrainPerSecond > 0
        ? atm.notesInCassette / netDrainPerSecond
        : double.infinity;
    final secondsUntilWorn =
        wearPerSecond > 0 ? atm.condition / wearPerSecond : double.infinity;
    final earningSeconds = min(seconds, min(secondsUntilEmpty, secondsUntilWorn));

    // Verwacht inkomen per transactie: tierinkomen x gemiddelde spreiding x
    // gewogen banktarief x multipliers, plus de DCC-verwachting (GDD 3.1).
    final dccChance =
        atm.isTouristLocation ? kDccChanceTourist : kDccChanceNormal;
    final incomePerTx = atm.incomePerTransaction *
            kIncomeSpreadAvg *
            bankRate *
            s.incomeMultiplier +
        dccChance * kDccBonusEur;
    final rawIncome = txPerSecond * earningSeconds * incomePerTx +
        depositFeePerSecond * earningSeconds;
    final income = rawIncome * offlineFactor;

    // Nieuwe cassette-inhoud: netto drain over de verdientijd; bij een
    // recycler kan dit negatief zijn (netto aanvulling), begrensd op 0 en
    // capaciteit.
    final capacity = atm.capacity(cassetteLevel);
    final drainedNotes = netDrainPerSecond * earningSeconds;
    final newNotes = (atm.notesInCassette - drainedNotes)
        .clamp(0, capacity.toDouble())
        .floor();

    // Slijtage loopt de volledige (gecapte) offline-tijd door zolang de
    // automaat operationeel is; bij staat nul stopt hij met verdienen en
    // handelt de eerstvolgende online tick de uitval af (GDD 4 en 9.4).
    final wearSeconds = min(seconds, secondsUntilWorn);
    final newCondition = max(0.0, atm.condition - wearPerSecond * wearSeconds);

    return (
      atm.copyWith(
        notesInCassette: newNotes,
        condition: newCondition,
        lifetimeEarned: atm.lifetimeEarned + income,
      ),
      income,
    );
  }
}
