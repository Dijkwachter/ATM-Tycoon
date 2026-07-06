import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/atm.dart';
import '../models/cit_van.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../models/mechanic.dart';
import 'game_controller.dart';

/// Opgesplitste logistieke state voor de tabbladen CiT en Monteurs
/// (Ontwerper dd 2026-07-06): elk tabblad kijkt naar zijn eigen
/// vlootstate in plaats van naar de volledige [GameState]. De providers
/// zijn afgeleide (read-only) projecties; alle mutaties blijven via de
/// [GameController] en de tick-engine lopen.

/// State van de CIT-tak: de geldwagens plus de upgradecontext die het
/// CiT-tabblad toont.
class CitFleetState {
  const CitFleetState({
    required this.vans,
    required this.nextVanPrice,
    required this.fleetFull,
    required this.armored,
    required this.gpsLevel,
    required this.vaultLevel,
  });

  final List<CitVan> vans;
  final double nextVanPrice;
  final bool fleetFull;

  /// Of het Gepantserd Chassis gekocht is (overvalkans 0%).
  final bool armored;

  /// Level van de Route-optimalisatie GPS (0 tot [kCitRouteUpgradeMaxLevel]).
  final int gpsLevel;

  /// Level van de High-Capacity Kluis (extra stops per rit).
  final int vaultLevel;
}

/// State van de technische dienst: de monteurs, de openstaande storingen
/// en de upgradecontext van het Monteurs-tabblad.
class MaintenanceFleetState {
  const MaintenanceFleetState({
    required this.mechanics,
    required this.nextMechanicPrice,
    required this.crewFull,
    required this.toolkitLevel,
    required this.hasPartsDepot,
    required this.hasReliabilityAnalyst,
    required this.openBreakdowns,
  });

  final List<ServiceMechanic> mechanics;
  final double nextMechanicPrice;
  final bool crewFull;

  /// Level van Gereedschap & Diagnose-software.
  final int toolkitLevel;

  /// Of het Onderdelenmagazijn (preventief onderhoud) vrijgeschakeld is.
  final bool hasPartsDepot;

  /// Of de Storings-Analist in dienst is.
  final bool hasReliabilityAnalyst;

  /// Automaten met een openstaande storing waar nog geen monteur naar
  /// onderweg is: kandidaten voor de handmatige dispatch.
  final List<Atm> openBreakdowns;
}

final citFleetProvider = Provider<CitFleetState>((ref) {
  final s = ref.watch(gameControllerProvider);
  return CitFleetState(
    vans: s.citVans,
    nextVanPrice: s.nextCitVanPrice,
    fleetFull: s.citVans.length >= kMaxCitVans,
    armored: s.upgradeLevel(UpgradeId.armoredChassis) > 0,
    gpsLevel: s.upgradeLevel(UpgradeId.citRoute),
    vaultLevel: s.upgradeLevel(UpgradeId.vaultCapacity),
  );
});

final maintenanceFleetProvider = Provider<MaintenanceFleetState>((ref) {
  final s = ref.watch(gameControllerProvider);
  return MaintenanceFleetState(
    mechanics: s.mechanics,
    nextMechanicPrice: s.nextMechanicPrice,
    crewFull: s.mechanics.length >= kMaxMechanics,
    toolkitLevel: s.upgradeLevel(UpgradeId.toolkit),
    hasPartsDepot: s.upgradeLevel(UpgradeId.partsDepot) > 0,
    hasReliabilityAnalyst: s.hasStaff(StaffId.reliabilityAnalyst),
    openBreakdowns: [
      for (final atm in s.atms)
        if (atm.hasBrokenCassette && !s.hasMechanicEnRouteTo(atm.id)) atm,
    ],
  );
});
