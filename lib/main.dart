// Kale bootstrap voor het fundament: start Hive, rekent offline-inkomen
// door, draait de tick-engine en logt de state. Geen UI-schermen; die
// volgen in een latere sessie (GDD 10).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'core/constants.dart';
import 'engine/game_controller.dart';
import 'models/hive_adapters.dart';
import 'persistence/save_repository.dart';

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
    final offline =
        ref.read(gameControllerProvider.notifier).lastOfflineResult;

    // Log de kernstaat elke autosave-periode; genoeg om het fundament te
    // bewijzen zonder placeholder-UI.
    if (state.tick % kAutosaveIntervalSeconds == 0) {
      debugPrint(
        'tick=${state.tick} uur=${state.hourOfDay} '
        'saldo=${state.balance.toStringAsFixed(2)} '
        'totaal=${state.totalEarned.toStringAsFixed(2)} '
        'level=${state.playerLevel.name} '
        'automaten=${state.atms.length} '
        'cassettes=${state.atms.map((a) => a.notesInCassette).join('/')} '
        'event=${state.activeEvent?.type.name ?? '-'}',
      );
    }

    return MaterialApp(
      title: 'ATM Empire',
      home: Scaffold(
        body: Center(
          child: Text(
            'ATM Empire fundament\n'
            'tick ${state.tick}\n'
            'saldo EUR ${state.balance.toStringAsFixed(2)}\n'
            'totaal verdiend EUR ${state.totalEarned.toStringAsFixed(2)}\n'
            'offline bijgeschreven EUR '
            '${offline?.income.toStringAsFixed(2) ?? '0.00'}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
