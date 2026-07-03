// App-shell van ATM Empire: start Hive, rekent offline-inkomen door,
// draait de tick-engine en toont de drie tabs uit GDD 10.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'core/constants.dart';
import 'engine/game_controller.dart';
import 'models/hive_adapters.dart';
import 'persistence/save_repository.dart';
import 'ui/format.dart';
import 'ui/screens/finance_screen.dart';
import 'ui/screens/map_screen.dart';
import 'ui/screens/upgrades_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/coin_rain.dart';
import 'ui/widgets/frosted_tab_bar.dart';
import 'ui/widgets/game_header.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Hive.initFlutter();
  } on MissingPlatformDirectoryException {
    // Omgevingen zonder platform-directories (flutter-tester, CI): val
    // terug op een vaste map zodat de save-cyclus ook daar werkt.
    final dir = Directory('${Directory.systemTemp.path}/atm_empire_dev')
      ..createSync(recursive: true);
    Hive.init(dir.path);
  }
  registerHiveAdapters();
  final repository = await SaveRepository.open();

  runApp(
    ProviderScope(
      overrides: [
        saveRepositoryProvider.overrideWithValue(repository),
      ],
      child: const AtmEmpireApp(),
    ),
  );
}

class AtmEmpireApp extends ConsumerStatefulWidget {
  const AtmEmpireApp({super.key});

  @override
  ConsumerState<AtmEmpireApp> createState() => _AtmEmpireAppState();
}

class _AtmEmpireAppState extends ConsumerState<AtmEmpireApp>
    with WidgetsBindingObserver {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final controller = ref.read(gameControllerProvider.notifier);
    controller.start();
    final offline = controller.lastOfflineResult;
    if (offline != null) {
      debugPrint(
        'offline: ${offline.simulatedSeconds.toStringAsFixed(0)}s '
        'doorgerekend, EUR ${offline.income.toStringAsFixed(2)} '
        'bijgeschreven',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Bij app-pauze direct opslaan, zodat de offline-doorrekening bij de
  /// volgende start een verse tijdstempel heeft.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.detached) {
      ref.read(gameControllerProvider.notifier).saveNow().ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final brokenCount = state.atms.where((a) => a.isBroken).length;

    if (state.tick % kAutosaveIntervalSeconds == 0) {
      debugPrint(
        'tick=${state.tick} uur=${formatGameClock(state.tick, kGameHourRealSeconds)} '
        'saldo=${state.balance.toStringAsFixed(2)} '
        'totaal=${state.totalEarned.toStringAsFixed(2)} '
        'automaten=${state.atms.length}',
      );
    }

    return MaterialApp(
      title: 'ATM Empire',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                GameHeader(
                  state: state,
                  incomePerMinute: controller.incomePerMinute,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: const [
                      MapScreen(),
                      UpgradesScreen(),
                      FinanceScreen(),
                    ],
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: CoinRainOverlay(feedback: controller.feedback),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FrostedTabBar(
                index: _tabIndex,
                brokenCount: brokenCount,
                onSelect: (i) => setState(() => _tabIndex = i),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
