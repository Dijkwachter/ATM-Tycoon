import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../engine/game_controller.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/atm_tile.dart';
import '../widgets/event_banner.dart';
import '../widgets/pill_overlay.dart';
import '../widgets/tactile_button.dart';

/// Kaart-tab (GDD 10): de automaat-tegels met acties, het actieve event en
/// de koopknop voor een nieuwe locatie. Alle acties kunnen vanaf de kaart;
/// de detail-sheet toont alleen extra cijfers.
class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  static const locationNames = {
    LocationType.station: 'Station',
    LocationType.winkel: 'Winkel',
    LocationType.winkelcentrum: 'Winkelcentrum',
    LocationType.horeca: 'Horeca / casino',
    LocationType.evenement: 'Evenement (stadion)',
    LocationType.reizen: 'Reizen (luchthaven)',
    LocationType.zorg: 'Zorg',
    LocationType.snelweg: 'Snelweg',
    LocationType.openbaar: 'Openbaar',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      children: [
        if (state.activeEvent != null)
          EventBanner(event: state.activeEvent!),
        for (final atm in state.atms) ...[
          PillOverlay(feedback: controller.feedback, atmId: atm.id),
          AtmTile(
            state: state,
            atm: atm,
            onRefill: () => controller.refillAtm(atm.id),
            onRepairTap: () => controller.tapRepair(atm.id),
            onMaintain: () => controller.preventiveMaintenance(atm.id),
            onUpgrade: () => controller.upgradeAtmTier(atm.id),
            onOpenDetails: () => _showDetails(context, ref, atm.id),
          ),
        ],
        _BuyAtmCard(
          state: state,
          onBuy: () => _showLocationPicker(context, ref),
        ),
      ],
    );
  }

  void _showDetails(BuildContext context, WidgetRef ref, int atmId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: _AtmDetailSheet(atmId: atmId),
      ),
    );
  }

  void _showLocationPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(gameControllerProvider);
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  'Kies een locatie voor '
                  '${formatEuroCompact(state.nextAtmPrice)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: kTextFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                for (final location in LocationType.values)
                  _LocationRow(
                    location: location,
                    state: state,
                    onPick: () {
                      ref
                          .read(gameControllerProvider.notifier)
                          .buyAtm(location);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.state,
    required this.onPick,
  });

  final LocationType location;
  final GameState state;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final profile = kBusyProfiles[location]!;
    final factor = profile.factorAt(state.hourOfDay);
    final busyLabel = factor >= 1.2
        ? 'druk'
        : factor <= 0.5
            ? 'rustig'
            : 'normaal';
    return Card(
      child: ListTile(
        onTap: onPick,
        title: Text(
          MapScreen.locationNames[location]!,
          style: const TextStyle(
              fontFamily: kTextFont, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'nu $busyLabel - gemiddeld x'
          '${profile.dayAverage.toStringAsFixed(2)}',
          style: const TextStyle(fontFamily: kDigitFont, fontSize: 12),
        ),
        trailing: const Icon(Icons.add_business_outlined,
            color: AppColors.ink),
      ),
    );
  }
}

class _BuyAtmCard extends StatelessWidget {
  const _BuyAtmCard({required this.state, required this.onBuy});

  final GameState state;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final slotsFree = state.atms.length < state.locationSlots;
    final affordable = state.balance >= state.nextAtmPrice;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cabinetShade.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Locaties: ${state.atms.length} van ${state.locationSlots}',
            style: const TextStyle(
              fontFamily: kDigitFont,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TactileButton(
            label: 'Nieuwe automaat',
            sublabel: slotsFree
                ? formatEuroCompact(state.nextAtmPrice)
                : 'sloten vol',
            color: AppColors.gradientBottom,
            textColor: AppColors.ink,
            onPressed: slotsFree && affordable ? onBuy : null,
          ),
        ],
      ),
    );
  }
}

/// Detail-sheet met de detailcijfers van een automaat (GDD 10).
class _AtmDetailSheet extends ConsumerWidget {
  const _AtmDetailSheet({required this.atmId});

  final int atmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final atm = state.atms.where((a) => a.id == atmId).firstOrNull;
    if (atm == null) {
      return const SizedBox.shrink();
    }
    final capacity = atm.capacity(state.upgradeLevel(UpgradeId.cassettes));
    final profile = kBusyProfiles[atm.location]!;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              MapScreen.locationNames[atm.location]!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: kTextFont,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            _detailRow('Inkomen per transactie',
                'EUR ${formatEuro(atm.incomePerTransaction)}'),
            _detailRow('Cassette', '${atm.notesInCassette} van $capacity'),
            _detailRow('Staat', '${(atm.condition * 100).round()}%'),
            _detailRow('Totaal verdiend',
                'EUR ${formatEuro(atm.lifetimeEarned)}'),
            _detailRow('Druktefactor nu',
                'x${profile.factorAt(state.hourOfDay).toStringAsFixed(2)}'),
            _detailRow('Etmaalgemiddelde',
                'x${profile.dayAverage.toStringAsFixed(2)}'),
            if (atm.tier.isRecycler)
              _detailRow('Recycler', 'accepteert stortingen'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: kTextFont)),
          Text(
            value,
            style: const TextStyle(
              fontFamily: kDigitFont,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
