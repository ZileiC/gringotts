import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/services/chart_scale.dart';

void main() {
  test('regular values keep headroom and clamp nothing', () {
    final result = ChartScale.resolve(<num>[67.5, 30, 12]);
    expect(result.maxY, closeTo(84.375, 0.0001));
    expect(result.clampedIndexes, isEmpty);
  });

  test('single outlier is clamped and the next value sets the scale', () {
    final result = ChartScale.resolve(<num>[250, 67.5, 12]);
    expect(result.maxY, closeTo(84.375, 0.0001));
    expect(result.clampedIndexes, <int>{0});
  });

  test('a single drawn value gets headroom and no clamp', () {
    final result = ChartScale.resolve(<num>[100]);
    expect(result.maxY, closeTo(125, 0.0001));
    expect(result.clampedIndexes, isEmpty);
  });

  test('a repeated flat outlier is clamped as one value group', () {
    final result = ChartScale.resolve(<num>[250, 250, 67.5]);
    expect(result.maxY, closeTo(84.375, 0.0001));
    expect(result.clampedIndexes, <int>{0, 1});
  });

  test('invariant: maxY covers every unclamped drawn value', () {
    final cases = <List<num>>[
      <num>[67.5, 30, 12],
      <num>[250, 67.5, 12],
      <num>[100],
      <num>[250, 250, 67.5],
      <num>[],
    ];
    for (final values in cases) {
      final result = ChartScale.resolve(values);
      for (var i = 0; i < values.length; i++) {
        if (result.clampedIndexes.contains(i)) continue;
        expect(
          values[i].toDouble(),
          lessThanOrEqualTo(result.maxY + 1e-9),
          reason: 'unclamped value at index $i must be <= maxY for $values',
        );
      }
    }
  });
}