import 'package:flutter_test/flutter_test.dart';
import 'package:api_client/api_client.dart';

void main() {
  group('Bank Links & Settings Tests', () {
    test('BankSettingDto parses instructions and fields', () {
      final json = {
        'bank_code': 'bidv',
        'enabled': true,
        'receiver_account': '00123456789',
        'receiver_name': 'BIDV SmartBanking',
        'instructions': 'Cài đặt chia sẻ thông báo trong app.',
        'version': 1,
      };
      final dto = BankSettingDto.fromJson(json);
      expect(dto.bankCode, 'bidv');
      expect(dto.enabled, isTrue);
      expect(dto.receiverAccount, '00123456789');
      expect(dto.instructions, 'Cài đặt chia sẻ thông báo trong app.');
    });

    test('BankBindingDto preserves leading zeros in account number', () {
      final json = {
        'id': 'bnd-1',
        'user_id': 'usr-1',
        'bank_code': 'vietinbank',
        'account_number': '000789012345',
        'version': 2,
        'capture_from': '2026-10-02T10:00:00Z',
        'first_received_at': null,
      };
      final dto = BankBindingDto.fromJson(json);
      expect(dto.accountNumber, '000789012345');
      expect(dto.firstReceivedAt, isNull);
    });
  });
}
