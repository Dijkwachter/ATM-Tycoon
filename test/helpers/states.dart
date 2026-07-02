import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/models/atm.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';

/// Zet de tick-teller zo dat de eerstvolgende tick op het gegeven speluur
/// valt (de engine verhoogt de teller aan het begin van de tick).
int tickForHour(int hour) => hour * kGameHourRealSeconds;

/// Bouwt een staat met een enkele automaat, zonder aanstaand event, zodat
/// tests volledig gescript kunnen rekenen.
GameState singleAtmState({
  LocationType location = LocationType.station,
  AtmTier tier = AtmTier.lobbyBasic,
  int? notesInCassette,
  double condition = 1.0,
  double balance = 1000,
  double totalEarned = 0,
  int hour = 12,
}) {
  final base = GameState.initial(nextEventInSeconds: 1000000);
  final atm = Atm(
    id: 0,
    tier: tier,
    location: location,
    notesInCassette: notesInCassette ?? kTierCapacity[tier.index],
    condition: condition,
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

GameState withStaffHired(GameState s, StaffId id) => s.copyWith(
      staff: [
        for (final m in s.staff) m.id == id ? m.copyWith(hired: true) : m,
      ],
    );

GameState withUpgradeLevel(GameState s, UpgradeId id, int level) => s.copyWith(
      upgrades: [
        for (final u in s.upgrades) u.id == id ? u.copyWith(level: level) : u,
      ],
    );
