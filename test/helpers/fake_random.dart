import 'dart:math';

/// Scriptbare Random voor deterministische engine-tests.
///
/// Waarden worden per type uit een wachtrij gelezen; is de wachtrij leeg dan
/// vallen we terug op een neutrale default: nextDouble 0,999 (geen kans
/// slaagt), nextBool false (1 biljet per transactie), nextInt 0.
class FakeRandom implements Random {
  FakeRandom({List<double>? doubles, List<bool>? bools, List<int>? ints})
    : doubles = List.of(doubles ?? const []),
      bools = List.of(bools ?? const []),
      ints = List.of(ints ?? const []);

  final List<double> doubles;
  final List<bool> bools;
  final List<int> ints;

  @override
  double nextDouble() => doubles.isEmpty ? 0.999 : doubles.removeAt(0);

  @override
  bool nextBool() => bools.isEmpty ? false : bools.removeAt(0);

  @override
  int nextInt(int max) {
    final value = ints.isEmpty ? 0 : ints.removeAt(0);
    return value % max;
  }
}
