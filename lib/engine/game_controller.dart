import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/game_state.dart';
import '../persistence/save_repository.dart';
import 'offline_calculator.dart';
import 'tick_engine.dart';

/// Wandklok-injectie zodat de offline-berekening en de autosave-tijdstempel
/// deterministisch testbaar zijn.
typedef Clock = DateTime Function();

/// Afhankelijkheden van de [GameController]; overridebaar in tests en
/// geconfigureerd in main.dart.
final tickEngineProvider = Provider<TickEngine>((ref) => TickEngine());

final offlineCalculatorProvider =
    Provider<OfflineCalculator>((ref) => const OfflineCalculator());

final clockProvider = Provider<Clock>((ref) => DateTime.now);

final saveRepositoryProvider = Provider<SaveRepository?>((ref) => null);

final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

/// Houdt de [GameState] bij, draait de tick-engine op 1 tick per seconde en
/// bewaart de staat elke [kAutosaveIntervalSeconds] seconden en bij
/// app-pauze (via [saveNow], aangeroepen door de lifecycle-observer in
/// main.dart).
class GameController extends Notifier<GameState> {
  Timer? _tickTimer;
  int _ticksSinceSave = 0;

  /// Resultaat van de laatste offline-doorrekening, voor logging en later UI.
  OfflineResult? lastOfflineResult;

  @override
  GameState build() {
    ref.onDispose(() => _tickTimer?.cancel());
    final saved = ref.read(saveRepositoryProvider)?.load();
    if (saved == null) {
      return GameState.initial(nextEventInSeconds: _firstEventInterval());
    }
    // Offline-doorrekening over het verschil met de tijdstempel (GDD 9.4).
    final elapsed = ref.read(clockProvider)().difference(saved.savedAt);
    final result =
        ref.read(offlineCalculatorProvider).apply(saved.state, elapsed);
    lastOfflineResult = result;
    return result.state;
  }

  int _firstEventInterval() =>
      kEventIntervalMinSeconds +
      ref.read(tickEngineProvider).random.nextInt(
          kEventIntervalMaxSeconds - kEventIntervalMinSeconds + 1);

  /// Start de klok: een tick per seconde (GDD 11).
  void start() {
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    state = ref.read(tickEngineProvider).tick(state);
    _ticksSinceSave += 1;
    if (_ticksSinceSave >= kAutosaveIntervalSeconds) {
      _ticksSinceSave = 0;
      unawaited(saveNow());
    }
  }

  /// Slaat de staat plus tijdstempel op; ook aangeroepen bij app-pauze.
  Future<void> saveNow() async {
    final repository = ref.read(saveRepositoryProvider);
    if (repository == null) {
      return;
    }
    await repository.save(state, ref.read(clockProvider)());
  }

  // Spelersacties: dunne doorgifte naar de engine.

  void refillAtm(int atmId) => _apply((e, s) => e.refillAtm(s, atmId));

  void tapRepair(int atmId) => _apply((e, s) => e.tapRepair(s, atmId));

  void preventiveMaintenance(int atmId) =>
      _apply((e, s) => e.preventiveMaintenance(s, atmId));

  void _apply(GameState Function(TickEngine, GameState) action) {
    state = action(ref.read(tickEngineProvider), state);
  }
}
