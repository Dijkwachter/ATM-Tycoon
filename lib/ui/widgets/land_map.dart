import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../theme.dart';

/// De landkaart (Ontwerper dd 2026-07-04): vier zone-kwadranten (dorp,
/// stad, regio, landelijk) met de locaties op vaste coördinaten. Zones die
/// de Nationale Bank geblokkeerd heeft (spreidingswet) kleuren rood en
/// tonen een slot; tikken op een locatie kiest hem voor aankoop.
class LandMap extends StatelessWidget {
  const LandMap({super.key, required this.state, this.onPickLocation});

  final GameState state;

  /// Aangeroepen bij een tik op een locatie in een niet-geblokkeerde zone.
  final void Function(LocationType location)? onPickLocation;

  static const zoneNames = {
    MapZone.dorp: 'Dorp',
    MapZone.stad: 'Stad',
    MapZone.regio: 'Regio',
    MapZone.landelijk: 'Landelijk',
  };

  static const locationIcons = {
    LocationType.station: Icons.train_outlined,
    LocationType.winkel: Icons.storefront_outlined,
    LocationType.winkelcentrum: Icons.local_mall_outlined,
    LocationType.horeca: Icons.local_bar_outlined,
    LocationType.evenement: Icons.stadium_outlined,
    LocationType.reizen: Icons.flight_outlined,
    LocationType.zorg: Icons.local_hospital_outlined,
    LocationType.snelweg: Icons.add_road_outlined,
    LocationType.openbaar: Icons.park_outlined,
  };

  static const shortLocationNames = {
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

  /// Kwadrant van een zone in genormaliseerde kaartcoördinaten.
  static Rect _zoneRect(MapZone zone) => switch (zone) {
    MapZone.dorp => const Rect.fromLTWH(0, 0, 0.5, 0.5),
    MapZone.stad => const Rect.fromLTWH(0.5, 0, 0.5, 0.5),
    MapZone.regio => const Rect.fromLTWH(0, 0.5, 0.5, 0.5),
    MapZone.landelijk => const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
  };

  int _atmCountAt(LocationType location) =>
      state.atms.where((a) => a.location == location).length;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: AppColors.card)),
                for (final zone in MapZone.values)
                  _ZoneQuadrant(
                    zone: zone,
                    rect: _zoneRect(zone),
                    width: w,
                    height: h,
                    count: state.zoneCount(zone),
                    blocked: state.isZoneBlocked(zone),
                  ),
                for (final location in LocationType.values)
                  _LocationDot(
                    location: location,
                    x: kLocationMapPoints[location]!.x * w,
                    y: kLocationMapPoints[location]!.y * h,
                    atmCount: _atmCountAt(location),
                    blocked: state.isZoneBlocked(kLocationZone[location]!),
                    onTap: onPickLocation == null
                        ? null
                        : () => onPickLocation!(location),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ZoneQuadrant extends StatelessWidget {
  const _ZoneQuadrant({
    required this.zone,
    required this.rect,
    required this.width,
    required this.height,
    required this.count,
    required this.blocked,
  });

  final MapZone zone;
  final Rect rect;
  final double width;
  final double height;
  final int count;
  final bool blocked;

  static const _zoneTints = {
    MapZone.dorp: Color(0x1A7CB342),
    MapZone.stad: Color(0x1AF5B91E),
    MapZone.regio: Color(0x1A5C7CFA),
    MapZone.landelijk: Color(0x1A8E959C),
  };

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.left * width,
      top: rect.top * height,
      width: rect.width * width,
      height: rect.height * height,
      child: Container(
        decoration: BoxDecoration(
          color: blocked
              ? AppColors.warning.withValues(alpha: 0.18)
              : _zoneTints[zone],
          border: Border.all(
            color: blocked
                ? AppColors.warning
                : AppColors.ink.withValues(alpha: 0.12),
            width: blocked ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  LandMap.zoneNames[zone]!.toUpperCase(),
                  style: TextStyle(
                    fontFamily: kDigitFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: blocked
                        ? AppColors.warning
                        : AppColors.ink.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: kDigitFont,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink.withValues(alpha: 0.55),
                  ),
                ),
                if (blocked) ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.lock, size: 11, color: AppColors.warning),
                ],
              ],
            ),
            if (blocked)
              Text(
                'vergunning geweigerd',
                style: TextStyle(
                  fontFamily: kTextFont,
                  fontSize: 8.5,
                  color: AppColors.warning.withValues(alpha: 0.9),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocationDot extends StatelessWidget {
  const _LocationDot({
    required this.location,
    required this.x,
    required this.y,
    required this.atmCount,
    required this.blocked,
    this.onTap,
  });

  final LocationType location;
  final double x;
  final double y;
  final int atmCount;
  final bool blocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const dotSize = 34.0;
    return Positioned(
      left: x - dotSize / 2,
      top: y - dotSize / 2,
      child: GestureDetector(
        onTap: blocked ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: atmCount > 0
                        ? AppColors.gradientBottom
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: blocked
                          ? AppColors.warning
                          : AppColors.ink.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    LandMap.locationIcons[location],
                    size: 18,
                    color: blocked ? AppColors.warning : AppColors.ink,
                  ),
                ),
                if (atmCount > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$atmCount',
                        style: const TextStyle(
                          fontFamily: kDigitFont,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ledGlow,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              LandMap.shortLocationNames[location]!,
              style: const TextStyle(
                fontFamily: kTextFont,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
