import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/services/smart_parser.dart';

void main() {
  group('A1 fix: leading-dot amounts (mandatory addendum)', () {
    test('.5 parses to 0.50 yuan = 50 cents', () {
      final r = SmartParser.parse('.5');
      expect(r.amountCents, 50);
      expect(r.merchant, isNull, reason: 'pure amount input must not leak to merchant');
    });

    test('.5 午餐 parses amount + category', () {
      final r = SmartParser.parse('.5 午餐');
      expect(r.amountCents, 50);
      expect(r.categoryId, isNotNull);
    });

    test('瑞幸 .5 keeps merchant + decimal amount', () {
      final r = SmartParser.parse('瑞幸 .5');
      expect(r.amountCents, 50);
      expect(r.merchant, '瑞幸');
    });

    test('.99 -> 99 cents', () {
      expect(SmartParser.parse('.99').amountCents, 99);
    });

    test('.05 -> 5 cents', () {
      expect(SmartParser.parse('.05').amountCents, 5);
    });

    test('regular forms still work: 15 / 15.5 / 15.55', () {
      expect(SmartParser.parse('15').amountCents, 1500);
      expect(SmartParser.parse('15.5').amountCents, 1550);
      expect(SmartParser.parse('15.55').amountCents, 1555);
    });
  });
}
