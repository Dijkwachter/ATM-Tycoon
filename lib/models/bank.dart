import 'dart:math' as math;

import '../core/constants.dart';
import 'enums.dart';

/// Een bankcontract. Immutable; wijzigingen gaan via [copyWith].
///
/// Regels: GDD 8. Elke opname gebeurt namens een bank met een
/// transactieaandeel en een tariefmultiplier. Contractlevels blijven
/// behouden door prestige heen.
class Bank {
  const Bank({
    required this.id,
    this.contractLevel = 0,
    required this.connected,
  });

  final BankId id;

  /// Onderhandelingslevel, 0 tot [kBankContractMaxLevel].
  final int contractLevel;

  /// De Zuiderbank moet eerst aangesloten worden (GDD 8); de andere drie
  /// banken zijn vanaf het begin aangesloten.
  final bool connected;

  double get baseRate => kBankBaseRate[id.index];

  /// Basisaandeel in de transacties, voor herverdeling na Zuiderbank.
  double get baseShare => kBankShare[id.index];

  /// Effectief tarief: basistarief plus 0,05 per contractlevel (GDD 8).
  double get effectiveRate =>
      baseRate + kBankNegotiationRatePerLevel * contractLevel;

  bool get canNegotiate => connected && contractLevel < kBankContractMaxLevel;

  /// Kosten van de volgende onderhandeling: 500 x 2^level (GDD 8).
  double get negotiationCost =>
      kBankNegotiationBaseCost *
      math.pow(kBankNegotiationCostGrowth, contractLevel);

  Bank copyWith({int? contractLevel, bool? connected}) {
    return Bank(
      id: id,
      contractLevel: contractLevel ?? this.contractLevel,
      connected: connected ?? this.connected,
    );
  }
}
