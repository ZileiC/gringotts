import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gringotts/services/direct_entry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DirectEntryService (T-06 direct entries)', () {
    test('setTileActive invokes platform channel and tolerates missing plugin',
        () async {
      const channel = MethodChannel('dev.jharayden.gringotts/tile');
      Object? receivedArg;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        receivedArg = call.arguments;
        return true;
      });

      await DirectEntryService.setTileActive(true);
      expect(receivedArg, isTrue);
    });

    test('initialize registers the 记一笔 shortcut without error', () async {
      const qaChannel = MethodChannel('plugins.flutter.io/quick_actions');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(qaChannel, (call) async => null);
      await DirectEntryService.initialize((type) {});
    });
  });
}
