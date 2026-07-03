import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/guilloche_painter.dart';
import '../widgets/led_display.dart';
import '../widgets/tactile_button.dart';

/// Introscherm: logo op de gele bankbiljet-gradient, de high score als
/// LED-display en de startknoppen. Met een bewaard spel zijn er twee
/// knoppen (verder spelen of opnieuw beginnen, met bevestiging); anders
/// een enkele startknop.
class IntroScreen extends StatelessWidget {
  const IntroScreen({
    super.key,
    required this.hasSave,
    required this.highScore,
    required this.onContinue,
    required this.onNewGame,
  });

  final bool hasSave;
  final double highScore;
  final VoidCallback onContinue;
  final VoidCallback onNewGame;

  Future<void> _confirmNewGame(BuildContext context) async {
    if (!hasSave) {
      onNewGame();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text(
          'Nieuw spel?',
          style: TextStyle(fontFamily: kTextFont, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Je huidige spel wordt gewist. De high score blijft staan.',
          style: TextStyle(fontFamily: kTextFont),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Wis en begin opnieuw'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      onNewGame();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Hero-paneel in de stijl van de header: gradient plus guilloche.
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: kHeaderGradient,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(28)),
                child: CustomPaint(
                  painter: const GuillochePainter(),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ATM',
                          style: TextStyle(
                            fontFamily: kTextFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 56,
                            height: 1.0,
                            letterSpacing: 10,
                            color: AppColors.ink.withValues(alpha: 0.9),
                          ),
                        ),
                        Text(
                          'EMPIRE',
                          style: TextStyle(
                            fontFamily: kTextFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 34,
                            height: 1.1,
                            letterSpacing: 14,
                            color: AppColors.ink.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'bouw je geldautomaten-imperium',
                          style: TextStyle(
                            fontFamily: kTextFont,
                            fontSize: 14,
                            color: AppColors.ink.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // High score en startknoppen.
          Expanded(
            flex: 2,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'HIGH SCORE - TOTAAL VERDIEND',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kDigitFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: LedDisplay(
                        value: highScore,
                        fontSize: 26,
                        decimals: 0,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (hasSave) ...[
                      TactileButton(
                        label: 'Verder spelen',
                        color: AppColors.serviceButton,
                        onPressed: onContinue,
                      ),
                      const SizedBox(height: 10),
                      TactileButton(
                        label: 'Nieuw spel',
                        sublabel: 'wist je huidige spel',
                        color: AppColors.ledPanel,
                        textColor: AppColors.ledGlow,
                        onPressed: () => _confirmNewGame(context),
                      ),
                    ] else
                      TactileButton(
                        label: 'Start spel',
                        sublabel: 'start met EUR 1.000',
                        color: AppColors.serviceButton,
                        onPressed: () => _confirmNewGame(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
