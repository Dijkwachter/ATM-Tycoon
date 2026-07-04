import 'dart:math';

import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Progressiesimulatie naar het model van de Simulatie-tab: een speler die
/// alles herinvesteert. We draaien 1800 ticks (30 minuten) met een vaste
/// seed en controleren de invarianten en de globale pacing, nu inclusief
/// de logistieke vertraging van de CIT-vloot (reistijd plus servicing) en
/// de spreidingswet van de Nationale Bank.
void main() {
  test(
    '1800 ticks: saldo nooit negatief en pacing volgens de Simulatie-tab',
    () {
      final engine = TickEngine(random: Random(42));
      var s = GameState.initial();

      // Kooprotatie voor nieuwe automaten. Het spel start om 00:00 zonder
      // automaten; een verstandige speler koopt eerst een dag- en een
      // nachtlocatie (station plus horeca) en spreidt daarna over de zones
      // zodat de Nationale Bank nooit hoeft te weigeren.
      const locations = [
        LocationType.station,
        LocationType.horeca,
        LocationType.winkel,
        LocationType.winkelcentrum,
        LocationType.evenement,
        LocationType.reizen,
        LocationType.snelweg,
        LocationType.zorg,
        LocationType.openbaar,
        LocationType.winkel,
        LocationType.station,
        LocationType.horeca,
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
          // Een wagen sturen onder een kwart voorraad; de engine weigert
          // zelf als de vloot bezet is of er al een wagen onderweg is.
          final current = s.atmById(atm.id);
          if (current.availableNotes < current.capacity * 0.25) {
            s = engine.requestService(s, atm.id);
          }
        }

        // Herinvesteren met een buffer voor CIT-ritten: eerst het netwerk
        // uitbreiden, dan de vloot verdubbelen, dan tiers upgraden.
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
          // Een tweede geldwagen zodra het netwerk dat rechtvaardigt.
          if (s.atms.length >= 4 &&
              s.citVans.length < 2 &&
              s.balance >= s.nextCitVanPrice + buffer) {
            s = engine.buyCitVan(s);
            purchased = true;
            continue;
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
        expect(
          s.balance,
          greaterThanOrEqualTo(0),
          reason: 'saldo negatief op tick $tickNumber',
        );
        for (final atm in s.atms) {
          for (final cassette in atm.cassettes) {
            expect(
              cassette.condition,
              inInclusiveRange(0, 1),
              reason: 'staat buiten bereik op tick $tickNumber',
            );
            expect(
              cassette.notes,
              inInclusiveRange(0, kCassetteCapacityUnits),
              reason: 'cassette buiten bereik op tick $tickNumber',
            );
          }
        }
        // De spreidingswet is nooit overtreden: geen zone loopt meer dan
        // de wettelijke marge op de leegste uit.
        expect(
          s.maxZoneCount,
          lessThanOrEqualTo(s.minZoneCount + kSpreadLawZoneCap),
          reason: 'spreidingswet overtreden op tick $tickNumber',
        );

        firstMilestoneTick ??= s.totalEarned >= 750 ? tickNumber : null;
        stadTick ??= s.totalEarned >= 2000 ? tickNumber : null;
        regioTick ??= s.totalEarned >= 8000 ? tickNumber : null;
      }

      // Pacing, grofweg tegen de Simulatie-tab (kolom Cumulatief). De
      // CIT-reistijden maken het spel iets trager dan de oude sim; het gaat
      // om de orde van grootte, niet om de exacte minuut.
      expect(
        firstMilestoneTick,
        isNotNull,
        reason: 'eerste mijlpaal niet gehaald binnen 30 min',
      );
      expect(
        firstMilestoneTick!,
        lessThanOrEqualTo(300),
        reason: 'eerste mijlpaal pas na 5 min (sim: 0,5 min)',
      );
      expect(stadTick, isNotNull, reason: 'Stad niet gehaald binnen 30 min');
      expect(
        stadTick!,
        lessThanOrEqualTo(1000),
        reason: 'Stad pas na ruim 16 min (sim: 6,5 min)',
      );
      expect(regioTick, isNotNull, reason: 'Regio niet gehaald binnen 30 min');

      // Bovengrens tegen weglopende inflatie: de sim haalt 25.000 rond
      // 25 min; ruim het dubbele in 30 minuten zou een balansfout zijn.
      expect(s.totalEarned, lessThan(60000));

      // Er is daadwerkelijk gespeeld: netwerk en vloot gegroeid.
      expect(s.atms.length, greaterThan(2));
      expect(s.citVans.length, greaterThanOrEqualTo(2));
    },
  );

  test('simulatie is deterministisch bij gelijke seed', () {
    GameState run() {
      final engine = TickEngine(random: Random(7));
      var s = GameState.initial();
      // Het startsaldo dekt twee automaten van de basisprijs.
      s = engine.buyAtm(s, LocationType.station);
      s = engine.buyAtm(s, LocationType.horeca);
      s = engine.requestService(s, 0);
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
    expect(a.citVans.single.status, b.citVans.single.status);
    expect(a.citVans.single.ticksRemaining, b.citVans.single.ticksRemaining);
  });
}
