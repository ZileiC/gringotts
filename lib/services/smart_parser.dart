import '../domain/seed_ids.dart';

/// One historical merchant row used for association lookups.
class MerchantHistoryEntry {
  const MerchantHistoryEntry(this.merchant, this.categoryId);

  final String merchant;
  final String? categoryId;
}

/// Result of parsing one mixed quick-entry line.
///
/// The parser never throws and never blocks: any input yields at least an
/// amount when a number is present (amount is the only required field).
class SmartParseResult {
  const SmartParseResult({
    this.amountCents,
    this.merchant,
    this.categoryId,
    this.merchantPrefix,
    this.merchantSuggestion,
  });

  /// Amount in integer cents; null when the input contains no number.
  final int? amountCents;

  /// Merchant extracted from text (dictionary, history, or raw text).
  final String? merchant;

  /// Category suggestion derived from text, dictionary, or history.
  final String? categoryId;

  /// Prefix that matched a historical merchant (for inline autocomplete).
  final String? merchantPrefix;

  /// Best historical merchant suggestion for [merchantPrefix].
  final String? merchantSuggestion;

  bool get hasAmount => amountCents != null;
}

/// Local offline parser for mixed quick-entry lines such as `瑞幸 15`,
/// `15 瑞幸`, or `15.5 午餐`.
///
/// Pure functions only: regex extraction + built-in dictionary + historical
/// merchant association. No network, no AI (M1.0 core rule).
class SmartParser {
  SmartParser._();

  static final RegExp _amountPattern = RegExp(r'(?:\d+(?:\.\d+)?|\.\d+)');

  /// Category keywords -> fixed seed category id.
  static const Map<String, String> categoryWords = {
    '早餐': categoryIdDining,
    '午餐': categoryIdDining,
    '晚餐': categoryIdDining,
    '夜宵': categoryIdDining,
    '外卖': categoryIdDining,
    '吃饭': categoryIdDining,
    '打车': categoryIdTransport,
    '地铁': categoryIdTransport,
    '公交': categoryIdTransport,
    '加油': categoryIdTransport,
    '火车': categoryIdTransport,
    '机票': categoryIdTransport,
    '超市': categoryIdShopping,
    '网购': categoryIdShopping,
    '淘宝': categoryIdShopping,
    '京东': categoryIdShopping,
    '房租': categoryIdHousing,
    '水电': categoryIdHousing,
    '物业': categoryIdHousing,
    '电影': categoryIdEntertainment,
    '游戏': categoryIdEntertainment,
    'KTV': categoryIdEntertainment,
    '会员': categoryIdEntertainment,
    '书': categoryIdStudy,
    '课程': categoryIdStudy,
    '培训': categoryIdStudy,
    '药': categoryIdMedical,
    '挂号': categoryIdMedical,
    '看病': categoryIdMedical,
    '红包': categoryIdGift,
    '礼物': categoryIdGift,
  };

  /// Built-in merchant dictionary -> default category.
  static const Map<String, String> merchantDictionary = {
    '瑞幸': categoryIdDining,
    '星巴克': categoryIdDining,
    '麦当劳': categoryIdDining,
    '肯德基': categoryIdDining,
    '蜜雪冰城': categoryIdDining,
    '喜茶': categoryIdDining,
    '美团外卖': categoryIdDining,
    '饿了么': categoryIdDining,
    '滴滴': categoryIdTransport,
    '京东': categoryIdShopping,
    '拼多多': categoryIdShopping,
    '山姆': categoryIdShopping,
    '盒马': categoryIdShopping,
  };

  /// Parses one mixed input line.
  ///
  /// Extraction order: amount (first number) -> remaining text resolved
  /// against (1) category words, (2) built-in merchants, (3) full history
  /// match, (4) history prefix suggestion, (5) raw merchant text.
  static SmartParseResult parse(
    String input, {
    List<MerchantHistoryEntry> history = const <MerchantHistoryEntry>[],
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const SmartParseResult();
    }

    final amountMatch = _amountPattern.firstMatch(trimmed);
    final amountCents =
        amountMatch == null ? null : _toCents(amountMatch.group(0)!);

    String? text;
    if (amountMatch == null) {
      text = trimmed;
    } else {
      final before = trimmed.substring(0, amountMatch.start).trim();
      final after = trimmed.substring(amountMatch.end).trim();
      text = (before.isNotEmpty && after.isNotEmpty)
          ? '$before $after'
          : (before.isNotEmpty ? before : after);
    }

    if (text.isEmpty) {
      return SmartParseResult(amountCents: amountCents);
    }

    // 1. Direct category word (e.g. `15 午餐`).
    final categoryHit = categoryWords[text];
    if (categoryHit != null) {
      return SmartParseResult(amountCents: amountCents, categoryId: categoryHit);
    }

    // 2. Built-in merchant dictionary.
    final merchantHit = merchantDictionary[text];
    if (merchantHit != null) {
      return SmartParseResult(
        amountCents: amountCents,
        merchant: text,
        categoryId: merchantHit,
      );
    }

    // 3. Full history merchant match.
    for (final entry in history) {
      if (entry.merchant == text) {
        return SmartParseResult(
          amountCents: amountCents,
          merchant: entry.merchant,
          categoryId: entry.categoryId,
        );
      }
    }

    // 4. History prefix association (e.g. `瑞` suggests `瑞幸`).
    for (final entry in history) {
      if (entry.merchant.startsWith(text) && entry.merchant.length > text.length) {
        return SmartParseResult(
          amountCents: amountCents,
          merchantPrefix: text,
          merchantSuggestion: entry.merchant,
          categoryId: entry.categoryId,
        );
      }
    }

    // 5. Unknown merchant: keep raw text, no category suggestion.
    return SmartParseResult(amountCents: amountCents, merchant: text);
  }

  /// Best historical merchant starting with [prefix], or null.
  static MerchantHistoryEntry? suggestMerchant(
    String prefix,
    List<MerchantHistoryEntry> history,
  ) {
    if (prefix.isEmpty) return null;
    for (final entry in history) {
      if (entry.merchant.startsWith(prefix) && entry.merchant.length > prefix.length) {
        return entry;
      }
    }
    return null;
  }

  /// Converts a yuan string (`15`, `15.5`, `15.55`) to integer cents.
  /// Truncates beyond two decimal places; never uses floating point storage.
  static int _toCents(String yuanText) {
    // Leading-dot form (`.5` = 0.50): normalize to `0.5` first.
    if (yuanText.startsWith('.')) {
      yuanText = '0$yuanText';
    }
    final parts = yuanText.split('.');
    final yuan = int.parse(parts[0]);
    var cents = 0;
    if (parts.length > 1) {
      final frac = parts[1].padRight(2, '0').substring(0, 2);
      cents = int.parse(frac);
    }
    return yuan * 100 + cents;
  }
}
