// Pure vertaling van spelstaat naar muziekparameters, los van audio-code
// zodat dit unit-testbaar is (Ontwerper dd 2026-07-06, vernieuwd
// audiosysteem). Geen tempo-veranderingen meer: de hoofdloop draait
// altijd op 1,00x en de lagen mengen via volume in en uit.

import '../models/game_state.dart';

/// Netwerkactiviteit: het totaal aan wachtende klanten plus lopende
/// transacties over alle automaten.
int networkActivity(GameState state) {
  var activity = 0;
  for (final atm in state.atms) {
    activity += atm.queueLength + (atm.transaction != null ? 1 : 0);
  }
  return activity;
}

/// Aantal voertuigen (CIT-wagens en monteursbussen) dat onderweg of aan
/// het werk is.
int activeVehicles(GameState state) {
  return state.citVans.where((v) => !v.isIdle).length +
      state.mechanics.where((m) => !m.isIdle).length;
}

/// Doelvolume van de percussielaag (shakers): stil op een lege kaart en
/// subtiel opkomend met de netwerkactiviteit; vol rond tien gelijktijdige
/// klanten.
double percussionLevelFor(GameState state) {
  return (networkActivity(state) / 10).clamp(0.0, 1.0) * 0.5;
}

/// Doelvolume van de pads-laag (warme melodielijn): fadet in wanneer er
/// voertuigen actief onderweg zijn en groeit licht mee met het aantal.
double padsLevelFor(GameState state) {
  return (activeVehicles(state) / 3).clamp(0.0, 1.0) * 0.45;
}
