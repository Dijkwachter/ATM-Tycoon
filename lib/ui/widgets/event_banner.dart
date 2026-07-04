import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/game_state.dart';
import '../theme.dart';

/// Banner met aftelling voor het actieve event, boven de kaart (GDD 6).
class EventBanner extends StatelessWidget {
  const EventBanner({super.key, required this.event});

  final ActiveEvent event;

  String get _label => switch (event.type) {
    GameEventType.kingsday => 'Koningsdag: dubbele drukte overal!',
    GameEventType.festival => 'Festivalweekend: drukte x3!',
    _ => 'Event actief',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.celebration_outlined,
            size: 18,
            color: AppColors.ledGlow,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: kTextFont,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
          Text('${event.secondsRemaining}s', style: ledDigits(14)),
        ],
      ),
    );
  }
}
