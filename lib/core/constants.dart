// ATM Empire balanswaarden.
//
// Dit bestand is de enige plek met balansgetallen; nergens anders in de code
// staan magic numbers. Elke constante verwijst naar zijn bron:
// - "Sheet!Cel" verwijst naar atm-empire-balancing.xlsx
// - "GDD x.y" verwijst naar een sectie of tabel in ATM_Empire_GDD.docx
// - "Ontwerper dd 2026-07-02" verwijst naar een expliciete beslissing van de
//   ontwerper waar GDD en spreadsheet geen waarde gaven.

import '../models/enums.dart';

/// Kans per seconde dat een operationele automaat een transactie doet,
/// voor vermenigvuldiging met de druktefactor. Bron: Parameters!B5.
const double kTransactionChancePerSecond = 0.55;

/// Bovengrens op de transactiekans na druktefactor. Bron: GDD 3.1 tabel
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

/// DCC-bonus in EUR bovenop een toerist-transactie. Bron: Parameters!B20.
const double kDccBonusEur = 4;

/// DCC-kans per transactie op een normale locatie. Bron: Parameters!B21.
const double kDccChanceNormal = 0.05;

/// DCC-kans per transactie op een toeristische locatie (Reizen, Station,
/// Evenement, Horeca). Bron: Parameters!B22.
const double kDccChanceTourist = 0.14;

/// Fee in EUR per storting op een recycler. Bron: Parameters!B23.
const double kDepositFeeEur = 0.5;

/// Kans per seconde op een storting bij een operationele recycler.
/// Bron: Parameters!B24.
const double kDepositChancePerSecond = 0.12;

/// Minimaal aantal biljetten dat een storting terug de cassette in brengt.
/// Bron: Parameters!C24 en GDD 3.1 tabel Inkomsten ("2-6 biljetten").
const int kDepositNotesMin = 2;

/// Maximaal aantal biljetten per storting. Bron: Parameters!C24 en GDD 3.1.
const int kDepositNotesMax = 6;

/// Basis-voorrijkosten bij uitval van een automaat. Bron: Parameters!B25.
const double kBreakdownCalloutBase = 40;

/// Extra voorrijkosten per tier (tierindex 0 tot 3). Bron: GDD 3.2 tabel
/// Kosten ("40 + 20 per tier").
const double kBreakdownCalloutPerTier = 20;

/// Basisprijs van een nieuwe automaat in EUR. Bron: GDD 3.3
/// ("Nieuwe automaat: 400 euro basis").
const double kAtmBasePrice = 400;

/// Prijsgroeifactor per volgende gekochte automaat. Bron: Parameters!B28.
const double kAtmPriceGrowthFactor = 1.6;

/// Aantal automaten waarmee een nieuw spel start (Lobby basic, gratis).
/// Bron: Simulatie!B5 ("Start: 2x Lobby basic").
const int kStartingAtmCount = 2;

/// Startsaldo in EUR. Bron: Simulatie-tab rekent vanaf 0; bevestigd door
/// Ontwerper dd 2026-07-02.
const double kStartingBalance = 0;

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
  LocationType.station: BusyProfile(
    [BusyWindow(7, 10, 2.0), BusyWindow(16, 19, 2.0), BusyWindow(1, 5, 0.2)],
    kDefaultBusyFactor,
  ),
  // Winkel: piek 09-18 factor 1,4; dal 21-09 factor 0,15.
  LocationType.winkel: BusyProfile(
    [BusyWindow(9, 18, 1.4), BusyWindow(21, 9, 0.15)],
    kDefaultBusyFactor,
  ),
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
// Terminal-tiers. Bron: Tiers-tab, rijen 2 tot 5.
// ---------------------------------------------------------------------------

/// Cassettecapaciteit in biljetten per tier, index 0 = Lobby basic tot
/// index 3 = TTW recycler. Bron: Tiers!B2 tot B5.
const List<int> kTierCapacity = [100, 160, 240, 340];

/// Inkomen per transactie in EUR per tier. Bron: Tiers!C2 tot C5.
const List<double> kTierIncomePerTransaction = [2, 3, 5, 8];

/// Upgradekosten in EUR om deze tier te bereiken vanaf de vorige.
/// Index 0 is de starttier en kost niets. Bron: Tiers!D2 tot D5.
const List<double> kTierUpgradeCost = [0, 350, 840, 2016];

// ---------------------------------------------------------------------------
// Netwerk-upgrades. Bron: Upgrades-tab en GDD 7.1 tabel Upgrades.
// ---------------------------------------------------------------------------

/// Grotere cassettes: basisprijs. Bron: Upgrades!B4.
const double kCassetteUpgradeBasePrice = 300;

/// Grotere cassettes: prijsgroeifactor per level. Bron: Upgrades!C4.
const double kCassetteUpgradeGrowth = 2;

/// Grotere cassettes: maximaal level. Bron: GDD 7.1 tabel Upgrades.
const int kCassetteUpgradeMaxLevel = 5;

/// Grotere cassettes: extra capaciteit per level, additief op de
/// tiercapaciteit. Bron: Upgrades!I4 ("+40% capaciteit").
const double kCassetteCapacityBonusPerLevel = 0.40;

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

/// CIT-routeoptimalisatie: korting op ritkosten per level, additief.
/// Bron: Parameters!C18 en Upgrades!I6 ("-15% refillkosten").
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
