import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates api base url formatting', () {
    final validUri = Uri.tryParse('http://10.0.2.2:8000/v1');
    expect(validUri?.hasScheme, isTrue);
    expect(validUri?.host.isNotEmpty, isTrue);

    final httpsUri = Uri.tryParse('https://api.quanlytao.app/v1');
    expect(httpsUri?.scheme, 'https');
    expect(httpsUri?.host, 'api.quanlytao.app');
  });
}
