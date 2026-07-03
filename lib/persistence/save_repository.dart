import 'package:hive/hive.dart';

import '../models/game_state.dart';

/// Persisteert de [GameState] plus een tijdstempel naar Hive.
///
/// De tijdstempel is de basis voor de offline-doorrekening bij app-start
/// (GDD 9.4 en 11).
class SaveRepository {
  SaveRepository(this._box);

  static const String boxName = 'atm_empire_save';
  static const String _stateKey = 'state';
  static const String _savedAtKey = 'savedAtMillis';
  static const String _highScoreKey = 'highScore';

  final Box<dynamic> _box;

  static Future<SaveRepository> open() async {
    final box = await Hive.openBox<dynamic>(boxName);
    return SaveRepository(box);
  }

  Future<void> save(GameState state, DateTime now) async {
    await _box.put(_stateKey, state);
    await _box.put(_savedAtKey, now.millisecondsSinceEpoch);
    await _box.flush();
  }

  /// Hoogste totaal-verdiend ooit, over alle spellen heen. Overleeft een
  /// nieuw spel; alleen een hogere score overschrijft hem.
  double get highScore => (_box.get(_highScoreKey) as num?)?.toDouble() ?? 0;

  Future<void> saveHighScore(double score) async {
    if (score <= highScore) {
      return;
    }
    await _box.put(_highScoreKey, score);
    await _box.flush();
  }

  /// Geeft de bewaarde staat en het opslagmoment, of null bij een vers spel.
  ({GameState state, DateTime savedAt})? load() {
    final state = _box.get(_stateKey) as GameState?;
    final savedAtMillis = _box.get(_savedAtKey) as int?;
    if (state == null || savedAtMillis == null) {
      return null;
    }
    return (
      state: state,
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAtMillis),
    );
  }
}
