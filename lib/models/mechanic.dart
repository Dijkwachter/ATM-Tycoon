import 'enums.dart';

/// Een servicemonteur uit de centrale ploeg. Immutable.
///
/// Het aanrijdsysteem (Ontwerper dd 2026-07-06) werkt als bij de
/// CIT-wagen: de monteur doorloopt per storing de cyclus
/// [CitVanStatus.transitToAtm] -> [CitVanStatus.servicing] (repareren ter
/// plaatse) -> [CitVanStatus.returning] -> [CitVanStatus.idle]; alleen
/// een idle monteur is inzetbaar. De engine stuurt monteurs automatisch
/// naar de oudste onbediende storing.
class ServiceMechanic {
  const ServiceMechanic({
    required this.id,
    this.status = CitVanStatus.idle,
    this.targetAtmId,
    this.ticksRemaining = 0,
  });

  final int id;
  final CitVanStatus status;

  /// De automaat van de lopende reparatie; null bij een idle monteur.
  final int? targetAtmId;

  /// Resterende ticks in de huidige fase.
  final int ticksRemaining;

  bool get isIdle => status == CitVanStatus.idle;

  ServiceMechanic copyWith({
    CitVanStatus? status,
    int? targetAtmId,
    int? ticksRemaining,
    bool clearTarget = false,
  }) {
    return ServiceMechanic(
      id: id,
      status: status ?? this.status,
      targetAtmId: clearTarget ? null : (targetAtmId ?? this.targetAtmId),
      ticksRemaining: ticksRemaining ?? this.ticksRemaining,
    );
  }
}
