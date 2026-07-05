import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/models/atm.dart';
import 'package:atm_empire/models/cassette.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';

/// Zet de tick-teller zo dat de eerstvolgende tick op het gegeven speluur
/// valt (de engine verhoogt de teller aan het begin van de tick).
int tickForHour(int hour) => hour * kGameHourRealSeconds;

/// Bouwt een staat met een enkele automaat (een cassette), zonder
/// aanstaand event, zodat tests volledig gescript kunnen rekenen.
GameState singleAtmState({
  LocationType location = LocationType.station,
  AtmHousing housing = AtmHousing.lobby,
  AtmFunction function = AtmFunction.dispenser,
  int level = 1,
  int? notesInCassette,
  double condition = 1.0,
  double repairSecondsRemaining = 0,
  int queueLength = 0,
  double balance = 1000,
  double totalEarned = 0,
  int hour = 12,
}) {
  final base = GameState.initial(nextEventInSeconds: 1000000);
  final atm = Atm(
    id: 0,
    housing: housing,
    function: function,
    level: level,
    location: location,
    queueLength: queueLength,
    cassettes: [
      Cassette(
        notes: notesInCassette ?? kCassetteCapacityUnits,
        condition: condition,
        repairSecondsRemaining: repairSecondsRemaining,
      ),
    ],
  );
  return base.copyWith(
    balance: balance,
    totalEarned: totalEarned,
    milestonesClaimed: claimedMilestonesFor(totalEarned),
    atms: [atm],
    tick: tickForHour(hour),
  );
}

/// Aantal mijlpalen dat bij dit totaal al uitgekeerd zou zijn, zodat tests
/// met een hoog starttotaal geen onbedoelde bonussen triggeren.
int claimedMilestonesFor(double totalEarned) =>
    kMilestoneThresholds.where((t) => totalEarned >= t).length;

/// Vervangt de eerste cassette van de eerste automaat, voor tests die een
/// cassettestand of storing willen scripten.
GameState withFirstCassette(
  GameState s, {
  int? notes,
  double? condition,
  double? repairSecondsRemaining,
}) {
  final atm = s.atms.first;
  return s.withAtm(
    atm.withCassette(
      0,
      atm.cassettes.first.copyWith(
        notes: notes,
        condition: condition,
        repairSecondsRemaining: repairSecondsRemaining,
      ),
    ),
  );
}

/// Zet [n] wachtende klanten voor de eerste automaat.
GameState withQueue(GameState s, int n) =>
    s.withAtm(s.atms.first.copyWith(queueLength: n));

/// Vulwaarden voor de aanloop-roll die elke tick een double consumeert:
/// 0,999 mist elke aanloopkans, zodat gescripte resolutie-rolls op hun
/// plek in de wachtrij blijven staan.
List<double> arrivalMisses(int ticks) => List.filled(ticks, 0.999);

GameState withStaffHired(GameState s, StaffId id) => s.copyWith(
  staff: [for (final m in s.staff) m.id == id ? m.copyWith(hired: true) : m],
);

GameState withUpgradeLevel(GameState s, UpgradeId id, int level) => s.copyWith(
  upgrades: [
    for (final u in s.upgrades) u.id == id ? u.copyWith(level: level) : u,
  ],
);
