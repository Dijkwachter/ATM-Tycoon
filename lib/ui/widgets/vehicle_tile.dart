import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../theme.dart';

/// Korte locatienamen voor de voertuig-dashboards van de tabbladen CiT
/// en Monteurs (Ontwerper dd 2026-07-06).
const Map<LocationType, String> kShortLocationNames = {
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

/// Statuskleuren van het gedeelde voertuigmodel: stand-by groen, heenreis
/// geel, bezig ter plaatse blauw, terugreis grijs.
Color vehicleStatusColor(CitVanStatus status) => switch (status) {
  CitVanStatus.idle => AppColors.incomePill,
  CitVanStatus.transitToAtm => AppColors.gradientBottom,
  CitVanStatus.servicing => AppColors.dccPill,
  CitVanStatus.returning => AppColors.steel,
};

/// Een rij van het live vloot-dashboard: naam, statuslabel, afteller en
/// een meelopende voortgangsbalk in de statuskleur. De balk vult zich
/// deterministisch met de engine-ticks (progress = 1 - resterend/totaal);
/// een stilstaand voertuig toont een rustige volle groene balk.
class VehicleTile extends StatelessWidget {
  const VehicleTile({
    super.key,
    required this.name,
    required this.icon,
    required this.status,
    required this.statusLabel,
    required this.progress,
    this.ticksRemaining = 0,
  });

  final String name;
  final IconData icon;
  final CitVanStatus status;
  final String statusLabel;

  /// Voortgang binnen de huidige fase, 0,0 tot 1,0.
  final double progress;

  /// Resterende ticks in de huidige fase; 0 bij stand-by.
  final int ticksRemaining;

  @override
  Widget build(BuildContext context) {
    final color = vehicleStatusColor(status);
    final active = status != CitVanStatus.idle;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: kTextFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kTextFont,
                    fontSize: 11.5,
                    color: AppColors.ink.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                Text(
                  '${ticksRemaining}s',
                  style: TextStyle(
                    fontFamily: kDigitFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: AppColors.ink.withValues(alpha: 0.10)),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    widthFactor: (active ? progress : 1.0).clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
