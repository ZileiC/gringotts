import 'dart:async';

import 'package:flutter/services.dart';
import 'package:quick_actions/quick_actions.dart';

/// Deep-entry service: app shortcuts (long-press icon) and Quick Settings
/// tile both land on the speed-entry home (which IS the home route, so the
/// shortcut's job is to bring the app forward / relaunch it).
///
/// Ticket T-06: long-press desktop icon shortcut "记一笔" + QS tile.
class DirectEntryService {
  DirectEntryService._();

  static const _quickActions = QuickActions();

  /// Initializes the shortcut item. Must be called once from main() /
  /// app init on Android.
  static Future<void> initialize(QuickActionHandler onLaunch) async {
    await _quickActions.initialize(onLaunch);
    await _quickActions.setShortcutItems([
      const ShortcutItem(
        type: 'action_new_record',
        localizedTitle: '记一笔',
        icon: 'ic_launcher',
      ),
    ]);
  }

  /// Toggles the Quick Settings tile service on Android.
  ///
  /// The tile service is declared natively in AndroidManifest; this method
  /// only exists for symmetry/testing on other platforms (no-op).
  static Future<void> setTileActive(bool active) async {
    const channel = MethodChannel('dev.jharayden.gringotts/tile');
    try {
      await channel.invokeMethod<bool>('setTileActive', active);
    } on MissingPluginException {
      // Desktop/unsupported platforms: ignore.
    }
  }
}
