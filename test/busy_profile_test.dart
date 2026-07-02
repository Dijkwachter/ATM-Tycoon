import 'package:atm_empire/core/constants.dart';
import 'package:atm_empire/models/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Drukteprofielen (GDD 5)', () {
    test('station heeft ochtend- en avondpiek, nachtdal en neutrale rest',
        () {
      final profile = kBusyProfiles[LocationType.station]!;
      expect(profile.factorAt(8), 2.0);
      expect(profile.factorAt(17), 2.0);
      expect(profile.factorAt(3), 0.2);
      expect(profile.factorAt(12), kDefaultBusyFactor);
      expect(profile.factorAt(6), kDefaultBusyFactor);
    });

    test('horeca-piek loopt over middernacht heen', () {
      final profile = kBusyProfiles[LocationType.horeca]!;
      expect(profile.factorAt(17), 1.8);
      expect(profile.factorAt(23), 1.8);
      expect(profile.factorAt(0), 1.8);
      expect(profile.factorAt(1), 1.8);
      expect(profile.factorAt(2), 0.4);
      expect(profile.factorAt(12), 0.4);
    });

    test('winkel-dal loopt over middernacht en de rest is neutraal', () {
      final profile = kBusyProfiles[LocationType.winkel]!;
      expect(profile.factorAt(10), 1.4);
      expect(profile.factorAt(23), 0.15);
      expect(profile.factorAt(5), 0.15);
      expect(profile.factorAt(19), kDefaultBusyFactor);
    });

    test('reizen is de hele dag 1,2', () {
      final profile = kBusyProfiles[LocationType.reizen]!;
      for (var hour = 0; hour < kHoursPerDay; hour++) {
        expect(profile.factorAt(hour), 1.2);
      }
    });

    test('elke locatiesoort heeft een profiel met positieve factoren', () {
      for (final location in LocationType.values) {
        final profile = kBusyProfiles[location]!;
        for (var hour = 0; hour < kHoursPerDay; hour++) {
          expect(profile.factorAt(hour), greaterThan(0),
              reason: '$location om $hour uur');
        }
        expect(profile.dayAverage, greaterThan(0));
      }
    });

    test('etmaalgemiddelde van station klopt met de tabel', () {
      // 6 piekuren x 2,0 + 4 daluren x 0,2 + 14 resturen x 1,0 = 26,8.
      final profile = kBusyProfiles[LocationType.station]!;
      expect(profile.dayAverage, closeTo(26.8 / 24, 1e-9));
    });

    test('gemengde startlocaties middelen rond 1,0 (Parameters!B26)', () {
      final station = kBusyProfiles[LocationType.station]!.dayAverage;
      final horeca = kBusyProfiles[LocationType.horeca]!.dayAverage;
      expect((station + horeca) / 2, closeTo(1.0, 0.05));
    });
  });
}
