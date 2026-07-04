import 'dart:math' as math;

import 'package:hive/hive.dart';

import '../core/constants.dart';
import 'atm.dart';
import 'bank.dart';
import 'cassette.dart';
import 'cit_van.dart';
import 'enums.dart';
import 'game_state.dart';
import 'staff.dart';
import 'upgrade.dart';

/// Handgeschreven Hive-adapters. Enums worden als index geserialiseerd;
/// veldvolgorde is het schema, dus alleen achteraan uitbreiden.
///
/// Migratie (Ontwerper dd 2026-07-04): het oude Atm-formaat had een enkele
/// cassette in losse velden; het nieuwe formaat begint met de sentinel
/// [AtmAdapter.formatV2] zodat beide gelezen kunnen worden. De GameState
/// kreeg de CIT-vloot als staartveld: oude saves zonder dat veld krijgen
/// de startvloot.

class AtmAdapter extends TypeAdapter<Atm> {
  @override
  final int typeId = 1;

  /// Sentinel van het multi-cassette-formaat. Het oude formaat begint met
  /// de (nooit negatieve) automaat-id, dus een negatieve eerste waarde
  /// markeert ondubbelzinnig het nieuwe schema.
  static const int formatV2 = -2;

  @override
  void write(BinaryWriter writer, Atm obj) {
    writer
      ..writeInt(formatV2)
      ..writeInt(obj.id)
      ..writeInt(obj.tier.index)
      ..writeInt(obj.location.index)
      ..writeDouble(obj.outageSecondsRemaining)
      ..writeDouble(obj.lifetimeEarned)
      ..writeInt(obj.cassettes.length);
    for (final c in obj.cassettes) {
      writer
        ..writeInt(c.notes)
        ..writeDouble(c.condition)
        ..writeDouble(c.repairSecondsRemaining);
    }
  }

  @override
  Atm read(BinaryReader reader) {
    final first = reader.readInt();
    if (first != formatV2) {
      return _readLegacy(reader, id: first);
    }
    final id = reader.readInt();
    final tier = AtmTier.values[reader.readInt()];
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
        ),
    ];
    return Atm(
      id: id,
      tier: tier,
      location: location,
      cassettes: cassettes,
      outageSecondsRemaining: outageSecondsRemaining,
      lifetimeEarned: lifetimeEarned,
    );
  }

  /// Oude formaat (enkele cassette): de inhoud wordt over cassettes van de
  /// vaste maat verdeeld zodat de speler geen biljetten verliest; staat en
  /// eventuele storing gelden voor alle slots.
  Atm _readLegacy(BinaryReader reader, {required int id}) {
    final tier = AtmTier.values[reader.readInt()];
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
        ),
    ];
    return Atm(
      id: id,
      tier: tier,
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
    return GameState(
      balance: balance,
      totalEarned: totalEarned,
      atms: atms,
      banks: banks,
      upgrades: upgrades,
      staff: staff,
      citVans: citVans,
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
      ..registerAdapter(CitVanAdapter());
  }
}
