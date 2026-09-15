/// Pure y-axis scale resolution for the statistics charts.
///
/// DESIGN_MAIN 11.8 invariant 3: when one non-zero drawn value is more than
/// 2.5x the next distinct non-zero value, the largest value is clamped to the
/// top of the plot and the remaining values set the scale.
class ChartScale {
  const ChartScale._();

  /// Resolves the chart's [maxY] and the indexes that must be clamped.
  ///
  /// Indexes refer to the original [values] iterable. Zero and non-finite
  /// values are ignored for outlier detection but keep their index; a chart
  /// with no positive drawn values falls back to a small non-zero scale so the
  /// axis is still meaningful.
  static ({double maxY, Set<int> clampedIndexes}) resolve(
    Iterable<num> values,
  ) {
    final entries = <({int index, double value})>[];
    var index = 0;
    for (final raw in values) {
      final value = raw.toDouble();
      if (value.isFinite && value > 0) {
        entries.add((index: index, value: value));
      }
      index++;
    }
    if (entries.isEmpty) {
      return (maxY: 100.0, clampedIndexes: const <int>{});
    }

    entries.sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      return byValue != 0 ? byValue : a.index.compareTo(b.index);
    });

    // A repeated flat line (for example the daily allowance) must not hide an
    // outlier by supplying the same value as `v2`; compare distinct values.
    final distinct = <double>[];
    for (final entry in entries) {
      if (!distinct.contains(entry.value)) distinct.add(entry.value);
    }

    final clampedIndexes = <int>{};
    final double maxY;
    if (distinct.length >= 2 && distinct[0] > 2.5 * distinct[1]) {
      maxY = distinct[1] * 1.25;
      for (final entry in entries) {
        if (entry.value == distinct[0]) clampedIndexes.add(entry.index);
      }
    } else {
      maxY = entries.first.value * 1.25;
    }

    return (maxY: maxY, clampedIndexes: clampedIndexes);
  }
}