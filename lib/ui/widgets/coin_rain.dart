import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/feedback.dart';
import '../format.dart';
import '../theme.dart';

/// Muntenregen plus bonusbanner bij mijlpalen en doelen (GDD 9.2 en 10).
/// Luistert op de feedback-stream; met reduced motion valt er niets en
/// verschijnt alleen de banner.
class CoinRainOverlay extends StatefulWidget {
  const CoinRainOverlay({super.key, required this.feedback});

  final Stream<GameFeedback> feedback;

  @override
  State<CoinRainOverlay> createState() => _CoinRainOverlayState();
}

class _Burst {
  _Burst(this.event, this.seeds);

  final GameFeedback event;
  final List<double> seeds;
}

class _CoinRainOverlayState extends State<CoinRainOverlay> {
  final Random _random = Random();
  StreamSubscription<GameFeedback>? _subscription;
  Timer? _clearTimer;
  _Burst? _burst;

  @override
  void initState() {
    super.initState();
    _subscription = widget.feedback.listen((event) {
      if (event.type != FeedbackType.milestone &&
          event.type != FeedbackType.refillGoal) {
        return;
      }
      setState(() {
        _burst = _Burst(
          event,
          List.generate(24, (_) => _random.nextDouble()),
        );
      });
      _clearTimer?.cancel();
      _clearTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() => _burst = null);
        }
      });
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final burst = _burst;
    if (burst == null) {
      return const SizedBox.shrink();
    }
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final label = burst.event.type == FeedbackType.milestone
        ? 'Mijlpaal! +${formatEuroCompact(burst.event.amount)}'
        : 'Bijvuldoel! +${formatEuroCompact(burst.event.amount)}';
    return IgnorePointer(
      child: Stack(
        children: [
          if (!reducedMotion)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 2200),
                builder: (context, t, _) => CustomPaint(
                  painter: _CoinPainter(seeds: burst.seeds, progress: t),
                ),
              ),
            ),
          Align(
            alignment: const Alignment(0, -0.5),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: kHeaderGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cabinetShade),
                boxShadow: const [
                  BoxShadow(color: Color(0x44000000), blurRadius: 10),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: kTextFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPainter extends CustomPainter {
  const _CoinPainter({required this.seeds, required this.progress});

  final List<double> seeds;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.gradientBottom;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.cabinetShade;
    for (var i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      // Elke munt start met eigen vertraging en valt met eigen snelheid.
      final delay = seed * 0.4;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) {
        continue;
      }
      final x = ((seed * 7919) % 1.0) * size.width;
      final y = t * (size.height + 40) - 20;
      final radius = 6.0 + seed * 4;
      canvas.drawCircle(Offset(x, y), radius, fill);
      canvas.drawCircle(Offset(x, y), radius, rim);
    }
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
