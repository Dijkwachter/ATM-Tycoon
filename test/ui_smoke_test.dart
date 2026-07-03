import 'dart:math';

import 'package:atm_empire/engine/game_controller.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tickEngineProvider
              .overrideWithValue(TickEngine(random: Random(1))),
        ],
        child: const AtmEmpireApp(),
      ),
    );
  }

  /// Door het introscherm heen: start een vers spel.
  Future<void> startGame(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Start spel'));
    await tester.pump();
  }

  /// Koopt vanaf de kaart een automaat op het station.
  Future<void> buyStationAtm(WidgetTester tester) async {
    await tester.tap(find.text('Nieuwe automaat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Station'));
    await tester.pumpAndSettle();
  }

  /// Ontmantelt de app zodat de periodieke ticktimer netjes wordt
  /// opgeruimd voordat de test eindigt.
  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('het introscherm toont logo, high score en startknop',
      (tester) async {
    await pumpApp(tester);

    expect(find.text('EMPIRE'), findsOneWidget);
    expect(find.text('HIGH SCORE - TOTAAL VERDIEND'), findsOneWidget);
    expect(find.text('Start spel'), findsOneWidget);
    // Zonder save is er geen verder-spelen-knop.
    expect(find.text('Verder spelen'), findsNothing);

    await tearDownApp(tester);
  });

  testWidgets('een nieuw spel start met 0 automaten en 1.000 saldo',
      (tester) async {
    await startGame(tester);

    expect(find.text('ATM EMPIRE'), findsOneWidget);
    expect(find.text('Servicing'), findsNothing);
    expect(find.textContaining('Welkom!'), findsOneWidget);
    expect(find.text('Locaties: 0 van 3'), findsOneWidget);
    // Tabbar met drie tabs.
    expect(find.text('Kaart'), findsOneWidget);
    expect(find.text('Upgrades'), findsOneWidget);
    expect(find.text('Financien'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('een automaat kopen zet een tegel op de kaart',
      (tester) async {
    await startGame(tester);
    await buyStationAtm(tester);

    expect(find.textContaining('Station'), findsOneWidget);
    expect(find.text('Servicing'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('de engine tikt en de klok loopt', (tester) async {
    await startGame(tester);

    // Vijf ticks is een speluur (GDD 5).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text('01:00'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('tabs wisselen naar Upgrades en Financien', (tester) async {
    await startGame(tester);

    await tester.tap(find.text('Upgrades'));
    await tester.pump();
    expect(find.text('Netwerk-upgrades'), findsOneWidget);
    expect(find.text('Monteur Sven'), findsOneWidget);

    await tester.tap(find.text('Financien'));
    await tester.pump();
    expect(find.text('Banken en contracten'), findsOneWidget);
    expect(find.text('Bank Oranje'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Zuiderbank'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Zuiderbank'), findsOneWidget);

    await tearDownApp(tester);
  });

  testWidgets('de detail-sheet opent en toont de cassette in biljetten',
      (tester) async {
    await startGame(tester);
    await buyStationAtm(tester);

    await tester.tap(find.textContaining('Station'));
    await tester.pumpAndSettle();
    expect(find.text('Inkomen per transactie'), findsOneWidget);
    expect(find.text('Etmaalgemiddelde'), findsOneWidget);
    // Basis-cassette in echte biljetten: capaciteit 2.000 (kNotesPerUnit);
    // er kan al een opname geweest zijn, dus de stand zelf ligt niet vast.
    expect(find.textContaining('van 2.000 biljetten'), findsWidgets);

    // Sluit de sheet weer.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tearDownApp(tester);
  });

  testWidgets('prestige is bij de start vergrendeld', (tester) async {
    await startGame(tester);

    await tester.tap(find.text('Financien'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('Prestige (level'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    // De knop bestaat maar het spel begint ver onder de drempel; een tik
    // wapent hem dus niet.
    await tester.tap(find.textContaining('Prestige (level'),
        warnIfMissed: false);
    await tester.pump();
    expect(find.text('Tik nogmaals om te verkopen'), findsNothing);

    await tearDownApp(tester);
  });
}
