import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/feedback.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/atm.dart';
import 'package:atm_empire/models/cassette.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_random.dart';
import 'helpers/states.dart';

void main() {
  group('Wachtrij en transactiefases (Ontwerper dd 2026-07-04)', () {
    test(
      'de voorste klant doorloopt de vier fases en betaalt bij afronding',
      () {
        // Level 1: kaart (1) + verwerking (4) + shutter (1) + afronding (1).
        // Aanloop-rolls missen (0,999); de resolutie is gescript: 1 biljet,
        // spreiding midden (1,1), Bank Oranje (0,9), geen DCC, geen jam.
        final engine = TickEngine(
          random: FakeRandom(
            doubles: [...arrivalMisses(8), 0.5, 0.0, 0.99, 0.99],
            bools: [false],
          ),
        );
        var s = withQueue(singleAtmState(balance: 0), 1);

        s = engine.tick(s);
        expect(s.atms.first.transaction!.phase, TransactionPhase.cardPresented);
        expect(s.atms.first.queueLength, 0);

        s = engine.tick(s);
        expect(s.atms.first.transaction!.phase, TransactionPhase.processing);

        for (var i = 0; i < 3; i++) {
          s = engine.tick(s);
          expect(s.atms.first.transaction!.phase, TransactionPhase.processing);
        }
        s = engine.tick(s);
        expect(s.atms.first.transaction!.phase, TransactionPhase.shutterAction);

        s = engine.tick(s);
        expect(s.atms.first.transaction!.phase, TransactionPhase.finishing);

        // Tot de afronding is er niets verdiend en niets uitgegeven.
        expect(s.totalEarned, 0);
        expect(s.atms.first.notesInCassette, kCassetteCapacityUnits);

        s = engine.tick(s);
        expect(s.atms.first.transaction, isNull);
        expect(s.totalEarned, closeTo(8.0 * 1.1 * 0.9, 1e-9));
        expect(s.atms.first.notesInCassette, kCassetteCapacityUnits - 1);
        expect(s.atms.first.lifetimeEarned, closeTo(8.0 * 1.1 * 0.9, 1e-9));
      },
    );

    test('een hoger level verwerkt sneller en verdient meer per klant', () {
      // Level 5: kaart (1) + verwerking (1) + shutter (1) + afronding (1).
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(5), 0.5, 0.0, 0.99, 0.99],
          bools: [false],
        ),
      );
      var s = withQueue(singleAtmState(level: 5, balance: 0), 1);
      expect(s.atms.first.totalServiceTicks, 4);
      for (var i = 0; i < 5; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.transaction, isNull);
      // Klanttevredenheid level 5: multiplier 1,75.
      expect(s.totalEarned, closeTo(8.0 * 1.75 * 1.1 * 0.9, 1e-9));
    });

    test('een klant komt aan en stapt meteen naar de vrije automaat', () {
      // Station om 12 uur: aanloopkans 0,40; roll 0,3 raakt.
      final engine = TickEngine(random: FakeRandom(doubles: [0.3]));
      final s = engine.tick(singleAtmState(balance: 0));
      expect(s.atms.first.transaction, isNotNull);
      expect(s.atms.first.queueLength, 0);
    });

    test('bij een volle rij lopen nieuwe klanten ongeduldig door', () {
      // Level 1 lobby: maximaal 3 wachtenden. De aanloop-roll 0,3 raakt;
      // de geduld-roll 0,999 laat de rest netjes staan.
      final engine = TickEngine(random: FakeRandom(doubles: [0.3, 0.999]));
      var s = singleAtmState(queueLength: 3, balance: 0);
      expect(s.atms.first.queueCapacity, 3);
      s = engine.tick(s);
      expect(s.atms.first.lostCustomers, 1);
      // De voorste wachtende is wel gewoon begonnen.
      expect(s.atms.first.transaction, isNotNull);
      expect(s.atms.first.queueLength, 2);
    });

    test('wachtende klanten verliezen hun geduld bij een lange rij', () {
      // Aanloop mist (0,999); na de start staan er nog 2 in de rij en de
      // geduld-roll 0,05 valt onder 2 x 0,06.
      final engine = TickEngine(random: FakeRandom(doubles: [0.999, 0.05]));
      var s = singleAtmState(queueLength: 3, balance: 0);
      s = engine.tick(s);
      expect(s.atms.first.queueLength, 1);
      expect(s.atms.first.lostCustomers, 1);
      expect(s.atms.first.transaction, isNotNull);
    });

    test('wachtrijcapaciteit groeit per level en TTW geeft bonusruimte', () {
      expect(singleAtmState(level: 1).atms.first.queueCapacity, 3);
      expect(singleAtmState(level: 5).atms.first.queueCapacity, 15);
      expect(
        singleAtmState(
          level: 1,
          housing: AtmHousing.ttw,
        ).atms.first.queueCapacity,
        3 + kTtwQueueBonus,
      );
    });

    test('een lobby heeft buiten openingstijden nauwelijks aanloop', () {
      // Station om 3 uur: factor 0,2. Lobby dicht: kans 0,2 x 0,15 x 0,40
      // = 0,012; roll 0,05 mist. TTW: kans 0,08; dezelfde roll raakt.
      final lobby = TickEngine(
        random: FakeRandom(doubles: [0.05]),
      ).tick(singleAtmState(hour: 3, balance: 0));
      expect(lobby.atms.first.transaction, isNull);

      final ttw = TickEngine(
        random: FakeRandom(doubles: [0.05]),
      ).tick(singleAtmState(hour: 3, housing: AtmHousing.ttw, balance: 0));
      expect(ttw.atms.first.transaction, isNotNull);
    });

    test('spreiding gebruikt de grenzen 0,8 en 1,4', () {
      GameState run(double spreadRoll) {
        final engine = TickEngine(
          random: FakeRandom(
            doubles: [...arrivalMisses(8), spreadRoll, 0.0, 0.99, 0.99],
            bools: [false],
          ),
        );
        var s = withQueue(singleAtmState(balance: 0), 1);
        for (var i = 0; i < 8; i++) {
          s = engine.tick(s);
        }
        return s;
      }

      expect(run(0.0).totalEarned, closeTo(8.0 * kIncomeSpreadMin * 0.9, 1e-9));
      expect(run(1.0).totalEarned, closeTo(8.0 * kIncomeSpreadMax * 0.9, 1e-9));
    });

    test('de bank wordt gewogen naar aandeel gekozen', () {
      // Roll 0,99 valt voorbij Oranje (0,5) en Rivier (0,3): Noorderbank
      // met tarief 1,35.
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(8), 0.5, 0.99, 0.99, 0.99],
          bools: [false],
        ),
      );
      var s = withQueue(singleAtmState(balance: 0), 1);
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      expect(s.totalEarned, closeTo(8.0 * 1.1 * 1.35, 1e-9));
    });

    test('onvoldoende voorraad: de klant vangt bot en telt als wegloper', () {
      final engine = TickEngine(
        random: FakeRandom(doubles: arrivalMisses(8), bools: [false]),
      );
      var s = withQueue(singleAtmState(notesInCassette: 0, balance: 0), 1);
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      expect(s.totalEarned, 0);
      expect(s.atms.first.lostCustomers, 1);
      expect(s.atms.first.transaction, isNull);
    });

    test('een klemgelopen biljet zet de actieve cassette in storing', () {
      // Jam-roll 0,005 valt onder de dispenserkans van 0,01 op level 1.
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(8), 0.5, 0.0, 0.99, 0.005],
          bools: [false],
        ),
      );
      var s = withQueue(singleAtmState(balance: 0), 1);
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      // Het inkomen is wel geboekt; daarna liep het biljet klem.
      expect(s.totalEarned, greaterThan(0));
      expect(s.atms.first.hasBrokenCassette, isTrue);
      expect(s.atms.first.repairSecondsRemaining, kRepairDurationSeconds);
    });

    test('op hogere levels loopt er minder vaak iets klem', () {
      // Dezelfde roll 0,005: level 5 dempt de kans naar 0,01 x 0,3 = 0,003.
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(5), 0.5, 0.0, 0.99, 0.005],
          bools: [false],
        ),
      );
      var s = withQueue(singleAtmState(level: 5, balance: 0), 1);
      for (var i = 0; i < 5; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.hasBrokenCassette, isFalse);
    });
  });

  group('DCC (GDD 3.1)', () {
    GameState run({required LocationType location, required double dccRoll}) {
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(8), 0.5, 0.0, dccRoll, 0.99],
          bools: [false],
        ),
      );
      var s = withQueue(singleAtmState(location: location, balance: 0), 1);
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      return s;
    }

    test('toeristische locatie: 14% kans op 4 euro extra', () {
      final s = run(location: LocationType.station, dccRoll: 0.13);
      expect(s.totalEarned, closeTo(8.0 * 1.1 * 0.9 + kDccBonusEur, 1e-9));
    });

    test('normale locatie: dezelfde roll geeft geen DCC', () {
      final s = run(location: LocationType.winkel, dccRoll: 0.13);
      expect(s.totalEarned, closeTo(8.0 * 1.1 * 0.9, 1e-9));
    });

    test('normale locatie: onder 5% wel DCC', () {
      final s = run(location: LocationType.winkel, dccRoll: 0.04);
      expect(s.totalEarned, closeTo(8.0 * 1.1 * 0.9 + kDccBonusEur, 1e-9));
    });
  });

  group('Stortingen op recyclers (Ontwerper dd 2026-07-04)', () {
    test('een storting betaalt de fee en vult de leegste cassette bij', () {
      // Start: aanloop mist (0,999), stortingsbeslissing 0,25 < 0,3.
      // Resolutie: 2 + 2 biljetten (ints [2]), geen jam.
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [0.999, 0.25, ...arrivalMisses(7), 0.99],
          ints: [2],
        ),
      );
      var s = withQueue(
        singleAtmState(
          function: AtmFunction.recycler,
          notesInCassette: 90,
          balance: 0,
        ),
        1,
      );
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.notesInCassette, 94);
      expect(s.totalEarned, closeTo(kRecyclerDepositFee, 1e-9));
      // Acht ticks basisslijtage plus de stortingsslijtage.
      expect(
        s.atms.first.condition,
        closeTo(1 - 8 * kWearPerSecond - kRecyclerWearPerDeposit, 1e-9),
      );
    });

    test('een storting kan de cassettecapaciteit niet overschrijden', () {
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [0.999, 0.25, ...arrivalMisses(7), 0.99],
          ints: [4],
        ),
      );
      var s = withQueue(
        singleAtmState(
          function: AtmFunction.recycler,
          notesInCassette: kCassetteCapacityUnits - 1,
          balance: 0,
        ),
        1,
      );
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits);
    });

    test('een dispenser krijgt nooit stortingen', () {
      // Op een dispenser wordt de stortingsbeslissing niet eens gerold:
      // dezelfde wachtrij levert een opname op.
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(8), 0.5, 0.0, 0.99, 0.99],
          bools: [false],
        ),
      );
      var s = withQueue(singleAtmState(balance: 0), 1);
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits - 1);
    });
  });

  group('Banktarieven (GDD 8)', () {
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

    test('Zuiderbank vereist level Regio en 5.000, en herschaalt aandelen', () {
      final engine = TickEngine(random: FakeRandom());
      final tooEarly = singleAtmState(balance: 10000, totalEarned: 4000);
      expect(
        engine.connectZuiderbank(tooEarly).bank(BankId.zuider).connected,
        isFalse,
      );

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
    test('de staat daalt met 0,004 per seconde op level 1', () {
      final s = TickEngine(random: FakeRandom()).tick(singleAtmState());
      expect(s.atms.first.condition, closeTo(1 - kWearPerSecond, 1e-9));
    });

    test('hogere levels slijten langzamer (betrouwbaarheid)', () {
      final s = TickEngine(random: FakeRandom()).tick(singleAtmState(level: 5));
      expect(
        s.atms.first.condition,
        closeTo(1 - kWearPerSecond * kLevelWearFactor[4], 1e-9),
      );
    });

    test('IBNS vertraagt de slijtage met 12% per level', () {
      var state = singleAtmState();
      state = withUpgradeLevel(state, UpgradeId.ibns, 2);
      final s = TickEngine(random: FakeRandom()).tick(state);
      expect(
        s.atms.first.condition,
        closeTo(
          1 - kWearPerSecond * (1 - 2 * kIbnsWearReductionPerLevel),
          1e-9,
        ),
      );
    });

    test('bij staat nul: uitval, aanrijkosten en monteur uitgestuurd', () {
      final s = TickEngine(
        random: FakeRandom(),
      ).tick(singleAtmState(condition: kWearPerSecond, balance: 100));
      expect(s.atms.first.isBroken, isTrue);
      // De monteur vertrekt dezelfde tick; de aanrijkosten (lobby
      // dispenser level 1: 40) zijn geboekt, plus de float-rente over de
      // onaangeroerde 100 biljetten van 10 euro.
      expect(s.mechanics.single.status, CitVanStatus.transitToAtm);
      expect(s.mechanics.single.targetAtmId, 0);
      const interest = 100 * 10 * kFloatInterestPerSecond;
      expect(s.balance, closeTo(100 - kBreakdownCalloutBase - interest, 1e-9));
    });

    test('TTW en recycler maken de nood-trip duurder; IBNS geeft korting', () {
      var state = singleAtmState(
        housing: AtmHousing.ttw,
        function: AtmFunction.recycler,
        condition: kWearPerSecond,
        balance: 1000,
      );
      state = withUpgradeLevel(state, UpgradeId.ibns, 1);
      // IBNS vertraagt ook de slijtage, dus deze startstaat breekt nog
      // net niet; een fractie lager wel.
      final notYet = TickEngine(random: FakeRandom()).tick(state);
      expect(notYet.atms.first.isBroken, isFalse);

      final breaking = TickEngine(
        random: FakeRandom(),
      ).tick(withFirstCassette(state, condition: 0.0001));
      expect(breaking.atms.first.isBroken, isTrue);
      // (40 + 20 + 20) x levelfactor 1,0 x IBNS-korting 0,92.
      const interest = kCassetteCapacityUnits * 10 * kFloatInterestPerSecond;
      expect(breaking.balance, closeTo(1000 - 80 * 0.92 - interest, 1e-9));
    });

    test('het beveiligingslevel halveert de nood-trip op level 5', () {
      final s = TickEngine(
        random: FakeRandom(),
      ).tick(singleAtmState(level: 5, condition: 0.0001, balance: 100));
      expect(s.atms.first.isBroken, isTrue);
      const interest = kCassetteCapacityUnits * 10 * kFloatInterestPerSecond;
      expect(
        s.balance,
        closeTo(100 - kBreakdownCalloutBase * 0.5 - interest, 1e-9),
      );
    });

    test('aanrijkosten brengen het saldo nooit onder nul', () {
      final s = TickEngine(
        random: FakeRandom(),
      ).tick(singleAtmState(condition: kWearPerSecond, balance: 10));
      expect(s.balance, 0);
      // De nood-trip komt er ook met een lege kas.
      expect(s.mechanics.single.isIdle, isFalse);
    });

    test('een storing wacht op de monteur: aanrijden, repareren, terug', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.tick(
        singleAtmState(condition: kWearPerSecond, balance: 1000),
      );
      expect(s.atms.first.isBroken, isTrue);
      final travel = s.travelTicksTo(LocationType.station);
      expect(s.mechanics.single.ticksRemaining, travel);

      // Aanrijden: de storing blijft zolang gewoon staan.
      for (var i = 0; i < travel; i++) {
        s = engine.tick(s);
        expect(s.atms.first.isBroken, isTrue);
      }
      expect(s.mechanics.single.status, CitVanStatus.servicing);
      expect(s.mechanics.single.ticksRemaining, kRepairDurationSeconds);

      // Repareren ter plaatse.
      for (var i = 0; i < kRepairDurationSeconds; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.isBroken, isFalse);
      // De reparatie landt aan het begin van de tick; dezelfde tick
      // slijt de verse cassette alweer een fractie.
      expect(s.atms.first.condition, closeTo(1 - kWearPerSecond, 1e-9));
      expect(s.mechanics.single.status, CitVanStatus.returning);

      // Terugreis: pas daarna is de monteur weer inzetbaar.
      for (var i = 0; i < travel; i++) {
        s = engine.tick(s);
      }
      expect(s.mechanics.single.isIdle, isTrue);
      expect(s.mechanics.single.targetAtmId, isNull);
    });

    test('met monteur Sven duurt de reparatie ter plaatse 12 seconden', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.tick(
        withStaffHired(
          singleAtmState(condition: kWearPerSecond),
          StaffId.mechanic,
        ),
      );
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel; i++) {
        s = engine.tick(s);
      }
      expect(s.mechanics.single.status, CitVanStatus.servicing);
      expect(s.mechanics.single.ticksRemaining, kRepairDurationMechanicSeconds);
    });

    test('meehelpen kan alleen met de monteur ter plaatse', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.tick(singleAtmState(condition: kWearPerSecond));
      // Onderweg helpt tikken nog niet.
      final enRoute = engine.tapRepair(s, 0);
      expect(
        enRoute.mechanics.single.ticksRemaining,
        s.mechanics.single.ticksRemaining,
      );

      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel; i++) {
        s = engine.tick(s);
      }
      expect(s.mechanics.single.status, CitVanStatus.servicing);
      final before = s.mechanics.single.ticksRemaining;
      s = engine.tapRepair(s, 0);
      expect(
        s.mechanics.single.ticksRemaining,
        before - kRepairTapSpeedupSeconds,
      );

      // Bijna klaar: een tik rondt af en stuurt de monteur terug.
      s = s.withMechanic(s.mechanics.single.copyWith(ticksRemaining: 2));
      s = engine.tapRepair(s, 0);
      expect(s.atms.first.isBroken, isFalse);
      expect(s.atms.first.condition, 1.0);
      expect(s.mechanics.single.status, CitVanStatus.returning);
    });

    test('een tweede storing wacht tot er een monteur vrij is', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(
        nextEventInSeconds: 1000000,
      ).copyWith(balance: 5000, totalEarned: 100000);
      s = engine.buyAtm(s, LocationType.station);
      s = engine.buyAtm(s, LocationType.winkel);
      s = withFirstCassette(s, condition: kWearPerSecond);
      s = s.withAtm(
        s.atms.last.withCassette(
          0,
          s.atms.last.cassettes.first.copyWith(condition: kWearPerSecond),
        ),
      );
      // Beide breken deze tick, maar er is maar een monteur: de tweede
      // storing blijft onbediend liggen.
      s = engine.tick(s);
      expect(s.atms.first.isBroken, isTrue);
      expect(s.atms.last.isBroken, isTrue);
      expect(s.mechanics.single.targetAtmId, 0);
      expect(s.hasMechanicEnRouteTo(1), isFalse);
    });

    test('monteurs aannemen: exponentiele prijs en maximum', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 100000);
      expect(s.nextMechanicPrice, kMechanicBasePrice);
      s = engine.buyMechanic(s);
      expect(s.mechanics.length, 2);
      expect(s.balance, 100000 - kMechanicBasePrice);
      expect(s.nextMechanicPrice, kMechanicBasePrice * kMechanicPriceGrowth);

      for (var i = 0; i < 10; i++) {
        s = s.copyWith(balance: 1000000);
        s = engine.buyMechanic(s);
      }
      expect(s.mechanics.length, kMaxMechanics);
    });

    test('preventief onderhoud is gratis en alleen onder 90% staat', () {
      final engine = TickEngine(random: FakeRandom());
      final worn = singleAtmState(condition: 0.5, balance: 77);
      final maintained = engine.preventiveMaintenance(worn, 0);
      expect(maintained.atms.first.condition, 1.0);
      expect(maintained.balance, 77);

      final fresh = singleAtmState(condition: 0.95);
      expect(engine.preventiveMaintenance(fresh, 0).atms.first.condition, 0.95);
    });
  });

  group('Float-rente (GDD 3.2)', () {
    test('rente loopt over de biljetwaarde per denominatie', () {
      // Slot 1 is een 10 euro-cassette: 100 eenheden x 10 euro.
      final s = TickEngine(
        random: FakeRandom(),
      ).tick(singleAtmState(balance: 100));
      const expected = 100 - 100 * 10 * kFloatInterestPerSecond;
      expect(s.balance, closeTo(expected, 1e-9));
    });

    test('een duurder slot draagt zwaarder mee in de float', () {
      final ten = singleAtmState();
      final engine = TickEngine(random: FakeRandom());
      var withFifty = singleAtmState(balance: 1000);
      withFifty = engine.buyCassette(withFifty, 0);
      withFifty = engine.buyCassette(withFifty.copyWith(balance: 1000), 0);
      // Slots 2 (20) en 3 (50) zijn leeg geleverd: alleen slot 1 telt.
      expect(ten.totalFloatValue, 100 * 10);
      expect(withFifty.totalFloatValue, 100 * 10);
      // Vul slot 3 (50 euro) en de float springt omhoog.
      final filled = withFifty.withAtm(
        withFifty.atms.first.withCassette(
          2,
          withFifty.atms.first.cassettes[2].copyWith(notes: 10),
        ),
      );
      expect(filled.totalFloatValue, 100 * 10 + 10 * 50);
    });

    test('float-rente kan het saldo nooit negatief maken', () {
      final s = TickEngine(
        random: FakeRandom(),
      ).tick(singleAtmState(balance: 0.01));
      expect(s.balance, 0);
    });
  });

  group('Events (GDD 6)', () {
    test('Koningsdag verdubbelt de aanloop van alle automaten', () {
      // Zonder event mist roll 0,5 (kans 0,40); met Koningsdag is de
      // kans 2 x 0,40 = 0,80 en raakt dezelfde roll.
      var s = singleAtmState(balance: 0);
      expect(
        TickEngine(
          random: FakeRandom(doubles: [0.5]),
        ).tick(s).atms.first.transaction,
        isNull,
      );
      final engine = TickEngine(random: FakeRandom(doubles: [0.5]));
      s = engine.fireEvent(s, GameEventType.kingsday);
      expect(s.activeEvent!.type, GameEventType.kingsday);
      final after = engine.tick(s);
      expect(after.atms.first.transaction, isNotNull);
    });

    test('festival verdrievoudigt alleen de doellocatie', () {
      final engine = TickEngine(random: FakeRandom(ints: [0]));
      var s = singleAtmState(hour: 3, housing: AtmHousing.ttw, balance: 0);
      s = engine.fireEvent(s, GameEventType.festival);
      expect(s.activeEvent!.targetAtmId, 0);
      // Station om 3 uur: factor 0,2 x 3 = 0,6; aanloopkans 0,24 en roll
      // 0,22 raakt nu wel.
      final hit = TickEngine(random: FakeRandom(doubles: [0.22])).tick(s);
      expect(hit.atms.first.transaction, isNotNull);
    });

    test('festival zonder toeristische locatie doet niets', () {
      final engine = TickEngine(random: FakeRandom());
      final s = engine.fireEvent(
        singleAtmState(location: LocationType.winkel),
        GameEventType.festival,
      );
      expect(s.activeEvent, isNull);
    });

    test('stroomstoring pauzeert 20 seconden en de rij loopt weg', () {
      final engine = TickEngine(random: FakeRandom());
      var s = engine.fireEvent(
        singleAtmState(balance: 50, queueLength: 2),
        GameEventType.powerOutage,
      );
      expect(s.atms.first.outageSecondsRemaining, kPowerOutageDurationSeconds);
      expect(s.atms.first.queueLength, 0);
      for (var i = 0; i < kPowerOutageDurationSeconds; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.isOperational, isTrue);
      expect(s.atms.first.condition, 1.0);
      expect(s.totalEarned, 0);
    });

    test('plofkraak zonder IBNS op level 1: hele automaat offline', () {
      // Level 1 heeft blokkeerkans 0: de default-roll slaat niets af.
      final engine = TickEngine(random: FakeRandom());
      final s = engine.fireEvent(
        singleAtmState(balance: 200),
        GameEventType.heistAttempt,
      );
      expect(s.atms.first.isBroken, isTrue);
      expect(s.atms.first.repairSecondsRemaining, kRepairDurationSeconds);
      expect(s.balance, 200);
    });

    test('level 5 beveiliging slaat een plofkraak zelf af', () {
      // Blokkeerkans op level 5 is 0,6; roll 0,5 wordt afgeslagen, zonder
      // verzekeringsuitkering.
      final engine = TickEngine(random: FakeRandom(doubles: [0.5]));
      final s = engine.fireEvent(
        singleAtmState(level: 5, balance: 200),
        GameEventType.heistAttempt,
      );
      expect(s.atms.first.isBroken, isFalse);
      expect(s.balance, 200);
    });

    test('een lobby is buiten openingstijden kwetsbaarder', () {
      // Zelfde level 5 en dezelfde roll 0,5, maar om 23 uur is de
      // blokkeerkans gehalveerd (0,3): de aanval slaagt.
      final engine = TickEngine(random: FakeRandom(doubles: [0.5]));
      final s = engine.fireEvent(
        singleAtmState(level: 5, hour: 23, balance: 200),
        GameEventType.heistAttempt,
      );
      expect(s.atms.first.isBroken, isTrue);
    });

    test('plofkraak met IBNS: afgeslagen en verzekering keert uit', () {
      final engine = TickEngine(random: FakeRandom());
      final state = withUpgradeLevel(
        singleAtmState(balance: 0),
        UpgradeId.ibns,
        2,
      );
      final s = engine.fireEvent(state, GameEventType.heistAttempt);
      expect(s.atms.first.isBroken, isFalse);
      expect(s.balance, kHeistInsuranceBase + 2 * kHeistInsurancePerIbnsLevel);
    });

    test('de eventtimer vuurt en plant een nieuw interval', () {
      // ints: eventtype 3 (stroomstoring), doelautomaat 0, interval +30.
      final engine = TickEngine(random: FakeRandom(ints: [3, 0, 30]));
      var s = singleAtmState().copyWith(nextEventInSeconds: 1);
      s = engine.tick(s);
      // De storing is gezet en dezelfde tick al 1 seconde afgeteld.
      expect(
        s.atms.first.outageSecondsRemaining,
        kPowerOutageDurationSeconds - 1,
      );
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

  group('Multi-cassette (Ontwerper dd 2026-07-04)', () {
    /// Staat met een automaat met twee cassettes.
    GameState twoCassetteState({
      Cassette first = const Cassette.full(),
      Cassette second = const Cassette.full(),
      double balance = 1000,
      int queueLength = 0,
    }) {
      final s = singleAtmState(balance: balance, queueLength: queueLength);
      return s.withAtm(s.atms.first.copyWith(cassettes: [first, second]));
    }

    test('een extra cassette kopen: leeg geleverd, vaste prijs, max 5', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: kExtraCassettePrice + 100);
      s = engine.buyCassette(s, 0);
      expect(s.atms.first.cassettes.length, 2);
      expect(s.atms.first.cassettes.last.notes, 0);
      expect(s.atms.first.cassettes.last.condition, 1.0);
      expect(s.balance, 100);
      expect(s.atms.first.capacity, 2 * kCassetteCapacityUnits);

      // Zonder saldo geen aankoop.
      expect(engine.buyCassette(s, 0).atms.first.cassettes.length, 2);

      // Nooit meer dan het maximum aantal slots.
      s = s.copyWith(balance: 100000);
      for (var i = 0; i < 10; i++) {
        s = engine.buyCassette(s, 0);
      }
      expect(s.atms.first.cassettes.length, kMaxCassettesPerAtm);
    });

    test('alleen de actieve (volste) cassette slijt', () {
      final engine = TickEngine(random: FakeRandom());
      final s = engine.tick(
        twoCassetteState(
          first: const Cassette(notes: 40, condition: 1.0),
          second: const Cassette(notes: 80, condition: 1.0),
        ),
      );
      final cassettes = s.atms.first.cassettes;
      expect(cassettes[0].condition, 1.0);
      expect(cassettes[1].condition, closeTo(1 - kWearPerSecond, 1e-9));
    });

    test('opnames trekken uit de volste cassette', () {
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(8), 0.5, 0.0, 0.99, 0.99],
          bools: [false],
        ),
      );
      var s = twoCassetteState(
        first: const Cassette(notes: 40, condition: 1.0),
        second: const Cassette(notes: 80, condition: 1.0),
        queueLength: 1,
      );
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.cassettes[0].notes, 40);
      expect(s.atms.first.cassettes[1].notes, 79);
    });

    test('een kapotte cassette halveert de aanloop van twee slots', () {
      // Station om 12 uur: kans 0,40; met 1 van 2 cassettes werkend is
      // dat 0,20. Roll 0,3 mist dan, terwijl hij zonder storing raakt.
      const broken = Cassette(
        notes: 50,
        condition: 0.5,
        repairSecondsRemaining: 1000,
      );
      final miss = TickEngine(
        random: FakeRandom(doubles: [0.3]),
      ).tick(twoCassetteState(first: broken, balance: 0));
      expect(miss.atms.first.transaction, isNull);

      final hit = TickEngine(
        random: FakeRandom(doubles: [0.15]),
      ).tick(twoCassetteState(first: broken, balance: 0));
      expect(hit.atms.first.transaction, isNotNull);
    });

    test('kapotte cassettes tellen niet mee als voorraad', () {
      final s = twoCassetteState(
        first: const Cassette(
          notes: 70,
          condition: 0.5,
          repairSecondsRemaining: 10,
        ),
        second: const Cassette(notes: 30, condition: 1.0),
      );
      final atm = s.atms.first;
      expect(atm.availableNotes, 30);
      expect(atm.totalNotes, 100);
      expect(atm.isBroken, isFalse);
      expect(atm.hasBrokenCassette, isTrue);
      expect(atm.workingFraction, 0.5);
    });

    test('breekt een cassette, dan draait de rest door', () {
      // De actieve (volste) cassette staat op bijna nul en breekt deze
      // tick; de andere blijft werken en de automaat is niet volledig
      // stuk.
      final engine = TickEngine(random: FakeRandom());
      final s = engine.tick(
        twoCassetteState(
          first: const Cassette(notes: 90, condition: kWearPerSecond),
          second: const Cassette(notes: 50, condition: 1.0),
          balance: 100,
        ),
      );
      final atm = s.atms.first;
      expect(atm.cassettes[0].isBroken, isTrue);
      expect(atm.cassettes[1].isBroken, isFalse);
      expect(atm.isBroken, isFalse);
      expect(atm.isOperational, isTrue);
      // Voorrijkosten zijn wel in rekening gebracht.
      expect(s.balance, lessThan(100));
    });

    test('volledig kapot: storingen wachten en de monteur repareert alles', () {
      final engine = TickEngine(random: FakeRandom());
      var s = twoCassetteState(
        first: const Cassette(
          notes: 10,
          condition: 0,
          repairSecondsRemaining: 30,
        ),
        second: const Cassette(
          notes: 10,
          condition: 0,
          repairSecondsRemaining: 30,
        ),
      );
      expect(s.atms.first.isBroken, isTrue);
      // Zonder monteur ter plaatse verandert er niets aan de storing.
      s = engine.tick(s);
      expect(s.atms.first.cassettes[0].isBroken, isTrue);
      expect(s.atms.first.cassettes[1].isBroken, isTrue);
      expect(s.mechanics.single.status, CitVanStatus.transitToAtm);

      // Monteur laten aankomen en de klus laten afronden: een bezoek
      // repareert alle cassettes, met behoud van inhoud.
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel + kRepairDurationSeconds; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.isBroken, isFalse);
      // De reparatie landt aan het begin van de tick; dezelfde tick slijt
      // de actieve (eerste) cassette alweer een fractie.
      expect(
        s.atms.first.cassettes[0].condition,
        closeTo(1 - kWearPerSecond, 1e-9),
      );
      expect(s.atms.first.cassettes[1].condition, 1.0);
      expect(s.atms.first.cassettes[0].notes, 10);
      expect(s.atms.first.cassettes[1].notes, 10);
    });

    test('preventief onderhoud herstelt alleen de werkende cassettes', () {
      final engine = TickEngine(random: FakeRandom());
      final s = engine.preventiveMaintenance(
        twoCassetteState(
          first: const Cassette(notes: 10, condition: 0.5),
          second: const Cassette(
            notes: 10,
            condition: 0.2,
            repairSecondsRemaining: 9,
          ),
        ),
        0,
      );
      expect(s.atms.first.cassettes[0].condition, 1.0);
      expect(s.atms.first.cassettes[1].condition, 0.2);
      expect(s.atms.first.cassettes[1].isBroken, isTrue);
    });
  });

  group('CIT-vloot (Ontwerper dd 2026-07-04)', () {
    test('servicing doorloopt heenreis, vullen en terugreis', () {
      final engine = TickEngine(random: FakeRandom());
      // Station ligt in de stad-zone: 25 ticks enkele reis.
      var s = singleAtmState(notesInCassette: 3, condition: 0.4);
      final travel = s.travelTicksTo(LocationType.station);
      expect(travel, kZoneTravelTicks[MapZone.stad]);

      s = engine.requestService(s, 0);
      expect(s.balance, 1000 - kCitCostPerTrip);
      expect(s.citVans.single.status, CitVanStatus.transitToAtm);
      expect(s.citVans.single.targetAtmId, 0);
      expect(s.citVans.single.ticksRemaining, travel);

      // Heenreis: na [travel] ticks staat de wagen er en begint het vullen.
      for (var i = 0; i < travel; i++) {
        s = engine.tick(s);
      }
      expect(s.citVans.single.status, CitVanStatus.servicing);
      expect(s.citVans.single.ticksRemaining, kServicingDurationTicks);
      // Nog niet gevuld.
      expect(s.atms.first.notesInCassette, 3);

      // Vullen: na 3 ticks zijn alle cassettes vol en gerepareerd. De
      // servicing landt aan het begin van de tick, dus dezelfde tick
      // slijt de verse cassette alweer een fractie.
      for (var i = 0; i < kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits);
      expect(s.atms.first.condition, closeTo(1 - kWearPerSecond, 1e-9));
      expect(s.refillGoalProgress, 1);
      expect(s.citVans.single.status, CitVanStatus.returning);

      // Terugreis: pas daarna is de wagen weer inzetbaar.
      for (var i = 0; i < travel - 1; i++) {
        s = engine.tick(s);
        expect(s.citVans.single.isIdle, isFalse);
      }
      s = engine.tick(s);
      expect(s.citVans.single.isIdle, isTrue);
      expect(s.citVans.single.targetAtmId, isNull);
    });

    test('servicing repareert ook een cassette in storing', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(
        notesInCassette: 0,
        condition: 0,
        repairSecondsRemaining: 1000,
      );
      s = engine.requestService(s, 0);
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel + kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.isBroken, isFalse);
      expect(s.atms.first.condition, closeTo(1 - kWearPerSecond, 1e-9));
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits);
    });

    test('is de hele vloot onderweg, dan kan er niet geserviced worden', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(
        nextEventInSeconds: 1000000,
      ).copyWith(balance: 5000, totalEarned: 100000);
      s = engine.buyAtm(s, LocationType.station);
      s = engine.buyAtm(s, LocationType.winkel);
      s = withFirstCassette(s, notes: 0);
      s = s.withAtm(
        s.atms.last.withCassette(
          0,
          s.atms.last.cassettes.first.copyWith(notes: 0),
        ),
      );

      s = engine.requestService(s, 0);
      expect(s.citVans.single.isIdle, isFalse);
      final balanceAfterFirst = s.balance;

      // De enige wagen is weg: het tweede verzoek doet niets.
      final refused = engine.requestService(s, 1);
      expect(refused.balance, balanceAfterFirst);
      expect(refused.citVans.single.targetAtmId, 0);
    });

    test('naar een automaat waar al een wagen heen rijdt gaat geen tweede', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 0, balance: 10000);
      s = engine.buyCitVan(s);
      s = engine.requestService(s, 0);
      final after = engine.requestService(s, 0);
      expect(after.balance, s.balance);
      expect(after.citVans.where((v) => !v.isIdle).length, 1);
    });

    test('een volle automaat in nieuwstaat heeft geen servicing nodig', () {
      final engine = TickEngine(random: FakeRandom());
      final s = singleAtmState(balance: 1000);
      final after = engine.requestService(s, 0);
      expect(after.balance, 1000);
      expect(after.citVans.single.isIdle, isTrue);
    });

    test('geldwagens kopen: exponentiele prijs en maximaal 5', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 100000);
      expect(s.nextCitVanPrice, kCitVanBasePrice);
      s = engine.buyCitVan(s);
      expect(s.citVans.length, 2);
      expect(s.balance, 100000 - kCitVanBasePrice);
      expect(s.nextCitVanPrice, kCitVanBasePrice * kCitVanPriceGrowth);

      for (var i = 0; i < 10; i++) {
        s = s.copyWith(balance: 1000000);
        s = engine.buyCitVan(s);
      }
      expect(s.citVans.length, kMaxCitVans);
    });

    test('CIT-route verkort ook de reistijd met 15% per level', () {
      var s = singleAtmState();
      expect(
        s.travelTicksTo(LocationType.snelweg),
        kZoneTravelTicks[MapZone.landelijk],
      );
      s = withUpgradeLevel(s, UpgradeId.citRoute, 2);
      // 60 x 0,7 = 42; station: 25 x 0,7 = 17,5 rondt naar 18.
      expect(s.travelTicksTo(LocationType.snelweg), 42);
      expect(s.travelTicksTo(LocationType.station), 18);
    });
  });

  group('Spreidingswet (Ontwerper dd 2026-07-04)', () {
    GameState buyMany(
      TickEngine engine,
      GameState s,
      List<LocationType> locations,
    ) {
      for (final location in locations) {
        s = engine.buyAtm(s, location);
      }
      return s;
    }

    test('vier automaten in een zone blokkeren de vijfde daar', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(
        nextEventInSeconds: 1000000,
      ).copyWith(balance: 1000000, totalEarned: 100000);
      expect(s.spreadApproval, 1.0);
      // Vier stuks in de stad-zone (station, winkelcentrum, horeca).
      s = buyMany(engine, s, [
        LocationType.station,
        LocationType.winkelcentrum,
        LocationType.horeca,
        LocationType.station,
      ]);
      expect(s.zoneCount(MapZone.stad), 4);
      expect(s.isZoneBlocked(MapZone.stad), isTrue);
      expect(s.spreadApproval, 0.0);

      // De Nationale Bank weigert de vergunning: geen aankoop, geen kosten.
      final refused = engine.buyAtm(s, LocationType.horeca);
      expect(refused.atms.length, 4);
      expect(refused.balance, s.balance);

      // Andere zones blijven gewoon open.
      final elsewhere = engine.buyAtm(s, LocationType.winkel);
      expect(elsewhere.atms.length, 5);
    });

    test('landelijke dekking heft de blokkade op', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(
        nextEventInSeconds: 1000000,
      ).copyWith(balance: 10000000, totalEarned: 100000);
      s = buyMany(engine, s, [
        LocationType.station,
        LocationType.winkelcentrum,
        LocationType.horeca,
        LocationType.station,
      ]);
      expect(s.isZoneBlocked(MapZone.stad), isTrue);

      // Een automaat in het dorp alleen is niet genoeg: regio en
      // landelijk zijn nog leeg.
      s = engine.buyAtm(s, LocationType.winkel);
      expect(s.isZoneBlocked(MapZone.stad), isTrue);

      // Pas met dekking in elke zone mag de stad weer groeien.
      s = buyMany(engine, s, [LocationType.evenement, LocationType.snelweg]);
      expect(s.minZoneCount, 1);
      expect(s.isZoneBlocked(MapZone.stad), isFalse);
      expect(s.spreadApproval, closeTo(0.25, 1e-9));
      s = engine.buyAtm(s, LocationType.horeca);
      expect(s.zoneCount(MapZone.stad), 5);
      // En op vijf tegen minimaal een is hij meteen weer op slot.
      expect(s.isZoneBlocked(MapZone.stad), isTrue);
    });

    test('elke locatiesoort heeft een zone en kaartpositie', () {
      for (final location in LocationType.values) {
        expect(kLocationZone[location], isNotNull);
        expect(kLocationMapPoints[location], isNotNull);
        expect(kZoneTravelTicks[kLocationZone[location]!], isNotNull);
      }
    });
  });

  group('Modulaire aankoop (Ontwerper dd 2026-07-04)', () {
    test('behuizing en functionaliteit bepalen de meerprijs', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(
        nextEventInSeconds: 1000000,
      ).copyWith(balance: 10000, totalEarned: 100000);
      expect(s.nextAtmPrice, 400);
      s = engine.buyAtm(
        s,
        LocationType.station,
        housing: AtmHousing.ttw,
        function: AtmFunction.recycler,
      );
      expect(s.atms.length, 1);
      expect(
        s.balance,
        10000 - 400 - kTtwHousingPremium - kRecyclerFunctionPremium,
      );
      final atm = s.atms.single;
      expect(atm.housing, AtmHousing.ttw);
      expect(atm.function, AtmFunction.recycler);
      expect(atm.level, 1);
      expect(atm.cassettes.single.notes, kCassetteCapacityUnits);
    });

    test('onvoldoende saldo voor de configuratie: geen aankoop', () {
      final engine = TickEngine(random: FakeRandom());
      final s = GameState.initial(
        nextEventInSeconds: 1000000,
      ).copyWith(balance: 500);
      // Basis (400) past, maar TTW recycler (800) niet.
      final refused = engine.buyAtm(
        s,
        LocationType.station,
        housing: AtmHousing.ttw,
        function: AtmFunction.recycler,
      );
      expect(refused.atms, isEmpty);
      expect(refused.balance, 500);
    });

    test('levelupgrades volgen de kostentabel tot het maximum', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 42, balance: 400);
      expect(s.atms.first.nextLevelCost, kLevelUpgradeCost[0]);
      s = engine.upgradeAtm(s, 0);
      expect(s.atms.first.level, 2);
      expect(s.balance, 50);
      // De cassette-inhoud blijft staan.
      expect(s.atms.first.notesInCassette, 42);
      // Volgende stap kost 840: onvoldoende saldo, geen wijziging.
      expect(engine.upgradeAtm(s, 0).atms.first.level, 2);

      // Tot en met level 5; daarna is er geen upgrade meer.
      s = s.copyWith(balance: 1000000);
      for (var i = 0; i < 10; i++) {
        s = engine.upgradeAtm(s, 0);
      }
      expect(s.atms.first.level, Atm.kMaxAtmLevel);
      expect(s.atms.first.nextLevelCost, isNull);
    });
  });

  group('Cassette-denominaties (Ontwerper dd 2026-07-06)', () {
    test('slots volgen de vaste configuratie 10/20/50/50/50', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 10000);
      expect(s.atms.first.cassettes.single.denomination, 10);
      for (var i = 0; i < 4; i++) {
        s = engine.buyCassette(s, 0);
      }
      expect([
        for (final c in s.atms.first.cassettes) c.denomination,
      ], kCassetteDenominations);
    });

    test('na prestige wordt het vijfde slot een 100 euro-cassette', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 10000).copyWith(prestigeLevel: 1);
      expect(s.hundredEuroNoteActive, isTrue);
      for (var i = 0; i < 4; i++) {
        s = engine.buyCassette(s, 0);
      }
      expect(
        [for (final c in s.atms.first.cassettes) c.denomination],
        [10, 20, 50, 50, kPrestigeFifthSlotDenomination],
      );
    });

    test('CIT-servicing behoudt de denominatie per slot', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 10000);
      s = engine.buyCassette(s, 0);
      s = withFirstCassette(s, notes: 0, condition: 0.3);
      s = engine.requestService(s, 0);
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel + kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      expect(
        [for (final c in s.atms.first.cassettes) c.denomination],
        [10, 20],
      );
      expect(s.atms.first.cassettes[1].notes, kCassetteCapacityUnits);
    });
  });

  group('CiT & Monteurs tabbladen (Ontwerper dd 2026-07-06)', () {
    test('een onbeveiligde wagen kan onderweg overvallen worden', () {
      final events = <GameFeedback>[];
      // De automaat staat volledig in storing (geen aanloop-rolls) en de
      // monteursploeg is leeg, zodat alleen de overval-roll van de
      // heenreis doubles consumeert: tick 1 mist (0,999), tick 2 raak.
      final engine = TickEngine(random: FakeRandom(doubles: [0.999, 0.0005]))
        ..onFeedback = events.add;
      var s = singleAtmState(
        notesInCassette: 0,
        repairSecondsRemaining: 1000,
      ).copyWith(mechanics: const []);
      s = engine.requestService(s, 0);
      expect(s.balance, 1000 - kCitCostPerTrip);

      s = engine.tick(s);
      expect(s.citVans.single.status, CitVanStatus.transitToAtm);

      s = engine.tick(s);
      expect(s.citVans.single.status, CitVanStatus.returning);
      expect(s.balance, 1000 - kCitCostPerTrip - kCitRobberyLoss);
      expect(events.where((e) => e.type == FeedbackType.robbery).length, 1);

      // De terugweg is de afgelegde afstand (1 tick); de rit heeft niets
      // opgeleverd: de automaat blijft leeg en in storing.
      s = engine.tick(s);
      expect(s.citVans.single.isIdle, isTrue);
      expect(s.citVans.single.targetAtmId, isNull);
      expect(s.atms.first.isBroken, isTrue);
      expect(s.atms.first.notesInCassette, 0);
      expect(s.refillGoalProgress, 0);
    });

    test('het gepantserd chassis sluit overvallen volledig uit', () {
      final events = <GameFeedback>[];
      // Dezelfde rake rolls als hierboven: met pantser wordt er niet
      // eens gerold, dus de rit loopt gewoon af.
      final engine = TickEngine(random: FakeRandom(doubles: [0.0, 0.0]))
        ..onFeedback = events.add;
      var s = withUpgradeLevel(
        singleAtmState(notesInCassette: 0, repairSecondsRemaining: 1000),
        UpgradeId.armoredChassis,
        1,
      ).copyWith(mechanics: const []);
      s = engine.requestService(s, 0);
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel + kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      expect(events.where((e) => e.type == FeedbackType.robbery), isEmpty);
      expect(s.atms.first.isBroken, isFalse);
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits);
      expect(s.citVans.single.status, CitVanStatus.returning);
    });

    test('de High-Capacity Kluis laat een wagen doorrijden naar de volgende '
        'lege automaat', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(nextEventInSeconds: 1000000).copyWith(
        balance: 5000,
        totalEarned: 100000,
        milestonesClaimed: claimedMilestonesFor(100000),
      );
      s = engine.buyAtm(s, LocationType.station);
      s = engine.buyAtm(s, LocationType.winkel);
      s = withFirstCassette(s, notes: 0);
      s = s.withAtm(
        s.atms.last.withCassette(
          0,
          s.atms.last.cassettes.first.copyWith(notes: 0),
        ),
      );
      s = withUpgradeLevel(s, UpgradeId.vaultCapacity, 1);

      final balanceBefore = s.balance;
      s = engine.requestService(s, 0);
      // Een rit, een keer het rittarief, met een extra stop in de kluis.
      expect(s.balance, closeTo(balanceBefore - s.citTripCost, 1e-9));
      expect(s.citVans.single.stopsRemaining, 1);

      final travelA = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travelA + kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      // Eerste stop bediend; de wagen rijdt direct door naar de tweede.
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits);
      expect(s.citVans.single.status, CitVanStatus.transitToAtm);
      expect(s.citVans.single.targetAtmId, 1);
      expect(s.citVans.single.stopsRemaining, 0);
      expect(s.refillGoalProgress, 1);

      final travelB = s.travelTicksTo(LocationType.winkel);
      for (var i = 0; i < travelB + kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.last.notesInCassette, kCassetteCapacityUnits);
      expect(s.citVans.single.status, CitVanStatus.returning);
      expect(s.refillGoalProgress, 2);
    });

    test('zonder kluis-upgrade rijdt de wagen na een stop terug', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(nextEventInSeconds: 1000000).copyWith(
        balance: 5000,
        totalEarned: 100000,
        milestonesClaimed: claimedMilestonesFor(100000),
      );
      s = engine.buyAtm(s, LocationType.station);
      s = engine.buyAtm(s, LocationType.winkel);
      s = withFirstCassette(s, notes: 0);
      s = s.withAtm(
        s.atms.last.withCassette(
          0,
          s.atms.last.cassettes.first.copyWith(notes: 0),
        ),
      );
      s = engine.requestService(s, 0);
      expect(s.citVans.single.stopsRemaining, 0);
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel + kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      expect(s.citVans.single.status, CitVanStatus.returning);
      expect(s.atms.last.notesInCassette, 0);
    });

    test('gereedschap & diagnose-software verkort de reparatietijd', () {
      var s = singleAtmState();
      expect(s.repairDurationSeconds, kRepairDurationSeconds);
      s = withUpgradeLevel(s, UpgradeId.toolkit, kToolkitMaxLevel);
      expect(
        s.repairDurationSeconds,
        (kRepairDurationSeconds *
                (1 - kToolkitReductionPerLevel * kToolkitMaxLevel))
            .round(),
      );
      // Stapelt met monteur Sven; afgerond en nooit onder 1 seconde.
      s = withStaffHired(s, StaffId.mechanic);
      expect(
        s.repairDurationSeconds,
        (kRepairDurationMechanicSeconds *
                (1 - kToolkitReductionPerLevel * kToolkitMaxLevel))
            .round(),
      );
    });

    test('het onderdelenmagazijn stuurt monteurs preventief uit, zonder '
        'voorrijkosten', () {
      final engine = TickEngine(random: FakeRandom());
      var s = withUpgradeLevel(
        singleAtmState(notesInCassette: 0, condition: 0.5),
        UpgradeId.partsDepot,
        1,
      );
      s = engine.tick(s);
      expect(s.mechanics.single.status, CitVanStatus.transitToAtm);
      expect(s.mechanics.single.targetAtmId, 0);
      // Preventief is regulier onderhoud: geen nood-tarief.
      expect(s.balance, 1000);

      // Ter plaatse pleegt de monteur het volledige onderhoud.
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel + s.repairDurationSeconds; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.condition, closeTo(1 - kWearPerSecond, 1e-9));
      expect(s.mechanics.single.status, CitVanStatus.returning);
    });

    test('zonder onderdelenmagazijn blijft de monteur bij het depot', () {
      final engine = TickEngine(random: FakeRandom());
      final s = engine.tick(singleAtmState(notesInCassette: 0, condition: 0.5));
      expect(s.mechanics.single.isIdle, isTrue);
    });

    test('de storings-analist meldt verhoogd risico precies een keer per '
        'passage', () {
      final events = <GameFeedback>[];
      final engine = TickEngine(random: FakeRandom())..onFeedback = events.add;
      var s = withStaffHired(
        singleAtmState(
          notesInCassette: 0,
          condition: kJamRiskConditionThreshold + kWearPerSecond / 2,
        ),
        StaffId.reliabilityAnalyst,
      );
      s = engine.tick(s);
      final alerts = events.where((e) => e.type == FeedbackType.jamRisk);
      expect(alerts.length, 1);
      expect(alerts.single.atmId, 0);
      // Onder de drempel blijft het stil: een melding per passage.
      s = engine.tick(s);
      s = engine.tick(s);
      expect(events.where((e) => e.type == FeedbackType.jamRisk).length, 1);
    });

    test('zonder storings-analist geen risicomelding', () {
      final events = <GameFeedback>[];
      final engine = TickEngine(random: FakeRandom())..onFeedback = events.add;
      engine.tick(
        singleAtmState(
          notesInCassette: 0,
          condition: kJamRiskConditionThreshold + kWearPerSecond / 2,
        ),
      );
      expect(events.where((e) => e.type == FeedbackType.jamRisk), isEmpty);
    });

    test('handmatige dispatch stuurt een vrije monteur met voorrijkosten', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 0, repairSecondsRemaining: 1000);
      final callout = s.atms.first.calloutCost;
      s = engine.sendMechanic(s, 0);
      expect(s.mechanics.single.status, CitVanStatus.transitToAtm);
      expect(s.mechanics.single.targetAtmId, 0);
      expect(
        s.mechanics.single.ticksRemaining,
        s.travelTicksTo(LocationType.station),
      );
      expect(s.balance, 1000 - callout);

      // Nogmaals sturen doet niets: er is al iemand onderweg.
      final again = engine.sendMechanic(s, 0);
      expect(again.balance, s.balance);

      // Naar een gezonde automaat vertrekt niemand.
      final unchanged = engine.sendMechanic(singleAtmState(), 0);
      expect(unchanged.mechanics.single.isIdle, isTrue);
      expect(unchanged.balance, 1000);
    });
  });
}
