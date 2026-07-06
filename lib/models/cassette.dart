import '../core/constants.dart';

/// Een cassette in een automaat. Immutable; wijzigingen via [copyWith].
///
/// De capaciteit ligt vast op [kCassetteCapacityUnits] engine-eenheden
/// (2.000 echte biljetten). Elke cassette heeft een vaste [denomination]
/// volgens de slotconfiguratie 10/20/50/50/50 (Ontwerper dd 2026-07-06);
/// na de eerste prestige wordt het vijfde slot een 100 EUR-cassette.
/// Slijtage en storingen worden per cassette bijgehouden: valt een
/// cassette uit, dan draaien de overige door en zakt de
/// transactiesnelheid van de automaat evenredig. Een storing blijft staan
/// tot een servicemonteur ter plaatse is (aanrijdsysteem).
class Cassette {
  const Cassette({
    required this.notes,
    required this.condition,
    this.repairSecondsRemaining = 0,
    this.denomination = 10,
  });

  /// Volle cassette in nieuwstaat, zoals bij een verse automaat.
  const Cassette.full({this.denomination = 10})
    : notes = kCassetteCapacityUnits,
      condition = 1.0,
      repairSecondsRemaining = 0;

  /// Lege cassette in nieuwstaat, zoals een bijgekochte cassette geleverd
  /// wordt: een CIT-rit vult hem.
  const Cassette.empty({this.denomination = 10})
    : notes = 0,
      condition = 1.0,
      repairSecondsRemaining = 0;

  /// Aantal biljetten (engine-eenheden), 0 tot [kCassetteCapacityUnits].
  final int notes;

  /// Staat van 0,0 tot 1,0. Bij nul vliegt deze cassette in storing.
  final double condition;

  /// Groter dan nul betekent storing: de cassette wacht op een monteur
  /// (de waarde is de verwachte reparatietijd ter plaatse, voor de UI).
  final double repairSecondsRemaining;

  /// Biljetwaarde van dit slot in EUR (10, 20, 50 of 100).
  final int denomination;

  bool get isBroken => repairSecondsRemaining > 0;

  /// Cashwaarde van de inhoud in EUR, voor de float-rente.
  double get cashValue => notes * denomination.toDouble();

  Cassette copyWith({
    int? notes,
    double? condition,
    double? repairSecondsRemaining,
  }) {
    return Cassette(
      notes: notes ?? this.notes,
      condition: condition ?? this.condition,
      repairSecondsRemaining:
          repairSecondsRemaining ?? this.repairSecondsRemaining,
      denomination: denomination,
    );
  }
}
