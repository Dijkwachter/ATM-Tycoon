import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/atm.dart';
import '../../models/cit_van.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../format.dart';
import '../theme.dart';
import 'tactile_button.dart';

/// Automaat-tegel (GDD 10): een gele kast in de headergradient, volle
/// breedte, met automaat-anatomie, cassetteslots, voorraad- en
/// slijtagebalk en drie actieknoppen. Een druk- of rustig-label toont de
/// dagcyclus (GDD 5).
class AtmTile extends StatelessWidget {
  const AtmTile({
    super.key,
    required this.state,
    required this.atm,
    required this.onService,
    required this.onRepairTap,
    required this.onMaintain,
    required this.onUpgrade,
    this.onOpenDetails,
  });

  final GameState state;
  final Atm atm;
  final VoidCallback? onService;
  final VoidCallback? onRepairTap;
  final VoidCallback? onMaintain;
  final VoidCallback? onUpgrade;
  final VoidCallback? onOpenDetails;

  double get _busyFactor =>
      kBusyProfiles[atm.location]!.factorAt(state.hourOfDay);

  /// De wagen die voor deze automaat onderweg is of er staat, of null.
  CitVan? get _incomingVan {
    for (final van in state.citVans) {
      if (van.targetAtmId == atm.id &&
          (van.status == CitVanStatus.transitToAtm ||
              van.status == CitVanStatus.servicing)) {
        return van;
      }
    }
    return null;
  }

  /// Minuten tot de voorraad leeg is bij de huidige drukte.
  double get _minutesUntilEmpty {
    final chance =
        (kTransactionChancePerSecond * _busyFactor).clamp(
          0.0,
          kTransactionChanceCap,
        ) *
        atm.workingFraction;
    var drainPerSecond = chance * kAvgNotesPerTransaction;
    if (state.hundredEuroNoteActive) {
      drainPerSecond *= kHundredEuroNoteDrainMultiplier;
    }
    if (drainPerSecond <= 0) {
      return double.infinity;
    }
    return atm.availableNotes / drainPerSecond / 60;
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
            _Anatomy(atm: atm, state: state, incomingVan: _incomingVan),
            const SizedBox(height: 10),
            _CassetteSlots(atm: atm),
            const SizedBox(height: 6),
            _CassetteBar(
              notes: atm.availableNotes,
              capacity: atm.capacity,
              minutesUntilEmpty: _minutesUntilEmpty,
            ),
            const SizedBox(height: 6),
            _WearBar(atm: atm),
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

  /// Servicing stuurt een CIT-wagen; de knop toont waar hij is zolang er
  /// een onderweg is, en meldt wanneer de hele vloot bezet is.
  Widget _servicingButton() {
    final van = _incomingVan;
    if (van != null) {
      return TactileButton(
        label: van.status == CitVanStatus.servicing
            ? 'Servicing...'
            : 'CIT onderweg',
        sublabel: '${van.ticksRemaining}s',
        color: AppColors.serviceButton,
        onPressed: null,
      );
    }
    final needsService =
        atm.availableNotes < atm.capacity ||
        atm.hasBrokenCassette ||
        atm.cassettes.any((c) => !c.isBroken && c.condition < 1.0);
    final noVanFree = state.idleVan == null;
    final canService =
        needsService && !noVanFree && state.balance >= state.citTripCost;
    return TactileButton(
      label: 'Servicing',
      sublabel: noVanFree
          ? 'geen wagen vrij'
          : formatEuroCompact(state.citTripCost),
      color: AppColors.serviceButton,
      onPressed: canService ? onService : null,
    );
  }

  /// Contextuele middenknop (GDD 10): meehelpen bij een cassettereparatie,
  /// anders preventief onderhoud onder 90% staat.
  Widget _maintenanceButton() {
    if (atm.hasBrokenCassette) {
      return TactileButton(
        label: 'Help mee',
        sublabel: '${atm.repairSecondsRemaining.ceil()}s',
        color: AppColors.warning,
        onPressed: onRepairTap,
      );
    }
    final available =
        atm.isOperational && atm.condition < kPreventiveMaintenanceThreshold;
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
  const _Anatomy({required this.atm, required this.state, this.incomingVan});

  final Atm atm;
  final GameState state;
  final CitVan? incomingVan;

  String get _status {
    if (atm.isBroken) {
      return 'STORING ${atm.repairSecondsRemaining.ceil()}s';
    }
    if (atm.isPausedByOutage) {
      return 'STROOM UIT ${atm.outageSecondsRemaining.ceil()}s';
    }
    if (incomingVan?.status == CitVanStatus.servicing) {
      return 'SERVICING ${incomingVan!.ticksRemaining}s';
    }
    if (atm.hasBrokenCassette) {
      return 'CASSETTE-STORING';
    }
    if (atm.availableNotes == 0) {
      return 'CASSETTE LEEG';
    }
    if (incomingVan != null) {
      return 'CIT ONDERWEG ${incomingVan!.ticksRemaining}s';
    }
    return 'IN BEDRIJF';
  }

  @override
  Widget build(BuildContext context) {
    final alert =
        atm.isBroken ||
        atm.isPausedByOutage ||
        atm.hasBrokenCassette ||
        atm.availableNotes == 0;
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
                          color: alert ? AppColors.warning : AppColors.ledGlow,
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
                    for (var col = 0; col < (hasThirdKeyColumn ? 3 : 2); col++)
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
                    border: Border.all(color: AppColors.incomePill, width: 2),
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

/// Rij cassetteslots: per cassette een mini-balkje met de vulling; een
/// cassette in storing kleurt rood met een moersleuteltje
/// (multi-cassette, Ontwerper dd 2026-07-04).
class _CassetteSlots extends StatelessWidget {
  const _CassetteSlots({required this.atm});

  final Atm atm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Slots',
          style: TextStyle(
            fontFamily: kDigitFont,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.ink.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 6),
        for (final cassette in atm.cassettes)
          Expanded(
            child: Container(
              height: 14,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: cassette.isBroken
                    ? AppColors.warning.withValues(alpha: 0.25)
                    : AppColors.ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: cassette.isBroken
                      ? AppColors.warning
                      : AppColors.ink.withValues(alpha: 0.25),
                ),
              ),
              child: cassette.isBroken
                  ? const Icon(Icons.build, size: 9, color: AppColors.warning)
                  : FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: cassette.notes / kCassetteCapacityUnits,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.incomePill,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
            ),
          ),
        for (var i = atm.cassettes.length; i < kMaxCassettesPerAtm; i++)
          Expanded(
            child: Container(
              height: 14,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.ink.withValues(alpha: 0.15),
                ),
              ),
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
    // Weergave in echte biljetten (basis-cassette 2.000); de teller telt
    // geanimeerd naar de nieuwe stand, zodat een bijvulling zichtbaar
    // naar vol loopt.
    final targetNotes = (notes * kNotesPerUnit).toDouble();
    final displayCapacity = formatEuro(
      (capacity * kNotesPerUnit).toDouble(),
      decimals: 0,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetNotes),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedNotes, _) => _LabeledBar(
        fraction: capacity == 0 ? 0 : notes / capacity,
        color: urgent ? AppColors.warning : AppColors.incomePill,
        left:
            'Cassette '
            '${formatEuro(animatedNotes.roundToDouble(), decimals: 0)} '
            'van $displayCapacity biljetten',
        right: notes == 0 ? 'leeg' : label,
        rightColor: urgent ? AppColors.warning : null,
      ),
    );
  }
}

/// Slijtagebalk (GDD 10): toont de slechtste werkende cassette; bij een
/// cassette in storing telt het label mee hoeveel er nog werken.
class _WearBar extends StatelessWidget {
  const _WearBar({required this.atm});

  final Atm atm;

  @override
  Widget build(BuildContext context) {
    final condition = atm.condition;
    final low = condition < 0.25;
    final broken = atm.cassettes.length - atm.workingCassettes.length;
    return _LabeledBar(
      fraction: condition,
      color: low ? AppColors.warning : AppColors.dccPill,
      left: 'Staat ${(condition * 100).round()}%',
      right: broken > 0
          ? '$broken cassette${broken == 1 ? '' : 's'} in storing'
          : condition < kPreventiveMaintenanceThreshold
          ? 'onderhoud beschikbaar'
          : '',
      rightColor: broken > 0 ? AppColors.warning : null,
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
