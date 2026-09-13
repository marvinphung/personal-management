import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/core/config/client_config.dart';

void main() {
  test(
    'missing public client settings fail clearly',
    () => expect(const ClientConfig('', '').error, contains('SUPABASE_URL')),
  );
  test(
    'rejects private secret keys',
    () => expect(
      const ClientConfig('https://example.supabase.co', 'sb_secret_test').error,
      isNotNull,
    ),
  );
  test('rejects service_role JWT', () {
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({'role': 'service_role'})),
    );
    expect(
      ClientConfig('https://example.supabase.co', 'header.$payload.sig').error,
      isNotNull,
    );
  });
  test(
    'permits publishable client keys over HTTPS',
    () => expect(
      const ClientConfig(
        'https://example.supabase.co',
        'sb_publishable_test',
      ).error,
      isNull,
    ),
  );
}
