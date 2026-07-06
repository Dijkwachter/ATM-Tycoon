import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/game_controller.dart';
import '../../models/enums.dart';
import '../widgets/shop_cards.dart';

/// Upgrades-tab: netwerk-upgrades (GDD 7.1) en personeel (GDD 7.2).
///
/// Tak-specifieke upgrades en personeel staan op hun eigen tabblad
/// (Ontwerper dd 2026-07-06): de CIT-upgrades en planner Fatima op CiT,
/// de monteurs-upgrades, Sven en de Storings-Analist op Monteurs. De
/// oude cassette-upgrade is vervangen door losse cassettes per automaat
/// (detailscherm); het enum-slot bestaat nog voor oude saves maar de UI
/// verbergt hem.
class UpgradesScreen extends ConsumerWidget {
  const UpgradesScreen({super.key});

  static const _upgradeInfo = {
    UpgradeId.ibns: (
      'Beveiliging (IBNS)',
      '-12% slijtage, -8% voorrijkosten, hogere plofkraak-uitkering',
    ),
  };

  static const _staffInfo = {
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
        const SectionTitle('Netwerk-upgrades'),
        for (final id in UpgradeId.values)
          if (_upgradeInfo.containsKey(id))
            UpgradeCard(
              title: _upgradeInfo[id]!.$1,
              description: _upgradeInfo[id]!.$2,
              level: state.upgradeLevel(id),
              maxLevel: state.upgrade(id).maxLevel,
              cost: state.upgrade(id).isMaxed
                  ? null
                  : state.upgrade(id).nextLevelCost,
              affordable:
                  !state.upgrade(id).isMaxed &&
                  state.balance >= state.upgrade(id).nextLevelCost,
              onBuy: () => controller.buyUpgrade(id),
            ),
        const SectionTitle('Personeel'),
        for (final id in StaffId.values)
          if (_staffInfo.containsKey(id))
            StaffCard(
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
