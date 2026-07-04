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

  // Verwachte waarden voor een Lobby basic op een station:
  // etmaalgemiddelde 26,8 / 24, transacties per seconde 0,55 x dat
  // gemiddelde, drain 1,5 biljet per transactie, gewogen banktarief
  // 0,5 x 0,9 + 0,3 x 1,1 + 0,2 x 1,35 = 1,05.
  const stationAvg = 26.8 / 24;
  const txPerSecond = kTransactionChancePerSecond * stationAvg;
  const drainPerSecond = txPerSecond * kAvgNotesPerTransaction;
  const weightedRate = 0.5 * 0.9 + 0.3 * 1.1 + 0.2 * 1.35;
  const incomePerTx =
      2.0 * kIncomeSpreadAvg * weightedRate + kDccChanceTourist * kDccBonusEur;

  group('Offline-doorrekening (GDD 9.4)', () {
    test('afwezigheid wordt gecapt op 1 uur', () {
      final result = calculator.apply(
        singleAtmState(),
        const Duration(hours: 5),
      );
      expect(result.simulatedSeconds, 3600);
    });

    test('inkomen is 50% van normaal, begrensd door de cassette', () {
      final result = calculator.apply(
        singleAtmState(balance: 0),
        const Duration(hours: 1),
      );
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
      const expected =
          expectedTx * incomePerTx * kOfflineIncomeFactorRegionalManager;
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
      expect(result.state.atms.first.notesInCassette, expectedNotes.floor());
    });

    test('een korte afwezigheid rekent alleen de verstreken tijd door', () {
      final result = calculator.apply(
        singleAtmState(balance: 0),
        const Duration(minutes: 1),
      );
      const expected = txPerSecond * 60 * incomePerTx * kOfflineIncomeFactor;
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

    test('stortingen remmen offline de leegloop van een recycler', () {
      final result = calculator.apply(
        singleAtmState(
          tier: AtmTier.ttwRecycler,
          location: LocationType.reizen,
          balance: 0,
        ),
        const Duration(hours: 1),
      );
      // Reizen: factor 1,2. Drain 0,55 x 1,2 x 1,5 = 0,99 per seconde;
      // stortingen vullen 0,12 x 4 = 0,48 aan: netto 0,51 per seconde.
      // De cassette van 100 is dan na zo'n 196 seconden leeg - langer dan
      // zonder recycling - en de slijtage (met stortingsslijtage) loopt
      // door tot de staat op is.
      expect(result.income, greaterThan(0));
      final atm = result.state.atms.first;
      expect(atm.notesInCassette, 0);
      expect(atm.condition, 0);
      // Ter vergelijking: een gewone TTW unit op dezelfde plek is door
      // dezelfde drain zonder aanvulling eerder leeg en verdient minder.
      final plain = calculator.apply(
        singleAtmState(
          tier: AtmTier.ttwUnit,
          location: LocationType.reizen,
          balance: 0,
        ),
        const Duration(hours: 1),
      );
      expect(plain.state.atms.first.notesInCassette, 0);
      // Recycler-inkomen per transactie is hoger (tier) plus stortingsfees;
      // belangrijker: hij verdient langer door. Grofweg dus meer inkomen.
      expect(result.income, greaterThan(plain.income));
    });

    test('een kapotte cassette maakt offline zijn reparatie af', () {
      final s = withFirstCassette(
        singleAtmState(balance: 0),
        repairSecondsRemaining: 100,
      );

      // Korter weg dan de reparatie duurt: alleen de timer loopt af.
      final still = calculator.apply(s, const Duration(seconds: 40));
      expect(still.income, 0);
      expect(still.state.atms.first.repairSecondsRemaining, 60);

      // Langer weg: reparatie klaar en staat hersteld. Cassettes die bij
      // vertrek in storing stonden verdienen offline niet mee
      // (vereenvoudiging); online pakt de automaat de draad weer op.
      final done = calculator.apply(s, const Duration(hours: 1));
      expect(done.state.atms.first.repairSecondsRemaining, 0);
      expect(done.state.atms.first.condition, 1.0);
      expect(done.income, 0);
    });

    test('werkende cassettes verdienen door terwijl een kapotte wacht', () {
      // Twee cassettes: een vol en werkend, een in storing. De werkende
      // verdient offline gewoon mee.
      var s = singleAtmState(balance: 0);
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
      // De werkende cassette is leeggetrokken.
      expect(atm.cassettes[0].notes, 0);
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
