import 'dart:math' as math;

import '../core/constants.dart';
import 'cassette.dart';
import 'enums.dart';

/// Een lopende transactie bij een automaat, opgeknipt in micro-fases die
/// de UI-choreografie voeden (Ontwerper dd 2026-07-04): kaart aanbieden,
/// verwerken, shutter-actie, afronden. Immutable.
class AtmTransaction {
  const AtmTransaction({
    required this.phase,
    required this.ticksRemaining,
    required this.isDeposit,
  });

  final TransactionPhase phase;

  /// Resterende ticks in de huidige fase.
  final int ticksRemaining;

  /// Storting (recycler) of opname.
  final bool isDeposit;

  AtmTransaction copyWith({TransactionPhase? phase, int? ticksRemaining}) {
    return AtmTransaction(
      phase: phase ?? this.phase,
      ticksRemaining: ticksRemaining ?? this.ticksRemaining,
      isDeposit: isDeposit,
    );
  }
}

/// Een geplaatste geldautomaat. Immutable; wijzigingen gaan via [copyWith].
///
/// Modulair samengesteld bij aankoop (Ontwerper dd 2026-07-04): een
/// behuizing ([AtmHousing]) en functionaliteit ([AtmFunction]), daarna 5
/// keer te upgraden ([level]). Het level stuurt transactiesnelheid,
/// mechanische betrouwbaarheid, wachtrij-capaciteit, beveiliging en de
/// klanttevredenheids-multiplier. Slijtage en storingen leven per
/// cassette; de wachtrij en de lopende transactie zijn speelstaat die
/// niet gepersisteerd wordt (klanten wachten niet op een app-herstart).
class Atm {
  const Atm({
    required this.id,
    required this.housing,
    required this.function,
    required this.level,
    required this.location,
    required this.cassettes,
    this.queueLength = 0,
    this.transaction,
    this.outageSecondsRemaining = 0,
    this.lifetimeEarned = 0,
    this.lostCustomers = 0,
  });

  /// Nieuwe automaat zoals hij geplaatst wordt: level 1, een volle
  /// cassette in nieuwstaat, lege wachtrij.
  factory Atm.fresh({
    required int id,
    required LocationType location,
    AtmHousing housing = AtmHousing.lobby,
    AtmFunction function = AtmFunction.dispenser,
  }) {
    return Atm(
      id: id,
      housing: housing,
      function: function,
      level: 1,
      location: location,
      cassettes: const [Cassette.full()],
    );
  }

  final int id;
  final AtmHousing housing;
  final AtmFunction function;

  /// Upgradelevel 1 tot en met [kMaxAtmLevel].
  final int level;

  final LocationType location;

  /// De cassetteslots, minimaal 1 en maximaal [kMaxCassettesPerAtm].
  final List<Cassette> cassettes;

  /// Aantal wachtende klanten (exclusief de klant aan de automaat).
  final int queueLength;

  /// De lopende transactie, of null als de automaat vrij is.
  final AtmTransaction? transaction;

  /// Resterende stroomstoringstijd in seconden (event, GDD 6).
  final double outageSecondsRemaining;

  /// Totaal verdiend door deze automaat, voor het schermpje op de kast.
  final double lifetimeEarned;

  /// Klanten die ongeduldig doorliepen omdat de rij vol stond.
  final int lostCustomers;

  /// Maximaal level van het upgradesysteem.
  static const int kMaxAtmLevel = 5;

  // -------------------------------------------------------------------------
  // Modulaire eigenschappen (level en configuratie).
  // -------------------------------------------------------------------------

  bool get isRecycler => function == AtmFunction.recycler;

  /// Maximale wachtrij; TTW heeft straatruimte voor een langere rij.
  int get queueCapacity =>
      kLevelQueueCapacity[level - 1] +
      (housing == AtmHousing.ttw ? kTtwQueueBonus : 0);

  /// Duur van de verwerkingsfase in ticks op dit level.
  int get processingTicks => kLevelProcessingTicks[level - 1];

  /// Totale transactieduur in ticks: kaart + verwerking + shutter +
  /// afronding.
  int get totalServiceTicks => 1 + processingTicks + 1 + 1;

  /// Basisinkomen per opname voor deze functionaliteit.
  double get baseIncome =>
      isRecycler ? kRecyclerBaseIncome : kDispenserBaseIncome;

  /// Klanttevredenheids-multiplier van dit level.
  double get levelIncomeMultiplier => kLevelIncomeMultiplier[level - 1];

  /// Kans op een klemgelopen biljet per afgeronde transactie.
  double get jamChance =>
      (isRecycler ? kRecyclerJamChance : kDispenserJamChance) *
      kLevelJamFactor[level - 1];

  /// Slijtageschaal van dit level (mechanische betrouwbaarheid).
  double get wearFactor => kLevelWearFactor[level - 1];

  /// Of het pand van een lobby-automaat op dit uur dicht is.
  bool isLobbyClosedAt(int hour) =>
      housing == AtmHousing.lobby &&
      (hour < kLobbyOpeningHour || hour >= kLobbyClosingHour);

  /// Kans dat deze kast een plofkraak/vandalismepoging zelf afslaat
  /// (beveiligingslevel); een lobby is daar buiten openingstijden
  /// kwetsbaarder in.
  double securityBlockChanceAt(int hour) =>
      kLevelSecurityBlockChance[level - 1] *
      (isLobbyClosedAt(hour) ? kLobbyClosedSecurityFactor : 1.0);

  /// Voorrijkosten van een nood-trip voor deze kast, voor de
  /// IBNS-korting: basis plus toeslagen, geschaald met het
  /// beveiligingslevel (op level 5 gehalveerd).
  double get calloutCost =>
      (kBreakdownCalloutBase +
          (housing == AtmHousing.ttw ? kBreakdownCalloutTtwSurcharge : 0) +
          (isRecycler ? kBreakdownCalloutRecyclerSurcharge : 0)) *
      kLevelCalloutFactor[level - 1];

  /// Kosten om het volgende level te bereiken, of null op het maximum.
  double? get nextLevelCost =>
      level >= kMaxAtmLevel ? null : kLevelUpgradeCost[level - 1];

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

  /// Werkend aandeel van de cassettes; de aanloop daalt hiermee evenredig
  /// wanneer cassettes in storing staan.
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
  /// storingen verholpen; de denominatie per slot blijft staan
  /// (Ontwerper dd 2026-07-04 en 2026-07-06).
  Atm serviced() {
    return copyWith(
      cassettes: [
        for (final c in cassettes) Cassette.full(denomination: c.denomination),
      ],
    );
  }

  /// Na een afgeronde monteursreparatie: alle storingen verholpen en de
  /// staat van elke cassette terug op 100% (de monteur neemt meteen het
  /// onderhoud van de hele kast mee, Ontwerper dd 2026-07-06); de inhoud
  /// blijft onaangeroerd (de monteur brengt geen geld mee - dat doet de
  /// CIT).
  Atm repaired() {
    return copyWith(
      cassettes: [
        for (final c in cassettes)
          c.copyWith(repairSecondsRemaining: 0, condition: 1.0),
      ],
    );
  }

  Atm copyWith({
    int? level,
    List<Cassette>? cassettes,
    int? queueLength,
    AtmTransaction? transaction,
    bool clearTransaction = false,
    double? outageSecondsRemaining,
    double? lifetimeEarned,
    int? lostCustomers,
  }) {
    return Atm(
      id: id,
      housing: housing,
      function: function,
      level: level ?? this.level,
      location: location,
      cassettes: cassettes ?? this.cassettes,
      queueLength: queueLength ?? this.queueLength,
      transaction: clearTransaction ? null : (transaction ?? this.transaction),
      outageSecondsRemaining:
          outageSecondsRemaining ?? this.outageSecondsRemaining,
      lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
      lostCustomers: lostCustomers ?? this.lostCustomers,
    );
  }
}
