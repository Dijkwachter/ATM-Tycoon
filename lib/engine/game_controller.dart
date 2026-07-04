import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/enums.dart';
import '../models/game_state.dart';
import '../persistence/save_repository.dart';
import 'feedback.dart';
import 'offline_calculator.dart';
import 'tick_engine.dart';

/// Wandklok-injectie zodat de offline-berekening en de autosave-tijdstempel
/// deterministisch testbaar zijn.
typedef Clock = DateTime Function();

/// Afhankelijkheden van de [GameController]; overridebaar in tests en
/// geconfigureerd in main.dart.
final tickEngineProvider = Provider<TickEngine>((ref) => TickEngine());

final offlineCalculatorProvider = Provider<OfflineCalculator>(
  (ref) => const OfflineCalculator(),
);

final clockProvider = Provider<Clock>((ref) => DateTime.now);

final saveRepositoryProvider = Provider<SaveRepository?>((ref) => null);

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

/// Houdt de [GameState] bij, draait de tick-engine op 1 tick per seconde en
/// bewaart de staat elke [kAutosaveIntervalSeconds] seconden en bij
/// app-pauze (via [saveNow], aangeroepen door de lifecycle-observer in
/// main.dart).
class GameController extends Notifier<GameState> {
  Timer? _tickTimer;
  int _ticksSinceSave = 0;
  final StreamController<GameFeedback> _feedback =
      StreamController<GameFeedback>.broadcast();

  /// Feedback-events voor pills en muntenregen (GDD 10).
  Stream<GameFeedback> get feedback => _feedback.stream;

  /// Resultaat van de laatste offline-doorrekening, voor logging en UI.
  OfflineResult? lastOfflineResult;

  /// Totaal-verdiend-monsters van de laatste 60 ticks, voor het inkomen
  /// per minuut in de header (GDD 10).
  final List<double> _earnedSamples = [];

  /// Verdiend in de afgelopen minuut, in EUR. Groeit de eerste minuut mee
  /// met het beschikbare venster.
  double get incomePerMinute =>
      _earnedSamples.isEmpty ? 0 : state.totalEarned - _earnedSamples.first;

  @override
  GameState build() {
    ref.onDispose(() {
      _tickTimer?.cancel();
      unawaited(_feedback.close());
    });
    ref.read(tickEngineProvider).onFeedback = (event) {
      if (!_feedback.isClosed) {
        _feedback.add(event);
      }
    };
    final saved = ref.read(saveRepositoryProvider)?.load();
    if (saved == null) {
      return GameState.initial(nextEventInSeconds: _firstEventInterval());
    }
    // Offline-doorrekening over het verschil met de tijdstempel (GDD 9.4).
    final elapsed = ref.read(clockProvider)().difference(saved.savedAt);
    final result = ref
        .read(offlineCalculatorProvider)
        .apply(saved.state, elapsed);
    lastOfflineResult = result;
    return result.state;
  }

  int _firstEventInterval() =>
      kEventIntervalMinSeconds +
      ref
          .read(tickEngineProvider)
          .random
          .nextInt(kEventIntervalMaxSeconds - kEventIntervalMinSeconds + 1);

  /// Start de klok: een tick per seconde (GDD 11).
  void start() {
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  /// Of er een bewaard spel is om mee verder te gaan (introscherm).
  bool get hasSave => ref.read(saveRepositoryProvider)?.load() != null;

  /// Hoogste totaal-verdiend ooit, inclusief het lopende spel.
  double get highScore {
    final stored = ref.read(saveRepositoryProvider)?.highScore ?? 0;
    return state.totalEarned > stored ? state.totalEarned : stored;
  }

  /// Begint een vers spel (introscherm). De high score blijft staan.
  void newGame() {
    lastOfflineResult = null;
    _earnedSamples.clear();
    state = GameState.initial(nextEventInSeconds: _firstEventInterval());
    unawaited(saveNow());
  }

  void _onTick() {
    _earnedSamples.add(state.totalEarned);
    if (_earnedSamples.length > 60) {
      _earnedSamples.removeAt(0);
    }
    state = ref.read(tickEngineProvider).tick(state);
    _ticksSinceSave += 1;
    if (_ticksSinceSave >= kAutosaveIntervalSeconds) {
      _ticksSinceSave = 0;
      unawaited(saveNow());
    }
  }

  /// Slaat de staat plus tijdstempel op; ook aangeroepen bij app-pauze.
  /// Werkt en passant de high score bij.
  Future<void> saveNow() async {
    final repository = ref.read(saveRepositoryProvider);
    if (repository == null) {
      return;
    }
    await repository.save(state, ref.read(clockProvider)());
    await repository.saveHighScore(state.totalEarned);
  }

  // Spelersacties: dunne doorgifte naar de engine.

  void requestService(int atmId) =>
      _apply((e, s) => e.requestService(s, atmId));

  void tapRepair(int atmId) => _apply((e, s) => e.tapRepair(s, atmId));

  void preventiveMaintenance(int atmId) =>
      _apply((e, s) => e.preventiveMaintenance(s, atmId));

  void buyAtm(LocationType location) => _apply((e, s) => e.buyAtm(s, location));

  void buyCassette(int atmId) => _apply((e, s) => e.buyCassette(s, atmId));

  void buyCitVan() => _apply((e, s) => e.buyCitVan(s));

  void upgradeAtmTier(int atmId) =>
      _apply((e, s) => e.upgradeAtmTier(s, atmId));

  void buyUpgrade(UpgradeId id) => _apply((e, s) => e.buyUpgrade(s, id));

  void hireStaff(StaffId id) => _apply((e, s) => e.hireStaff(s, id));

  void negotiateBankContract(BankId id) =>
      _apply((e, s) => e.negotiateBankContract(s, id));

  void connectZuiderbank() => _apply((e, s) => e.connectZuiderbank(s));

  /// Prestige; de verplichte dubbele tikbevestiging (GDD 9.3) is de
  /// verantwoordelijkheid van de aanroepende UI.
  void prestige() => _apply((e, s) => e.prestige(s));

  void _apply(GameState Function(TickEngine, GameState) action) {
    state = action(ref.read(tickEngineProvider), state);
  }
}
