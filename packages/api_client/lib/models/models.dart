class UserDto {
  final String id;
  final String username;
  final String role;
  final String status;
  final bool mustChangePassword;
  final bool captureEnabled;

  const UserDto({
    required this.id,
    required this.username,
    required this.role,
    required this.status,
    required this.mustChangePassword,
    required this.captureEnabled,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as String,
      username: json['username'] as String,
      role: json['role'] as String? ?? 'user',
      status: json['status'] as String? ?? 'pending',
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      captureEnabled: json['capture_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'role': role,
    'status': status,
    'must_change_password': mustChangePassword,
    'capture_enabled': captureEnabled,
  };
}

class AuthResponseDto {
  final String token;
  final String expiresAt;
  final UserDto user;

  const AuthResponseDto({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    return AuthResponseDto(
      token: json['token'] as String,
      expiresAt: json['expires_at'] as String,
      user: UserDto.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class RegisterResponseDto {
  final String userId;
  final String username;
  final String status;
  final String message;

  const RegisterResponseDto({
    required this.userId,
    required this.username,
    required this.status,
    required this.message,
  });

  factory RegisterResponseDto.fromJson(Map<String, dynamic> json) {
    return RegisterResponseDto(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      status: json['status'] as String,
      message: json['message'] as String,
    );
  }
}

class BankSettingDto {
  final String bankCode;
  final bool enabled;
  final String? receiverAccount;
  final String? receiverName;
  final String? instructions;
  final int version;

  const BankSettingDto({
    required this.bankCode,
    required this.enabled,
    this.receiverAccount,
    this.receiverName,
    this.instructions,
    required this.version,
  });

  factory BankSettingDto.fromJson(Map<String, dynamic> json) {
    return BankSettingDto(
      bankCode: json['bank_code'] as String,
      enabled: json['enabled'] as bool? ?? true,
      receiverAccount: json['receiver_account'] as String?,
      receiverName: json['receiver_name'] as String?,
      instructions: json['instructions'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }
}

class BankBindingDto {
  final String id;
  final String userId;
  final String bankCode;
  final String accountNumber;
  final int version;
  final String captureFrom;
  final String? firstReceivedAt;

  const BankBindingDto({
    required this.id,
    required this.userId,
    required this.bankCode,
    required this.accountNumber,
    required this.version,
    required this.captureFrom,
    this.firstReceivedAt,
  });

  factory BankBindingDto.fromJson(Map<String, dynamic> json) {
    return BankBindingDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bankCode: json['bank_code'] as String,
      accountNumber: json['account_number'] as String,
      version: json['version'] as int? ?? 1,
      captureFrom: json['capture_from'] as String,
      firstReceivedAt: json['first_received_at'] as String?,
    );
  }
}

class PendingBankEventDto {
  final String id;
  final String userId;
  final String? bindingId;
  final String bankCode;
  final String ownerAccountSnapshot;
  final int amountVnd;
  final String direction;
  final String occurredAt;
  final String timeSource;
  final String receivedAt;
  final String bankDescription;
  final int version;

  const PendingBankEventDto({
    required this.id,
    required this.userId,
    this.bindingId,
    required this.bankCode,
    required this.ownerAccountSnapshot,
    required this.amountVnd,
    required this.direction,
    required this.occurredAt,
    required this.timeSource,
    required this.receivedAt,
    required this.bankDescription,
    required this.version,
  });

  factory PendingBankEventDto.fromJson(Map<String, dynamic> json) {
    return PendingBankEventDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bindingId: json['binding_id'] as String?,
      bankCode: json['bank_code'] as String,
      ownerAccountSnapshot: json['owner_account_snapshot'] as String,
      amountVnd: int.parse(json['amount_vnd'].toString()),
      direction: json['direction'] as String,
      occurredAt: json['occurred_at'] as String,
      timeSource: json['time_source'] as String,
      receivedAt: json['received_at'] as String,
      bankDescription: json['bank_description'] as String,
      version: json['version'] as int? ?? 1,
    );
  }
}

class WidgetSummaryDto {
  final int count;
  final int revision;
  final List<String> pendingIds;

  const WidgetSummaryDto({
    required this.count,
    required this.revision,
    required this.pendingIds,
  });

  factory WidgetSummaryDto.fromJson(Map<String, dynamic> json) {
    return WidgetSummaryDto(
      count: json['count'] as int? ?? 0,
      revision: json['revision'] as int? ?? 1,
      pendingIds: (json['pending_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class WidgetTokenResponseDto {
  final String token;
  final String expiresAt;

  const WidgetTokenResponseDto({
    required this.token,
    required this.expiresAt,
  });

  factory WidgetTokenResponseDto.fromJson(Map<String, dynamic> json) {
    return WidgetTokenResponseDto(
      token: json['token'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
    );
  }
}
