import 'package:atm_empire/ui/theme.dart';
import 'package:atm_empire/ui/widgets/game_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/states.dart';

void main() {
  testWidgets('de header-chips passen ook smal met lange labels', (
    tester,
  ) async {
    // Worst case (speler dd 2026-07-06): hoog inkomen per minuut, level
    // Landelijk en een smal toestel. Een RenderFlex-overflow zou deze
    // test laten falen.
    final state = singleAtmState(totalEarned: 100000);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: GameHeader(state: state, incomePerMinute: 17641.11),
            ),
          ),
        ),
      ),
    );

    expect(find.text('€ 17.641 per min'), findsOneWidget);
    expect(find.text('Level Landelijk'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
