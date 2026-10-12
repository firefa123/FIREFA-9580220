import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firefa_main_app/features/modules/offline_sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('concurrent initialize calls share one initialization future', () async {
    final queue = FirefaOfflineSyncQueue.instance;

    final first = queue.initialize();
    final second = queue.initialize();

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    expect(queue.exportSnapshot()['version'], 1);
  });
}
