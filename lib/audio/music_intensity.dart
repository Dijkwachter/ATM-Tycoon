// Pure vertaling van spelstaat naar muziekparameters, los van audio-code
// zodat dit unit-testbaar is. Het tempo van de loop stijgt met de drukte
// (de drukste locatie telt) en krijgt een extra zetje wanneer ergens een
// cassette bijna leeg is; de percussielaag is stil bij rust en komt op bij
// drukte en bij bijna lege cassettes.

import '../core/constants.dart';
import '../models/enums.dart';
import '../models/game_state.dart';

/// Hoogste druktefactor van de geplaatste automaten op dit speluur;
/// zonder automaten geldt 1,0 (neutraal).
double peakBusyFactor(GameState state) {
  if (state.atms.isEmpty) {
    return 1.0;
  }
  var peak = 0.0;
  for (final atm in state.atms) {
    final factor = kBusyProfiles[atm.location]!.factorAt(state.hourOfDay);
    if (factor > peak) {
      peak = factor;
    }
  }
  return peak;
}

/// Laagste cassettevulling (0,0 tot 1,0) van de werkende automaten;
/// 1,0 wanneer er niets te melden valt.
double lowestCassetteFraction(GameState state) {
  var lowest = 1.0;
  for (final atm in state.atms) {
    if (!atm.isOperational) {
      continue;
    }
    final capacity = atm.capacity(state.upgradeLevel(UpgradeId.cassettes));
    if (capacity <= 0) {
      continue;
    }
    final fraction = atm.notesInCassette / capacity;
    if (fraction < lowest) {
      lowest = fraction;
    }
  }
  return lowest;
}

/// Afspeelsnelheid van de muziekloop: 0,95 in de nacht tot 1,25 op de
/// piek, plus 0,06 wanneer ergens een cassette onder een kwart zit.
double musicSpeedFor(GameState state) {
  final busy = peakBusyFactor(state);
  var speed = 0.95 + (busy - 0.3) / (2.2 - 0.3) * 0.30;
  if (lowestCassetteFraction(state) < 0.25) {
    speed += 0.06;
  }
  return speed.clamp(0.95, 1.30);
}

/// Volume van de percussielaag: hoorbaar bij drukte, dringend bij bijna
/// lege cassettes.
double percussionLevelFor(GameState state) {
  var level = 0.0;
  if (peakBusyFactor(state) >= 1.2) {
    level = 0.35;
  }
  final cassette = lowestCassetteFraction(state);
  if (cassette < 0.25) {
    level = 0.6;
  }
  if (cassette < 0.10) {
    level = 0.85;
  }
  return level;
}
