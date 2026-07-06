import 'dart:io';

import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/models/atm.dart';
import 'package:atm_empire/models/cassette.dart';
import 'package:atm_empire/models/cit_van.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:atm_empire/models/hive_adapters.dart';
import 'package:atm_empire/models/mechanic.dart';
import 'package:atm_empire/persistence/save_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// Alleen voor de migratietests: er bestaat geen publieke API om rauwe
// legacy-bytes te bouwen, dus we gebruiken de interne writer en reader.
// ignore: implementation_imports
import 'package:hive/src/binary/binary_reader_impl.dart';
// ignore: implementation_imports
import 'package:hive/src/binary/binary_writer_impl.dart';

import 'helpers/states.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('atm_empire_hive_test');
    Hive.init(tempDir.path);
    registerHiveAdapters();
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('GameState plus tijdstempel overleven een Hive-rondreis', () async {
    // Een staat met zoveel mogelijk afwijkende velden.
    var state = singleAtmState(
      housing: AtmHousing.ttw,
      function: AtmFunction.recycler,
      level: 4,
      location: LocationType.evenement,
      balance: 1234.56,
      totalEarned: 8888,
    );
    state = withStaffHired(state, StaffId.analyst);
    state = withUpgradeLevel(state, UpgradeId.ibns, 3);
    state = state.copyWith(
      atms: [
        state.atms.first.copyWith(
          cassettes: const [
            Cassette(
              notes: 77,
              condition: 0.42,
              repairSecondsRemaining: 7,
              denomination: 10,
            ),
            Cassette(notes: 46, condition: 0.9, denomination: 50),
          ],
          lifetimeEarned: 55.5,
          lostCustomers: 12,
        ),
        Atm.fresh(id: 9, location: LocationType.snelweg),
      ],
      citVans: const [
        CitVan(id: 0),
        CitVan(
          id: 1,
          status: CitVanStatus.transitToAtm,
          targetAtmId: 9,
          ticksRemaining: 12,
        ),
      ],
      mechanics: const [
        ServiceMechanic(
          id: 0,
          status: CitVanStatus.servicing,
          targetAtmId: 0,
          ticksRemaining: 8,
        ),
        ServiceMechanic(id: 1),
      ],
      banks: [
        for (final b in state.banks)
          b.id == BankId.zuider
              ? b.copyWith(connected: true, contractLevel: 2)
              : b,
      ],
      prestigeLevel: 2,
      refillGoalRound: 3,
      refillGoalProgress: 2,
      nextEventInSeconds: 77,
      activeEvent: const ActiveEvent(
        type: GameEventType.festival,
        secondsRemaining: 33,
        targetAtmId: 9,
      ),
    );
    final savedAt = DateTime(2026, 7, 2, 12, 30);

    final repository = await SaveRepository.open();
    await repository.save(state, savedAt);
    final loaded = repository.load();

    expect(loaded, isNotNull);
    expect(loaded!.savedAt, savedAt);
    final restored = loaded.state;
    expect(restored.balance, state.balance);
    expect(restored.totalEarned, state.totalEarned);
    expect(restored.tick, state.tick);
    expect(restored.prestigeLevel, 2);
    expect(restored.milestonesClaimed, state.milestonesClaimed);
    expect(restored.refillGoalRound, 3);
    expect(restored.refillGoalProgress, 2);
    expect(restored.nextEventInSeconds, 77);

    expect(restored.atms.length, 2);
    final atm = restored.atms.first;
    expect(atm.id, 0);
    expect(atm.housing, AtmHousing.ttw);
    expect(atm.function, AtmFunction.recycler);
    expect(atm.level, 4);
    expect(atm.location, LocationType.evenement);
    expect(atm.cassettes.length, 2);
    expect(atm.cassettes.first.notes, 77);
    expect(atm.cassettes.first.condition, 0.42);
    expect(atm.cassettes.first.repairSecondsRemaining, 7);
    expect(atm.cassettes.first.denomination, 10);
    expect(atm.cassettes.last.notes, 46);
    expect(atm.cassettes.last.condition, 0.9);
    expect(atm.cassettes.last.denomination, 50);
    expect(atm.lifetimeEarned, 55.5);
    expect(atm.lostCustomers, 12);
    // Wachtrij en lopende transactie zijn bewust niet gepersisteerd.
    expect(atm.queueLength, 0);
    expect(atm.transaction, isNull);

    expect(restored.citVans.length, 2);
    expect(restored.citVans.first.isIdle, isTrue);
    expect(restored.citVans.last.status, CitVanStatus.transitToAtm);
    expect(restored.citVans.last.targetAtmId, 9);
    expect(restored.citVans.last.ticksRemaining, 12);

    expect(restored.mechanics.length, 2);
    expect(restored.mechanics.first.status, CitVanStatus.servicing);
    expect(restored.mechanics.first.targetAtmId, 0);
    expect(restored.mechanics.first.ticksRemaining, 8);
    expect(restored.mechanics.last.isIdle, isTrue);

    expect(restored.bank(BankId.zuider).connected, isTrue);
    expect(restored.bank(BankId.zuider).contractLevel, 2);
    expect(restored.upgradeLevel(UpgradeId.ibns), 3);
    expect(restored.hasStaff(StaffId.analyst), isTrue);
    expect(restored.hasStaff(StaffId.mechanic), isFalse);

    expect(restored.activeEvent, isNotNull);
    expect(restored.activeEvent!.type, GameEventType.festival);
    expect(restored.activeEvent!.secondsRemaining, 33);
    expect(restored.activeEvent!.targetAtmId, 9);
  });

  test('een leeg spel laadt als null', () async {
    final box = await Hive.openBox<dynamic>('empty_box_test');
    final repository = SaveRepository(box);
    expect(repository.load(), isNull);
  });

  group('Migratie van oude saves (Ontwerper dd 2026-07-04)', () {
    test('v1: enkele cassette wordt verdeeld en de tier gemapt', () {
      // Het v1-formaat: id, tier, locatie, biljetten, staat, reparatie,
      // stroomstoring, verdiend - zonder sentinel. Tierindex 3 was de
      // TTW recycler.
      final writer = BinaryWriterImpl(Hive);
      writer
        ..writeInt(4)
        ..writeInt(3)
        ..writeInt(LocationType.reizen.index)
        ..writeInt(234)
        ..writeDouble(0.66)
        ..writeDouble(0.0)
        ..writeDouble(3.0)
        ..writeDouble(1234.5);

      final atm = AtmAdapter().read(BinaryReaderImpl(writer.toBytes(), Hive));

      expect(atm.id, 4);
      expect(atm.housing, AtmHousing.ttw);
      expect(atm.function, AtmFunction.recycler);
      expect(atm.level, 3);
      expect(atm.location, LocationType.reizen);
      // 234 biljetten worden 100 + 100 + 34: geen biljet verloren; de
      // slots krijgen de vaste denominatie-configuratie.
      expect(atm.cassettes.length, 3);
      expect([for (final c in atm.cassettes) c.notes], [100, 100, 34]);
      expect([for (final c in atm.cassettes) c.denomination], [10, 20, 50]);
      expect(atm.cassettes.every((c) => c.condition == 0.66), isTrue);
      expect(atm.totalNotes, 234);
      expect(atm.outageSecondsRemaining, 3.0);
      expect(atm.lifetimeEarned, 1234.5);
    });

    test('v1: een lege automaat krijgt een lege cassette', () {
      final writer = BinaryWriterImpl(Hive);
      writer
        ..writeInt(0)
        ..writeInt(0)
        ..writeInt(LocationType.winkel.index)
        ..writeInt(0)
        ..writeDouble(1.0)
        ..writeDouble(0.0)
        ..writeDouble(0.0)
        ..writeDouble(0.0);

      final atm = AtmAdapter().read(BinaryReaderImpl(writer.toBytes(), Hive));
      expect(atm.cassettes.length, 1);
      expect(atm.cassettes.single.notes, 0);
      expect(atm.housing, AtmHousing.lobby);
      expect(atm.function, AtmFunction.dispenser);
      expect(atm.level, 1);
    });

    test('v2: multi-cassette met tier wordt naar de configuratie gemapt', () {
      // Het v2-formaat: sentinel -2, id, tier, locatie, stroomstoring,
      // verdiend, cassettelijst. Tierindex 1 was de Lobby plus.
      final writer = BinaryWriterImpl(Hive);
      writer
        ..writeInt(-2)
        ..writeInt(7)
        ..writeInt(1)
        ..writeInt(LocationType.station.index)
        ..writeDouble(0.0)
        ..writeDouble(9.9)
        ..writeInt(2)
        ..writeInt(80)
        ..writeDouble(0.5)
        ..writeDouble(0.0)
        ..writeInt(30)
        ..writeDouble(0.9)
        ..writeDouble(21.0);

      final atm = AtmAdapter().read(BinaryReaderImpl(writer.toBytes(), Hive));
      expect(atm.id, 7);
      expect(atm.housing, AtmHousing.lobby);
      expect(atm.function, AtmFunction.dispenser);
      expect(atm.level, 2);
      expect(atm.cassettes.length, 2);
      expect(atm.cassettes.first.notes, 80);
      expect(atm.cassettes.last.isBroken, isTrue);
      expect(atm.lifetimeEarned, 9.9);
    });

    test('een GameState zonder vlootveld krijgt de startvloot', () {
      // Het oude GameState-formaat eindigde na het actieve event; de
      // vlootlijst is een staartveld.
      final state = singleAtmState(balance: 777, totalEarned: 42);
      final writer = BinaryWriterImpl(Hive);
      writer
        ..writeDouble(state.balance)
        ..writeDouble(state.totalEarned)
        ..writeList(state.atms)
        ..writeList(state.banks)
        ..writeList(state.upgrades)
        ..writeList(state.staff)
        ..writeInt(state.prestigeLevel)
        ..writeInt(state.milestonesClaimed)
        ..writeInt(state.refillGoalRound)
        ..writeInt(state.refillGoalProgress)
        ..writeInt(state.tick)
        ..writeInt(state.nextEventInSeconds)
        ..writeBool(false);

      final migrated = GameStateAdapter().read(
        BinaryReaderImpl(writer.toBytes(), Hive),
      );
      expect(migrated.balance, 777);
      expect(migrated.citVans.length, kStartingCitVans);
      expect(migrated.citVans.every((v) => v.isIdle), isTrue);
    });
  });
}
