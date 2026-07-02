import 'dart:io';

import 'package:atm_empire/models/atm.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:atm_empire/models/hive_adapters.dart';
import 'package:atm_empire/persistence/save_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

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
      tier: AtmTier.ttwRecycler,
      location: LocationType.evenement,
      notesInCassette: 123,
      condition: 0.42,
      balance: 1234.56,
      totalEarned: 8888,
    );
    state = withStaffHired(state, StaffId.analyst);
    state = withUpgradeLevel(state, UpgradeId.ibns, 3);
    state = state.copyWith(
      atms: [
        state.atms.first.copyWith(
          repairSecondsRemaining: 7,
          lifetimeEarned: 55.5,
        ),
        Atm.fresh(id: 9, location: LocationType.snelweg),
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
    expect(atm.tier, AtmTier.ttwRecycler);
    expect(atm.location, LocationType.evenement);
    expect(atm.notesInCassette, 123);
    expect(atm.condition, 0.42);
    expect(atm.repairSecondsRemaining, 7);
    expect(atm.lifetimeEarned, 55.5);

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
}
