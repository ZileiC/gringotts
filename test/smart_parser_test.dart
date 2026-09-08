import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/domain/seed_ids.dart';
import 'package:gringotts/services/smart_parser.dart';

void main() {
  group('SmartParser: mixed line parsing (>=20 cases)', () {
    test('merchant amount order: 瑞幸 15', () {
      final r = SmartParser.parse('瑞幸 15');
      expect(r.amountCents, 1500);
      expect(r.merchant, '瑞幸');
      expect(r.categoryId, categoryIdDining);
    });

    test('amount merchant order: 15 瑞幸', () {
      final r = SmartParser.parse('15 瑞幸');
      expect(r.amountCents, 1500);
      expect(r.merchant, '瑞幸');
      expect(r.categoryId, categoryIdDining);
    });

    test('decimal amount: 15.5 午餐', () {
      final r = SmartParser.parse('15.5 午餐');
      expect(r.amountCents, 1550);
      expect(r.categoryId, categoryIdDining);
    });

    test('category word: 28 打车', () {
      final r = SmartParser.parse('28 打车');
      expect(r.amountCents, 2800);
      expect(r.categoryId, categoryIdTransport);
    });

    test('amount only: 42', () {
      final r = SmartParser.parse('42');
      expect(r.amountCents, 4200);
      expect(r.merchant, isNull);
      expect(r.categoryId, isNull);
    });

    test('unknown merchant: 33 山寨奶茶店', () {
      final r = SmartParser.parse('33 山寨奶茶店');
      expect(r.amountCents, 3300);
      expect(r.merchant, '山寨奶茶店');
      expect(r.categoryId, isNull);
    });

    test('unknown merchant after amount: 山寨奶茶店 33', () {
      final r = SmartParser.parse('山寨奶茶店 33');
      expect(r.amountCents, 3300);
      expect(r.merchant, '山寨奶茶店');
    });

    test('no number at all: only text', () {
      final r = SmartParser.parse('没有数字');
      expect(r.amountCents, isNull);
      expect(r.merchant, '没有数字');
    });

    test('empty input', () {
      final r = SmartParser.parse('');
      expect(r.amountCents, isNull);
      expect(r.merchant, isNull);
    });

    test('whitespace-only input', () {
      final r = SmartParser.parse('   ');
      expect(r.amountCents, isNull);
    });

    test('decimal two places: 15.55 瑞幸', () {
      final r = SmartParser.parse('15.55 瑞幸');
      expect(r.amountCents, 1555);
      expect(r.categoryId, categoryIdDining);
    });

    test('decimal trailing zero: 15.50 午餐', () {
      final r = SmartParser.parse('15.50 午餐');
      expect(r.amountCents, 1550);
    });

    test('decimal one trailing digit pads: 15.5 -> 1550', () {
      final r = SmartParser.parse('15.5');
      expect(r.amountCents, 1550);
    });

    test('text before and after amount: 瑞幸 15 加班', () {
      final r = SmartParser.parse('瑞幸 15 加班');
      expect(r.amountCents, 1500);
      expect(r.merchant, isNotNull);
      expect(r.merchant, contains('瑞幸'));
    });

    test('history full match: 自定义商户 20', () {
      final r = SmartParser.parse(
        '自定义商户 20',
        history: const [MerchantHistoryEntry('自定义商户', categoryIdShopping)],
      );
      expect(r.amountCents, 2000);
      expect(r.merchant, '自定义商户');
      expect(r.categoryId, categoryIdShopping);
    });

    test('history prefix association: 瑞 -> 瑞幸', () {
      final r = SmartParser.parse(
        '瑞 15',
        history: const [MerchantHistoryEntry('瑞幸', categoryIdDining)],
      );
      expect(r.amountCents, 1500);
      expect(r.merchantPrefix, '瑞');
      expect(r.merchantSuggestion, '瑞幸');
      expect(r.categoryId, categoryIdDining);
    });

    test('history beats raw text for unknown prefix', () {
      final r = SmartParser.parse(
        '星 30',
        history: const [MerchantHistoryEntry('星巴克', categoryIdDining)],
      );
      expect(r.merchantSuggestion, '星巴克');
      expect(r.categoryId, categoryIdDining);
    });

    test('case: 纯 merchant no amount keeps text only', () {
      final r = SmartParser.parse('瑞幸');
      expect(r.amountCents, isNull);
      expect(r.merchant, '瑞幸');
    });

    test('integer boundary: 0.01', () {
      final r = SmartParser.parse('0.01');
      expect(r.amountCents, 1);
    });

    test('large amount: 12345.67', () {
      final r = SmartParser.parse('12345.67');
      expect(r.amountCents, 1234567);
    });

    test('zero amount: 0', () {
      final r = SmartParser.parse('0');
      expect(r.amountCents, 0);
    });

    test('merchant dictionary: 滴滴', () {
      final r = SmartParser.parse('滴滴 25');
      expect(r.amountCents, 2500);
      expect(r.merchant, '滴滴');
      expect(r.categoryId, categoryIdTransport);
    });

    test('乱序: text with punctuation between', () {
      final r = SmartParser.parse('瑞幸，15');
      expect(r.amountCents, 1500);
      expect(r.merchant, isNotNull);
    });
  });

  group('SmartParser.suggestMerchant', () {
    test('suggests first history match for prefix', () {
      final s = SmartParser.suggestMerchant('瑞', const [
        MerchantHistoryEntry('瑞幸', categoryIdDining),
        MerchantHistoryEntry('瑞幸咖啡', categoryIdDining),
      ]);
      expect(s, isNotNull);
      expect(s!.merchant, '瑞幸');
    });

    test('no match returns null', () {
      final s = SmartParser.suggestMerchant('不', const [
        MerchantHistoryEntry('瑞幸', categoryIdDining),
      ]);
      expect(s, isNull);
    });
  });
}
