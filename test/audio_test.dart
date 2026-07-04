import 'package:atm_empire/audio/music_intensity.dart';
import 'package:atm_empire/engine/feedback.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_random.dart';
import 'helpers/states.dart';

void main() {
  group('cassetteEmpty-feedback', () {
    test('wordt gemeld als de laatste biljetten worden opgenomen', () {
      final events = <GameFeedback>[];
      final engine = TickEngine(
        // Transactiekans slaagt (0,0), spreiding laag, geen DCC.
        random: FakeRandom(doubles: [0.0, 0.0, 0.999]),
        onFeedback: events.add,
      );
      final state = singleAtmState(notesInCassette: 1, hour: 12);

      engine.tick(state);

      expect(
        events.where((e) => e.type == FeedbackType.cassetteEmpty).length,
        1,
      );
    });

    test('blijft stil zolang er biljetten overblijven', () {
      final events = <GameFeedback>[];
      final engine = TickEngine(
        random: FakeRandom(doubles: [0.0, 0.0, 0.999]),
        onFeedback: events.add,
      );
      final state = singleAtmState(notesInCassette: 500, hour: 12);

      engine.tick(state);

      expect(
        events.where((e) => e.type == FeedbackType.cassetteEmpty),
        isEmpty,
      );
    });
  });

  group('muziekintensiteit', () {
    test('tempo is laag in de nacht en hoog op de piek', () {
      final night = singleAtmState(hour: 3);
      final peak = singleAtmState(hour: 17);

      expect(musicSpeedFor(night), lessThan(musicSpeedFor(peak)));
      expect(musicSpeedFor(night), greaterThanOrEqualTo(0.95));
      expect(musicSpeedFor(peak), lessThanOrEqualTo(1.30));
    });

    test('bijna lege cassette verhoogt het tempo', () {
      final full = singleAtmState(hour: 12);
      final low = singleAtmState(hour: 12, notesInCassette: 10);

      expect(musicSpeedFor(low), greaterThan(musicSpeedFor(full)));
    });

    test('percussie zwijgt in rust en komt op bij lege cassettes', () {
      final calm = singleAtmState(hour: 3);
      expect(percussionLevelFor(calm), 0.0);

      final low = singleAtmState(hour: 3, notesInCassette: 10);
      expect(percussionLevelFor(low), greaterThanOrEqualTo(0.6));
    });

    test('percussie komt op bij drukte', () {
      // Station om 17 uur zit in het spitsvenster (factor >= 1,2).
      final busy = singleAtmState(location: LocationType.station, hour: 17);
      expect(percussionLevelFor(busy), greaterThanOrEqualTo(0.35));
    });
  });
}
