/// Nederlandse getalnotatie zonder intl-afhankelijkheid: punt voor
/// duizendtallen, komma voor decimalen.
String formatEuro(double value, {int decimals = 2}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  final whole = buffer.toString();
  final result = decimals > 0 && parts.length > 1
      ? '$whole,${parts[1]}'
      : whole;
  return negative ? '-$result' : result;
}

/// Compact bedrag voor knoppen: geen decimalen bij ronde bedragen.
String formatEuroCompact(double value) {
  final rounded = value.roundToDouble();
  return (value - rounded).abs() < 0.005
      ? formatEuro(rounded, decimals: 0)
      : formatEuro(value);
}

/// Spelklok als HH:MM (een speluur duurt 5 echte seconden, GDD 5).
String formatGameClock(int tick, int secondsPerHour) {
  final hour = (tick ~/ secondsPerHour) % 24;
  final minute = (tick % secondsPerHour) * 60 ~/ secondsPerHour;
  final hh = hour.toString().padLeft(2, '0');
  final mm = minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
