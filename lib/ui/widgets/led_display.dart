import 'package:flutter/material.dart';

import '../format.dart';
import '../theme.dart';

/// Donker LED-display met gloeiende cijfers die vloeiend doortellen
/// (GDD 10). Respecteert reduced motion: dan springt de waarde direct.
class LedDisplay extends StatelessWidget {
  const LedDisplay({
    super.key,
    required this.value,
    this.fontSize = 34,
    this.prefix = 'EUR ',
    this.decimals = 2,
  });

  final double value;
  final double fontSize;
  final String prefix;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ledPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cabinetShade, width: 1.5),
      ),
      child: reducedMotion
          ? _text(value)
          : TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, animated, _) => _text(animated),
            ),
    );
  }

  Widget _text(double shown) {
    return Text(
      '$prefix${formatEuro(shown, decimals: decimals)}',
      style: ledDigits(fontSize),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
