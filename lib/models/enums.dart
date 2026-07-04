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
enum BankId { oranje, rivier, noorder, zuider }

/// Netwerk-upgrades. Bron: GDD 7.1 tabel Upgrades.
enum UpgradeId {
  /// Vervallen slot: de oude capaciteitsupgrade is vervangen door losse
  /// cassettes per automaat (Ontwerper dd 2026-07-04). De enum-index blijft
  /// staan omdat oude saves de index serialiseren; de UI verbergt hem en de
  /// engine negeert het level.
  cassettes,
  ibns,
  citRoute,
}

/// Personeel. Bron: GDD 7.2 tabel Medewerkers.
enum StaffId { mechanic, citPlanner, analyst, regionalManager }

/// Random events. Bron: GDD 6 tabel Events.
enum GameEventType { kingsday, festival, heistAttempt, powerOutage }

/// Spelerslevels op totaal verdiend. Bron: GDD 9.1 tabel Levels.
enum PlayerLevel { dorp, stad, regio, landelijk }

/// Zones van de landkaart, elk een kwadrant met eigen locaties en
/// CIT-reistijd (Ontwerper dd 2026-07-04).
enum MapZone { dorp, stad, regio, landelijk }

/// Status van een CIT-geldwagen (Ontwerper dd 2026-07-04): pas als de
/// wagen terug is bij het depot is hij weer inzetbaar.
enum CitVanStatus { idle, transitToAtm, servicing, returning }
