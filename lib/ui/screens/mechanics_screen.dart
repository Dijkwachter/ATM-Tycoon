import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../engine/fleet_providers.dart';
import '../../engine/game_controller.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../../models/mechanic.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/shop_cards.dart';
import '../widgets/tactile_button.dart';
import '../widgets/vehicle_tile.dart';

/// Monteurs-tabblad (Ontwerper dd 2026-07-06): het live storings-dashboard
/// van de technische dienst - servicebussen met status, openstaande
/// storingen met handmatige dispatch - plus de upgrades van deze tak:
/// vlootuitbreiding, Gereedschap & Diagnose-software, het
/// Onderdelenmagazijn en de Storings-Analist.
class MechanicsScreen extends ConsumerWidget {
  const MechanicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crew = ref.watch(maintenanceFleetProvider);
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        const SectionTitle('Servicebussen'),
        _CrewDashboard(crew: crew, state: state),
        if (crew.openBreakdowns.isNotEmpty) ...[
          const SectionTitle('Openstaande storingen'),
          _BreakdownsCard(crew: crew, state: state, controller: controller),
        ],
        const SectionTitle('Upgrades & gereedschap'),
        _buyMechanicCard(crew, state, controller),
        _upgradeCard(
          state,
          controller,
          UpgradeId.toolkit,
          'Gereedschap & Diagnose-software',
          '-${(kToolkitReductionPerLevel * 100).round()}% reparatietijd op '
              'locatie per level (nu ${state.repairDurationSeconds}s)',
        ),
        _upgradeCard(
          state,
          controller,
          UpgradeId.partsDepot,
          'Onderdelenmagazijn',
          'Monteurs rijden automatisch preventief uit onder '
              '${(kPartsDepotThreshold * 100).round()}% conditie, zonder '
              'voorrijkosten',
        ),
        const SectionTitle('Personeel'),
        _staffCard(
          state,
          controller,
          StaffId.mechanic,
          'Monteur Sven',
          'Reparaties van $kRepairDurationSeconds naar '
              '$kRepairDurationMechanicSeconds seconden',
        ),
        _staffCard(
          state,
          controller,
          StaffId.reliabilityAnalyst,
          'Storings-Analist',
          'Notificatie en audio-alert zodra een cassette verhoogd '
              'storingsrisico vertoont (onder '
              '${(kJamRiskConditionThreshold * 100).round()}% conditie)',
        ),
      ],
    );
  }

  Widget _buyMechanicCard(
    MaintenanceFleetState crew,
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
              'Monteursauto Vloot: extra servicebussen lossen meerdere '
              'storingen tegelijkertijd op.',
              style: TextStyle(
                fontFamily: kTextFont,
                fontSize: 12,
                color: AppColors.ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TactileButton(
              label: crew.crewFull ? 'Ploeg compleet' : 'Koop servicebus',
              sublabel: crew.crewFull
                  ? '$kMaxMechanics monteurs'
                  : formatEuroCompact(crew.nextMechanicPrice),
              color: AppColors.warning,
              onPressed:
                  !crew.crewFull && state.balance >= crew.nextMechanicPrice
                  ? controller.buyMechanic
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

/// Live dashboard van de servicebussen: Depot (stand-by), Spoedrit naar
/// een storing, Preventief Onderhoud (Onderdelenmagazijn) of terugreis.
class _CrewDashboard extends StatelessWidget {
  const _CrewDashboard({required this.crew, required this.state});

  final MaintenanceFleetState crew;
  final GameState state;

  (String, double) _statusAndProgress(ServiceMechanic mechanic) {
    final target = state.atms
        .where((a) => a.id == mechanic.targetAtmId)
        .firstOrNull;
    final where = target == null
        ? ''
        : ' ${kShortLocationNames[target.location]}';
    final travel = target == null ? 1 : state.travelTicksTo(target.location);
    // Spoedrit bij een openstaande storing; anders is het een preventieve
    // onderhoudsrit van het Onderdelenmagazijn.
    final emergency = target?.hasBrokenCassette ?? true;
    return switch (mechanic.status) {
      CitVanStatus.idle => ('Depot - stand-by', 1.0),
      CitVanStatus.transitToAtm => (
        emergency
            ? 'Spoedrit naar$where - ATM storing'
            : 'Preventief Onderhoud bij$where',
        1 - mechanic.ticksRemaining / travel,
      ),
      CitVanStatus.servicing => (
        emergency ? 'Reparatie bij$where' : 'Onderhoud bij$where',
        1 - mechanic.ticksRemaining / state.repairDurationSeconds,
      ),
      CitVanStatus.returning => (
        'Terugreis naar depot',
        1 - mechanic.ticksRemaining / travel,
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
            for (final mechanic in crew.mechanics)
              Builder(
                builder: (context) {
                  final (label, progress) = _statusAndProgress(mechanic);
                  return VehicleTile(
                    name: 'Servicebus ${mechanic.id + 1}',
                    icon: Icons.engineering_outlined,
                    status: mechanic.status,
                    statusLabel: label,
                    progress: progress,
                    ticksRemaining: mechanic.ticksRemaining,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Openstaande storingen waar nog geen monteur naar onderweg is, met een
/// handmatige dispatch-knop per automaat.
class _BreakdownsCard extends StatelessWidget {
  const _BreakdownsCard({
    required this.crew,
    required this.state,
    required this.controller,
  });

  final MaintenanceFleetState crew;
  final GameState state;
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final hasIdleMechanic = crew.mechanics.any((m) => m.isIdle);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final atm in crew.openBreakdowns)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.report_problem_outlined,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ATM ${atm.id + 1} - '
                        '${kShortLocationNames[atm.location]}',
                        style: const TextStyle(
                          fontFamily: kTextFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 132,
                      child: TactileButton(
                        label: 'Stuur monteur',
                        sublabel: hasIdleMechanic ? null : 'geen bus vrij',
                        color: AppColors.warning,
                        onPressed: hasIdleMechanic
                            ? () => controller.sendMechanic(atm.id)
                            : null,
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
