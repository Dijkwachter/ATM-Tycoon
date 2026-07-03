import 'package:flutter/material.dart';

import '../theme.dart';

/// Tactiele 3D-knop (GDD 10): een dikke onderrand die indrukt bij een tik.
class TactileButton extends StatefulWidget {
  const TactileButton({
    super.key,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.sublabel,
    this.onPressed,
  });

  final String label;
  final String? sublabel;
  final Color color;
  final Color textColor;
  final VoidCallback? onPressed;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = enabled
        ? widget.color
        : Color.lerp(widget.color, Colors.grey, 0.55)!;
    final depth = _pressed && enabled ? 1.0 : 4.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        margin: EdgeInsets.only(top: 5 - depth + 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(color, Colors.black, 0.45)!,
              offset: Offset(0, depth),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kTextFont,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: widget.textColor,
              ),
            ),
            if (widget.sublabel != null)
              Text(
                widget.sublabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kDigitFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: widget.textColor.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
