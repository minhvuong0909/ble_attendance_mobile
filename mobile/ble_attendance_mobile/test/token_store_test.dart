import 'package:ble_attendance_mobile/data/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'PrefsTokenStore saves, reads and clears the token and base url',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsTokenStore();
      expect(await store.readToken(), isNull);
      await store.saveToken('abc');
      await store.saveBaseUrl('http://x:8000');
      expect(await store.readToken(), 'abc');
      expect(await store.readBaseUrl(), 'http://x:8000');
      await store.clearToken();
      expect(await store.readToken(), isNull);
      expect(await store.readBaseUrl(), 'http://x:8000');
    },
  );
}
