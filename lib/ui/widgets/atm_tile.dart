import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/atm.dart';
import '../../models/cit_van.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../format.dart';
import '../theme.dart';
import 'tactile_button.dart';

/// Automaat-tegel (GDD 10, levende simulatie Ontwerper dd 2026-07-04):
/// een scene waarin klanten komen aanlopen, in de rij staan en de
/// transactie-choreografie doorlopen (kaart, verwerking, shutter,
/// afronding), boven de cassetteslots, voorraad- en slijtagebalk en de
/// drie actieknoppen. De kast groeit visueel mee van een vergeelde
/// plastic doos (level 1) naar een Quantum Node met glazen kap en
/// neonstrips (level 5).
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

  /// Minuten tot de voorraad leeg is bij de huidige doorvoer.
  double get _minutesUntilEmpty {
    final arrivals =
        (kTransactionChancePerSecond * _busyFactor).clamp(
          0.0,
          kTransactionChanceCap,
        ) *
        atm.workingFraction;
    final throughput = arrivals < 1 / atm.totalServiceTicks
        ? arrivals
        : 1 / atm.totalServiceTicks;
    var drainPerSecond =
        throughput *
        (atm.isRecycler ? 1 - kRecyclerDepositShare : 1) *
        kAvgNotesPerTransaction;
    if (state.hundredEuroNoteActive) {
      drainPerSecond *= kHundredEuroNoteDrainMultiplier;
    }
    if (drainPerSecond <= 0) {
      return double.infinity;
    }
    return atm.availableNotes / drainPerSecond / 60;
  }

  /// Kast-uiterlijk per level (Ontwerper dd 2026-07-04): van vergeeld
  /// beige plastic (1) via geel en staal naar de donkere carbon Quantum
  /// Node met neon-gele gloed (5). AnimatedContainer laat een upgrade
  /// vloeiend overgaan.
  BoxDecoration _cabinetDecoration() {
    final radius = BorderRadius.circular(16);
    const dropShadow = BoxShadow(
      color: Color(0x22000000),
      blurRadius: 5,
      offset: Offset(0, 2),
    );
    return switch (atm.level) {
      1 => BoxDecoration(
        color: const Color(0xFFE8DCC0),
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFC9BA97), width: 1),
        boxShadow: const [dropShadow],
      ),
      2 => BoxDecoration(
        color: AppColors.cabinetBasic,
        borderRadius: radius,
        border: Border.all(color: AppColors.cabinetShade, width: 1),
        boxShadow: const [dropShadow],
      ),
      3 => BoxDecoration(
        gradient: kHeaderGradient,
        borderRadius: radius,
        border: Border.all(color: AppColors.cabinetShade, width: 1),
        boxShadow: const [dropShadow],
      ),
      4 => BoxDecoration(
        gradient: kHeaderGradient,
        borderRadius: radius,
        border: Border.all(color: AppColors.steel, width: 5),
        boxShadow: const [dropShadow],
      ),
      _ => BoxDecoration(
        color: const Color(0xFF2E2A22),
        borderRadius: radius,
        border: Border.all(color: AppColors.steel, width: 5),
        boxShadow: const [
          dropShadow,
          BoxShadow(color: Color(0x88FFD75E), blurRadius: 16),
        ],
      ),
    };
  }

  /// Tekstkleur die leesbaar blijft op de donkere level 5-kast.
  Color get _inkOnCabinet => atm.level >= 5 ? AppColors.ledGlow : AppColors.ink;

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
            _TitleRow(atm: atm, busyFactor: _busyFactor, ink: _inkOnCabinet),
            const SizedBox(height: 8),
            _LiveScene(atm: atm, state: state, incomingVan: _incomingVan),
            const SizedBox(height: 10),
            _CassetteSlots(atm: atm, ink: _inkOnCabinet),
            const SizedBox(height: 6),
            _CassetteBar(
              notes: atm.availableNotes,
              capacity: atm.capacity,
              minutesUntilEmpty: _minutesUntilEmpty,
              ink: _inkOnCabinet,
            ),
            const SizedBox(height: 6),
            _WearBar(atm: atm, ink: _inkOnCabinet),
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

  /// Contextuele middenknop (GDD 10 en aanrijdsysteem Ontwerper dd
  /// 2026-07-06): meehelpen zodra de monteur ter plaatse repareert, de
  /// aanrijstatus tonen zolang hij onderweg is, anders preventief
  /// onderhoud onder 90% staat.
  Widget _maintenanceButton() {
    if (atm.hasBrokenCassette) {
      final repairing = state.mechanicRepairingAt(atm.id);
      if (repairing != null) {
        return TactileButton(
          label: 'Help mee',
          sublabel: '${repairing.ticksRemaining}s',
          color: AppColors.warning,
          onPressed: onRepairTap,
        );
      }
      final enRoute = state.mechanics
          .where(
            (m) =>
                m.targetAtmId == atm.id &&
                m.status == CitVanStatus.transitToAtm,
          )
          .firstOrNull;
      return TactileButton(
        label: 'Monteur',
        sublabel: enRoute == null
            ? 'wacht op monteur'
            : 'onderweg ${enRoute.ticksRemaining}s',
        color: AppColors.warning,
        onPressed: null,
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
    final cost = atm.nextLevelCost;
    final canUpgrade = cost != null && state.balance >= cost;
    return TactileButton(
      label: cost == null ? 'Level max' : 'Level ${atm.level + 1}',
      sublabel: cost == null ? 'Quantum Node' : formatEuroCompact(cost),
      color: AppColors.ledPanel,
      textColor: AppColors.ledGlow,
      onPressed: canUpgrade ? onUpgrade : null,
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.atm,
    required this.busyFactor,
    required this.ink,
  });

  final Atm atm;
  final double busyFactor;
  final Color ink;

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

  String get _configName =>
      '${atm.housing == AtmHousing.ttw ? 'TTW' : 'Lobby'}'
      ' ${atm.isRecycler ? 'recycler' : 'dispenser'}';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${_locationNames[atm.location]} - $_configName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kTextFont,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: ink,
            ),
          ),
        ),
        _LevelPips(level: atm.level, ink: ink),
        const SizedBox(width: 6),
        if (busyFactor >= 1.2)
          const _BusyLabel(label: 'druk', color: AppColors.incomePill)
        else if (busyFactor <= 0.5)
          const _BusyLabel(label: 'rustig', color: AppColors.cabinetShade),
      ],
    );
  }
}

/// Vijf pips die het upgradelevel van deze kast tonen.
class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level, required this.ink});

  final int level;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= Atm.kMaxAtmLevel; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= level ? ink : ink.withValues(alpha: 0.18),
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

/// De levende scene (Ontwerper dd 2026-07-04): een straatje of hal met de
/// wachtrij links en de automaat rechts. Klanten schuiven met implicit
/// animations naar hun plek; de voorste doorloopt de choreografie van
/// [TransactionPhase]. De machine zelf toont een kaartlezer die knippert,
/// een scherm met laad-indicator en de shutter: smal en discreet op een
/// dispenser, een dubbel zo grote gemotoriseerde klep met groene gloed op
/// een recycler.
class _LiveScene extends StatelessWidget {
  const _LiveScene({required this.atm, required this.state, this.incomingVan});

  final Atm atm;
  final GameState state;
  final CitVan? incomingVan;

  /// Status van de storing met de monteursfase (aanrijdsysteem).
  String _brokenStatus(String prefix) {
    final repairing = state.mechanicRepairingAt(atm.id);
    if (repairing != null) {
      return '$prefix: REPARATIE ${repairing.ticksRemaining}s';
    }
    final enRoute = state.mechanics
        .where(
          (m) =>
              m.targetAtmId == atm.id && m.status == CitVanStatus.transitToAtm,
        )
        .firstOrNull;
    if (enRoute != null) {
      return '$prefix: MONTEUR ${enRoute.ticksRemaining}s';
    }
    return '$prefix: WACHT OP MONTEUR';
  }

  String get _status {
    if (atm.isBroken) {
      return _brokenStatus('STORING');
    }
    if (atm.isPausedByOutage) {
      return 'STROOM UIT ${atm.outageSecondsRemaining.ceil()}s';
    }
    if (incomingVan?.status == CitVanStatus.servicing) {
      return 'SERVICING ${incomingVan!.ticksRemaining}s';
    }
    if (atm.hasBrokenCassette) {
      return _brokenStatus('CASSETTE');
    }
    if (atm.availableNotes == 0) {
      return 'CASSETTE LEEG';
    }
    if (incomingVan != null) {
      return 'CIT ONDERWEG ${incomingVan!.ticksRemaining}s';
    }
    return switch (atm.transaction?.phase) {
      TransactionPhase.cardPresented => 'PAS AANGEBODEN',
      TransactionPhase.processing => 'VERWERKEN...',
      TransactionPhase.shutterAction =>
        atm.transaction!.isDeposit ? 'STORTING TELT' : 'GELD UITGEVEN',
      TransactionPhase.finishing => 'KLAAR',
      null => 'IN BEDRIJF',
    };
  }

  @override
  Widget build(BuildContext context) {
    final phase = atm.transaction?.phase;
    final alert =
        atm.isBroken ||
        atm.isPausedByOutage ||
        atm.hasBrokenCassette ||
        atm.availableNotes == 0;
    final isNight = state.hourOfDay < 7 || state.hourOfDay >= 21;
    return SizedBox(
      height: 96,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          const machineWidth = 118.0;
          final machineLeft = width - machineWidth;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // Achtergrond: hal (lobby) of straatgevel (TTW), met een
                // licht isometrisch vloervlak.
                Positioned.fill(
                  child: Container(
                    color: atm.housing == AtmHousing.ttw
                        ? (isNight
                              ? const Color(0xFF3A4148)
                              : const Color(0xFF6E7880))
                        : (isNight
                              ? const Color(0xFF7A7468)
                              : const Color(0xFFEFE7D4)),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 26,
                  child: Transform(
                    transform: Matrix4.identity()..setEntry(1, 0, -0.06),
                    child: Container(
                      color: atm.housing == AtmHousing.ttw
                          ? const Color(0xFF4E565E)
                          : const Color(0xFFDDD0B4),
                    ),
                  ),
                ),
                // De wachtende klanten schuiven naar hun plek in de rij.
                for (var i = 0; i < atm.queueLength && i < 8; i++)
                  _Customer(
                    key: ValueKey('q$i'),
                    left: machineLeft - 46.0 - i * 22.0,
                    seed: atm.id * 131 + i * 17,
                    walking: false,
                  ),
                // De klant aan de automaat.
                if (atm.transaction != null)
                  _Customer(
                    key: const ValueKey('active'),
                    left: machineLeft - 22,
                    seed: atm.id * 131 + 997,
                    walking: false,
                    leaning: phase == TransactionPhase.cardPresented,
                  ),
                // De machine zelf.
                Positioned(
                  right: 0,
                  top: 4,
                  bottom: 4,
                  width: machineWidth,
                  child: _Machine(atm: atm, status: _status, alert: alert),
                ),
                // Glazen overkapping op level 5 (de Quantum Node).
                if (atm.level >= 5)
                  Positioned(
                    right: 0,
                    top: 0,
                    width: machineWidth + 46,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(10),
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                // Wachtrijteller.
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'rij ${atm.queueLength} van ${atm.queueCapacity}',
                      style: const TextStyle(
                        fontFamily: kDigitFont,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Deterministisch uiterlijk van een klant (Ontwerper dd 2026-07-06): de
/// wereldbevolking loopt langs de automaat, dus huidtinten van licht tot
/// donker, haarkleuren en haarlengtes (kort, lang, knot of kaal) wisselen
/// per persoon. Alles wordt uit de seed afgeleid zodat de mix stabiel en
/// testbaar is.
class _CustomerLook {
  _CustomerLook(int seed)
    : skin = _skins[seed % _skins.length],
      coat = _coats[(seed * 7 + 3) % _coats.length],
      hairColor = _hairColors[(seed * 5 + 1) % _hairColors.length],
      hairStyle = _HairStyle.values[(seed * 13 + 2) % _HairStyle.values.length];

  final Color skin;
  final Color coat;
  final Color hairColor;
  final _HairStyle hairStyle;

  /// Huidtinten van licht tot donker.
  static const _skins = [
    Color(0xFFF5D5C0),
    Color(0xFFE8BC9A),
    Color(0xFFD1A374),
    Color(0xFFB07B4F),
    Color(0xFF8A5A35),
    Color(0xFF5C3B22),
  ];

  static const _coats = [
    Color(0xFF5C7CFA),
    Color(0xFF37B24D),
    Color(0xFFE8590C),
    Color(0xFF845EF7),
    Color(0xFF1098AD),
    Color(0xFFD6336C),
    Color(0xFF74665C),
    Color(0xFFE6B117),
  ];

  static const _hairColors = [
    Color(0xFF241A12),
    Color(0xFF4E342E),
    Color(0xFF8D6E63),
    Color(0xFFD9B380),
    Color(0xFFA9502C),
    Color(0xFFB0B0B0),
  ];
}

/// Haarlengte/-stijl: kort, lang tot op de schouders, een knot, of kaal.
enum _HairStyle { short, long, bun, bald }

/// Een klant: hoofd met haar plus jas, met AnimatedPositioned zodat hij
/// of zij vloeiend naar de plek in de rij schuift wanneer de engine-stand
/// verandert.
class _Customer extends StatelessWidget {
  const _Customer({
    super.key,
    required this.left,
    required this.seed,
    required this.walking,
    this.leaning = false,
  });

  final double left;
  final int seed;
  final bool walking;
  final bool leaning;

  @override
  Widget build(BuildContext context) {
    final look = _CustomerLook(seed);
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      left: left,
      bottom: 10,
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 300),
        turns: leaning ? 0.015 : 0,
        child: SizedBox(
          width: 14,
          height: 34,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // Lang haar valt achter het hoofd tot op de schouders.
              if (look.hairStyle == _HairStyle.long)
                Positioned(
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 15,
                    decoration: BoxDecoration(
                      color: look.hairColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              // Knotje boven het hoofd.
              if (look.hairStyle == _HairStyle.bun)
                Positioned(
                  top: -3,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: look.hairColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              // Hoofd.
              Positioned(
                top: 2,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: look.skin,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Kort haar of de aanzet van de knot als een kapje op het
              // hoofd; kaal laat de kruin vrij.
              if (look.hairStyle != _HairStyle.bald)
                Positioned(
                  top: 2,
                  child: Container(
                    width: 9,
                    height: 4,
                    decoration: BoxDecoration(
                      color: look.hairColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ),
                ),
              // Jas.
              Positioned(
                top: 12,
                child: Container(
                  width: 12,
                  height: 20,
                  decoration: BoxDecoration(
                    color: look.coat,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// De automaat in de scene: scherm met status, knipperende kaartlezer en
/// de shutter met de fase-choreografie.
class _Machine extends StatelessWidget {
  const _Machine({
    required this.atm,
    required this.status,
    required this.alert,
  });

  final Atm atm;
  final String status;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final phase = atm.transaction?.phase;
    final isDeposit = atm.transaction?.isDeposit ?? false;
    final shutterOpen = phase == TransactionPhase.shutterAction;
    final cardActive = phase == TransactionPhase.cardPresented;

    final bodyColor = switch (atm.level) {
      1 => const Color(0xFFD9CBA8),
      2 => AppColors.cabinetBasic,
      3 => AppColors.gradientBottom,
      4 => AppColors.steel,
      _ => const Color(0xFF23201A),
    };

    return Container(
      decoration: BoxDecoration(
        color: bodyColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: atm.level >= 4 ? AppColors.steel : AppColors.cabinetShade,
          width: atm.level >= 4 ? 3 : 1,
        ),
        boxShadow: atm.level >= 5
            ? const [BoxShadow(color: Color(0x66FFD75E), blurRadius: 10)]
            : null,
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Neonstrip vanaf level 4.
          if (atm.level >= 4)
            Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color: AppColors.ledGlow,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(color: Color(0xAAFFE27A), blurRadius: 6),
                ],
              ),
            ),
          // Scherm: status in LED-cijfers, curved vanaf level 5.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.ledPanel,
              borderRadius: BorderRadius.circular(atm.level >= 5 ? 9 : 4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ledDigits(
                    8.5,
                    color: alert ? AppColors.warning : AppColors.ledGlow,
                  ),
                ),
                Text(
                  formatEuro(atm.lifetimeEarned),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ledDigits(11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Kaartlezer: knippert blauw/groen tijdens het aanbieden.
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 26,
                height: 6,
                decoration: BoxDecoration(
                  color: cardActive
                      ? const Color(0xFF37B24D)
                      : AppColors.ledPanel,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: cardActive
                      ? const [
                          BoxShadow(color: Color(0x8837B24D), blurRadius: 6),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 4),
              if (phase == TransactionPhase.processing)
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.ledGlow.withValues(alpha: 0.9),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          // De shutter. Dispenser: smalle, discrete sleuf. Recycler: een
          // twee keer zo grote gemotoriseerde klep die wijd openschuift,
          // met een groene LED-gloed bij een storting.
          _Shutter(
            isRecycler: atm.isRecycler,
            open: shutterOpen,
            depositGlow: shutterOpen && isDeposit,
          ),
        ],
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({
    required this.isRecycler,
    required this.open,
    required this.depositGlow,
  });

  final bool isRecycler;
  final bool open;
  final bool depositGlow;

  @override
  Widget build(BuildContext context) {
    final height = isRecycler ? 18.0 : 9.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.ledPanel,
        borderRadius: BorderRadius.circular(4),
        boxShadow: depositGlow
            ? const [BoxShadow(color: Color(0xAA37B24D), blurRadius: 8)]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Binnenkant: geld (opname) of groene gloed (storting).
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              color: depositGlow
                  ? const Color(0xFF37B24D)
                  : open
                  ? AppColors.gradientBottom
                  : AppColors.ledPanel,
            ),
          ),
          // De klep zelf schuift soepel omhoog open.
          AnimatedAlign(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOutCubic,
              height: open ? height * 0.22 : height,
              decoration: BoxDecoration(
                color: AppColors.steel,
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.ink.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rij cassetteslots: per cassette een mini-balkje met de vulling en de
/// denominatie van het slot; een cassette in storing kleurt rood met een
/// moersleuteltje.
class _CassetteSlots extends StatelessWidget {
  const _CassetteSlots({required this.atm, required this.ink});

  final Atm atm;
  final Color ink;

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
            color: ink.withValues(alpha: 0.7),
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
                    : ink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: cassette.isBroken
                      ? AppColors.warning
                      : ink.withValues(alpha: 0.25),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: cassette.isBroken
                  ? const Icon(Icons.build, size: 9, color: AppColors.warning)
                  : Stack(
                      children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: cassette.notes / kCassetteCapacityUnits,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.incomePill,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '€${cassette.denomination}',
                            style: TextStyle(
                              fontFamily: kDigitFont,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: ink.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
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
                border: Border.all(color: ink.withValues(alpha: 0.15)),
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
    required this.ink,
  });

  final int notes;
  final int capacity;
  final double minutesUntilEmpty;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final urgent = minutesUntilEmpty < 1.5;
    final label = minutesUntilEmpty.isFinite
        ? 'leeg over ${minutesUntilEmpty.toStringAsFixed(1)} min'
        : 'stabiel';
    // Weergave in echte biljetten (cassette 2.000); de teller telt
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
        ink: ink,
      ),
    );
  }
}

/// Slijtagebalk (GDD 10): toont de slechtste werkende cassette; bij een
/// cassette in storing telt het label mee hoeveel er nog werken.
class _WearBar extends StatelessWidget {
  const _WearBar({required this.atm, required this.ink});

  final Atm atm;
  final Color ink;

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
      ink: ink,
    );
  }
}

class _LabeledBar extends StatelessWidget {
  const _LabeledBar({
    required this.fraction,
    required this.color,
    required this.left,
    required this.right,
    required this.ink,
    this.rightColor,
  });

  final double fraction;
  final Color color;
  final String left;
  final String right;
  final Color ink;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontFamily: kDigitFont,
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: ink,
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
                color: rightColor ?? ink.withValues(alpha: 0.7),
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
            backgroundColor: ink.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
