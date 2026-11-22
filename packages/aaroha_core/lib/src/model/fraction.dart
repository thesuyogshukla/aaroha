/// An exact rational number, used for note timing in matras so that
/// subdivisions like thirds never drift.
class Fraction implements Comparable<Fraction> {
  factory Fraction(int numerator, [int denominator = 1]) {
    if (denominator == 0) throw ArgumentError.value(denominator, 'denominator', 'is zero');
    final sign = denominator < 0 ? -1 : 1;
    final g = _gcd(numerator.abs(), denominator.abs());
    return Fraction._(sign * numerator ~/ g, sign * denominator ~/ g);
  }

  const Fraction._(this.numerator, this.denominator);

  static const zero = Fraction._(0, 1);
  static const one = Fraction._(1, 1);

  final int numerator;
  final int denominator;

  bool get isInteger => denominator == 1;

  int floor() =>
      numerator >= 0 ? numerator ~/ denominator : -((-numerator + denominator - 1) ~/ denominator);

  double toDouble() => numerator / denominator;

  Fraction operator +(Fraction o) =>
      Fraction(numerator * o.denominator + o.numerator * denominator, denominator * o.denominator);
  Fraction operator -(Fraction o) =>
      Fraction(numerator * o.denominator - o.numerator * denominator, denominator * o.denominator);
  Fraction operator *(Fraction o) => Fraction(numerator * o.numerator, denominator * o.denominator);
  Fraction operator /(Fraction o) => Fraction(numerator * o.denominator, denominator * o.numerator);

  bool operator <(Fraction o) => compareTo(o) < 0;
  bool operator <=(Fraction o) => compareTo(o) <= 0;
  bool operator >(Fraction o) => compareTo(o) > 0;
  bool operator >=(Fraction o) => compareTo(o) >= 0;

  @override
  int compareTo(Fraction o) => (numerator * o.denominator).compareTo(o.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Fraction && other.numerator == numerator && other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isInteger ? '$numerator' : '$numerator/$denominator';
}

int _gcd(int a, int b) => b == 0 ? (a == 0 ? 1 : a) : _gcd(b, a % b);

int lcm(int a, int b) => a ~/ _gcd(a, b) * b;
