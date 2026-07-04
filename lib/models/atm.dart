import 'dart:math' as math;

import '../core/constants.dart';
import 'cassette.dart';
import 'enums.dart';

/// Een geplaatste geldautomaat. Immutable; wijzigingen gaan via [copyWith].
///
/// Regels: GDD 3.3 (tiers), GDD 4 (slijtage en storingen), GDD 5 (locatie
/// en drukteprofiel). Sinds de multi-cassette-verbouwing (Ontwerper dd
/// 2026-07-04) heeft een automaat 1 tot [kMaxCassettesPerAtm] cassettes met
/// elk hun eigen inhoud, staat en storingsstatus.
class Atm {
  const Atm({
    required this.id,
    required this.tier,
    required this.location,
    required this.cassettes,
    this.outageSecondsRemaining = 0,
    this.lifetimeEarned = 0,
  });

  /// Nieuwe automaat zoals hij geplaatst wordt: een volle cassette in
  /// nieuwstaat.
  factory Atm.fresh({
    required int id,
    required LocationType location,
    AtmTier tier = AtmTier.lobbyBasic,
  }) {
    return Atm(
      id: id,
      tier: tier,
      location: location,
      cassettes: const [Cassette.full()],
    );
  }

  final int id;
  final AtmTier tier;
  final LocationType location;

  /// De cassetteslots, minimaal 1 en maximaal [kMaxCassettesPerAtm].
  final List<Cassette> cassettes;

  /// Resterende stroomstoringstijd in seconden (event, GDD 6).
  final double outageSecondsRemaining;

  /// Totaal verdiend door deze automaat, voor het schermpje op de kast.
  final double lifetimeEarned;

  // -------------------------------------------------------------------------
  // Afgeleide cassettewaarden.
  // -------------------------------------------------------------------------

  /// Cassettes die niet in storing staan en dus kunnen uitgeven.
  List<Cassette> get workingCassettes => [
    for (final c in cassettes)
      if (!c.isBroken) c,
  ];

  /// Biljetten die op dit moment uitgegeven kunnen worden (werkende
  /// cassettes).
  int get availableNotes {
    var sum = 0;
    for (final c in cassettes) {
      if (!c.isBroken) {
        sum += c.notes;
      }
    }
    return sum;
  }

  /// Alle biljetten in de kast, ook in kapotte cassettes; cash blijft cash
  /// en telt mee voor de float-rente (GDD 3.2).
  int get totalNotes {
    var sum = 0;
    for (final c in cassettes) {
      sum += c.notes;
    }
    return sum;
  }

  /// Compat-alias voor de uitgeefbare voorraad.
  int get notesInCassette => availableNotes;

  /// Totale capaciteit: vaste cassettegrootte maal het aantal slots.
  int get capacity => cassettes.length * kCassetteCapacityUnits;

  /// Werkend aandeel van de cassettes; de transactiesnelheid daalt hiermee
  /// evenredig wanneer cassettes in storing staan.
  double get workingFraction =>
      cassettes.isEmpty ? 0 : workingCassettes.length / cassettes.length;

  bool get hasBrokenCassette => cassettes.any((c) => c.isBroken);

  /// Volledig in storing: geen enkele cassette werkt nog.
  bool get isBroken => cassettes.isNotEmpty && workingCassettes.isEmpty;

  bool get isPausedByOutage => outageSecondsRemaining > 0;

  /// Operationeel: minstens een werkende cassette en geen stroomstoring.
  bool get isOperational => !isPausedByOutage && workingCassettes.isNotEmpty;

  /// Langste resterende reparatietijd, voor de storingsweergave.
  double get repairSecondsRemaining {
    var longest = 0.0;
    for (final c in cassettes) {
      longest = math.max(longest, c.repairSecondsRemaining);
    }
    return longest;
  }

  /// Slechtste staat onder de werkende cassettes; 0 als er geen werkt.
  /// Dit stuurt de slijtagebalk en de onderhoudsdrempel (GDD 4).
  double get condition {
    var lowest = double.infinity;
    for (final c in cassettes) {
      if (!c.isBroken) {
        lowest = math.min(lowest, c.condition);
      }
    }
    return lowest.isFinite ? lowest : 0;
  }

  /// Index van de actieve cassette: de werkende cassette met de meeste
  /// biljetten geeft uit en slijt; -1 als er geen werkt.
  int get activeCassetteIndex {
    var best = -1;
    var bestNotes = -1;
    for (var i = 0; i < cassettes.length; i++) {
      final c = cassettes[i];
      if (!c.isBroken && c.notes > bestNotes) {
        best = i;
        bestNotes = c.notes;
      }
    }
    return best;
  }

  bool get isTouristLocation => kTouristLocations.contains(location);

  /// Inkomen per transactie voor deze tier, voor multipliers.
  double get incomePerTransaction => kTierIncomePerTransaction[tier.index];

  // -------------------------------------------------------------------------
  // Pure cassettebewerkingen.
  // -------------------------------------------------------------------------

  /// Vervangt de cassette op [index].
  Atm withCassette(int index, Cassette cassette) {
    return copyWith(
      cassettes: [
        for (var i = 0; i < cassettes.length; i++)
          i == index ? cassette : cassettes[i],
      ],
    );
  }

  /// Trekt [notes] biljetten uit de werkende cassettes, volste eerst; null
  /// wanneer de voorraad niet toereikend is en de opname dus niet doorgaat.
  Atm? drained(int notes) {
    if (availableNotes < notes) {
      return null;
    }
    var remaining = notes;
    final updated = [...cassettes];
    while (remaining > 0) {
      // Volste werkende cassette; het while-criterium garandeert voorraad.
      var best = -1;
      var bestNotes = 0;
      for (var i = 0; i < updated.length; i++) {
        final c = updated[i];
        if (!c.isBroken && c.notes > bestNotes) {
          best = i;
          bestNotes = c.notes;
        }
      }
      final take = math.min(bestNotes, remaining);
      updated[best] = updated[best].copyWith(notes: bestNotes - take);
      remaining -= take;
    }
    return copyWith(cassettes: updated);
  }

  /// Na een afgeronde CIT-servicing: alle cassettes vol, staat 100% en
  /// storingen verholpen (Ontwerper dd 2026-07-04).
  Atm serviced() {
    return copyWith(
      cassettes: [for (final _ in cassettes) const Cassette.full()],
    );
  }

  Atm copyWith({
    AtmTier? tier,
    List<Cassette>? cassettes,
    double? outageSecondsRemaining,
    double? lifetimeEarned,
  }) {
    return Atm(
      id: id,
      tier: tier ?? this.tier,
      location: location,
      cassettes: cassettes ?? this.cassettes,
      outageSecondsRemaining:
          outageSecondsRemaining ?? this.outageSecondsRemaining,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
    );
  }
}
