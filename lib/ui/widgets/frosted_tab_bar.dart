import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// Frosted-glass tabbar met SVG-iconen (GDD 10). De storingsbadge staat
/// op het Monteurs-tabblad: daar wordt de technische dienst aangestuurd
/// (Ontwerper dd 2026-07-06).
class FrostedTabBar extends StatelessWidget {
  const FrostedTabBar({
    super.key,
    required this.index,
    required this.onSelect,
    required this.brokenCount,
  });

  final int index;
  final ValueChanged<int> onSelect;

  /// Aantal automaten in storing, als badge op de Monteurs-tab.
  final int brokenCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Colors.white.withValues(alpha: 0.7),
          padding: EdgeInsets.only(
            top: 6,
            bottom: MediaQuery.of(context).padding.bottom + 6,
          ),
          child: Row(
            children: [
              _tab(0, 'Kaart', 'assets/icons/tab_kaart.svg'),
              _tab(1, 'CiT', 'assets/icons/tab_cit.svg'),
              _tab(
                2,
                'Monteurs',
                'assets/icons/tab_monteurs.svg',
                badge: brokenCount,
              ),
              _tab(3, 'Upgrades', 'assets/icons/tab_upgrades.svg'),
              _tab(4, 'Financien', 'assets/icons/tab_financien.svg'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int tabIndex, String label, String asset, {int badge = 0}) {
    final selected = index == tabIndex;
    final color = selected
        ? AppColors.ink
        : AppColors.ink.withValues(alpha: 0.45);
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(tabIndex),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset(
                  asset,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '$badge',
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
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: kTextFont,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
