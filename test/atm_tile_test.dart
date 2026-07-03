import 'package:atm_empire/models/enums.dart';
import 'package:atm_empire/ui/widgets/atm_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/states.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, AtmTier tier) async {
    final state = singleAtmState(tier: tier);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AtmTile(
            state: state,
            atm: state.atms.single,
            onRefill: () {},
            onRepairTap: () {},
            onMaintain: () {},
            onUpgrade: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('lobby basic: geen contactless, camera of stortsleuf',
      (tester) async {
    await pumpTile(tester, AtmTier.lobbyBasic);

    expect(find.textContaining('Lobby basic'), findsOneWidget);
    expect(find.byIcon(Icons.contactless_outlined), findsNothing);
    expect(find.text('STORT'), findsNothing);
  });

  testWidgets('lobby plus: contactless erbij, nog geen stortsleuf',
      (tester) async {
    await pumpTile(tester, AtmTier.lobbyPlus);

    expect(find.textContaining('Lobby plus'), findsOneWidget);
    expect(find.byIcon(Icons.contactless_outlined), findsOneWidget);
    expect(find.text('STORT'), findsNothing);
  });

  testWidgets('ttw recycler: contactless en stortsleuf', (tester) async {
    await pumpTile(tester, AtmTier.ttwRecycler);

    expect(find.textContaining('TTW recycler'), findsOneWidget);
    expect(find.byIcon(Icons.contactless_outlined), findsOneWidget);
    expect(find.text('STORT'), findsOneWidget);
  });
}
