import 'dart:math' as math;

import 'package:hive/hive.dart';

import '../core/constants.dart';
import 'atm.dart';
import 'bank.dart';
import 'cassette.dart';
import 'cit_van.dart';
import 'enums.dart';
import 'game_state.dart';
import 'mechanic.dart';
import 'staff.dart';
import 'upgrade.dart';

/// Handgeschreven Hive-adapters. Enums worden als index geserialiseerd;
/// veldvolgorde is het schema, dus alleen achteraan uitbreiden.
///
/// Migratie (Ontwerper dd 2026-07-04): de Atm heeft drie generaties. V1
/// (enkele cassette in losse velden) begint met de nooit-negatieve id;
/// v2 (multi-cassette met tiers) met sentinel -2; v3 (modulair:
/// behuizing, functionaliteit, level) met sentinel -3. Alle drie zijn
/// leesbaar; er wordt alleen v3 geschreven. Wachtrij en lopende
/// transactie zijn bewust geen onderdeel van het schema: klanten wachten
/// niet op een app-herstart. De GameState kreeg de CIT-vloot als
/// staartveld: oude saves zonder dat veld krijgen de startvloot.

class AtmAdapter extends TypeAdapter<Atm> {
  @override
  final int typeId = 1;

  /// Sentinel van het multi-cassette-formaat met tiers (vervallen).
  static const int formatV2 = -2;

  /// Sentinel van het modulaire formaat (behuizing/functionaliteit/level).
  static const int formatV3 = -3;

  /// Sentinel van het formaat met cassette-denominaties (Ontwerper dd
  /// 2026-07-06).
  static const int formatV4 = -4;

  /// Mapping van de vervallen tier-index naar de modulaire configuratie:
  /// lobbyBasic, lobbyPlus, ttwUnit, ttwRecycler.
  static const List<(AtmHousing, AtmFunction, int)> tierMigration = [
    (AtmHousing.lobby, AtmFunction.dispenser, 1),
    (AtmHousing.lobby, AtmFunction.dispenser, 2),
    (AtmHousing.ttw, AtmFunction.dispenser, 3),
    (AtmHousing.ttw, AtmFunction.recycler, 3),
  ];

  @override
  void write(BinaryWriter writer, Atm obj) {
    writer
      ..writeInt(formatV4)
      ..writeInt(obj.id)
      ..writeInt(obj.housing.index)
      ..writeInt(obj.function.index)
      ..writeInt(obj.level)
      ..writeInt(obj.location.index)
      ..writeDouble(obj.outageSecondsRemaining)
      ..writeDouble(obj.lifetimeEarned)
      ..writeInt(obj.lostCustomers)
      ..writeInt(obj.cassettes.length);
    for (final c in obj.cassettes) {
      writer
        ..writeInt(c.notes)
        ..writeDouble(c.condition)
        ..writeDouble(c.repairSecondsRemaining)
        ..writeInt(c.denomination);
    }
  }

  @override
  Atm read(BinaryReader reader) {
    final first = reader.readInt();
    if (first == formatV4) {
      return _readModern(reader, withDenominations: true);
    }
    if (first == formatV3) {
      return _readModern(reader, withDenominations: false);
    }
    if (first == formatV2) {
      return _readV2(reader);
    }
    return _readV1(reader, id: first);
  }

  /// V3 en v4 delen de lay-out; v3 mist alleen de denominatie per
  /// cassette en krijgt die dan uit de vaste slotconfiguratie.
  Atm _readModern(BinaryReader reader, {required bool withDenominations}) {
    final id = reader.readInt();
    final housing = AtmHousing.values[reader.readInt()];
    final function = AtmFunction.values[reader.readInt()];
    final level = reader.readInt();
    final location = LocationType.values[reader.readInt()];
    final outageSecondsRemaining = reader.readDouble();
    final lifetimeEarned = reader.readDouble();
    final lostCustomers = reader.readInt();
    final count = reader.readInt();
    final cassettes = <Cassette>[
      for (var i = 0; i < count; i++)
        Cassette(
          notes: reader.readInt(),
          condition: reader.readDouble(),
          repairSecondsRemaining: reader.readDouble(),
          denomination: withDenominations
              ? reader.readInt()
              : kCassetteDenominations[math.min(
                  i,
                  kCassetteDenominations.length - 1,
                )],
        ),
    ];
    return Atm(
      id: id,
      housing: housing,
      function: function,
      level: level,
      location: location,
      cassettes: cassettes,
      outageSecondsRemaining: outageSecondsRemaining,
      lifetimeEarned: lifetimeEarned,
      lostCustomers: lostCustomers,
    );
  }

  /// V2 (multi-cassette met tiers): de tier wordt naar de modulaire
  /// configuratie gemapt via [tierMigration].
  Atm _readV2(BinaryReader reader) {
    final id = reader.readInt();
    final tierIndex = reader.readInt();
    final location = LocationType.values[reader.readInt()];
    final outageSecondsRemaining = reader.readDouble();
    final lifetimeEarned = reader.readDouble();
    final count = reader.readInt();
    final cassettes = <Cassette>[
      for (var i = 0; i < count; i++)
        Cassette(
          notes: reader.readInt(),
          condition: reader.readDouble(),
          repairSecondsRemaining: reader.readDouble(),
          denomination:
              kCassetteDenominations[math.min(
                i,
                kCassetteDenominations.length - 1,
              )],
        ),
    ];
    final (housing, function, level) = tierMigration[tierIndex];
    return Atm(
      id: id,
      housing: housing,
      function: function,
      level: level,
      location: location,
      cassettes: cassettes,
      outageSecondsRemaining: outageSecondsRemaining,
      lifetimeEarned: lifetimeEarned,
    );
  }

  /// V1 (enkele cassette): de inhoud wordt over cassettes van de vaste
  /// maat verdeeld zodat de speler geen biljetten verliest; staat en
  /// eventuele storing gelden voor alle slots. De tier wordt daarna als
  /// bij v2 gemapt.
  Atm _readV1(BinaryReader reader, {required int id}) {
    final tierIndex = reader.readInt();
    final location = LocationType.values[reader.readInt()];
    final notes = reader.readInt();
    final condition = reader.readDouble();
    final repairSecondsRemaining = reader.readDouble();
    final outageSecondsRemaining = reader.readDouble();
    final lifetimeEarned = reader.readDouble();

    final slots = math.max(
      1,
      math.min(kMaxCassettesPerAtm, (notes / kCassetteCapacityUnits).ceil()),
    );
    var remaining = notes;
    final cassettes = <Cassette>[
      for (var i = 0; i < slots; i++)
        Cassette(
          notes: () {
            final take = math.min(kCassetteCapacityUnits, remaining);
            remaining -= take;
            return take;
          }(),
          condition: condition,
          repairSecondsRemaining: repairSecondsRemaining,
          denomination:
              kCassetteDenominations[math.min(
                i,
                kCassetteDenominations.length - 1,
              )],
        ),
    ];
    final (housing, function, level) = tierMigration[tierIndex];
    return Atm(
      id: id,
      housing: housing,
      function: function,
      level: level,
      location: location,
      cassettes: cassettes,
      outageSecondsRemaining: outageSecondsRemaining,
      lifetimeEarned: lifetimeEarned,
    );
  }
}

class CitVanAdapter extends TypeAdapter<CitVan> {
  @override
  final int typeId = 6;

  @override
  void write(BinaryWriter writer, CitVan obj) {
    writer
      ..writeInt(obj.id)
      ..writeInt(obj.status.index)
      ..writeInt(obj.ticksRemaining)
      ..writeBool(obj.targetAtmId != null);
    if (obj.targetAtmId != null) {
      writer.writeInt(obj.targetAtmId!);
    }
  }

  @override
  CitVan read(BinaryReader reader) {
    final id = reader.readInt();
    final status = CitVanStatus.values[reader.readInt()];
    final ticksRemaining = reader.readInt();
    final hasTarget = reader.readBool();
    return CitVan(
      id: id,
      status: status,
      ticksRemaining: ticksRemaining,
      targetAtmId: hasTarget ? reader.readInt() : null,
    );
  }
}

class BankAdapter extends TypeAdapter<Bank> {
  @override
  final int typeId = 2;

  @override
  void write(BinaryWriter writer, Bank obj) {
    writer
      ..writeInt(obj.id.index)
      ..writeInt(obj.contractLevel)
      ..writeBool(obj.connected);
  }

  @override
  Bank read(BinaryReader reader) {
    return Bank(
      id: BankId.values[reader.readInt()],
      contractLevel: reader.readInt(),
      connected: reader.readBool(),
    );
  }
}

class UpgradeAdapter extends TypeAdapter<Upgrade> {
  @override
  final int typeId = 3;

  @override
  void write(BinaryWriter writer, Upgrade obj) {
    writer
      ..writeInt(obj.id.index)
      ..writeInt(obj.level);
  }

  @override
  Upgrade read(BinaryReader reader) {
    return Upgrade(
      id: UpgradeId.values[reader.readInt()],
      level: reader.readInt(),
    );
  }
}

class StaffAdapter extends TypeAdapter<Staff> {
  @override
  final int typeId = 4;

  @override
  void write(BinaryWriter writer, Staff obj) {
    writer
      ..writeInt(obj.id.index)
      ..writeBool(obj.hired);
  }

  @override
  Staff read(BinaryReader reader) {
    return Staff(
      id: StaffId.values[reader.readInt()],
      hired: reader.readBool(),
    );
  }
}

class ActiveEventAdapter extends TypeAdapter<ActiveEvent> {
  @override
  final int typeId = 5;

  @override
  void write(BinaryWriter writer, ActiveEvent obj) {
    writer
      ..writeInt(obj.type.index)
      ..writeInt(obj.secondsRemaining)
      ..writeBool(obj.targetAtmId != null);
    if (obj.targetAtmId != null) {
      writer.writeInt(obj.targetAtmId!);
    }
  }

  @override
  ActiveEvent read(BinaryReader reader) {
    final type = GameEventType.values[reader.readInt()];
    final secondsRemaining = reader.readInt();
    final hasTarget = reader.readBool();
    return ActiveEvent(
      type: type,
      secondsRemaining: secondsRemaining,
      targetAtmId: hasTarget ? reader.readInt() : null,
    );
  }
}

class GameStateAdapter extends TypeAdapter<GameState> {
  @override
  final int typeId = 0;

  @override
  void write(BinaryWriter writer, GameState obj) {
    writer
      ..writeDouble(obj.balance)
      ..writeDouble(obj.totalEarned)
      ..writeList(obj.atms)
      ..writeList(obj.banks)
      ..writeList(obj.upgrades)
      ..writeList(obj.staff)
      ..writeInt(obj.prestigeLevel)
      ..writeInt(obj.milestonesClaimed)
      ..writeInt(obj.refillGoalRound)
      ..writeInt(obj.refillGoalProgress)
      ..writeInt(obj.tick)
      ..writeInt(obj.nextEventInSeconds)
      ..writeBool(obj.activeEvent != null);
    if (obj.activeEvent != null) {
      writer.write(obj.activeEvent!);
    }
    // Staartvelden (na de oude lay-out, zodat oude saves leesbaar blijven).
    writer.writeList(obj.citVans);
    writer.writeList(obj.mechanics);
  }

  @override
  GameState read(BinaryReader reader) {
    final balance = reader.readDouble();
    final totalEarned = reader.readDouble();
    final atms = reader.readList().cast<Atm>();
    final banks = reader.readList().cast<Bank>();
    final upgrades = reader.readList().cast<Upgrade>();
    final staff = reader.readList().cast<Staff>();
    final prestigeLevel = reader.readInt();
    final milestonesClaimed = reader.readInt();
    final refillGoalRound = reader.readInt();
    final refillGoalProgress = reader.readInt();
    final tick = reader.readInt();
    final nextEventInSeconds = reader.readInt();
    final hasEvent = reader.readBool();
    final activeEvent = hasEvent ? reader.read() as ActiveEvent : null;
    // Oude saves stoppen hier: dan krijgt de speler de startvloot.
    final citVans = reader.availableBytes > 0
        ? reader.readList().cast<CitVan>()
        : [for (var i = 0; i < kStartingCitVans; i++) CitVan(id: i)];
    // Tweede staartveld: de monteursploeg (Ontwerper dd 2026-07-06);
    // oudere saves krijgen de startploeg.
    final mechanics = reader.availableBytes > 0
        ? reader.readList().cast<ServiceMechanic>()
        : [for (var i = 0; i < kStartingMechanics; i++) ServiceMechanic(id: i)];
    return GameState(
      balance: balance,
      totalEarned: totalEarned,
      atms: atms,
      banks: banks,
      upgrades: upgrades,
      staff: staff,
      citVans: citVans,
      mechanics: mechanics,
      prestigeLevel: prestigeLevel,
      milestonesClaimed: milestonesClaimed,
      refillGoalRound: refillGoalRound,
      refillGoalProgress: refillGoalProgress,
      tick: tick,
      nextEventInSeconds: nextEventInSeconds,
      activeEvent: activeEvent,
    );
  }
}

class ServiceMechanicAdapter extends TypeAdapter<ServiceMechanic> {
  @override
  final int typeId = 7;

  @override
  void write(BinaryWriter writer, ServiceMechanic obj) {
    writer
      ..writeInt(obj.id)
      ..writeInt(obj.status.index)
      ..writeInt(obj.ticksRemaining)
      ..writeBool(obj.targetAtmId != null);
    if (obj.targetAtmId != null) {
      writer.writeInt(obj.targetAtmId!);
    }
  }

  @override
  ServiceMechanic read(BinaryReader reader) {
    final id = reader.readInt();
    final status = CitVanStatus.values[reader.readInt()];
    final ticksRemaining = reader.readInt();
    final hasTarget = reader.readBool();
    return ServiceMechanic(
      id: id,
      status: status,
      ticksRemaining: ticksRemaining,
      targetAtmId: hasTarget ? reader.readInt() : null,
    );
  }
}

/// Registreert alle adapters precies een keer.
void registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive
      ..registerAdapter(GameStateAdapter())
      ..registerAdapter(AtmAdapter())
      ..registerAdapter(BankAdapter())
      ..registerAdapter(UpgradeAdapter())
      ..registerAdapter(StaffAdapter())
      ..registerAdapter(ActiveEventAdapter())
      ..registerAdapter(CitVanAdapter())
      ..registerAdapter(ServiceMechanicAdapter());
  }
}
