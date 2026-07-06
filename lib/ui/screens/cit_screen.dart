import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../engine/fleet_providers.dart';
import '../../engine/game_controller.dart';
import '../../models/cit_van.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/shop_cards.dart';
import '../widgets/tactile_button.dart';
import '../widgets/vehicle_tile.dart';

/// CiT-tabblad (Ontwerper dd 2026-07-06): het live vloot-dashboard van de
/// waardetransporten plus de upgrades van de transporttak - vlootuitbreiding,
/// Gepantserd Chassis, Route-optimalisatie GPS en de High-Capacity Kluis.
class CitScreen extends ConsumerWidget {
  const CitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleet = ref.watch(citFleetProvider);
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        const SectionTitle('Vloot'),
        _FleetDashboard(fleet: fleet, state: state),
        const SectionTitle('Upgrades & beveiliging'),
        _buyVanCard(fleet, state, controller),
        _upgradeCard(
          state,
          controller,
          UpgradeId.armoredChassis,
          'Gepantserd Chassis',
          'Overvallen tijdens de rit volledig afgeweerd (kans naar 0%)',
        ),
        _upgradeCard(
          state,
          controller,
          UpgradeId.citRoute,
          'Route-optimalisatie GPS',
          '-${(kCitRouteDiscountPerLevel * 100).round()}% reistijd en '
              'ritkosten per level',
        ),
        _upgradeCard(
          state,
          controller,
          UpgradeId.vaultCapacity,
          'High-Capacity Kluis',
          'Een wagen bevoorraadt +1 automaat per rit per level '
              '(route-planning)',
        ),
        const SectionTitle('Personeel'),
        _staffCard(
          state,
          controller,
          StaffId.citPlanner,
          'CIT-planner Fatima',
          'Stuurt automatisch een wagen zodra een automaat onder '
              '${(kCitPlannerRefillThreshold * 100).round()}% voorraad zakt',
        ),
      ],
    );
  }

  Widget _buyVanCard(
    CitFleetState fleet,
    GameState state,
    GameController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vloot Uitbreiding: extra waardetransporten lossen meerdere '
              'bevoorradingen tegelijk op.',
              style: TextStyle(
                fontFamily: kTextFont,
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TactileButton(
              label: fleet.fleetFull ? 'Vloot compleet' : 'Koop geldwagen',
              sublabel: fleet.fleetFull
                  ? '$kMaxCitVans wagens'
                  : formatEuroCompact(fleet.nextVanPrice),
              color: AppColors.serviceButton,
              onPressed: !fleet.fleetFull && state.balance >= fleet.nextVanPrice
                  ? controller.buyCitVan
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _upgradeCard(
    GameState state,
    GameController controller,
    UpgradeId id,
    String title,
    String description,
  ) {
    final upgrade = state.upgrade(id);
    return UpgradeCard(
      title: title,
      description: description,
      level: upgrade.level,
      maxLevel: upgrade.maxLevel,
      cost: upgrade.isMaxed ? null : upgrade.nextLevelCost,
      affordable: !upgrade.isMaxed && state.balance >= upgrade.nextLevelCost,
      onBuy: () => controller.buyUpgrade(id),
    );
  }

  Widget _staffCard(
    GameState state,
    GameController controller,
    StaffId id,
    String title,
    String description,
  ) {
    final member = state.staffMember(id);
    return StaffCard(
      title: title,
      description: description,
      hired: member.hired,
      price: member.price,
      affordable: state.balance >= member.price,
      onHire: () => controller.hireStaff(id),
    );
  }
}

/// Live dashboard: per waardetransport de status met voortgangsbalk.
class _FleetDashboard extends StatelessWidget {
  const _FleetDashboard({required this.fleet, required this.state});

  final CitFleetState fleet;
  final GameState state;

  (String, double) _statusAndProgress(CitVan van) {
    final target = state.atms.where((a) => a.id == van.targetAtmId).firstOrNull;
    final where = target == null
        ? ''
        : ' ${kShortLocationNames[target.location]}';
    final travel = target == null ? 1 : state.travelTicksTo(target.location);
    return switch (van.status) {
      CitVanStatus.idle => ('Idle - stand-by bij het depot', 1.0),
      CitVanStatus.transitToAtm => (
        'Onderweg naar ATM$where',
        1 - van.ticksRemaining / travel,
      ),
      CitVanStatus.servicing => (
        'Bezig met vullen...$where',
        1 - van.ticksRemaining / kServicingDurationTicks,
      ),
      CitVanStatus.returning => (
        'Terugreis naar depot',
        1 - van.ticksRemaining / travel,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final van in fleet.vans)
              Builder(
                builder: (context) {
                  final (label, progress) = _statusAndProgress(van);
                  return VehicleTile(
                    name: 'Waardetransport ${van.id + 1}',
                    icon: Icons.local_shipping_outlined,
                    status: van.status,
                    statusLabel: label,
                    progress: progress,
                    ticksRemaining: van.ticksRemaining,
                  );
                },
              ),
            if (fleet.armored)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 14,
                      color: AppColors.incomePill,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Gepantserd chassis actief: overvalkans 0%',
                      style: TextStyle(
                        fontFamily: kTextFont,
                        fontSize: 11.5,
                        color: AppColors.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
