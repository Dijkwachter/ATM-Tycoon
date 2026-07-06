import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';
import 'tactile_button.dart';

/// Gedeelde winkel-kaarten voor de tabbladen Upgrades, CiT en Monteurs
/// (Ontwerper dd 2026-07-06): sectiekop, upgrade-kaart met levelblokjes
/// en personeels-kaart met "In dienst"-vinkje.

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key});

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

class UpgradeCard extends StatelessWidget {
  const UpgradeCard({
    super.key,
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

  /// Kosten van het volgende level; null wanneer de upgrade gemaxt is.
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

class StaffCard extends StatelessWidget {
  const StaffCard({
    super.key,
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
                          Icon(
                            Icons.check_circle,
                            color: AppColors.incomePill,
                            size: 18,
                          ),
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
