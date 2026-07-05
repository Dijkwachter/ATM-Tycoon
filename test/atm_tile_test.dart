import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/models/game_state.dart';
import 'package:atm_empire/ui/widgets/atm_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/states.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, GameState state) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AtmTile(
            state: state,
            atm: state.atms.single,
            onService: () {},
            onRepairTap: () {},
            onMaintain: () {},
            onUpgrade: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('lobby dispenser level 1: configuratie en korte rij', (
    tester,
  ) async {
    await pumpTile(tester, singleAtmState());

    expect(find.textContaining('Lobby dispenser'), findsOneWidget);
    expect(find.text('rij 0 van 3'), findsOneWidget);
    // De volgende upgrade is level 2.
    expect(find.text('Level 2'), findsOneWidget);
  });

  testWidgets('ttw recycler: configuratienaam en TTW-bonusruimte in de rij', (
    tester,
  ) async {
    await pumpTile(
      tester,
      singleAtmState(housing: AtmHousing.ttw, function: AtmFunction.recycler),
    );

    expect(find.textContaining('TTW recycler'), findsOneWidget);
    expect(find.text('rij 0 van 6'), findsOneWidget);
  });

  testWidgets('level 5 is het maximum: de Quantum Node', (tester) async {
    await pumpTile(tester, singleAtmState(level: 5));

    expect(find.text('Level max'), findsOneWidget);
    expect(find.text('Quantum Node'), findsOneWidget);
    expect(find.text('rij 0 van 15'), findsOneWidget);
  });

  testWidgets('een wachtende klant en de kaartfase zijn zichtbaar', (
    tester,
  ) async {
    final state = singleAtmState(queueLength: 2);
    await pumpTile(tester, state);
    expect(find.text('rij 2 van 3'), findsOneWidget);
  });
}
