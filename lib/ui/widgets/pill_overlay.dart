import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/feedback.dart';
import '../format.dart';
import '../theme.dart';

/// Zwevende feedback-pills boven een automaat-tegel (GDD 10): groen voor
/// inkomsten, blauw voor DCC, paars voor recycling. Pills stijgen op en
/// vervagen; met reduced motion staan ze stil en verdwijnen ze alleen.
class PillOverlay extends StatefulWidget {
  const PillOverlay({super.key, required this.feedback, required this.atmId});

  final Stream<GameFeedback> feedback;
  final int atmId;

  @override
  State<PillOverlay> createState() => _PillOverlayState();
}

class _Pill {
  _Pill(this.event, this.slot);

  final GameFeedback event;
  final int slot;
}

class _PillOverlayState extends State<PillOverlay> {
  final List<_Pill> _pills = [];
  final Set<Timer> _timers = {};
  StreamSubscription<GameFeedback>? _subscription;
  int _slot = 0;

  @override
  void initState() {
    super.initState();
    _subscription = widget.feedback.listen((event) {
      if (event.atmId != widget.atmId || !_isPillType(event.type)) {
        return;
      }
      final pill = _Pill(event, _slot++);
      setState(() => _pills.add(pill));
      late final Timer timer;
      timer = Timer(const Duration(milliseconds: 1400), () {
        _timers.remove(timer);
        if (mounted) {
          setState(() => _pills.remove(pill));
        }
      });
      _timers.add(timer);
    });
  }

  bool _isPillType(FeedbackType type) =>
      type == FeedbackType.income ||
      type == FeedbackType.dcc ||
      type == FeedbackType.recycling ||
      type == FeedbackType.insurance ||
      type == FeedbackType.robbery;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: SizedBox(
        height: 0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final pill in _pills)
              Positioned(
                top: -8,
                left: 16.0 + (pill.slot % 3) * 90,
                child: reducedMotion
                    ? _PillChip(event: pill.event)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1400),
                        builder: (context, t, child) => Transform.translate(
                          offset: Offset(0, -34 * t),
                          child: Opacity(
                            opacity: (1 - t).clamp(0, 1),
                            child: child,
                          ),
                        ),
                        child: _PillChip(event: pill.event),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.event});

  final GameFeedback event;

  Color get _color => switch (event.type) {
    FeedbackType.dcc => AppColors.dccPill,
    FeedbackType.recycling => AppColors.recyclingPill,
    FeedbackType.robbery => AppColors.warning,
    _ => AppColors.incomePill,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${event.type == FeedbackType.robbery ? '-' : '+'}'
        '€ ${formatEuro(event.amount)}',
        style: const TextStyle(
          fontFamily: kDigitFont,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}
