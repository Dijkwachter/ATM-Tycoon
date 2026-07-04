import 'enums.dart';

/// Een CIT-geldwagen uit de centrale vloot. Immutable.
///
/// De wagen doorloopt per servicing-opdracht de cyclus
/// [CitVanStatus.transitToAtm] -> [CitVanStatus.servicing] ->
/// [CitVanStatus.returning] -> [CitVanStatus.idle]; alleen een idle wagen
/// is inzetbaar (Ontwerper dd 2026-07-04).
class CitVan {
  const CitVan({
    required this.id,
    this.status = CitVanStatus.idle,
    this.targetAtmId,
    this.ticksRemaining = 0,
  });

  final int id;
  final CitVanStatus status;

  /// De automaat van de lopende opdracht; null bij een idle wagen.
  final int? targetAtmId;

  /// Resterende ticks in de huidige fase.
  final int ticksRemaining;

  bool get isIdle => status == CitVanStatus.idle;

  CitVan copyWith({
    CitVanStatus? status,
    int? targetAtmId,
    int? ticksRemaining,
    bool clearTarget = false,
  }) {
    return CitVan(
      id: id,
      status: status ?? this.status,
      targetAtmId: clearTarget ? null : (targetAtmId ?? this.targetAtmId),
      ticksRemaining: ticksRemaining ?? this.ticksRemaining,
    );
  }
}
