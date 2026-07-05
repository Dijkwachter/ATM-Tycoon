import 'package:atm_empire/audio/music_intensity.dart';
import 'package:atm_empire/engine/feedback.dart';
import 'package:atm_empire/engine/tick_engine.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_random.dart';
import 'helpers/states.dart';

void main() {
  group('cassetteEmpty-feedback', () {
    /// Laat een volledige opname doorlopen (acht ticks op level 1).
    List<GameFeedback> runWithdrawal(int startNotes) {
      final events = <GameFeedback>[];
      final engine = TickEngine(
        random: FakeRandom(
          doubles: [...arrivalMisses(8), 0.5, 0.0, 0.99, 0.99],
          bools: [false],
        ),
        onFeedback: events.add,
      );
      var s = withQueue(
        singleAtmState(notesInCassette: startNotes, hour: 12),
        1,
      );
      for (var i = 0; i < 8; i++) {
        s = engine.tick(s);
      }
      return events;
    }

    test('wordt gemeld als de laatste biljetten worden opgenomen', () {
      final events = runWithdrawal(1);
      expect(
        events.where((e) => e.type == FeedbackType.cassetteEmpty).length,
        1,
      );
    });

    test('blijft stil zolang er biljetten overblijven', () {
      final events = runWithdrawal(100);
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
