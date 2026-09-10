import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/network/secure_local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Map<String, String> mockSecureStore = {};

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'read':
            final key = methodCall.arguments['key'] as String;
            return mockSecureStore[key];
          case 'write':
            final key = methodCall.arguments['key'] as String;
            final value = methodCall.arguments['value'] as String;
            mockSecureStore[key] = value;
            return null;
          case 'delete':
            final key = methodCall.arguments['key'] as String;
            mockSecureStore.remove(key);
            return null;
          case 'deleteAll':
            mockSecureStore.clear();
            return null;
          default:
            return null;
        }
      },
    );
  });

  group('SecureLocalStorage Unit Tests', () {
    const storage = SecureLocalStorage();

    test('storage initializes without error', () async {
      await expectLater(storage.initialize(), completes);
    });

    test('storage persists, reads, and deletes session tokens securely', () async {
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);

      await storage.persistSession('mock_jwt_session_token_xyz');

      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), equals('mock_jwt_session_token_xyz'));

      await storage.removePersistedSession();

      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });
  });
}
