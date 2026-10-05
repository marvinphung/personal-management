import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:api_client/api_client.dart';

void main() {
  group('ApiClient Tests', () {
    test('login stores token in SessionStore and returns UserDto', () async {
      final sessionStore = InMemorySessionStore();
      final mockClient = MockClient((request) async {
        if (request.url.path == '/v1/auth/login') {
          return http.Response(
            jsonEncode({
              'token': 'test_token_123',
              'expires_at': '2026-11-01T00:00:00Z',
              'user': {
                'id': '00000000-0000-0000-0000-000000000001',
                'username': 'testuser',
                'role': 'user',
                'status': 'active',
                'must_change_password': false,
                'capture_enabled': true,
              },
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/v1',
        sessionStore: sessionStore,
        httpClient: mockClient,
      );

      final authResponse = await api.login('testuser', 'Password123!');
      expect(authResponse.token, 'test_token_123');
      expect(authResponse.user.username, 'testuser');
      expect(await sessionStore.getToken(), 'test_token_123');
    });

    test('authenticated request passes Bearer token', () async {
      final sessionStore = InMemorySessionStore('saved_token_abc');
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer saved_token_abc');
        return http.Response(
          jsonEncode({
            'id': '00000000-0000-0000-0000-000000000001',
            'username': 'testuser',
            'role': 'user',
            'status': 'active',
            'must_change_password': false,
            'capture_enabled': true,
          }),
          200,
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/v1',
        sessionStore: sessionStore,
        httpClient: mockClient,
      );

      final user = await api.getMe();
      expect(user.username, 'testuser');
    });

    test('error response throws ApiException with details', () async {
      final sessionStore = InMemorySessionStore();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'code': 'INVALID_CREDENTIALS',
            'message': 'Sai mật khẩu',
            'request_id': 'req-999',
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/v1',
        sessionStore: sessionStore,
        httpClient: mockClient,
      );

      expect(
        () => api.login('user', 'wrong'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'INVALID_CREDENTIALS')
              .having((e) => e.message, 'message', 'Sai mật khẩu')
              .having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('logout clears SessionStore', () async {
      final sessionStore = InMemorySessionStore('token_to_clear');
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Logged out'}), 200);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/v1',
        sessionStore: sessionStore,
        httpClient: mockClient,
      );

      await api.logout();
      expect(await sessionStore.getToken(), isNull);
    });

    test('collector enrollment is explicit and never requests handover', () async {
      final sessionStore = InMemorySessionStore('admin_token');
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/admin/collectors/enroll');
        expect(request.headers['Authorization'], 'Bearer admin_token');
        expect(jsonDecode(request.body), {'handover': false});
        return http.Response(
          jsonEncode({
            'collector_id': 'collector-1',
            'collector_token': 'one-time-token',
            'collector_epoch': 1,
            'state': 'active',
            'handover_performed': false,
            'bindings': [
              {
                'binding_id': 'binding-1',
                'bank_code': 'bidv',
                'account_number': '1234',
                'binding_version': 1,
                'capture_epoch': 1,
              },
            ],
          }),
          201,
        );
      });
      final api = ApiClient(
        baseUrl: 'http://localhost:8000/v1',
        sessionStore: sessionStore,
        httpClient: mockClient,
      );

      final enrollment = await api.enrollCurrentCollector();

      expect(enrollment['collector_token'], 'one-time-token');
      expect(enrollment['handover_performed'], false);
    });
  });
}
