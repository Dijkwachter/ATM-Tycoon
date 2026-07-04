import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../engine/game_controller.dart';
import '../../models/cit_van.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/tactile_button.dart';

/// Financien-tab: banken en contracten (GDD 8), mijlpalen en het
/// bijvuldoel (GDD 9.2) en prestige met dubbele tikbevestiging (GDD 9.3).
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  static const _bankNames = {
    BankId.oranje: 'Bank Oranje',
    BankId.rivier: 'Rivierbank',
    BankId.noorder: 'Noorderbank',
    BankId.zuider: 'Zuiderbank',
  };

  static const _shortLocationNames = {
    LocationType.station: 'Station',
    LocationType.winkel: 'Winkel',
    LocationType.winkelcentrum: 'Centrum',
    LocationType.horeca: 'Horeca',
    LocationType.evenement: 'Stadion',
    LocationType.reizen: 'Luchthaven',
    LocationType.zorg: 'Zorg',
    LocationType.snelweg: 'Snelweg',
    LocationType.openbaar: 'Openbaar',
  };

  static String _shortLocation(LocationType location) =>
      _shortLocationNames[location]!;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      children: [
        _OverviewCard(state: state),
        const _SectionTitle('CIT-vloot'),
        _FleetCard(state: state, onBuyVan: controller.buyCitVan),
        const _SectionTitle('Banken en contracten'),
        for (final id in BankId.values)
          _BankCard(
            name: _bankNames[id]!,
            state: state,
            bankId: id,
            onNegotiate: () => controller.negotiateBankContract(id),
            onConnect: controller.connectZuiderbank,
          ),
        const _SectionTitle('Doelen'),
        _MilestoneCard(state: state),
        _RefillGoalCard(state: state),
        const _SectionTitle('Prestige'),
        _PrestigeCard(state: state, onPrestige: controller.prestige),
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _row('Saldo', 'EUR ${formatEuro(state.balance)}'),
            _row('Totaal verdiend', 'EUR ${formatEuro(state.totalEarned)}'),
            _row(
              'Cash in cassettes (float)',
              'EUR ${formatEuro(state.totalFloatValue, decimals: 0)}',
            ),
            _row('CIT-rit', 'EUR ${formatEuroCompact(state.citTripCost)}'),
            if (state.prestigeLevel > 0)
              _row(
                'Prestigebonus',
                '+${(state.prestigeLevel * kPrestigeBonusPerLevel * 100).round()}%',
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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

/// Vlootbeheer (Ontwerper dd 2026-07-04): per geldwagen de status, plus de
/// koopknop voor een extra wagen. Zijn alle wagens onderweg, dan kan er
/// nergens acuut geserviced worden - dat is precies de spanning.
class _FleetCard extends StatelessWidget {
  const _FleetCard({required this.state, required this.onBuyVan});

  final GameState state;
  final VoidCallback onBuyVan;

  String _vanStatus(CitVan van) {
    final target = state.atms.where((a) => a.id == van.targetAtmId).firstOrNull;
    final where = target == null
        ? ''
        : ' - ${FinanceScreen._shortLocation(target.location)}';
    return switch (van.status) {
      CitVanStatus.idle => 'stand-by bij het depot',
      CitVanStatus.transitToAtm => 'onderweg$where (${van.ticksRemaining}s)',
      CitVanStatus.servicing => 'servicing$where (${van.ticksRemaining}s)',
      CitVanStatus.returning => 'terugreis (${van.ticksRemaining}s)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final fleetFull = state.citVans.length >= kMaxCitVans;
    final affordable = state.balance >= state.nextCitVanPrice;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final van in state.citVans)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 18,
                      color: van.isIdle
                          ? AppColors.incomePill
                          : AppColors.ink.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Wagen ${van.id + 1}',
                      style: const TextStyle(
                        fontFamily: kTextFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _vanStatus(van),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontFamily: kDigitFont,
                          fontSize: 11.5,
                          color: AppColors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TactileButton(
              label: fleetFull ? 'Vloot compleet' : 'Koop geldwagen',
              sublabel: fleetFull
                  ? '$kMaxCitVans wagens'
                  : formatEuroCompact(state.nextCitVanPrice),
              color: AppColors.serviceButton,
              onPressed: !fleetFull && affordable ? onBuyVan : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({
    required this.name,
    required this.state,
    required this.bankId,
    required this.onNegotiate,
    required this.onConnect,
  });

  final String name;
  final GameState state;
  final BankId bankId;
  final VoidCallback onNegotiate;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final bank = state.bank(bankId);
    final share = state.bankShares[bankId];

    final Widget action;
    if (!bank.connected) {
      final unlockable =
          state.playerLevel.index >= PlayerLevel.regio.index &&
          state.balance >= kZuiderbankUnlockCost;
      action = TactileButton(
        label: 'Sluit aan',
        sublabel: formatEuroCompact(kZuiderbankUnlockCost),
        color: AppColors.dccPill,
        onPressed: unlockable ? onConnect : null,
      );
    } else if (bank.canNegotiate) {
      action = TactileButton(
        label: 'Onderhandel',
        sublabel: formatEuroCompact(bank.negotiationCost),
        color: AppColors.ledPanel,
        textColor: AppColors.ledGlow,
        onPressed: state.balance >= bank.negotiationCost ? onNegotiate : null,
      );
    } else {
      action = const Text(
        'Max',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: kTextFont, fontWeight: FontWeight.w700),
      );
    }

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
                    name,
                    style: const TextStyle(
                      fontFamily: kTextFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bank.connected
                        ? 'aandeel ${((share ?? 0) * 100).round()}% - tarief '
                              'x${bank.effectiveRate.toStringAsFixed(2)} - '
                              'level ${bank.contractLevel}'
                        : 'nog niet aangesloten - unlock vanaf level Regio',
                    style: TextStyle(
                      fontFamily: kDigitFont,
                      fontSize: 11.5,
                      color: AppColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 108, child: action),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final done = state.milestonesClaimed >= kMilestoneThresholds.length;
    final target = done ? null : kMilestoneThresholds[state.milestonesClaimed];
    final reward = done ? null : kMilestoneRewards[state.milestonesClaimed];
    final progress = target == null
        ? 1.0
        : (state.totalEarned / target).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Volgende mijlpaal',
                  style: TextStyle(
                    fontFamily: kTextFont,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  done
                      ? 'alle mijlpalen gehaald'
                      : '${formatEuroCompact(target!)} '
                            '(+${formatEuroCompact(reward!)})',
                  style: const TextStyle(
                    fontFamily: kDigitFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.ink.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.gradientBottom,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefillGoalCard extends StatelessWidget {
  const _RefillGoalCard({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bijvuldoel: ${state.refillGoalProgress} van '
              '${state.refillGoalTarget}',
              style: const TextStyle(
                fontFamily: kTextFont,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '+${formatEuroCompact(state.refillGoalReward)}',
              style: const TextStyle(
                fontFamily: kDigitFont,
                fontWeight: FontWeight.w700,
                color: AppColors.incomePill,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prestige-kaart met de verplichte dubbele tikbevestiging (GDD 9.3):
/// de eerste tik wapent de knop, de tweede verkoopt het netwerk. Na drie
/// seconden ontwapent de knop zichzelf.
class _PrestigeCard extends StatefulWidget {
  const _PrestigeCard({required this.state, required this.onPrestige});

  final GameState state;
  final VoidCallback onPrestige;

  @override
  State<_PrestigeCard> createState() => _PrestigeCardState();
}

class _PrestigeCardState extends State<_PrestigeCard> {
  bool _armed = false;
  Timer? _disarmTimer;

  @override
  void dispose() {
    _disarmTimer?.cancel();
    super.dispose();
  }

  void _tap() {
    if (!_armed) {
      setState(() => _armed = true);
      _disarmTimer?.cancel();
      _disarmTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _armed = false);
        }
      });
      return;
    }
    _disarmTimer?.cancel();
    setState(() => _armed = false);
    widget.onPrestige();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.state.totalEarned >= kPrestigeThreshold;
    final progress = (widget.state.totalEarned / kPrestigeThreshold).clamp(
      0.0,
      1.0,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verkoop het netwerk voor een permanente bonus van '
              '+${(kPrestigeBonusPerLevel * 100).round()}% per '
              'prestigelevel. De eerste prestige ontgrendelt het 100 euro '
              'biljet. Bankcontractlevels blijven behouden.',
              style: TextStyle(
                fontFamily: kTextFont,
                fontSize: 12.5,
                color: AppColors.ink.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.ink.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.recyclingPill,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TactileButton(
              label: _armed
                  ? 'Tik nogmaals om te verkopen'
                  : 'Prestige (level ${widget.state.prestigeLevel})',
              sublabel: unlocked
                  ? null
                  : 'vanaf ${formatEuroCompact(kPrestigeThreshold)} '
                        'totaal verdiend',
              color: _armed ? AppColors.warning : AppColors.recyclingPill,
              onPressed: unlocked ? _tap : null,
            ),
          ],
        ),
      ),
    );
  }
}
