import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/game_controller.dart';
import '../../models/enums.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/tactile_button.dart';

/// Upgrades-tab: netwerk-upgrades (GDD 7.1) en personeel (GDD 7.2).
class UpgradesScreen extends ConsumerWidget {
  const UpgradesScreen({super.key});

  static const _upgradeInfo = {
    UpgradeId.cassettes: (
      'Grotere cassettes',
      '+40% capaciteit per level, minder ritten',
    ),
    UpgradeId.ibns: (
      'Beveiliging (IBNS)',
      '-12% slijtage, -8% voorrijkosten, hogere plofkraak-uitkering',
    ),
    UpgradeId.citRoute: (
      'CIT routeoptimalisatie',
      '-15% ritkosten per level',
    ),
  };

  static const _staffInfo = {
    StaffId.mechanic: (
      'Monteur Sven',
      'Reparaties van 30 naar 12 seconden',
    ),
    StaffId.citPlanner: (
      'CIT-planner Fatima',
      'Vult automatisch bij onder 15% cassette',
    ),
    StaffId.analyst: (
      'Data-analist Kim',
      '+10% inkomen door een slimmere denominatiemix',
    ),
    StaffId.regionalManager: (
      'Regiomanager Joris',
      'Offline inkomen van 50 naar 75%',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        const _SectionTitle('Netwerk-upgrades'),
        for (final id in UpgradeId.values)
          _UpgradeCard(
            title: _upgradeInfo[id]!.$1,
            description: _upgradeInfo[id]!.$2,
            level: state.upgradeLevel(id),
            maxLevel: state.upgrade(id).maxLevel,
            cost: state.upgrade(id).isMaxed
                ? null
                : state.upgrade(id).nextLevelCost,
            affordable: !state.upgrade(id).isMaxed &&
                state.balance >= state.upgrade(id).nextLevelCost,
            onBuy: () => controller.buyUpgrade(id),
          ),
        const _SectionTitle('Personeel'),
        for (final id in StaffId.values)
          _StaffCard(
            title: _staffInfo[id]!.$1,
            description: _staffInfo[id]!.$2,
            hired: state.hasStaff(id),
            price: state.staffMember(id).price,
            affordable: state.balance >= state.staffMember(id).price,
            onHire: () => controller.hireStaff(id),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: kTextFont,
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.title,
    required this.description,
    required this.level,
    required this.maxLevel,
    required this.cost,
    required this.affordable,
    required this.onBuy,
  });

  final String title;
  final String description;
  final int level;
  final int maxLevel;
  final double? cost;
  final bool affordable;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: kTextFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: kTextFont,
                      fontSize: 12,
                      color: AppColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (var i = 0; i < maxLevel; i++)
                        Container(
                          width: 16,
                          height: 6,
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: i < level
                                ? AppColors.gradientBottom
                                : AppColors.ink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: TactileButton(
                label: cost == null ? 'Max' : 'Koop',
                sublabel: cost == null ? null : formatEuroCompact(cost!),
                color: AppColors.ledPanel,
                textColor: AppColors.ledGlow,
                onPressed: affordable ? onBuy : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.title,
    required this.description,
    required this.hired,
    required this.price,
    required this.affordable,
    required this.onHire,
  });

  final String title;
  final String description;
  final bool hired;
  final double price;
  final bool affordable;
  final VoidCallback onHire;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: kTextFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontFamily: kTextFont,
                      fontSize: 12,
                      color: AppColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: hired
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.incomePill, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'In dienst',
                            style: TextStyle(
                              fontFamily: kTextFont,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : TactileButton(
                      label: 'Neem aan',
                      sublabel: formatEuroCompact(price),
                      color: AppColors.serviceButton,
                      onPressed: affordable ? onHire : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
