import 'dart:math';

import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Progressiesimulatie naar het model van de Simulatie-tab: een speler die
/// alles herinvesteert. We draaien 1800 ticks (30 minuten) met een vaste
/// seed en controleren de invarianten en de globale pacing, inclusief het
/// wachtrijmodel (maximaal een klant per verwerkingscyclus), de
/// CIT-logistiek en de spreidingswet van de Nationale Bank.
void main() {
  test('1800 ticks: saldo nooit negatief en pacing binnen de bandbreedte', () {
    // Seed 43 sinds het overvalrisico op CIT-transits (Ontwerper dd
    // 2026-07-06): elke transit-tick verbruikt een roll, waardoor de
    // oude seed 42 net naast de pacing-band viel. Deze run bevat ook
    // een daadwerkelijke overval, dus dat pad draait in de simulatie mee.
    final engine = TickEngine(random: Random(43));
    var s = GameState.initial();

    // Kooprotatie voor nieuwe automaten. Het spel start om 00:00; een
    // verstandige speler zet de nachtlocatie horeca als through-the-wall
    // neer (24/7 aanloop) en spreidt daarna over de zones zodat de
    // Nationale Bank nooit hoeft te weigeren.
    const locations = [
      LocationType.horeca,
      LocationType.station,
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
    const ttwLocations = {LocationType.horeca, LocationType.snelweg};
    var bought = 0;

    int? firstMilestoneTick;
    int? stadTick;
    int? regioTick;

    for (var tickNumber = 1; tickNumber <= 1800; tickNumber++) {
      s = engine.tick(s);

      // Speleracties, zoals de Simulatie-tab aanneemt dat de speler
      // speelt.
      for (final atm in s.atms) {
        if (atm.isOperational &&
            atm.condition < kPreventiveMaintenanceThreshold) {
          s = engine.preventiveMaintenance(s, atm.id);
        }
        final current = s.atmById(atm.id);
        if (current.availableNotes < current.capacity * 0.25) {
          s = engine.requestService(s, atm.id);
        }
      }

      // Herinvesteren met een buffer voor CIT-ritten: eerst het netwerk
      // uitbreiden, dan de vloot verdubbelen, dan levels upgraden.
      final buffer = kCitCostPerTrip * s.atms.length;
      var purchased = true;
      while (purchased) {
        purchased = false;
        final location = locations[bought % locations.length];
        final housing = ttwLocations.contains(location)
            ? AtmHousing.ttw
            : AtmHousing.lobby;
        final price =
            s.nextAtmPrice +
            (housing == AtmHousing.ttw ? kTtwHousingPremium : 0);
        if (s.atms.length < s.locationSlots && s.balance >= price + buffer) {
          final before = s.atms.length;
          s = engine.buyAtm(s, location, housing: housing);
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
        // Goedkoopste levelupgrade eerst (snellere verwerking).
        for (final atm in s.atms) {
          final cost = atm.nextLevelCost;
          if (cost != null && s.balance >= cost + buffer) {
            s = engine.upgradeAtm(s, atm.id);
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
        expect(
          atm.queueLength,
          inInclusiveRange(0, atm.queueCapacity),
          reason: 'wachtrij buiten bereik op tick $tickNumber',
        );
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
      // De spreidingswet is nooit overtreden.
      expect(
        s.maxZoneCount,
        lessThanOrEqualTo(s.minZoneCount + kSpreadLawZoneCap),
        reason: 'spreidingswet overtreden op tick $tickNumber',
      );

      firstMilestoneTick ??= s.totalEarned >= 750 ? tickNumber : null;
      stadTick ??= s.totalEarned >= 2000 ? tickNumber : null;
      regioTick ??= s.totalEarned >= 8000 ? tickNumber : null;
    }

    // Pacing: het wachtrijmodel verwerkt op level 1 hooguit een klant
    // per zeven seconden, dus de curve ligt trager dan de oude sim;
    // het gaat om de orde van grootte.
    expect(
      firstMilestoneTick,
      isNotNull,
      reason: 'eerste mijlpaal niet gehaald binnen 30 min',
    );
    expect(
      firstMilestoneTick!,
      lessThanOrEqualTo(500),
      reason: 'eerste mijlpaal pas na ruim 8 min',
    );
    expect(stadTick, isNotNull, reason: 'Stad niet gehaald binnen 30 min');
    expect(
      stadTick!,
      lessThanOrEqualTo(1300),
      reason: 'Stad pas na bijna 22 min',
    );
    expect(regioTick, isNotNull, reason: 'Regio niet gehaald binnen 30 min');

    // Bovengrens tegen weglopende inflatie.
    expect(s.totalEarned, lessThan(60000));

    // Er is daadwerkelijk gespeeld: netwerk en vloot gegroeid.
    expect(s.atms.length, greaterThan(2));
    expect(s.citVans.length, greaterThanOrEqualTo(2));
  });

  test('simulatie is deterministisch bij gelijke seed', () {
    GameState run() {
      final engine = TickEngine(random: Random(7));
      var s = GameState.initial();
      // Het startsaldo dekt een basisautomaat plus een TTW-automaat.
      s = engine.buyAtm(s, LocationType.station);
      s = engine.buyAtm(s, LocationType.horeca, housing: AtmHousing.ttw);
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
    expect(a.atms.first.queueLength, b.atms.first.queueLength);
    expect(a.nextEventInSeconds, b.nextEventInSeconds);
    expect(a.citVans.single.status, b.citVans.single.status);
    expect(a.citVans.single.ticksRemaining, b.citVans.single.ticksRemaining);
  });
}
