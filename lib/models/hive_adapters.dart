import 'package:hive/hive.dart';

import 'atm.dart';
import 'bank.dart';
import 'enums.dart';
import 'game_state.dart';
import 'staff.dart';
import 'upgrade.dart';

/// Handgeschreven Hive-adapters. Enums worden als index geserialiseerd;
/// veldvolgorde is het schema, dus alleen achteraan uitbreiden.

class AtmAdapter extends TypeAdapter<Atm> {
  @override
  final int typeId = 1;

  @override
  void write(BinaryWriter writer, Atm obj) {
    writer
      ..writeInt(obj.id)
      ..writeInt(obj.tier.index)
      ..writeInt(obj.location.index)
      ..writeInt(obj.notesInCassette)
      ..writeDouble(obj.condition)
      ..writeDouble(obj.repairSecondsRemaining)
      ..writeDouble(obj.outageSecondsRemaining)
      ..writeDouble(obj.lifetimeEarned);
  }

  @override
  Atm read(BinaryReader reader) {
    return Atm(
      id: reader.readInt(),
      tier: AtmTier.values[reader.readInt()],
      location: LocationType.values[reader.readInt()],
      notesInCassette: reader.readInt(),
      condition: reader.readDouble(),
      repairSecondsRemaining: reader.readDouble(),
      outageSecondsRemaining: reader.readDouble(),
      lifetimeEarned: reader.readDouble(),
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
    return GameState(
      balance: balance,
      totalEarned: totalEarned,
      atms: atms,
      banks: banks,
      upgrades: upgrades,
      staff: staff,
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
      ..registerAdapter(ActiveEventAdapter());
  }
}
