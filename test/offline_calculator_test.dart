import 'dart:math';

import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/offline_calculator.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/cassette.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_random.dart';
import 'helpers/states.dart';

void main() {
  const calculator = OfflineCalculator();

  // Verwachte waarden voor een TTW dispenser level 1 op een station (TTW
  // heeft geen openingstijden-demping, dus het etmaalgemiddelde geldt
  // onverdund): aanloop 0,55 x (26,8 / 24), maar de doorvoer wordt
  // begrensd door de verwerkingstijd van 7 ticks per klant.
  const stationAvg = 26.8 / 24;
  const arrivals = kTransactionChancePerSecond * stationAvg;
  final txPerSecond = min(arrivals, 1 / 7);
  final drainPerSecond = txPerSecond * kAvgNotesPerTransaction;
  const weightedRate = 0.5 * 0.9 + 0.3 * 1.1 + 0.2 * 1.35;
  const incomePerTx =
      kDispenserBaseIncome * kIncomeSpreadAvg * weightedRate +
      kDccChanceTourist * kDccBonusEur;

  group('Offline-doorrekening (GDD 9.4)', () {
    test('afwezigheid wordt gecapt op 1 uur', () {
      final result = calculator.apply(
        singleAtmState(),
        const Duration(hours: 5),
      );
      expect(result.simulatedSeconds, 3600);
    });

    test('de doorvoer wordt door de verwerkingstijd begrensd', () {
      // De aanloop (0,61 per seconde) is hoger dan wat een level 1-kast
      // verwerkt (1 klant per 7 seconden): het slijtagebudget van 250
      // seconden is dan de verdiengrens binnen het uur.
      final result = calculator.apply(
        singleAtmState(housing: AtmHousing.ttw, balance: 0),
        const Duration(hours: 1),
      );
      const earningSeconds = 1.0 / kWearPerSecond;
      final expected =
          txPerSecond * earningSeconds * incomePerTx * kOfflineIncomeFactor;
      expect(result.income, closeTo(expected, 0.01));
      // Er blijven biljetten over: de cassette was niet de grens.
      expect(result.state.atms.first.notesInCassette, greaterThan(0));
      expect(result.state.atms.first.condition, 0);
    });

    test('met regiomanager is het 75% in plaats van 50%', () {
      final base = calculator.apply(
        singleAtmState(housing: AtmHousing.ttw, balance: 0),
        const Duration(hours: 1),
      );
      var s = singleAtmState(housing: AtmHousing.ttw, balance: 0);
      s = withStaffHired(s, StaffId.regionalManager);
      final manager = calculator.apply(s, const Duration(hours: 1));
      expect(
        manager.income / base.income,
        closeTo(
          kOfflineIncomeFactorRegionalManager / kOfflineIncomeFactor,
          1e-9,
        ),
      );
    });

    test('slijtage begrenst de verdientijd en loopt offline door', () {
      // Staat 0,1 is na 25 seconden op; daarna stopt het verdienen.
      final result = calculator.apply(
        singleAtmState(housing: AtmHousing.ttw, condition: 0.1, balance: 0),
        const Duration(hours: 1),
      );
      const earningSeconds = 0.1 / kWearPerSecond;
      final expected =
          txPerSecond * earningSeconds * incomePerTx * kOfflineIncomeFactor;
      expect(result.income, closeTo(expected, 0.01));
      expect(result.state.atms.first.condition, 0);
      final expectedNotes = 100 - (drainPerSecond * earningSeconds).ceil();
      expect(result.state.atms.first.notesInCassette, expectedNotes);
    });

    test('een korte afwezigheid rekent alleen de verstreken tijd door', () {
      final result = calculator.apply(
        singleAtmState(housing: AtmHousing.ttw, balance: 0),
        const Duration(minutes: 1),
      );
      final expected = txPerSecond * 60 * incomePerTx * kOfflineIncomeFactor;
      expect(result.simulatedSeconds, 60);
      expect(result.income, closeTo(expected, 0.01));
      expect(
        result.state.atms.first.condition,
        closeTo(1 - kWearPerSecond * 60, 1e-9),
      );
    });

    test('een lobby verdient offline minder door de openingstijden', () {
      // Op een rustige locatie met een snelle kast (level 5) is de
      // aanloop de grens, niet de verwerkingstijd: dan telt de demping
      // buiten openingstijden door in het offline-inkomen. De afwezigheid
      // is kort zodat de tijd bindt en niet de cassette-inhoud.
      final lobby = calculator.apply(
        singleAtmState(location: LocationType.openbaar, level: 5, balance: 0),
        const Duration(minutes: 2),
      );
      final ttw = calculator.apply(
        singleAtmState(
          location: LocationType.openbaar,
          level: 5,
          housing: AtmHousing.ttw,
          balance: 0,
        ),
        const Duration(minutes: 2),
      );
      expect(lobby.income, lessThan(ttw.income));
      expect(lobby.income, greaterThan(0));
    });

    test('niets verstreken betekent geen wijziging', () {
      final s = singleAtmState();
      final result = calculator.apply(s, Duration.zero);
      expect(result.income, 0);
      expect(result.state.balance, s.balance);
      expect(result.state.atms.first.notesInCassette, 100);
    });

    test('stortingen vullen een recycler offline netto bij', () {
      // Doorvoer 1/7: 70% opnames drainen 0,15 per seconde, 30%
      // stortingen vullen 0,17 aan: netto stijgt de voorraad tot de
      // slijtage het verdienen stopt.
      final result = calculator.apply(
        singleAtmState(
          housing: AtmHousing.ttw,
          function: AtmFunction.recycler,
          notesInCassette: 50,
          balance: 0,
        ),
        const Duration(hours: 1),
      );
      expect(result.income, greaterThan(0));
      final atm = result.state.atms.first;
      expect(atm.notesInCassette, greaterThan(50));
      expect(atm.condition, 0);
    });

    test('een storing wacht offline op de monteur', () {
      // Zonder monteur onderweg blijft de storing offline gewoon staan:
      // reparaties lopen niet meer vanzelf (aanrijdsysteem).
      final s = withFirstCassette(
        singleAtmState(balance: 0),
        repairSecondsRemaining: 30,
      );
      final still = calculator.apply(s, const Duration(hours: 1));
      expect(still.state.atms.first.isBroken, isTrue);
      expect(still.income, 0);
    });

    test('een monteur onderweg rondt zijn reparatie offline af', () {
      final engine = TickEngine(random: FakeRandom());
      var s = withFirstCassette(
        singleAtmState(balance: 0),
        repairSecondsRemaining: 30,
      );
      // Een online tick stuurt de monteur uit.
      s = engine.tick(s);
      expect(s.mechanics.single.status, CitVanStatus.transitToAtm);
      final travel = s.travelTicksTo(LocationType.station);

      // Te kort voor de aankomst: de storing staat er nog.
      final short = calculator.apply(s, const Duration(seconds: 10));
      expect(short.state.atms.first.isBroken, isTrue);
      expect(short.state.mechanics.single.ticksRemaining, travel - 10);
      expect(short.income, 0);

      // Lang genoeg voor heenreis, reparatie en terugreis: gerepareerd,
      // de monteur weer inzetbaar en de kast verdiende daarna door.
      final done = calculator.apply(
        s,
        Duration(seconds: travel * 2 + kRepairDurationSeconds),
      );
      expect(done.state.atms.first.isBroken, isFalse);
      expect(done.state.mechanics.single.isIdle, isTrue);
      expect(done.income, greaterThan(0));
    });

    test('werkende cassettes verdienen door terwijl een kapotte wacht', () {
      // Twee cassettes: een vol en werkend, een in storing. De werkende
      // verdient offline gewoon mee.
      var s = singleAtmState(housing: AtmHousing.ttw, balance: 0);
      s = s.withAtm(
        s.atms.first.copyWith(
          cassettes: [
            const Cassette.full(),
            const Cassette(
              notes: 50,
              condition: 0.5,
              repairSecondsRemaining: 5000,
            ),
          ],
        ),
      );
      final result = calculator.apply(s, const Duration(hours: 1));
      expect(result.income, greaterThan(0));
      final atm = result.state.atms.first;
      // De kapotte cassette hield zijn inhoud en storing (5000 > 3600).
      expect(atm.cassettes[1].notes, 50);
      expect(atm.cassettes[1].isBroken, isTrue);
      // De werkende cassette is deels leeggetrokken (slijtagegrens).
      expect(atm.cassettes[0].notes, lessThan(100));
      expect(atm.cassettes[0].notes, greaterThan(0));
    });

    test('een wagen onderweg rondt zijn servicing offline af', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 0, condition: 0.5);
      s = engine.requestService(s, 0);
      final travel = s.travelTicksTo(LocationType.station);

      // Lang genoeg weg voor heenreis, servicing en terugreis: de wagen is
      // weer inzetbaar en de servicing (vullen plus repareren) is voor de
      // doorrekening toegepast, waarna de automaat offline doorverdiende.
      final done = calculator.apply(
        s,
        Duration(seconds: travel * 2 + kServicingDurationTicks),
      );
      final atm = done.state.atms.first;
      expect(done.state.citVans.single.isIdle, isTrue);
      expect(atm.condition, greaterThan(0.5));
      expect(atm.notesInCassette, greaterThan(0));
      expect(done.income, greaterThan(0));

      // Te kort voor de aankomst: de wagen is nog onderweg en de cassette
      // nog leeg.
      final short = calculator.apply(s, const Duration(seconds: 10));
      expect(short.state.citVans.single.status, CitVanStatus.transitToAtm);
      expect(short.state.citVans.single.ticksRemaining, travel - 10);
      expect(short.state.atms.first.notesInCassette, 0);
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
