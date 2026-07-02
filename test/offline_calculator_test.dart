import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/offline_calculator.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/states.dart';

void main() {
  const calculator = OfflineCalculator();

  // Verwachte waarden voor een Lobby basic op een station:
  // etmaalgemiddelde 26,8 / 24, transacties per seconde 0,55 x dat
  // gemiddelde, drain 1,5 biljet per transactie, gewogen banktarief
  // 0,5 x 0,9 + 0,3 x 1,1 + 0,2 x 1,35 = 1,05.
  const stationAvg = 26.8 / 24;
  const txPerSecond = kTransactionChancePerSecond * stationAvg;
  const drainPerSecond = txPerSecond * kAvgNotesPerTransaction;
  const weightedRate = 0.5 * 0.9 + 0.3 * 1.1 + 0.2 * 1.35;
  const incomePerTx = 2.0 * kIncomeSpreadAvg * weightedRate +
      kDccChanceTourist * kDccBonusEur;

  group('Offline-doorrekening (GDD 9.4)', () {
    test('afwezigheid wordt gecapt op 1 uur', () {
      final result =
          calculator.apply(singleAtmState(), const Duration(hours: 5));
      expect(result.simulatedSeconds, 3600);
    });

    test('inkomen is 50% van normaal, begrensd door de cassette', () {
      final result =
          calculator.apply(singleAtmState(balance: 0), const Duration(hours: 1));
      // De cassette (100 biljetten) is de grens: 100 / 1,5 transacties.
      const expectedTx = 100 / kAvgNotesPerTransaction;
      const expected = expectedTx * incomePerTx * kOfflineIncomeFactor;
      expect(result.income, closeTo(expected, 0.01));
      expect(result.state.balance, closeTo(expected, 0.01));
      expect(result.state.atms.first.notesInCassette, 0);
    });

    test('met regiomanager is het 75%', () {
      var s = singleAtmState(balance: 0);
      s = withStaffHired(s, StaffId.regionalManager);
      final result = calculator.apply(s, const Duration(hours: 1));
      const expectedTx = 100 / kAvgNotesPerTransaction;
      const expected = expectedTx *
          incomePerTx *
          kOfflineIncomeFactorRegionalManager;
      expect(result.income, closeTo(expected, 0.01));
    });

    test('slijtage begrenst de verdientijd en loopt offline door', () {
      // Staat 0,1 is na 25 seconden op; daarna stopt het verdienen.
      final result = calculator.apply(
        singleAtmState(condition: 0.1, balance: 0),
        const Duration(hours: 1),
      );
      const earningSeconds = 0.1 / kWearPerSecond;
      const expected =
          txPerSecond * earningSeconds * incomePerTx * kOfflineIncomeFactor;
      expect(result.income, closeTo(expected, 0.01));
      expect(result.state.atms.first.condition, 0);
      const expectedNotes = 100 - drainPerSecond * earningSeconds;
      expect(result.state.atms.first.notesInCassette,
          expectedNotes.floor());
    });

    test('een korte afwezigheid rekent alleen de verstreken tijd door', () {
      final result = calculator.apply(
        singleAtmState(balance: 0),
        const Duration(minutes: 1),
      );
      const expected =
          txPerSecond * 60 * incomePerTx * kOfflineIncomeFactor;
      expect(result.simulatedSeconds, 60);
      expect(result.income, closeTo(expected, 0.01));
      expect(
        result.state.atms.first.condition,
        closeTo(1 - kWearPerSecond * 60, 1e-9),
      );
    });

    test('niets verstreken betekent geen wijziging', () {
      final s = singleAtmState();
      final result = calculator.apply(s, Duration.zero);
      expect(result.income, 0);
      expect(result.state.balance, s.balance);
      expect(result.state.atms.first.notesInCassette, 100);
    });

    test('een recycler wordt offline door stortingen aangevuld', () {
      final result = calculator.apply(
        singleAtmState(
          tier: AtmTier.ttwRecycler,
          location: LocationType.reizen,
          balance: 0,
        ),
        const Duration(hours: 1),
      );
      // Reizen: factor 1,2. Drain 0,55 x 1,2 x 1,5 = 0,99 per seconde;
      // stortingen vullen 0,12 x 4 = 0,48 aan. Netto leegloop is trager
      // dan de slijtagegrens, dus slijtage begrenst hier.
      expect(result.income, greaterThan(0));
      final atm = result.state.atms.first;
      expect(atm.condition, 0);
      expect(atm.notesInCassette, greaterThan(0));
      expect(atm.notesInCassette,
          lessThanOrEqualTo(kTierCapacity[AtmTier.ttwRecycler.index]));
    });

    test('een kapotte automaat maakt eerst zijn reparatie af', () {
      var s = singleAtmState(balance: 0);
      s = s.withAtm(s.atms.first.copyWith(repairSecondsRemaining: 100));

      // Korter weg dan de reparatie duurt: alleen de timer loopt af.
      final still = calculator.apply(s, const Duration(seconds: 40));
      expect(still.income, 0);
      expect(still.state.atms.first.repairSecondsRemaining, 60);

      // Langer weg: reparatie klaar, daarna wordt er verdiend.
      final done = calculator.apply(s, const Duration(hours: 1));
      expect(done.state.atms.first.repairSecondsRemaining, 0);
      expect(done.income, greaterThan(0));
    });

    test('offline inkomen telt mee voor totaal verdiend', () {
      final result = calculator.apply(
        singleAtmState(balance: 0, totalEarned: 500),
        const Duration(hours: 1),
      );
      expect(result.state.totalEarned, closeTo(500 + result.income, 1e-9));
    });
  });
}
