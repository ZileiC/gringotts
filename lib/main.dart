import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'services/direct_entry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // T-06: long-press icon shortcut "记一笔" lands on the speed-entry home.
  // The home route IS the quick-entry page, so a plain launch is enough;
  // initialize() keeps the shortcut item registered.
  await DirectEntryService.initialize((String type) {});
  runApp(
    const ProviderScope(
      child: GringottsApp(),
    ),
  );
}
