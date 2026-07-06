import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/atm.dart';
import 'package:atm_empire/models/cassette.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_random.dart';
import 'helpers/states.dart';

/// Laat een gescripte opname volledig doorlopen: klant in de rij, acht
/// ticks fases, resolutie met spreiding midden (1,1), Bank Oranje (0,9),
/// geen DCC en geen jam. Inkomen: 8 x 1,1 x 0,9 = 7,92 op level 1.
GameState runWithdrawal(GameState s) {
  final total = s.atms.first.totalServiceTicks;
  final engine = TickEngine(
    random: FakeRandom(
      doubles: [...arrivalMisses(total + 1), 0.5, 0.0, 0.99, 0.99],
      bools: [false],
    ),
  );
  s = withQueue(s, 1);
  for (var i = 0; i <= total; i++) {
    s = engine.tick(s);
  }
  return s;
}

void main() {
  group('Mijlpalen (GDD 9.2)', () {
    test('het passeren van 750 totaal keert 150 uit', () {
      // Een opname van 7,92 duwt het totaal over de eerste drempel.
      final s = runWithdrawal(singleAtmState(balance: 0, totalEarned: 749));
      expect(s.milestonesClaimed, 1);
      expect(s.totalEarned, closeTo(749 + 7.92 + 150, 1e-9));
      // Saldo: inkomen plus bonus minus de float-rente van acht ticks.
      expect(s.balance, closeTo(7.92 + 150, 0.5));
    });

    test('mijlpaalbonussen kunnen doorcascaderen', () {
      // Op 1.996 duwt een opname het totaal over 2.000; de bonus van
      // 300 blijft onder 4.000, dus precies een extra mijlpaal.
      final before = singleAtmState(balance: 0, totalEarned: 1996);
      expect(before.milestonesClaimed, 1);
      final s = runWithdrawal(before);
      expect(s.milestonesClaimed, 2);
      expect(s.totalEarned, closeTo(1996 + 7.92 + 300, 1e-9));
    });

    test('levels volgen de totaal-verdiend-drempels', () {
      expect(singleAtmState(totalEarned: 0).playerLevel, PlayerLevel.dorp);
      expect(singleAtmState(totalEarned: 1999).playerLevel, PlayerLevel.dorp);
      expect(singleAtmState(totalEarned: 2000).playerLevel, PlayerLevel.stad);
      expect(singleAtmState(totalEarned: 8000).playerLevel, PlayerLevel.regio);
      expect(
        singleAtmState(totalEarned: 25000).playerLevel,
        PlayerLevel.landelijk,
      );
      expect(singleAtmState(totalEarned: 2000).locationSlots, 6);
    });
  });

  group('Bijvuldoel (GDD 9.2, via de CIT-vloot)', () {
    /// Stuurt een wagen en tikt door tot de servicing is toegepast; de
    /// cassette gaat daarna meteen weer leeg zodat de volgende ronde kan
    /// (en er nauwelijks float-rente over volle cassettes loopt).
    GameState completeService(TickEngine engine, GameState s) {
      s = engine.requestService(s, 0);
      final before = s.refillGoalRound * 1000 + s.refillGoalProgress;
      while (s.refillGoalRound * 1000 + s.refillGoalProgress == before) {
        s = engine.tick(s);
      }
      s = withFirstCassette(s, notes: 0);
      // Wagen terug laten keren zodat hij weer inzetbaar is.
      while (s.citVans.any((v) => !v.isIdle)) {
        s = engine.tick(s);
      }
      return s;
    }

    test('drie afgeronde servicing-ritten ronden de eerste ronde af', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 0, balance: 1000);
      for (var i = 0; i < 3; i++) {
        s = completeService(engine, s);
      }
      expect(s.refillGoalRound, 1);
      expect(s.refillGoalProgress, 0);
      expect(s.refillGoalTarget, 4);
      expect(
        s.refillGoalReward,
        closeTo(kRefillGoalBaseReward * kRefillGoalRewardGrowth, 1e-9),
      );
      // Saldo: 1000 - 3 ritten van 60 + beloning 75, minus een restje
      // float-rente over de korte momenten met een volle cassette.
      expect(s.balance, closeTo(1000 - 3 * kCitCostPerTrip + 75, 0.5));
      expect(s.totalEarned, 75);
    });

    test('N groeit per ronde en blijft maximaal 8', () {
      var s = singleAtmState().copyWith(refillGoalRound: 4);
      expect(s.refillGoalTarget, 7);
      s = s.copyWith(refillGoalRound: 10);
      expect(s.refillGoalTarget, kRefillGoalMaxTarget);
    });

    test('CIT-routeoptimalisatie geeft 15% korting per level', () {
      var s = singleAtmState(notesInCassette: 0, balance: 1000);
      s = withUpgradeLevel(s, UpgradeId.citRoute, 2);
      expect(s.citTripCost, closeTo(60 * 0.7, 1e-9));
      final after = TickEngine(random: FakeRandom()).requestService(s, 0);
      expect(after.balance, closeTo(1000 - 42, 1e-9));
    });

    test('CIT-planner stuurt automatisch een wagen onder 15% voorraad', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 14, balance: 1000);
      s = withStaffHired(s, StaffId.citPlanner);
      s = engine.tick(s);
      expect(s.citVans.single.status, CitVanStatus.transitToAtm);
      expect(s.citVans.single.targetAtmId, 0);
      // Na reistijd plus servicing is de cassette echt vol.
      final travel = s.travelTicksTo(LocationType.station);
      for (var i = 0; i < travel + kServicingDurationTicks; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits);
      expect(s.refillGoalProgress, 1);

      // Boven de drempel blijft de planner van de vloot af.
      var idle = singleAtmState(notesInCassette: 16, balance: 1000);
      idle = withStaffHired(idle, StaffId.citPlanner);
      expect(engine.tick(idle).citVans.single.isIdle, isTrue);
    });
  });

  group('Aankopen (GDD 3.3 en 7)', () {
    test('de eerste twee automaten kosten 400, daarna groeit de prijs', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(nextEventInSeconds: 1000000);
      // Startsaldo 1.000: twee basisautomaten van 400 passen erin.
      expect(s.balance, 1000);
      expect(s.atms, isEmpty);
      expect(s.nextAtmPrice, 400);
      s = engine.buyAtm(s, LocationType.winkel);
      expect(s.atms.length, 1);
      expect(s.balance, 600);
      expect(s.nextAtmPrice, 400);
      s = engine.buyAtm(s, LocationType.station);
      expect(s.atms.length, 2);
      expect(s.balance, 200);
      expect(s.nextAtmPrice, closeTo(640, 1e-9));
      final bought = s.atms.last;
      expect(bought.housing, AtmHousing.lobby);
      expect(bought.function, AtmFunction.dispenser);
      expect(bought.level, 1);
      expect(bought.cassettes.length, 1);
      expect(bought.notesInCassette, kCassetteCapacityUnits);
      expect(bought.condition, 1.0);
    });

    test('locatiesloten begrenzen het netwerk', () {
      final engine = TickEngine(random: FakeRandom());
      var s = GameState.initial(
        nextEventInSeconds: 1000000,
      ).copyWith(balance: 100000);
      s = engine.buyAtm(s, LocationType.winkel);
      s = engine.buyAtm(s, LocationType.station);
      s = engine.buyAtm(s, LocationType.horeca);
      expect(s.atms.length, 3);
      // Level Dorp heeft 3 sloten: de vierde wordt geweigerd.
      final refused = engine.buyAtm(s, LocationType.zorg);
      expect(refused.atms.length, 3);
      expect(refused.balance, s.balance);
    });

    test('netwerk-upgrades verdubbelen in prijs en hebben een maximum', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 750);
      s = engine.buyUpgrade(s, UpgradeId.ibns);
      expect(s.upgradeLevel(UpgradeId.ibns), 1);
      expect(s.balance, 500);
      expect(s.upgrade(UpgradeId.ibns).nextLevelCost, 500);
      s = engine.buyUpgrade(s, UpgradeId.ibns);
      expect(s.upgradeLevel(UpgradeId.ibns), 2);
      expect(s.balance, 0);

      var maxed = withUpgradeLevel(
        singleAtmState(balance: 100000),
        UpgradeId.citRoute,
        kCitRouteUpgradeMaxLevel,
      );
      maxed = engine.buyUpgrade(maxed, UpgradeId.citRoute);
      expect(maxed.upgradeLevel(UpgradeId.citRoute), kCitRouteUpgradeMaxLevel);
      expect(maxed.balance, 100000);
    });

    test('de vervallen cassette-upgrade is niet meer koopbaar', () {
      final engine = TickEngine(random: FakeRandom());
      final s = engine.buyUpgrade(
        singleAtmState(balance: 100000),
        UpgradeId.cassettes,
      );
      expect(s.upgradeLevel(UpgradeId.cassettes), 0);
      expect(s.balance, 100000);
      expect(s.upgrade(UpgradeId.cassettes).isMaxed, isTrue);
    });

    test('capaciteit groeit per gekochte cassette, niet per level', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 2 * kExtraCassettePrice);
      expect(s.atms.first.capacity, kCassetteCapacityUnits);
      s = engine.buyCassette(s, 0);
      s = engine.buyCassette(s, 0);
      expect(s.atms.first.capacity, 3 * kCassetteCapacityUnits);
      // Het upgradelevel verandert de capaciteit niet.
      final leveled = singleAtmState(level: 5);
      expect(leveled.atms.first.capacity, kCassetteCapacityUnits);
    });

    test('personeel is eenmalig en kost de tabelprijs', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(balance: 4000);
      s = engine.hireStaff(s, StaffId.analyst);
      expect(s.hasStaff(StaffId.analyst), isTrue);
      expect(s.balance, 0);
      expect(s.incomeMultiplier, closeTo(1.10, 1e-9));
      // Nogmaals aannemen verandert niets.
      expect(engine.hireStaff(s, StaffId.analyst).balance, 0);
    });
  });

  group('Prestige (GDD 9.3)', () {
    test('onder de drempel kan prestige niet', () {
      final engine = TickEngine(random: FakeRandom());
      final s = singleAtmState(totalEarned: 24999);
      expect(engine.prestige(s).prestigeLevel, 0);
    });

    test('prestige reset het netwerk maar houdt bankcontractlevels', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(totalEarned: 25000, balance: 9999);
      s = s.copyWith(
        banks: [
          for (final b in s.banks)
            b.copyWith(contractLevel: 3, connected: true),
        ],
      );
      final after = engine.prestige(s);
      expect(after.prestigeLevel, 1);
      expect(after.balance, kStartingBalance);
      expect(after.totalEarned, 0);
      expect(after.atms, isEmpty);
      expect(after.milestonesClaimed, 0);
      // Ook de CIT-vloot gaat terug naar de startwagen.
      expect(after.citVans.length, kStartingCitVans);
      expect(after.citVans.every((v) => v.isIdle), isTrue);
      expect(after.bank(BankId.oranje).contractLevel, 3);
      // De Zuiderbank-aansluiting is een aankoop en reset dus wel.
      expect(after.bank(BankId.zuider).connected, isFalse);
      expect(after.bank(BankId.zuider).contractLevel, 3);
    });

    test('prestige geeft +25% en activeert het 100 euro biljet', () {
      final engine = TickEngine(random: FakeRandom());
      final after = engine.prestige(singleAtmState(totalEarned: 25000));
      expect(after.hundredEuroNoteActive, isTrue);
      // 1,25 prestige x 1,6 biljet = 2,0.
      expect(after.incomeMultiplier, closeTo(2.0, 1e-9));
    });

    test('het 100 euro biljet laat cassettes 40% sneller leeglopen', () {
      // Na prestige: extra-biljet-roll 0,5 onder de kans 0,6, dus drie
      // biljetten voor een opname, en inkomen x2.
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(8), 0.5, 0.5, 0.0, 0.99, 0.99],
          bools: [true],
        ),
      );
      // Prestige start zonder automaten: zet er zelf een neer.
      var s = TickEngine(
        random: FakeRandom(),
      ).prestige(singleAtmState(totalEarned: 25000));
      s = s.copyWith(
        atms: [
          const Atm(
            id: 0,
            housing: AtmHousing.lobby,
            function: AtmFunction.dispenser,
            level: 1,
            location: LocationType.station,
            queueLength: 1,
            cassettes: [Cassette.full()],
          ),
        ],
        tick: tickForHour(12),
        nextEventInSeconds: 1000000,
      );
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      expect(s.atms.first.notesInCassette, kCassetteCapacityUnits - 3);
      expect(s.totalEarned, closeTo(8.0 * 1.1 * 0.9 * 2.0, 1e-9));
    });
  });
}
