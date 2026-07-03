import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/atm.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../format.dart';
import '../theme.dart';
import 'tactile_button.dart';

/// Automaat-tegel (GDD 10): een gele kast in de headergradient, volle
/// breedte, met automaat-anatomie, cassette- en slijtagebalk en drie
/// actieknoppen. Een druk- of rustig-label toont de dagcyclus (GDD 5).
class AtmTile extends StatelessWidget {
  const AtmTile({
    super.key,
    required this.state,
    required this.atm,
    required this.onRefill,
    required this.onRepairTap,
    required this.onMaintain,
    required this.onUpgrade,
    this.onOpenDetails,
  });

  final GameState state;
  final Atm atm;
  final VoidCallback? onRefill;
  final VoidCallback? onRepairTap;
  final VoidCallback? onMaintain;
  final VoidCallback? onUpgrade;
  final VoidCallback? onOpenDetails;

  int get _capacity => atm.capacity(state.upgradeLevel(UpgradeId.cassettes));

  double get _busyFactor =>
      kBusyProfiles[atm.location]!.factorAt(state.hourOfDay);

  /// Minuten tot de cassette leeg is bij de huidige drukte.
  double get _minutesUntilEmpty {
    final chance = (kTransactionChancePerSecond * _busyFactor)
        .clamp(0.0, kTransactionChanceCap);
    var drainPerSecond = chance * kAvgNotesPerTransaction;
    if (state.hundredEuroNoteActive) {
      drainPerSecond *= kHundredEuroNoteDrainMultiplier;
    }
    if (drainPerSecond <= 0) {
      return double.infinity;
    }
    return atm.notesInCassette / drainPerSecond / 60;
  }

  /// Kast-uiterlijk per tier: de instapkast is vlak geel, vanaf lobby plus
  /// glanst de gradient, de TTW-units krijgen een stalen muurframe en de
  /// recycler gloeit goud. AnimatedContainer laat een upgrade vloeiend
  /// overgaan in de nieuwe kast.
  BoxDecoration _cabinetDecoration() {
    final radius = BorderRadius.circular(16);
    const dropShadow = BoxShadow(
      color: Color(0x22000000),
      blurRadius: 5,
      offset: Offset(0, 2),
    );
    return switch (atm.tier) {
      AtmTier.lobbyBasic => BoxDecoration(
          color: AppColors.cabinetBasic,
          borderRadius: radius,
          border: Border.all(color: AppColors.cabinetShade, width: 1),
          boxShadow: const [dropShadow],
        ),
      AtmTier.lobbyPlus => BoxDecoration(
          gradient: kHeaderGradient,
          borderRadius: radius,
          border: Border.all(color: AppColors.cabinetShade, width: 1),
          boxShadow: const [dropShadow],
        ),
      AtmTier.ttwUnit => BoxDecoration(
          gradient: kHeaderGradient,
          borderRadius: radius,
          border: Border.all(color: AppColors.steel, width: 5),
          boxShadow: const [dropShadow],
        ),
      AtmTier.ttwRecycler => BoxDecoration(
          gradient: kHeaderGradient,
          borderRadius: radius,
          border: Border.all(color: AppColors.steel, width: 5),
          boxShadow: const [
            dropShadow,
            BoxShadow(color: Color(0x66FFD75E), blurRadius: 14),
          ],
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenDetails,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: _cabinetDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitleRow(atm: atm, busyFactor: _busyFactor),
            const SizedBox(height: 8),
            _Anatomy(atm: atm, state: state),
            const SizedBox(height: 10),
            _CassetteBar(
              notes: atm.notesInCassette,
              capacity: _capacity,
              minutesUntilEmpty: _minutesUntilEmpty,
            ),
            const SizedBox(height: 6),
            _WearBar(condition: atm.condition),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _servicingButton()),
                const SizedBox(width: 8),
                Expanded(child: _maintenanceButton()),
                const SizedBox(width: 8),
                Expanded(child: _upgradeButton()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _servicingButton() {
    final canRefill = atm.notesInCassette < _capacity &&
        state.balance >= state.citTripCost;
    return TactileButton(
      label: 'Servicing',
      sublabel: formatEuroCompact(state.citTripCost),
      color: AppColors.serviceButton,
      onPressed: canRefill ? onRefill : null,
    );
  }

  /// Contextuele middenknop (GDD 10): meehelpen bij reparatie, anders
  /// preventief onderhoud onder 90% staat.
  Widget _maintenanceButton() {
    if (atm.isBroken) {
      return TactileButton(
        label: 'Help mee',
        sublabel: '${atm.repairSecondsRemaining.ceil()}s',
        color: AppColors.warning,
        onPressed: onRepairTap,
      );
    }
    final available = atm.isOperational &&
        atm.condition < kPreventiveMaintenanceThreshold;
    return TactileButton(
      label: 'Onderhoud',
      sublabel: 'gratis',
      color: AppColors.ink,
      onPressed: available ? onMaintain : null,
    );
  }

  Widget _upgradeButton() {
    final next = atm.tier.next;
    final cost = next == null ? null : kTierUpgradeCost[next.index];
    final canUpgrade = cost != null && state.balance >= cost;
    return TactileButton(
      label: 'Upgrade',
      sublabel: cost == null ? 'max' : formatEuroCompact(cost),
      color: AppColors.ledPanel,
      textColor: AppColors.ledGlow,
      onPressed: canUpgrade ? onUpgrade : null,
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.atm, required this.busyFactor});

  final Atm atm;
  final double busyFactor;

  static const _tierNames = [
    'Lobby basic',
    'Lobby plus',
    'TTW unit',
    'TTW recycler',
  ];

  static const _locationNames = {
    LocationType.station: 'Station',
    LocationType.winkel: 'Winkel',
    LocationType.winkelcentrum: 'Winkelcentrum',
    LocationType.horeca: 'Horeca',
    LocationType.evenement: 'Evenement',
    LocationType.reizen: 'Luchthaven',
    LocationType.zorg: 'Zorg',
    LocationType.snelweg: 'Snelweg',
    LocationType.openbaar: 'Openbaar',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_locationNames[atm.location]} - '
            '${_tierNames[atm.tier.index]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: kTextFont,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
        ),
        _TierPips(tier: atm.tier),
        const SizedBox(width: 6),
        if (busyFactor >= 1.2)
          const _BusyLabel(label: 'druk', color: AppColors.incomePill)
        else if (busyFactor <= 0.5)
          const _BusyLabel(label: 'rustig', color: AppColors.cabinetShade),
      ],
    );
  }
}

/// Vier pips die de tier-voortgang van deze kast tonen: gevuld tot en met
/// de huidige tier, gedoofd daarboven.
class _TierPips extends StatelessWidget {
  const _TierPips({required this.tier});

  final AtmTier tier;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final t in AtmTier.values)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.index <= tier.index
                  ? AppColors.ink
                  : AppColors.ink.withValues(alpha: 0.18),
            ),
          ),
      ],
    );
  }
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: kTextFont,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// De automaat-anatomie (GDD 10): donker schermpje met status en verdiend
/// bedrag in LED-cijfers, pinpad van zes donkere toetsen, pasjessleuf en
/// geldsleuf met donkere geleiders.
class _Anatomy extends StatelessWidget {
  const _Anatomy({required this.atm, required this.state});

  final Atm atm;
  final GameState state;

  String get _status {
    if (atm.isBroken) {
      return 'STORING ${atm.repairSecondsRemaining.ceil()}s';
    }
    if (atm.isPausedByOutage) {
      return 'STROOM UIT ${atm.outageSecondsRemaining.ceil()}s';
    }
    if (atm.notesInCassette == 0) {
      return 'CASSETTE LEEG';
    }
    return 'IN BEDRIJF';
  }

  @override
  Widget build(BuildContext context) {
    final alert = atm.isBroken ||
        atm.isPausedByOutage ||
        atm.notesInCassette == 0;
    final tier = atm.tier;
    // De anatomie groeit mee met de tier: vanaf lobby plus een derde
    // toetsenrij en contactless, vanaf TTW een camera, en alleen de
    // recycler heeft een stortsleuf (GDD 3.3).
    final hasThirdKeyColumn = tier.index >= AtmTier.lobbyPlus.index;
    final hasContactless = tier.index >= AtmTier.lobbyPlus.index;
    final hasCamera = tier.index >= AtmTier.ttwUnit.index;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Schermpje, met camera-dot op de TTW-units.
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.ledPanel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cabinetShade),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ledDigits(
                          11,
                          color:
                              alert ? AppColors.warning : AppColors.ledGlow,
                        ),
                      ),
                    ),
                    if (hasCamera)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.ledDim,
                          border: Border.all(
                            color: AppColors.steel,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  formatEuro(atm.lifetimeEarned),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ledDigits(15),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Pinpad: zes toetsen, vanaf lobby plus negen.
        Column(
          children: [
            for (var row = 0; row < 3; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    for (var col = 0;
                        col < (hasThirdKeyColumn ? 3 : 2);
                        col++)
                      Container(
                        width: hasThirdKeyColumn ? 11 : 15,
                        height: 11,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: AppColors.ledPanel,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        // Pasjessleuf (met contactless vanaf lobby plus), geldsleuf en op
        // de recycler een groene stortsleuf.
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.ledPanel,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (hasContactless) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.contactless_outlined,
                      size: 12,
                      color: AppColors.ledPanel,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.gradientBottom,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.ledPanel, width: 2.5),
                ),
              ),
              if (tier.isRecycler) ...[
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: AppColors.incomePill,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'STORT',
                      style: TextStyle(
                        fontFamily: kDigitFont,
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.incomePill,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Cassettebalk met biljettenteller (N van M) en leeg-over-indicator,
/// rood onder 1,5 minuut (GDD 10).
class _CassetteBar extends StatelessWidget {
  const _CassetteBar({
    required this.notes,
    required this.capacity,
    required this.minutesUntilEmpty,
  });

  final int notes;
  final int capacity;
  final double minutesUntilEmpty;

  @override
  Widget build(BuildContext context) {
    final urgent = minutesUntilEmpty < 1.5;
    final label = minutesUntilEmpty.isFinite
        ? 'leeg over ${minutesUntilEmpty.toStringAsFixed(1)} min'
        : 'stabiel';
    return _LabeledBar(
      fraction: capacity == 0 ? 0 : notes / capacity,
      color: urgent ? AppColors.warning : AppColors.incomePill,
      left: 'Cassette $notes van $capacity',
      right: notes == 0 ? 'leeg' : label,
      rightColor: urgent ? AppColors.warning : null,
    );
  }
}

/// Slijtagebalk (GDD 10).
class _WearBar extends StatelessWidget {
  const _WearBar({required this.condition});

  final double condition;

  @override
  Widget build(BuildContext context) {
    final low = condition < 0.25;
    return _LabeledBar(
      fraction: condition,
      color: low ? AppColors.warning : AppColors.dccPill,
      left: 'Staat ${(condition * 100).round()}%',
      right: condition < kPreventiveMaintenanceThreshold
          ? 'onderhoud beschikbaar'
          : '',
    );
  }
}

class _LabeledBar extends StatelessWidget {
  const _LabeledBar({
    required this.fraction,
    required this.color,
    required this.left,
    required this.right,
    this.rightColor,
  });

  final double fraction;
  final Color color;
  final String left;
  final String right;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontFamily: kDigitFont,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left, style: labelStyle),
            Text(
              right,
              style: labelStyle.copyWith(
                color: rightColor ?? AppColors.ink.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 7,
            backgroundColor: AppColors.ink.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
