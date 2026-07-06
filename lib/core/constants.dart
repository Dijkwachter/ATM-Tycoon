// ATM Empire balanswaarden.
//
// Dit bestand is de enige plek met balansgetallen; nergens anders in de code
// staan magic numbers. Elke constante verwijst naar zijn bron:
// - "Sheet!Cel" verwijst naar atm-empire-balancing.xlsx
// - "GDD x.y" verwijst naar een sectie of tabel in ATM_Empire_GDD.docx
// - "Ontwerper dd 2026-07-02" verwijst naar een expliciete beslissing van de
//   ontwerper waar GDD en spreadsheet geen waarde gaven.

import '../models/enums.dart';

/// Kans per seconde dat er een klant bij een operationele automaat
/// aankomt, voor vermenigvuldiging met de druktefactor. In het
/// wachtrijmodel (Ontwerper dd 2026-07-04) is dit de aanloop; de
/// verwerkingssnelheid van de automaat bepaalt hoe snel de rij slinkt.
/// Bron: Parameters!B5 (0,55), verlaagd naar 0,40 (Ontwerper dd
/// 2026-07-06) zodat de rij alleen in piekvakken echt vol staat in
/// plaats van permanent.
const double kTransactionChancePerSecond = 0.40;

/// Geduld van wachtende klanten (Ontwerper dd 2026-07-06): per tick is de
/// kans dat er iemand uit de rij wegloopt evenredig met de rijlengte
/// (rijlengte x deze kans, maximaal een wegloper per tick). Daardoor
/// pendelt de rij mee met de drukte in plaats van permanent vol te staan.
const double kQueueImpatienceChance = 0.06;

/// Bovengrens op de aanloopkans na druktefactor. Bron: GDD 3.1 tabel
/// Inkomsten ("max 0,95").
const double kTransactionChanceCap = 0.95;

/// Gemiddeld aantal biljetten dat een transactie uit de cassette haalt.
/// Geimplementeerd als 1 of 2 biljetten met gelijke kans. Bron: Parameters!B6.
const double kAvgNotesPerTransaction = 1.5;

/// Minimale spreidingsfactor op het tierinkomen per transactie.
/// Bron: GDD 3.1 tabel Inkomsten ("spreiding 0,8-1,4").
const double kIncomeSpreadMin = 0.8;

/// Maximale spreidingsfactor op het tierinkomen per transactie.
/// Bron: GDD 3.1 tabel Inkomsten. Gemiddelde 1,1 staat in Parameters!B7.
const double kIncomeSpreadMax = 1.4;

/// Gemiddelde spreidingsfactor, gebruikt in de deterministische
/// offline-berekening. Bron: Parameters!B7.
const double kIncomeSpreadAvg = 1.1;

/// Gemiddelde waarde van een biljet in de cassette, voor de float-rente.
/// Bron: Parameters!B8.
const double kAvgNoteValueEur = 40;

/// Float-rente per seconde over de cashwaarde in alle cassettes.
/// Kan het saldo nooit negatief maken. Bron: Parameters!B9.
const double kFloatInterestPerSecond = 0.000012;

/// Slijtage van de staat-balk per seconde (1,0 = 100 procent staat).
/// Bron: Parameters!B10.
const double kWearPerSecond = 0.004;

/// Extra slijtage per storting op een recycler. Bron: GDD 4
/// ("Recyclers slijten 0,003 extra per storting").
const double kRecyclerWearPerDeposit = 0.003;

/// Reparatieduur in seconden zonder monteur. Bron: Parameters!B11.
const int kRepairDurationSeconds = 30;

/// Reparatieduur in seconden met monteur in dienst. Bron: Parameters!B12.
const int kRepairDurationMechanicSeconds = 12;

/// Versnelling in seconden per tik tijdens een reparatie. Bron: GDD 4
/// ("elke tik versnelt 3 seconden").
const int kRepairTapSpeedupSeconds = 3;

/// Staat-drempel waaronder gratis preventief onderhoud beschikbaar is.
/// Bron: GDD 4 ("beschikbaar onder 90% staat").
const double kPreventiveMaintenanceThreshold = 0.90;

/// Deel van het normale inkomen dat offline wordt uitgekeerd.
/// Bron: Parameters!B13.
const double kOfflineIncomeFactor = 0.5;

/// Offline-inkomensdeel met regiomanager in dienst. Bron: GDD 7.2 tabel
/// Personeel ("Offline inkomen 50 naar 75%").
const double kOfflineIncomeFactorRegionalManager = 0.75;

/// Maximale offline-verdientijd in uren. Bron: Parameters!B14.
const int kOfflineCapHours = 1;

/// Permanente inkomensbonus per prestigelevel. Bron: Parameters!B15.
const double kPrestigeBonusPerLevel = 0.25;

/// Totaal-verdiend-drempel waarboven prestige mogelijk is. Bron: GDD 9.3
/// en Mijlpalen!A7.
const double kPrestigeThreshold = 25000;

/// Inkomensmultiplier van het 100 euro biljet, actief vanaf de eerste
/// prestige. Bron: Parameters!B16.
const double kHundredEuroNoteIncomeMultiplier = 1.6;

/// Cassette-drain-multiplier van het 100 euro biljet. Bron: Parameters!B17.
const double kHundredEuroNoteDrainMultiplier = 1.4;

/// Vast tarief per CIT-rit (servicing), onafhankelijk van cassettegrootte.
/// Bron: Parameters!B18.
const double kCitCostPerTrip = 60;

// ---------------------------------------------------------------------------
// Multi-cassette. Bron: Ontwerper dd 2026-07-04 ("Van enkele cassette naar
// multi-cassette slots").
// ---------------------------------------------------------------------------

/// Vaste capaciteit van een cassette in engine-eenheden. Met [kNotesPerUnit]
/// (20) komt dit overeen met de 2.000 echte biljetten uit het ontwerp.
const int kCassetteCapacityUnits = 100;

/// Maximaal aantal cassetteslots per automaat.
const int kMaxCassettesPerAtm = 5;

/// Vaste prijs van een extra cassette (leeg geleverd; een CIT-rit vult hem).
/// Bron: Ontwerper dd 2026-07-04.
const double kExtraCassettePrice = 500;

// ---------------------------------------------------------------------------
// CIT-vloot en reistijden. Bron: Ontwerper dd 2026-07-04 ("Logistiek &
// Dynamic CIT Management").
// ---------------------------------------------------------------------------

/// Aantal geldwagens waarmee een vers spel start.
const int kStartingCitVans = 1;

/// Maximale vlootomvang.
const int kMaxCitVans = 5;

/// Prijs van de tweede geldwagen; daarna exponentieel via
/// [kCitVanPriceGrowth].
const double kCitVanBasePrice = 1500;

/// Prijsgroeifactor per extra geldwagen.
const double kCitVanPriceGrowth = 2.0;

/// Duur van het vullen en repareren ter plaatse, in ticks.
const int kServicingDurationTicks = 3;

// ---------------------------------------------------------------------------
// Modulaire automaten: behuizing x functionaliteit x level 1-5.
// Bron: Ontwerper dd 2026-07-04 ("Modulaire ATM basis & het 5-level
// upgradesysteem").
// ---------------------------------------------------------------------------

/// Meerprijs van een through-the-wall-behuizing bij aankoop.
const double kTtwHousingPremium = 150;

/// Meerprijs van een recycler-module bij aankoop.
const double kRecyclerFunctionPremium = 250;

/// Basisinkomen per opname in EUR per functionaliteit: de recycler heeft
/// hogere basisinkomsten (dikkere transacties, stortbonussen apart).
/// Verhoogd van 7,0/9,0 (Ontwerper dd 2026-07-06) als compensatie voor de
/// rustigere aanloop, zodat de progressiecurve op peil blijft.
const double kDispenserBaseIncome = 8.0;
const double kRecyclerBaseIncome = 10.5;

/// Upgradekosten om level 2 tot en met 5 te bereiken.
const List<double> kLevelUpgradeCost = [350, 840, 2016, 4838];

/// Verwerkingsfase-duur (ticks) per level; de totale transactieduur is
/// kaart (1) + verwerking + shutter (1) + afronding (1). Hogere levels
/// werken wachtrijen dus sneller weg.
const List<int> kLevelProcessingTicks = [4, 3, 2, 2, 1];

/// Maximale wachtrij per level voordat nieuwe klanten ongeduldig
/// doorlopen ("Level 1: max 3 mensen, Level 5: max 15").
const List<int> kLevelQueueCapacity = [3, 6, 9, 12, 15];

/// Extra wachtrijplekken van een TTW-behuizing (straatkant, meer ruimte).
const int kTtwQueueBonus = 3;

/// Mechanische betrouwbaarheid: schaal op de basisslijtage per tick.
const List<double> kLevelWearFactor = [1.0, 0.85, 0.7, 0.55, 0.4];

/// Mechanische betrouwbaarheid: schaal op de klemloopkans per transactie.
const List<double> kLevelJamFactor = [1.0, 0.8, 0.6, 0.45, 0.3];

/// Kans op een interne mechanische storing (klemgelopen biljet) per
/// afgeronde transactie, voor de levelschaal. De recycler heeft meer
/// bewegende delen (invoer, teller) en dus meer risico.
const double kDispenserJamChance = 0.01;
const double kRecyclerJamChance = 0.03;

/// Beveiliging: kans dat een plofkraak/vandalismepoging wordt afgeslagen
/// puur op de kastbeveiliging (los van IBNS, die ook een verzekering
/// uitkeert).
const List<double> kLevelSecurityBlockChance = [0.0, 0.15, 0.3, 0.45, 0.6];

/// Beveiliging: schaal op de voorrijkosten van een nood-trip; op level 5
/// gehalveerd.
const List<double> kLevelCalloutFactor = [1.0, 0.875, 0.75, 0.625, 0.5];

/// Klanttevredenheid en UI-modernisering: permanente multiplier op de
/// verdiende transactiekosten per level.
const List<double> kLevelIncomeMultiplier = [1.0, 1.15, 1.3, 1.5, 1.75];

/// Aandeel stortingen in de transacties van een recycler; stortingen
/// vullen de cassettes live bij.
const double kRecyclerDepositShare = 0.3;

/// Fee in EUR per storting op een recycler (voor level- en
/// netwerkmultipliers).
const double kRecyclerDepositFee = 2.0;

/// Openingstijden van panden met een lobby-automaat: daarbuiten is de
/// aanloop minimaal en is de kast kwetsbaarder voor vandalisme. Retail
/// sluit doorgaans rond 20:00 (Ontwerper dd 2026-07-06).
const int kLobbyOpeningHour = 7;
const int kLobbyClosingHour = 20;

/// Aanloopfactor voor een lobby-automaat buiten openingstijden.
const double kLobbyClosedArrivalFactor = 0.15;

/// Schaal op de beveiligings-blokkeerkans van een lobby-automaat buiten
/// openingstijden (kwetsbaarder voor vandalisme).
const double kLobbyClosedSecurityFactor = 0.5;

/// Extra voorrijkosten bovenop [kBreakdownCalloutBase] voor zwaardere
/// behuizingen en modules.
const double kBreakdownCalloutTtwSurcharge = 20;
const double kBreakdownCalloutRecyclerSurcharge = 20;

/// DCC-bonus in EUR bovenop een toerist-transactie. Bron: Parameters!B20.
const double kDccBonusEur = 4;

/// DCC-kans per transactie op een normale locatie. Bron: Parameters!B21.
const double kDccChanceNormal = 0.05;

/// DCC-kans per transactie op een toeristische locatie (Reizen, Station,
/// Evenement, Horeca). Bron: Parameters!B22.
const double kDccChanceTourist = 0.14;

/// Minimaal aantal biljetten dat een storting terug de cassette in brengt.
/// Bron: Parameters!C24 en GDD 3.1 tabel Inkomsten ("2-6 biljetten").
const int kDepositNotesMin = 2;

/// Maximaal aantal biljetten per storting. Bron: Parameters!C24 en GDD 3.1.
const int kDepositNotesMax = 6;

/// Basis-voorrijkosten bij uitval van een automaat. Bron: Parameters!B25.
const double kBreakdownCalloutBase = 40;

/// Basisprijs van een nieuwe automaat in EUR. Bron: GDD 3.3
/// ("Nieuwe automaat: 400 euro basis").
const double kAtmBasePrice = 400;

/// Prijsgroeifactor per volgende gekochte automaat. Bron: Parameters!B28.
const double kAtmPriceGrowthFactor = 1.6;

/// Een nieuw spel start zonder automaten; de speler koopt zijn netwerk
/// zelf bij elkaar vanaf het startsaldo (Ontwerper dd 2026-07-03).
/// De eerste [kFlatPricedAtmCount] automaten kosten de basisprijs, daarna
/// groeit de prijs met [kAtmPriceGrowthFactor].
const int kFlatPricedAtmCount = 2;

/// Startsaldo in EUR: genoeg voor twee automaten van de basisprijs, of
/// een automaat plus een eerste investering (Ontwerper dd 2026-07-03).
const double kStartingBalance = 1000;

/// Weergaveschaal van de cassette: de engine rekent in spreadsheet-
/// eenheden (basis-cassette 100), de UI toont echte biljetten (basis-
/// cassette 2.000). Ontwerper dd 2026-07-03: "een cassette wordt normaal
/// met 2000 biljetten gevuld".
const int kNotesPerUnit = 20;

// ---------------------------------------------------------------------------
// Dagcyclus. Bron: GDD 5.
// ---------------------------------------------------------------------------

/// Duur van een speluur in echte seconden. Bron: GDD 5
/// ("Een speluur duurt 5 echte seconden").
const int kGameHourRealSeconds = 5;

/// Uren per etmaal; een etmaal duurt daarmee 120 echte seconden (GDD 5).
const int kHoursPerDay = 24;

/// Druktefactor voor uren die buiten zowel het piek- als het dalvenster van
/// een locatiesoort vallen. Bron: Ontwerper dd 2026-07-02, consistent met
/// Parameters!B26 (gemiddelde druktefactor over etmaal is ~1,0).
const double kDefaultBusyFactor = 1.0;

/// Een druktevenster binnen het etmaal. Bij [startHour] groter dan [endHour]
/// loopt het venster over middernacht heen (bijv. horeca 17-02 uur).
class BusyWindow {
  const BusyWindow(this.startHour, this.endHour, this.factor);

  /// Beginuur, inclusief.
  final int startHour;

  /// Einduur, exclusief.
  final int endHour;

  /// Druktefactor binnen dit venster.
  final double factor;

  bool contains(int hour) => startHour <= endHour
      ? hour >= startHour && hour < endHour
      : hour >= startHour || hour < endHour;
}

/// Drukteprofiel van een locatiesoort: expliciete vensters plus een factor
/// voor alle overige uren.
class BusyProfile {
  const BusyProfile(this.windows, this.otherFactor);

  final List<BusyWindow> windows;

  /// Factor voor uren buiten alle vensters. Voor locaties waar het GDD alle
  /// resterende uren benoemt (bijv. "nacht" of "overdag") is dit die factor;
  /// waar het GDD uren onbenoemd laat is dit [kDefaultBusyFactor].
  final double otherFactor;

  double factorAt(int hour) {
    for (final window in windows) {
      if (window.contains(hour)) {
        return window.factor;
      }
    }
    return otherFactor;
  }

  /// Rekenkundig gemiddelde over het etmaal, voor de deterministische
  /// offline-berekening.
  double get dayAverage {
    var sum = 0.0;
    for (var hour = 0; hour < kHoursPerDay; hour++) {
      sum += factorAt(hour);
    }
    return sum / kHoursPerDay;
  }
}

/// Drukteprofielen per locatiesoort. Bron: GDD 5 tabel Drukteprofielen.
/// De factor voor onbenoemde tussenuren (alleen Station en Winkel) is
/// [kDefaultBusyFactor], bevestigd door Ontwerper dd 2026-07-02.
const Map<LocationType, BusyProfile> kBusyProfiles = {
  // Station: piek 07-10 en 16-19 factor 2,0; dal 01-05 factor 0,2.
  LocationType.station: BusyProfile([
    BusyWindow(7, 10, 2.0),
    BusyWindow(16, 19, 2.0),
    BusyWindow(1, 5, 0.2),
  ], kDefaultBusyFactor),
  // Winkel: piek 09-18 factor 1,4; dal 21-09 factor 0,15.
  LocationType.winkel: BusyProfile([
    BusyWindow(9, 18, 1.4),
    BusyWindow(21, 9, 0.15),
  ], kDefaultBusyFactor),
  // Winkelcentrum: piek 10-21 factor 1,5; nacht factor 0,15.
  LocationType.winkelcentrum: BusyProfile([BusyWindow(10, 21, 1.5)], 0.15),
  // Horeca / casino: piek 17-02 factor 1,8; overdag factor 0,4.
  LocationType.horeca: BusyProfile([BusyWindow(17, 2, 1.8)], 0.4),
  // Evenement (stadion): piek 19-23 factor 2,5; overig factor 0,3.
  LocationType.evenement: BusyProfile([BusyWindow(19, 23, 2.5)], 0.3),
  // Reizen (luchthaven): hele dag factor 1,2.
  LocationType.reizen: BusyProfile([], 1.2),
  // Zorg: piek 08-20 factor 1,0; nacht factor 0,4.
  LocationType.zorg: BusyProfile([BusyWindow(8, 20, 1.0)], 0.4),
  // Snelweg: piek 06-22 factor 1,1; nacht factor 0,5.
  LocationType.snelweg: BusyProfile([BusyWindow(6, 22, 1.1)], 0.5),
  // Openbaar: piek 09-18 factor 0,9; nacht factor 0,1.
  LocationType.openbaar: BusyProfile([BusyWindow(9, 18, 0.9)], 0.1),
};

/// Toeristische locaties met verhoogde DCC-kans. Bron: Parameters!C22 en
/// GDD 3.1 tabel Inkomsten ("Reizen, Station, Evenement, Horeca").
const Set<LocationType> kTouristLocations = {
  LocationType.reizen,
  LocationType.station,
  LocationType.evenement,
  LocationType.horeca,
};

// ---------------------------------------------------------------------------
// Landkaart en toezichthouder. Bron: Ontwerper dd 2026-07-04 ("Interactieve
// landkaart & De Nationale Bank").
// ---------------------------------------------------------------------------

/// Kaartzone van elke locatiesoort.
const Map<LocationType, MapZone> kLocationZone = {
  LocationType.winkel: MapZone.dorp,
  LocationType.zorg: MapZone.dorp,
  LocationType.openbaar: MapZone.dorp,
  LocationType.station: MapZone.stad,
  LocationType.winkelcentrum: MapZone.stad,
  LocationType.horeca: MapZone.stad,
  LocationType.evenement: MapZone.regio,
  LocationType.reizen: MapZone.regio,
  LocationType.snelweg: MapZone.landelijk,
};

/// Enkele reistijd van een CIT-wagen naar een zone, in ticks. Het depot
/// staat in het dorp; hoe verder de zone, hoe langer de rit (15 tot 60).
const Map<MapZone, int> kZoneTravelTicks = {
  MapZone.dorp: 15,
  MapZone.stad: 25,
  MapZone.regio: 40,
  MapZone.landelijk: 60,
};

/// Vast punt op de landkaart, genormaliseerd 0,0 tot 1,0 in beide assen.
class MapPoint {
  const MapPoint(this.x, this.y);

  final double x;
  final double y;
}

/// Vaste coördinaten van elke locatiesoort op de landkaart. De kaart is in
/// kwadranten verdeeld: dorp linksboven, stad rechtsboven, regio linksonder,
/// landelijk rechtsonder.
const Map<LocationType, MapPoint> kLocationMapPoints = {
  LocationType.winkel: MapPoint(0.14, 0.16),
  LocationType.zorg: MapPoint(0.34, 0.34),
  LocationType.openbaar: MapPoint(0.15, 0.38),
  LocationType.station: MapPoint(0.64, 0.14),
  LocationType.winkelcentrum: MapPoint(0.86, 0.30),
  LocationType.horeca: MapPoint(0.66, 0.38),
  LocationType.evenement: MapPoint(0.16, 0.64),
  LocationType.reizen: MapPoint(0.36, 0.86),
  LocationType.snelweg: MapPoint(0.74, 0.74),
};

/// Spreidingswet van de Nationale Bank: vanaf dit aantal automaten in een
/// zone weigert de toezichthouder een volgende vergunning in die zone
/// zolang de rest van het land achterblijft. Concreet: een zone is
/// geblokkeerd wanneer hij [kSpreadLawZoneCap] of meer automaten heeft en
/// de leegste zone er [kSpreadLawZoneCap] minder heeft.
const int kSpreadLawZoneCap = 4;

// ---------------------------------------------------------------------------
// Events. Bron: GDD 6, tabel Events.
// ---------------------------------------------------------------------------

/// Minimale tijd in seconden tussen twee events. Bron: GDD 6
/// ("Elke 60 tot 120 seconden vuurt een willekeurig event").
const int kEventIntervalMinSeconds = 60;

/// Maximale tijd in seconden tussen twee events. Bron: GDD 6.
const int kEventIntervalMaxSeconds = 120;

/// Koningsdag: druktemultiplier voor alle automaten. Bron: GDD 6 tabel
/// Events ("dubbele drukte").
const double kKingsdayBusyMultiplier = 2.0;

/// Koningsdag: duur in seconden. Bron: GDD 6 tabel Events.
const int kKingsdayDurationSeconds = 45;

/// Festivalweekend: druktemultiplier voor een toeristische locatie.
/// Bron: GDD 6 tabel Events ("drukte x3").
const double kFestivalBusyMultiplier = 3.0;

/// Festivalweekend: duur in seconden. Bron: GDD 6 tabel Events.
const int kFestivalDurationSeconds = 60;

/// Stroomstoring: duur in seconden dat een automaat offline is.
/// Bron: GDD 6 tabel Events.
const int kPowerOutageDurationSeconds = 20;

/// Verzekeringsuitkering basis bij een afgeslagen plofkraakpoging.
/// Bron: GDD 3.1 tabel Inkomsten ("keert 100 + 60 per IBNS-level uit").
const double kHeistInsuranceBase = 100;

/// Extra verzekeringsuitkering per IBNS-level. Bron: GDD 3.1 tabel Inkomsten.
const double kHeistInsurancePerIbnsLevel = 60;

// ---------------------------------------------------------------------------
// Netwerk-upgrades. Bron: Upgrades-tab en GDD 7.1 tabel Upgrades.
// ---------------------------------------------------------------------------

/// Beveiliging (IBNS): basisprijs. Bron: Upgrades!B5.
const double kIbnsUpgradeBasePrice = 250;

/// Beveiliging (IBNS): prijsgroeifactor per level. Bron: Upgrades!C5.
const double kIbnsUpgradeGrowth = 2;

/// Beveiliging (IBNS): maximaal level. Bron: GDD 7.1 tabel Upgrades.
const int kIbnsUpgradeMaxLevel = 5;

/// IBNS: slijtagereductie per level, additief. Bron: GDD 4
/// ("IBNS: 12% langzamer per level") en Upgrades!I5.
const double kIbnsWearReductionPerLevel = 0.12;

/// IBNS: korting op voorrijkosten per level, additief. Bron: GDD 7.1 tabel
/// Upgrades ("-8% voorrijkosten") en Parameters!C25.
const double kIbnsCalloutDiscountPerLevel = 0.08;

/// CIT-routeoptimalisatie: basisprijs. Bron: Upgrades!B6.
const double kCitRouteUpgradeBasePrice = 400;

/// CIT-routeoptimalisatie: prijsgroeifactor per level. Bron: Upgrades!C6.
const double kCitRouteUpgradeGrowth = 2;

/// CIT-routeoptimalisatie: maximaal level. Bron: GDD 7.1 tabel Upgrades.
const int kCitRouteUpgradeMaxLevel = 4;

/// CIT-routeoptimalisatie: korting op ritkosten en reistijd per level,
/// additief. Bron: Parameters!C18 en Upgrades!I6 ("-15% refillkosten");
/// de reistijdkorting is Ontwerper dd 2026-07-04 (CIT-vlootsysteem).
const double kCitRouteDiscountPerLevel = 0.15;

// ---------------------------------------------------------------------------
// Personeel. Bron: GDD 7.2 tabel Medewerkers; monteurprijs ook Upgrades!B7.
// ---------------------------------------------------------------------------

/// Prijs van monteur Sven (reparaties 30 naar 12 seconden).
/// Bron: Upgrades!B7 en GDD 7.2.
const double kStaffMechanicPrice = 3000;

/// Prijs van CIT-planner Fatima (vult automatisch bij onder 15% cassette).
/// Bron: GDD 7.2 tabel Medewerkers.
const double kStaffCitPlannerPrice = 2500;

/// Cassette-drempel waaronder de CIT-planner automatisch bijvult.
/// Bron: GDD 7.2 tabel Medewerkers ("onder 15% cassette").
const double kCitPlannerRefillThreshold = 0.15;

/// Prijs van data-analist Kim (+10% inkomen). Bron: GDD 7.2 tabel
/// Medewerkers.
const double kStaffAnalystPrice = 4000;

/// Inkomensbonus van de data-analist. Bron: GDD 7.2 tabel Medewerkers
/// ("+10% inkomen").
const double kAnalystIncomeBonus = 0.10;

/// Prijs van regiomanager Joris (offline inkomen 50 naar 75%).
/// Bron: GDD 7.2 tabel Medewerkers.
const double kStaffRegionalManagerPrice = 5000;

// ---------------------------------------------------------------------------
// Banken. Bron: Banken-tab en GDD 8.
// ---------------------------------------------------------------------------

/// Transactieaandeel per bank: Bank Oranje, Rivierbank, Noorderbank,
/// Zuiderbank (aandeel na aansluiting). Bron: Banken!B2 tot B5.
const List<double> kBankShare = [0.5, 0.3, 0.2, 0.15];

/// Basistarief-multiplier per bank. Bron: Banken!C2 tot C5.
const List<double> kBankBaseRate = [0.9, 1.1, 1.35, 1.5];

/// Tariefverhoging per onderhandelingslevel. Bron: Banken!D2 en GDD 8
/// ("+0,05 tarief per level").
const double kBankNegotiationRatePerLevel = 0.05;

/// Maximaal contractlevel per bank. Bron: Banken!E2 en GDD 8.
const int kBankContractMaxLevel = 5;

/// Basiskosten van een contractonderhandeling; kosten zijn
/// basis x 2^level. Bron: Banken!F2 en GDD 8 ("kosten 500 x 2^level").
const double kBankNegotiationBaseCost = 500;

/// Groeifactor van de onderhandelingskosten per level. Bron: GDD 8
/// ("500 x 2^level").
const double kBankNegotiationCostGrowth = 2;

/// Aansluitkosten van de Zuiderbank, beschikbaar vanaf level Regio.
/// Bron: Banken!A5 en GDD 8 tabel Banken ("Unlock vanaf level Regio voor
/// 5.000").
const double kZuiderbankUnlockCost = 5000;

/// Schaalfactor op de aandelen van de bestaande drie banken na aansluiting
/// van de Zuiderbank. Bron: GDD 8 tabel Banken ("bestaande aandelen schalen
/// x0,85").
const double kZuiderbankShareRescale = 0.85;

// ---------------------------------------------------------------------------
// Progressie. Bron: GDD 9 en Mijlpalen-tab.
// ---------------------------------------------------------------------------

/// Totaal-verdiend-drempels per spelerslevel: Dorp, Stad, Regio, Landelijk
/// netwerk. Bron: GDD 9.1 tabel Levels.
const List<double> kLevelThresholds = [0, 2000, 8000, 25000];

/// Locatiesloten per spelerslevel. Bron: GDD 9.1 tabel Levels.
const List<int> kLevelLocationSlots = [3, 6, 9, 12];

/// Mijlpaaldrempels op totaal verdiend. Bron: Mijlpalen!A2 tot A7.
const List<double> kMilestoneThresholds = [750, 2000, 4000, 8000, 14000, 25000];

/// Cashbonus per mijlpaal. Bron: Mijlpalen!B2 tot B7.
const List<double> kMilestoneRewards = [150, 300, 500, 900, 1500, 3000];

/// Bijvuldoel: aantal bijvullingen in de eerste ronde. Bron: GDD 9.2
/// ("N groeit van 3 naar 8").
const int kRefillGoalBaseTarget = 3;

/// Bijvuldoel: maximaal aantal bijvullingen per ronde. Bron: GDD 9.2.
const int kRefillGoalMaxTarget = 8;

/// Bijvuldoel: beloning van de eerste ronde in EUR. Bron: Ontwerper dd
/// 2026-07-02 (niet in GDD of spreadsheet).
const double kRefillGoalBaseReward = 75;

/// Bijvuldoel: groeifactor van de beloning per ronde. Bron: GDD 9.2
/// ("de beloning met factor 1,6 per ronde").
const double kRefillGoalRewardGrowth = 1.6;

// ---------------------------------------------------------------------------
// Persistentie.
// ---------------------------------------------------------------------------

/// Interval in seconden waarmee de game state automatisch wordt opgeslagen.
/// Bron: sessie-specificatie fundament ("automatisch elke 10 seconden").
const int kAutosaveIntervalSeconds = 10;
