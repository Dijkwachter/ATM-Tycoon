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
import '../widgets/land_map.dart';
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
        if (state.activeEvent != null) EventBanner(event: state.activeEvent!),
        if (state.atms.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.cabinetShade.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Welkom! Je start met ${formatEuroCompact(state.balance)}. '
              'Koop hieronder je eerste automaat: kies een drukke locatie '
              'voor snel geld, of een rustige die de nacht doorverdient.',
              style: const TextStyle(fontFamily: kTextFont, fontSize: 14),
            ),
          ),
        for (final atm in state.atms) ...[
          PillOverlay(feedback: controller.feedback, atmId: atm.id),
          AtmTile(
            state: state,
            atm: atm,
            onService: () => controller.requestService(atm.id),
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
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: _AtmDetailSheet(atmId: atmId),
      ),
    );
  }

  /// Koopflow via de landkaart (Ontwerper dd 2026-07-04): tik op een
  /// locatie in een open zone om daar te bouwen; zones die de Nationale
  /// Bank blokkeert (spreidingswet) kleuren rood met een slot.
  void _showLocationPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(gameControllerProvider);
          final approval = (state.spreadApproval * 100).round();
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
                const SizedBox(height: 4),
                Text(
                  'Nationale Bank spreidingsscore: $approval%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kDigitFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: approval < 50
                        ? AppColors.warning
                        : AppColors.ink.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                LandMap(
                  state: state,
                  onPickLocation: (location) {
                    ref.read(gameControllerProvider.notifier).buyAtm(location);
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),
                _PickerBusyHint(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Compacte druktehint onder de kaart: welke locaties nu druk of rustig
/// zijn (GDD 5), zodat de kaart zelf schoon blijft.
class _PickerBusyHint extends StatelessWidget {
  const _PickerBusyHint({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final busy = <String>[];
    final quiet = <String>[];
    for (final location in LocationType.values) {
      final factor = kBusyProfiles[location]!.factorAt(state.hourOfDay);
      if (factor >= 1.2) {
        busy.add(LandMap.shortLocationNames[location]!);
      } else if (factor <= 0.5) {
        quiet.add(LandMap.shortLocationNames[location]!);
      }
    }
    return Text(
      [
        if (busy.isNotEmpty) 'Nu druk: ${busy.join(', ')}',
        if (quiet.isNotEmpty) 'rustig: ${quiet.join(', ')}',
      ].join(' - '),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: kTextFont,
        fontSize: 11.5,
        color: AppColors.ink.withValues(alpha: 0.7),
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

/// Detail-sheet met de detailcijfers van een automaat (GDD 10) en het
/// cassettebeheer: losse slots met elk hun vulling en staat, plus de
/// koopknop voor een extra cassette (Ontwerper dd 2026-07-04).
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
    final profile = kBusyProfiles[atm.location]!;
    final slotsFree = atm.cassettes.length < kMaxCassettesPerAtm;
    final canBuyCassette = slotsFree && state.balance >= kExtraCassettePrice;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: SingleChildScrollView(
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
              _detailRow(
                'Inkomen per transactie',
                'EUR ${formatEuro(atm.incomePerTransaction)}',
              ),
              _detailRow(
                'Cassette',
                '${formatEuro((atm.availableNotes * kNotesPerUnit).toDouble(), decimals: 0)}'
                    ' van '
                    '${formatEuro((atm.capacity * kNotesPerUnit).toDouble(), decimals: 0)}'
                    ' biljetten',
              ),
              _detailRow('Staat', '${(atm.condition * 100).round()}%'),
              _detailRow(
                'Totaal verdiend',
                'EUR ${formatEuro(atm.lifetimeEarned)}',
              ),
              _detailRow(
                'Druktefactor nu',
                'x${profile.factorAt(state.hourOfDay).toStringAsFixed(2)}',
              ),
              _detailRow(
                'Etmaalgemiddelde',
                'x${profile.dayAverage.toStringAsFixed(2)}',
              ),
              if (atm.tier.isRecycler)
                _detailRow('Recycler', 'accepteert stortingen'),
              const SizedBox(height: 10),
              for (var i = 0; i < atm.cassettes.length; i++)
                _detailRow(
                  'Slot ${i + 1}',
                  atm.cassettes[i].isBroken
                      ? 'storing '
                            '${atm.cassettes[i].repairSecondsRemaining.ceil()}s'
                      : '${formatEuro((atm.cassettes[i].notes * kNotesPerUnit).toDouble(), decimals: 0)}'
                            ' biljetten - staat '
                            '${(atm.cassettes[i].condition * 100).round()}%',
                ),
              const SizedBox(height: 10),
              TactileButton(
                label:
                    'Extra cassette '
                    '(${atm.cassettes.length} van $kMaxCassettesPerAtm)',
                sublabel: slotsFree
                    ? '${formatEuroCompact(kExtraCassettePrice)} - '
                          'leeg geleverd'
                    : 'alle slots bezet',
                color: AppColors.gradientBottom,
                textColor: AppColors.ink,
                onPressed: canBuyCassette
                    ? () => ref
                          .read(gameControllerProvider.notifier)
                          .buyCassette(atmId)
                    : null,
              ),
            ],
          ),
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
