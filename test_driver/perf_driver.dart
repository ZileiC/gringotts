import 'dart:convert';

import 'package:integration_test/integration_test_driver.dart';

/// Driver entry point for the T-09E profile-mode frame sampling.
///
/// Run with:
///   flutter drive --profile -d windows \
///     --driver=test_driver/perf_driver.dart \
///     --target=integration_test/perf_scan_test.dart
///
/// The per-phase FrameTiming summaries (average / 90th / 99th percentile /
/// missed-budget counts) are printed as one PERF_SUMMARY line so the numbers
/// can be pasted into WORKLOG without interpretation.
Future<void> main() => integrationDriver(
      responseDataCallback: (Map<String, dynamic>? data) async {
        if (data == null) {
          // ignore: avoid_print
          print('PERF_SUMMARY none');
          return;
        }
        // ignore: avoid_print
        print('PERF_SUMMARY ${jsonEncode(data)}');
      },
    );
