// Enums van het domeinmodel. Balanswaarden staan in lib/core/constants.dart.

/// Terminal-tiers, oplopend. Bron: GDD 3.3 en Tiers-tab.
enum AtmTier {
  lobbyBasic,
  lobbyPlus,
  ttwUnit,
  ttwRecycler;

  /// Alleen de TTW recycler accepteert stortingen. Bron: GDD 3.3 tabel
  /// Terminal-tiers.
  bool get isRecycler => this == AtmTier.ttwRecycler;

  AtmTier? get next =>
      index + 1 < AtmTier.values.length ? AtmTier.values[index + 1] : null;
}

/// Locatiesoorten met elk een eigen drukteprofiel. Bron: GDD 5 tabel
/// Drukteprofielen.
enum LocationType {
  station,
  winkel,
  winkelcentrum,
  horeca,
  evenement,
  reizen,
  zorg,
  snelweg,
  openbaar,
}

/// De vier banken. Zuiderbank moet eerst aangesloten worden.
/// Bron: GDD 8 tabel Banken.
enum BankId {
  oranje,
  rivier,
  noorder,
  zuider,
}

/// Netwerk-upgrades. Bron: GDD 7.1 tabel Upgrades.
enum UpgradeId {
  cassettes,
  ibns,
  citRoute,
}

/// Personeel. Bron: GDD 7.2 tabel Medewerkers.
enum StaffId {
  mechanic,
  citPlanner,
  analyst,
  regionalManager,
}

/// Random events. Bron: GDD 6 tabel Events.
enum GameEventType {
  kingsday,
  festival,
  heistAttempt,
  powerOutage,
}

/// Spelerslevels op totaal verdiend. Bron: GDD 9.1 tabel Levels.
enum PlayerLevel {
  dorp,
  stad,
  regio,
  landelijk,
}
