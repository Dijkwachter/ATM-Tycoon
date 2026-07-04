import '../core/constants.dart';

/// Een cassette in een automaat. Immutable; wijzigingen via [copyWith].
///
/// De capaciteit ligt vast op [kCassetteCapacityUnits] engine-eenheden
/// (2.000 echte biljetten). Slijtage en storingen worden per cassette
/// bijgehouden: valt een cassette uit, dan draaien de overige door en zakt
/// de transactiesnelheid van de automaat evenredig
/// (Ontwerper dd 2026-07-04).
class Cassette {
  const Cassette({
    required this.notes,
    required this.condition,
    this.repairSecondsRemaining = 0,
  });

  /// Volle cassette in nieuwstaat, zoals bij een verse automaat.
  const Cassette.full()
    : notes = kCassetteCapacityUnits,
      condition = 1.0,
      repairSecondsRemaining = 0;

  /// Lege cassette in nieuwstaat, zoals een bijgekochte cassette geleverd
  /// wordt: een CIT-rit vult hem.
  const Cassette.empty()
    : notes = 0,
      condition = 1.0,
      repairSecondsRemaining = 0;

  /// Aantal biljetten (engine-eenheden), 0 tot [kCassetteCapacityUnits].
  final int notes;

  /// Staat van 0,0 tot 1,0. Bij nul vliegt deze cassette in storing.
  final double condition;

  /// Resterende reparatietijd in seconden; groter dan nul betekent storing.
  final double repairSecondsRemaining;

  bool get isBroken => repairSecondsRemaining > 0;

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
    );
  }
}
