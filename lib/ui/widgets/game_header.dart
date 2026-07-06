import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/game_state.dart';
import '../format.dart';
import '../theme.dart';
import 'guilloche_painter.dart';
import 'led_display.dart';

/// De gele signatuur-header (GDD 10): gradient met guilloche-patroon,
/// saldo als donker LED-display, spelklok en netto inkomen per minuut.
class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.state,
    required this.incomePerMinute,
    this.muted = false,
    this.onToggleMute,
  });

  final GameState state;
  final double incomePerMinute;
  final bool muted;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: kHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: CustomPaint(
          painter: const GuillochePainter(),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ATM EMPIRE',
                        style: TextStyle(
                          fontFamily: kTextFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 2,
                          color: AppColors.ink.withValues(alpha: 0.8),
                        ),
                      ),
                      Row(
                        children: [
                          if (onToggleMute != null)
                            GestureDetector(
                              onTap: onToggleMute,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Icon(
                                  muted
                                      ? Icons.volume_off_outlined
                                      : Icons.volume_up_outlined,
                                  size: 18,
                                  color: AppColors.ink.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          _InfoChip(
                            label: formatGameClock(
                              state.tick,
                              kGameHourRealSeconds,
                            ),
                            icon: Icons.schedule,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(child: LedDisplay(value: state.balance)),
                  const SizedBox(height: 10),
                  // Drie chips die samen altijd op een rij passen: hele
                  // euro's in het minuutbedrag en per chip een
                  // scale-down zodat lange labels (Level Landelijk,
                  // hoge inkomens) nooit tegen de schermrand drukken
                  // (speler dd 2026-07-06).
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _flexibleChip(
                        _InfoChip(
                          label:
                              '€ ${formatEuro(incomePerMinute, decimals: 0)} '
                              'per min',
                          icon: Icons.trending_up,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Goedkeuringsscore van de Nationale Bank
                      // (spreidingswet): rood zodra zones tegen de grens
                      // aan zitten.
                      _flexibleChip(
                        _InfoChip(
                          label: 'NB ${(state.spreadApproval * 100).round()}%',
                          icon: Icons.account_balance_outlined,
                          warning: state.spreadApproval < 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _flexibleChip(
                        _InfoChip(
                          label: 'Level ${_levelLabel(state)}',
                          icon: Icons.flag_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chip die meebuigt met de beschikbare ruimte: krimpt in plaats van
  /// overlopen wanneer de drie labels samen breder zijn dan de header.
  Widget _flexibleChip(Widget chip) {
    return Flexible(
      child: FittedBox(fit: BoxFit.scaleDown, child: chip),
    );
  }

  String _levelLabel(GameState state) => switch (state.playerLevel.index) {
    0 => 'Dorp',
    1 => 'Stad',
    2 => 'Regio',
    _ => 'Landelijk',
  };
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    this.warning = false,
  });

  final String label;
  final IconData icon;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning ? AppColors.warning : AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warning
            ? AppColors.warning.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: kDigitFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
