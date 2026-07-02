import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_random.dart';
import 'helpers/states.dart';

void main() {
  group('Transacties (GDD 3.1)', () {
    test('opname volgt de inkomensformule en draineert de cassette', () {
      // Station om 12 uur: druktefactor 1,0 dus kans 0,55. Script: roll 0,5
      // slaagt, 1 biljet, spreiding midden (1,1), Bank Oranje (0,90),
      // geen DCC.
      final engine = TickEngine(
        random: FakeRandom(doubles: [0.5, 0.5, 0.0, 0.99], bools: [false]),
      );
      final s = engine.tick(singleAtmState(balance: 0));

      const expectedIncome = 2.0 * 1.1 * 0.9;
      expect(s.totalEarned, closeTo(expectedIncome, 1e-9));
      expect(s.atms.first.notesInCassette, 99);
      expect(s.atms.first.lifetimeEarned, closeTo(expectedIncome, 1e-9));
      // Saldo is inkomen minus float-rente over de resterende biljetten.
      const interest = 99 * kAvgNoteValueEur * kFloatInterestPerSecond;
      expect(s.balance, closeTo(expectedIncome - interest, 1e-9));
    });

    test('een transactie kan twee biljetten kosten', () {
      final engine = TickEngine(
        random: FakeRandom(doubles: [0.5, 0.5, 0.0, 0.99], bools: [true]),
      );
      final s = engine.tick(singleAtmState());
      expect(s.atms.first.notesInCassette, 98);
    });

    test('spreiding gebruikt de grenzen 0,8 en 1,4', () {
      final low = TickEngine(
        random: FakeRandom(doubles: [0.5, 0.0, 0.0, 0.99], bools: [false]),
      ).tick(singleAtmState(balance: 0));
      expect(low.totalEarned, closeTo(2.0 * kIncomeSpreadMin * 0.9, 1e-9));

      final high = TickEngine(
        random: FakeRandom(doubles: [0.5, 1.0, 0.0, 0.99], bools: [false]),
      ).tick(singleAtmState(balance: 0));
      expect(high.totalEarned, closeTo(2.0 * kIncomeSpreadMax * 0.9, 1e-9));
    });

    test('geen transactie als de roll boven de kans ligt', () {
      final engine = TickEngine(random: FakeRandom(doubles: [0.56]));
      final s = engine.tick(singleAtmState(balance: 0));
      expect(s.totalEarned, 0);
      expect(s.atms.first.notesInCassette, 100);
    });

    test('drukte verhoogt de kans, gecapt op 0,95', () {
      // Evenement om 20 uur: factor 2,5 geeft 1,375 maar de cap is 0,95.
      final hit = TickEngine(
        random: FakeRandom(doubles: [0.94, 0.5, 0.0, 0.99], bools: [false]),
      ).tick(singleAtmState(
          location: LocationType.evenement, hour: 20, balance: 0));
      expect(hit.totalEarned, greaterThan(0));

      final miss = TickEngine(random: FakeRandom(doubles: [0.96]))
          .tick(singleAtmState(
              location: LocationType.evenement, hour: 20, balance: 0));
      expect(miss.totalEarned, 0);
    });

    test('in het dal is de kans laag', () {
      // Station om 3 uur: factor 0,2 geeft kans 0,11; roll 0,12 mist.
      final s = TickEngine(random: FakeRandom(doubles: [0.12]))
          .tick(singleAtmState(hour: 3, balance: 0));
      expect(s.totalEarned, 0);
    });

    test('een lege cassette levert geen inkomen', () {
      final engine = TickEngine(
        random: FakeRandom(doubles: [0.1], bools: [false]),
      );
      final s = engine.tick(singleAtmState(notesInCassette: 0, balance: 0));
      expect(s.totalEarned, 0);
      expect(s.atms.first.notesInCassette, 0);
    });

    test('onvoldoende biljetten voor de opname: transactie gaat niet door',
        () {
      final engine = TickEngine(
        random: FakeRandom(doubles: [0.1], bools: [true]),
      );
      final s = engine.tick(singleAtmState(notesInCassette: 1, balance: 0));
      expect(s.totalEarned, 0);
      expect(s.atms.first.notesInCassette, 1);
    });
  });

  group('Banktarieven (GDD 8)', () {
    test('de bank wordt gewogen naar aandeel gekozen', () {
      // Roll 0,99 valt voorbij Oranje (0,5) en Rivier (0,3): Noorderbank
      // met tarief 1,35.
      final s = TickEngine(
        random: FakeRandom(doubles: [0.5, 0.5, 0.99, 0.99], bools: [false]),
      ).tick(singleAtmState(balance: 0));
      expect(s.totalEarned, closeTo(2.0 * 1.1 * 1.35, 1e-9));
    });

    test('heronderhandelen verhoogt het tarief met 0,05 per level', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 500);
      s = engine.negotiateBankContract(s, BankId.oranje);
      expect(s.bank(BankId.oranje).contractLevel, 1);
      expect(s.bank(BankId.oranje).effectiveRate, closeTo(0.95, 1e-9));
      expect(s.balance, 0);
      // Volgend level kost 500 x 2^1 = 1000.
      expect(s.bank(BankId.oranje).negotiationCost, 1000);
    });

    test('onderhandelen boven het maximum of zonder saldo kan niet', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 100);
      expect(engine.negotiateBankContract(s, BankId.oranje).balance, 100);

      s = s.copyWith(
        balance: 1000000,
        banks: [
          for (final b in s.banks)
            b.id == BankId.oranje
                ? b.copyWith(contractLevel: kBankContractMaxLevel)
                : b,
        ],
      );
      final after = engine.negotiateBankContract(s, BankId.oranje);
      expect(after.bank(BankId.oranje).contractLevel, kBankContractMaxLevel);
      expect(after.balance, 1000000);
    });

    test('Zuiderbank vereist level Regio en 5.000, en herschaalt aandelen',
        () {
      final engine = TickEngine(random: FakeRandom());
      final tooEarly = singleAtmState(balance: 10000, totalEarned: 4000);
      expect(
          engine.connectZuiderbank(tooEarly).bank(BankId.zuider).connected,
          isFalse);

      final ready = singleAtmState(balance: 10000, totalEarned: 8000);
      final s = engine.connectZuiderbank(ready);
      expect(s.bank(BankId.zuider).connected, isTrue);
      expect(s.balance, 5000);
      final shares = s.bankShares;
      expect(shares[BankId.oranje], closeTo(0.425, 1e-9));
      expect(shares[BankId.rivier], closeTo(0.255, 1e-9));
      expect(shares[BankId.noorder], closeTo(0.17, 1e-9));
      expect(shares[BankId.zuider], closeTo(0.15, 1e-9));
      expect(shares.values.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
    });
  });

  group('Slijtage en reparatie (GDD 4)', () {
    test('de staat daalt met 0,004 per seconde', () {
      final s = TickEngine(random: FakeRandom()).tick(singleAtmState());
      expect(s.atms.first.condition, closeTo(1 - kWearPerSecond, 1e-9));
    });

    test('IBNS vertraagt de slijtage met 12% per level', () {
      var state = singleAtmState();
      state = withUpgradeLevel(state, UpgradeId.ibns, 2);
      final s = TickEngine(random: FakeRandom()).tick(state);
      expect(
        s.atms.first.condition,
        closeTo(1 - kWearPerSecond * (1 - 2 * kIbnsWearReductionPerLevel),
            1e-9),
      );
    });

    test('bij staat nul: uitval, voorrijkosten en reparatietimer', () {
      final s = TickEngine(random: FakeRandom())
          .tick(singleAtmState(condition: kWearPerSecond, balance: 100));
      expect(s.atms.first.isBroken, isTrue);
      expect(s.atms.first.repairSecondsRemaining, kRepairDurationSeconds);
      // Lobby basic: voorrijkosten 40 + 20 x tier 0 = 40, plus de
      // float-rente over de onaangeroerde 100 biljetten.
      const interest = 100 * kAvgNoteValueEur * kFloatInterestPerSecond;
      expect(s.balance,
          closeTo(100 - kBreakdownCalloutBase - interest, 1e-9));
    });

    test('voorrijkosten schalen met tier en IBNS geeft korting', () {
      var state = singleAtmState(
        tier: AtmTier.ttwUnit,
        condition: kWearPerSecond,
        balance: 1000,
      );
      state = withUpgradeLevel(state, UpgradeId.ibns, 1);
      final s = TickEngine(random: FakeRandom()).tick(state);
      // (40 + 20 x 2) x (1 - 0,08) = 73,6; maar IBNS vertraagt ook de
      // slijtage, dus de automaat valt met deze startstaat nog niet uit.
      expect(s.atms.first.isBroken, isFalse);

      final justBreaking = TickEngine(random: FakeRandom()).tick(
        withUpgradeLevel(
          singleAtmState(
            tier: AtmTier.ttwUnit,
            condition: 0.0001,
            balance: 1000,
          ),
          UpgradeId.ibns,
          1,
        ),
      );
      expect(justBreaking.atms.first.isBroken, isTrue);
      final interest = kTierCapacity[AtmTier.ttwUnit.index] *
          kAvgNoteValueEur *
          kFloatInterestPerSecond;
      expect(
          justBreaking.balance, closeTo(1000 - 80 * 0.92 - interest, 1e-9));
    });

    test('voorrijkosten brengen het saldo nooit onder nul', () {
      final s = TickEngine(random: FakeRandom())
          .tick(singleAtmState(condition: kWearPerSecond, balance: 10));
      expect(s.balance, 0);
    });

    test('reparatie telt af en herstelt de staat naar 100%', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.tick(singleAtmState(condition: kWearPerSecond));
      expect(s.atms.first.repairSecondsRemaining, kRepairDurationSeconds);
      for (var i = 0; i < kRepairDurationSeconds; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.isBroken, isFalse);
      expect(s.atms.first.condition, 1.0);
    });

    test('met monteur duurt een reparatie 12 seconden', () {
      final state = withStaffHired(
        singleAtmState(condition: kWearPerSecond),
        StaffId.mechanic,
      );
      final s = TickEngine(random: FakeRandom()).tick(state);
      expect(s.atms.first.repairSecondsRemaining,
          kRepairDurationMechanicSeconds);
    });

    test('meehelpen: elke tik versnelt 3 seconden en kan afronden', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.tick(singleAtmState(condition: kWearPerSecond));
      final before = s.atms.first.repairSecondsRemaining;
      s = engine.tapRepair(s, 0);
      expect(s.atms.first.repairSecondsRemaining,
          before - kRepairTapSpeedupSeconds);

      var almostDone = s.withAtm(
        s.atms.first.copyWith(repairSecondsRemaining: 2),
      );
      almostDone = engine.tapRepair(almostDone, 0);
      expect(almostDone.atms.first.isBroken, isFalse);
      expect(almostDone.atms.first.condition, 1.0);
    });

    test('preventief onderhoud is gratis en alleen onder 90% staat', () {
      final engine = TickEngine(random: FakeRandom());
      final worn = singleAtmState(condition: 0.5, balance: 77);
      final maintained = engine.preventiveMaintenance(worn, 0);
      expect(maintained.atms.first.condition, 1.0);
      expect(maintained.balance, 77);

      final fresh = singleAtmState(condition: 0.95);
      expect(
          engine.preventiveMaintenance(fresh, 0).atms.first.condition, 0.95);
    });
  });

  group('DCC (GDD 3.1)', () {
    test('toeristische locatie: 14% kans op 4 euro extra', () {
      final s = TickEngine(
        random: FakeRandom(doubles: [0.5, 0.5, 0.0, 0.13], bools: [false]),
      ).tick(singleAtmState(balance: 0));
      expect(s.totalEarned, closeTo(2.0 * 1.1 * 0.9 + kDccBonusEur, 1e-9));
    });

    test('normale locatie: dezelfde roll geeft geen DCC', () {
      // Winkel om 12 uur is geen toeristische locatie; 0,13 > 0,05.
      final s = TickEngine(
        random: FakeRandom(doubles: [0.5, 0.5, 0.0, 0.13], bools: [false]),
      ).tick(singleAtmState(location: LocationType.winkel, balance: 0));
      expect(s.totalEarned, closeTo(2.0 * 1.1 * 0.9, 1e-9));
    });

    test('normale locatie: onder 5% wel DCC', () {
      final s = TickEngine(
        random: FakeRandom(doubles: [0.5, 0.5, 0.0, 0.04], bools: [false]),
      ).tick(singleAtmState(location: LocationType.winkel, balance: 0));
      expect(s.totalEarned, closeTo(2.0 * 1.1 * 0.9 + kDccBonusEur, 1e-9));
    });
  });

  group('Stortingen op recyclers (GDD 3.1 en 4)', () {
    test('storting: fee, biljetten terug en extra slijtage', () {
      // Transactieroll mist (0,96), stortingsroll 0,05 slaagt, 2 + 2
      // biljetten.
      final s = TickEngine(
        random: FakeRandom(doubles: [0.96, 0.05], ints: [2]),
      ).tick(singleAtmState(
        tier: AtmTier.ttwRecycler,
        notesInCassette: 100,
        balance: 0,
      ));
      expect(s.atms.first.notesInCassette, 104);
      expect(
        s.atms.first.condition,
        closeTo(1 - kWearPerSecond - kRecyclerWearPerDeposit, 1e-9),
      );
      const interest = 104 * kAvgNoteValueEur * kFloatInterestPerSecond;
      expect(s.balance, closeTo(kDepositFeeEur - interest, 1e-9));
      expect(s.totalEarned, kDepositFeeEur);
    });

    test('een storting kan de capaciteit niet overschrijden', () {
      final s = TickEngine(
        random: FakeRandom(doubles: [0.96, 0.05], ints: [4]),
      ).tick(singleAtmState(
        tier: AtmTier.ttwRecycler,
        notesInCassette: kTierCapacity[AtmTier.ttwRecycler.index] - 1,
      ));
      expect(s.atms.first.notesInCassette,
          kTierCapacity[AtmTier.ttwRecycler.index]);
    });

    test('alleen recyclers accepteren stortingen', () {
      // Voor een gewone TTW unit wordt de stortingsroll niet eens
      // geconsumeerd; met dezelfde queue blijft het saldo op nul.
      final s = TickEngine(
        random: FakeRandom(doubles: [0.96, 0.05], ints: [2]),
      ).tick(singleAtmState(tier: AtmTier.ttwUnit, balance: 0));
      expect(s.totalEarned, 0);
    });
  });

  group('Float-rente (GDD 3.2)', () {
    test('rente loopt over de cashwaarde van alle cassettes', () {
      final s = TickEngine(random: FakeRandom())
          .tick(singleAtmState(balance: 100));
      const expected =
          100 - 100 * kAvgNoteValueEur * kFloatInterestPerSecond;
      expect(s.balance, closeTo(expected, 1e-9));
    });

    test('float-rente kan het saldo nooit negatief maken', () {
      final s = TickEngine(random: FakeRandom())
          .tick(singleAtmState(balance: 0.01));
      expect(s.balance, 0);
    });
  });

  group('Events (GDD 6)', () {
    test('Koningsdag verdubbelt de drukte van alle automaten', () {
      final engine = TickEngine(
        random: FakeRandom(doubles: [0.94, 0.5, 0.0, 0.99], bools: [false]),
      );
      var s = singleAtmState(balance: 0);
      // Zonder event zou roll 0,94 missen (kans 0,55).
      expect(TickEngine(random: FakeRandom(doubles: [0.94]))
          .tick(s)
          .totalEarned, 0);
      s = engine.fireEvent(s, GameEventType.kingsday);
      expect(s.activeEvent!.type, GameEventType.kingsday);
      final after = engine.tick(s);
      expect(after.totalEarned, greaterThan(0));
    });

    test('festival verdrievoudigt alleen de doellocatie', () {
      final engine = TickEngine(random: FakeRandom(ints: [0]));
      var s = singleAtmState(hour: 3, balance: 0);
      s = engine.fireEvent(s, GameEventType.festival);
      expect(s.activeEvent!.targetAtmId, 0);
      // Station om 3 uur: factor 0,2 x 3 = 0,6; roll 0,32 slaagt nu wel.
      final hit = TickEngine(
        random: FakeRandom(doubles: [0.32, 0.5, 0.0, 0.99], bools: [false]),
      ).tick(s);
      expect(hit.totalEarned, greaterThan(0));
    });

    test('festival zonder toeristische locatie doet niets', () {
      final engine = TickEngine(random: FakeRandom());
      final s = engine.fireEvent(
        singleAtmState(location: LocationType.winkel),
        GameEventType.festival,
      );
      expect(s.activeEvent, isNull);
    });

    test('stroomstoring pauzeert 20 seconden zonder kosten of slijtage', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.fireEvent(singleAtmState(balance: 50),
          GameEventType.powerOutage);
      expect(s.atms.first.outageSecondsRemaining,
          kPowerOutageDurationSeconds);
      for (var i = 0; i < kPowerOutageDurationSeconds; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.isOperational, isTrue);
      expect(s.atms.first.condition, 1.0);
      expect(s.totalEarned, 0);
    });

    test('plofkraak zonder IBNS: een reparatiecyclus offline, geen kosten',
        () {
      final engine = TickEngine(random: FakeRandom());
      final s = engine.fireEvent(
          singleAtmState(balance: 200), GameEventType.heistAttempt);
      expect(s.atms.first.isBroken, isTrue);
      expect(s.atms.first.repairSecondsRemaining, kRepairDurationSeconds);
      expect(s.balance, 200);
    });

    test('plofkraak met IBNS: afgeslagen en verzekering keert uit', () {
      final engine = TickEngine(random: FakeRandom());
      final state =
          withUpgradeLevel(singleAtmState(balance: 0), UpgradeId.ibns, 2);
      final s = engine.fireEvent(state, GameEventType.heistAttempt);
      expect(s.atms.first.isBroken, isFalse);
      expect(
        s.balance,
        kHeistInsuranceBase + 2 * kHeistInsurancePerIbnsLevel,
      );
    });

    test('de eventtimer vuurt en plant een nieuw interval', () {
      // ints: eventtype 3 (stroomstoring), doelautomaat 0, interval +30.
      final engine = TickEngine(random: FakeRandom(ints: [3, 0, 30]));
      var s = singleAtmState().copyWith(nextEventInSeconds: 1);
      s = engine.tick(s);
      // De storing is gezet en dezelfde tick al 1 seconde afgeteld.
      expect(s.atms.first.outageSecondsRemaining,
          kPowerOutageDurationSeconds - 1);
      expect(s.nextEventInSeconds, kEventIntervalMinSeconds + 30);
    });

    test('een lopend event telt af en verdwijnt', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.fireEvent(singleAtmState(), GameEventType.kingsday);
      for (var i = 0; i < kKingsdayDurationSeconds; i++) {
        s = engine.tick(s);
      }
      expect(s.activeEvent, isNull);
    });
  });
}
