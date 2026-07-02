import 'dart:math';

import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Progressiesimulatie naar het model van de Simulatie-tab: een speler die
/// alles herinvesteert. We draaien 1800 ticks (30 minuten) met een vaste
/// seed en controleren de invarianten en de globale pacing.
void main() {
  test('1800 ticks: saldo nooit negatief en pacing volgens de Simulatie-tab',
      () {
    final engine = TickEngine(random: Random(42));
    var s = GameState.initial();

    // Kooprotatie voor nieuwe automaten: gemengde locatiesoorten.
    const locations = [
      LocationType.winkel,
      LocationType.winkelcentrum,
      LocationType.evenement,
      LocationType.reizen,
      LocationType.snelweg,
      LocationType.zorg,
      LocationType.station,
      LocationType.horeca,
      LocationType.openbaar,
      LocationType.winkel,
    ];
    var bought = 0;

    int? firstMilestoneTick;
    int? stadTick;
    int? regioTick;

    for (var tickNumber = 1; tickNumber <= 1800; tickNumber++) {
      s = engine.tick(s);

      // Speleracties, zoals de Simulatie-tab aanneemt dat de speler speelt.
      for (final atm in s.atms) {
        // Gratis preventief onderhoud zodra het beschikbaar is (GDD 4:
        // "vooruitplannen voelt daardoor slim").
        if (atm.isOperational &&
            atm.condition < kPreventiveMaintenanceThreshold) {
          s = engine.preventiveMaintenance(s, atm.id);
        }
        // Bijvullen onder een kwart cassette.
        final capacity =
            atm.capacity(s.upgradeLevel(UpgradeId.cassettes));
        if (s.atmById(atm.id).notesInCassette < capacity * 0.25) {
          s = engine.refillAtm(s, atm.id);
        }
      }

      // Herinvesteren met een buffer voor CIT-ritten: eerst het netwerk
      // uitbreiden, dan tiers upgraden (volgorde van de Simulatie-tab).
      final buffer = kCitCostPerTrip * s.atms.length;
      var purchased = true;
      while (purchased) {
        purchased = false;
        if (s.atms.length < s.locationSlots &&
            s.balance >= s.nextAtmPrice + buffer) {
          final before = s.atms.length;
          s = engine.buyAtm(s, locations[bought % locations.length]);
          if (s.atms.length > before) {
            bought += 1;
            purchased = true;
            continue;
          }
        }
        // Goedkoopste tier-upgrade eerst.
        for (final atm in s.atms) {
          final next = atm.tier.next;
          if (next != null &&
              s.balance >= kTierUpgradeCost[next.index] + buffer) {
            s = engine.upgradeAtmTier(s, atm.id);
            purchased = true;
            break;
          }
        }
      }

      // Invarianten: het ontwerp belooft dat straf vertraging is, geen
      // verlies (GDD 1).
      expect(s.balance, greaterThanOrEqualTo(0),
          reason: 'saldo negatief op tick $tickNumber');
      for (final atm in s.atms) {
        expect(atm.condition, inInclusiveRange(0, 1),
            reason: 'staat buiten bereik op tick $tickNumber');
        final capacity =
            atm.capacity(s.upgradeLevel(UpgradeId.cassettes));
        expect(atm.notesInCassette, inInclusiveRange(0, capacity),
            reason: 'cassette buiten bereik op tick $tickNumber');
      }

      firstMilestoneTick ??= s.totalEarned >= 750 ? tickNumber : null;
      stadTick ??= s.totalEarned >= 2000 ? tickNumber : null;
      regioTick ??= s.totalEarned >= 8000 ? tickNumber : null;
    }

    // Pacing, grofweg tegen de Simulatie-tab (kolom Cumulatief):
    // mijlpaal 750 rond 0,5 min, Stad (2.000) rond 6,5 min, Regio (8.000)
    // rond 20 min. We staan ruime marge toe; het gaat om de orde van
    // grootte, niet om de exacte minuut.
    expect(firstMilestoneTick, isNotNull,
        reason: 'eerste mijlpaal niet gehaald binnen 30 min');
    expect(firstMilestoneTick!, lessThanOrEqualTo(240),
        reason: 'eerste mijlpaal pas na 4 min (sim: 0,5 min)');
    expect(stadTick, isNotNull, reason: 'Stad niet gehaald binnen 30 min');
    expect(stadTick!, lessThanOrEqualTo(900),
        reason: 'Stad pas na 15 min (sim: 6,5 min)');
    expect(regioTick, isNotNull, reason: 'Regio niet gehaald binnen 30 min');

    // Bovengrens tegen weglopende inflatie: de sim haalt 25.000 rond
    // 25 min; ruim het dubbele in 30 minuten zou een balansfout zijn.
    expect(s.totalEarned, lessThan(60000));

    // Er is daadwerkelijk gespeeld: netwerk gegroeid en ritten betaald.
    expect(s.atms.length, greaterThan(kStartingAtmCount));
  });

  test('simulatie is deterministisch bij gelijke seed', () {
    GameState run() {
      final engine = TickEngine(random: Random(7));
      var s = GameState.initial();
      for (var i = 0; i < 300; i++) {
        s = engine.tick(s);
      }
      return s;
    }

    final a = run();
    final b = run();
    expect(a.balance, b.balance);
    expect(a.totalEarned, b.totalEarned);
    expect(a.atms.first.notesInCassette, b.atms.first.notesInCassette);
    expect(a.atms.first.condition, b.atms.first.condition);
    expect(a.nextEventInSeconds, b.nextEventInSeconds);
  });
}
