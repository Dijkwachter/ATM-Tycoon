import 'package:flutter/material.dart';

/// Visuele identiteit van ATM Empire (GDD 10): de warmte van de gele
/// automaat, de precisie van een bankbiljet. Licht thema.
abstract final class AppColors {
  /// Achtergrond: warm licht beige (GDD 10, F2F0EA).
  static const Color background = Color(0xFFF2F0EA);

  /// Kaarten: wit (GDD 10).
  static const Color card = Colors.white;

  /// Tekst: donker (GDD 10, 26221A).
  static const Color ink = Color(0xFF26221A);

  /// Headergradient boven (GDD 10, FFD75E).
  static const Color gradientTop = Color(0xFFFFD75E);

  /// Headergradient onder (GDD 10, F5B91E).
  static const Color gradientBottom = Color(0xFFF5B91E);

  /// Gloeiende LED-cijfers (GDD 10, FFE27A).
  static const Color ledGlow = Color(0xFFFFE27A);

  /// Donker LED-displaypaneel in header en automaat-schermpje.
  static const Color ledPanel = Color(0xFF1E1A12);

  /// Gedoofde LED-segmenten op het paneel.
  static const Color ledDim = Color(0xFF3A3322);

  /// Inkomsten-pills: groen (GDD 10).
  static const Color incomePill = Color(0xFF2E9E5B);

  /// DCC-pills: blauw (GDD 10).
  static const Color dccPill = Color(0xFF2E6FD8);

  /// Recycling-pills: paars (GDD 10).
  static const Color recyclingPill = Color(0xFF8A4FD8);

  /// Servicing-knop: groen (GDD 10).
  static const Color serviceButton = Color(0xFF2E9E5B);

  /// Waarschuwing (cassette leeg onder 1,5 min, storing): rood.
  static const Color warning = Color(0xFFD8402E);

  /// Randen en geleiders op de gele kasten.
  static const Color cabinetShade = Color(0xFFB8860B);

  /// Stalen muurframe van through-the-wall-automaten (tier 3 en 4).
  static const Color steel = Color(0xFF8E959C);

  /// Vlakke, goedkopere kastkleur van de instap-tier (lobby basic).
  static const Color cabinetBasic = Color(0xFFF8D566);
}

/// De headergradient van geel naar diep goudgeel (GDD 10).
const LinearGradient kHeaderGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.gradientTop, AppColors.gradientBottom],
);

/// Outfit voor tekst (modern geometrisch), Chakra Petch voor cijfers en
/// displays (technisch, past bij LED-panelen). Beide met echte 400/600/700
/// gewichten, zodat vet niet meer kunstmatig wordt gerenderd.
const String kTextFont = 'Outfit';
const String kDigitFont = 'Chakra Petch';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kTextFont,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.gradientBottom,
      surface: AppColors.background,
      onSurface: AppColors.ink,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
  );
}

/// Stijl voor LED-cijfers op donkere panelen.
TextStyle ledDigits(double size, {Color color = AppColors.ledGlow}) {
  return TextStyle(
    fontFamily: kDigitFont,
    fontWeight: FontWeight.w700,
    fontSize: size,
    color: color,
    letterSpacing: 0.5,
    // Tabulaire cijfers: elk cijfer even breed, zodat oplopende
    // bedragen niet heen en weer springen op het paneel.
    fontFeatures: const [FontFeature.tabularFigures()],
    shadows: [Shadow(color: color.withValues(alpha: 0.55), blurRadius: 8)],
  );
}
