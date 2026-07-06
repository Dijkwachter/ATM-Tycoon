// Enums van het domeinmodel. Balanswaarden staan in lib/core/constants.dart.

/// Behuizing (vormfactor) van een automaat (Ontwerper dd 2026-07-04,
/// modulair ATM-systeem). Lobby staat vrijstaand binnen in een pand:
/// kortere wachtrij en buiten openingstijden nauwelijks aanloop maar wel
/// kwetsbaarder voor vandalisme. Through-the-wall zit in de buitenmuur:
/// grotere wachtrij-capaciteit en 24/7 activiteit.
enum AtmHousing { lobby, ttw }

/// Functionaliteit van een automaat. De dispenser doet alleen opnames;
/// de recycler accepteert ook stortingen (klanten vullen de cassettes
/// live bij) maar heeft meer bewegende delen en dus een hogere kans op
/// mechanische storingen zoals klemgelopen geld.
enum AtmFunction { dispenser, recycler }

/// Micro-fases van een lopende transactie, gevoed aan de UI voor de
/// geanimeerde choreografie (kaart aanbieden, verwerken, shutter open,
/// afronden). Elke fase duurt een of meer hele ticks.
enum TransactionPhase { cardPresented, processing, shutterAction, finishing }

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

  /// Gepantserd chassis voor de CIT-vloot: overvallen onderweg worden
  /// volledig afgeweerd (Ontwerper dd 2026-07-06, CiT-tabblad).
  armoredChassis,

  /// High-Capacity Kluis: een geldwagen kan per rit meerdere automaten
  /// aandoen (1 extra stop per level).
  vaultCapacity,

  /// Gereedschap & Diagnose-software: verkort de reparatietijd van
  /// monteurs ter plaatse (-20% per level).
  toolkit,

  /// Onderdelenmagazijn: monteurs rijden preventief uit naar automaten
  /// waarvan de conditie onder de drempel zakt, zonder voorrijkosten.
  partsDepot,
}

/// Personeel. Bron: GDD 7.2 tabel Medewerkers.
enum StaffId {
  mechanic,
  citPlanner,
  analyst,
  regionalManager,
  reliabilityAnalyst,
}

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
