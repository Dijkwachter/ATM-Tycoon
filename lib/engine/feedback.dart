/// Kortstondige feedback-events uit de engine voor de UI (GDD 10):
/// groene inkomsten-pills, blauwe DCC-pills, paarse recycling-pills en
/// muntenregen bij mijlpalen. Deze events zijn geen spelstaat en worden
/// niet gepersisteerd.
enum FeedbackType {
  /// Opname-inkomen op een automaat: groene pill.
  income,

  /// DCC-bonus op een automaat: blauwe pill.
  dcc,

  /// Stortingsfee op een recycler: paarse pill.
  recycling,

  /// Mijlpaalbonus: muntenregen.
  milestone,

  /// Bijvuldoel-beloning.
  refillGoal,

  /// Verzekeringsuitkering na een afgeslagen plofkraak.
  insurance,
}

class GameFeedback {
  const GameFeedback(this.type, this.amount, {this.atmId});

  final FeedbackType type;
  final double amount;

  /// De automaat waar dit gebeurde; null voor netwerkbrede events.
  final int? atmId;
}
