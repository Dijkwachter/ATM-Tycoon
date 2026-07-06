import 'package:atm_empire/audio/music_intensity.dart';
import 'package:atm_empire/engine/feedback.dart';
import 'package:atm_empire/engine/tick_engine.dart';
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

  group('muzieklagen (Ontwerper dd 2026-07-06)', () {
    test('percussie zwijgt op een rustige kaart en fadet in met de '
        'wachtrijen', () {
      final calm = singleAtmState();
      expect(percussionLevelFor(calm), 0.0);

      final oneCustomer = withQueue(singleAtmState(), 1);
      expect(percussionLevelFor(oneCustomer), greaterThan(0.0));

      final busy = withQueue(singleAtmState(), 8);
      expect(
        percussionLevelFor(busy),
        greaterThan(percussionLevelFor(oneCustomer)),
      );
    });

    test('percussievolume is begrensd, hoe druk het ook wordt', () {
      final packed = withQueue(singleAtmState(level: 5), 15);
      expect(percussionLevelFor(packed), lessThanOrEqualTo(0.5));
    });

    test('pads zwijgen bij een stilstaande vloot en fadet in zodra er '
        'voertuigen rijden', () {
      final idle = singleAtmState();
      expect(padsLevelFor(idle), 0.0);

      // Een CIT-rit aanvragen zet een wagen op pad.
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 0);
      s = engine.requestService(s, 0);
      expect(padsLevelFor(s), greaterThan(0.0));
      expect(padsLevelFor(s), lessThanOrEqualTo(0.45));
    });

    test('ook een rijdende monteur telt als actief voertuig', () {
      final engine = TickEngine(random: FakeRandom());
      var s = singleAtmState(notesInCassette: 0, repairSecondsRemaining: 1000);
      s = engine.sendMechanic(s, 0);
      expect(padsLevelFor(s), greaterThan(0.0));
    });
  });
}
