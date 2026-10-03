import 'dart:convert';
import 'package:http/http.dart' as http;
import '../errors/api_exception.dart';
import '../models/models.dart';
import '../session/session_store.dart';

class ApiClient {
  final String baseUrl;
  final SessionStore sessionStore;
  final http.Client _httpClient;

  ApiClient({
    required this.baseUrl,
    required this.sessionStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  String _cleanUrl(String path) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    return '$base$p';
  }

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requiresAuth) {
      final token = await sessionStore.getToken();
      if (token != null) {
        map['Authorization'] = 'Bearer $token';
      }
    }
    return map;
  }

  void _handleError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    String code = 'UNKNOWN_ERROR';
    String message = 'Đã xảy ra lỗi máy chủ';
    String? reqId;

    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        if (body.containsKey('code')) code = body['code'].toString();
        if (body.containsKey('message')) message = body['message'].toString();
        if (body.containsKey('request_id')) reqId = body['request_id']?.toString();
        if (body.containsKey('detail')) {
          final detail = body['detail'];
          if (detail is Map) {
            if (detail.containsKey('code')) code = detail['code'].toString();
            if (detail.containsKey('message')) message = detail['message'].toString();
          } else if (detail is String) {
            message = detail;
          }
        }
      }
    } catch (_) {
      message = response.body.isNotEmpty ? response.body : response.reasonPhrase ?? message;
    }

    throw ApiException(
      code: code,
      message: message,
      requestId: reqId,
      statusCode: response.statusCode,
    );
  }

  // --- Auth Endpoints ---

  Future<RegisterResponseDto> register(String username, String password) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/auth/register')),
      headers: await _headers(requiresAuth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    _handleError(res);
    return RegisterResponseDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<AuthResponseDto> login(String username, String password) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/auth/login')),
      headers: await _headers(requiresAuth: false),
      body: jsonEncode({'username': username, 'password': password}),
    );
    _handleError(res);
    final dto = AuthResponseDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    await sessionStore.saveToken(dto.token);
    return dto;
  }

  Future<void> logout() async {
    try {
      final res = await _httpClient.post(
        Uri.parse(_cleanUrl('/auth/logout')),
        headers: await _headers(),
      );
      _handleError(res);
    } finally {
      await sessionStore.clear();
    }
  }

  Future<UserDto> getMe() async {
    final res = await _httpClient.get(
      Uri.parse(_cleanUrl('/me')),
      headers: await _headers(),
    );
    _handleError(res);
    return UserDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/auth/change-password')),
      headers: await _headers(),
      body: jsonEncode({'old_password': oldPassword, 'new_password': newPassword}),
    );
    _handleError(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data.containsKey('token')) {
      await sessionStore.saveToken(data['token'].toString());
    }
  }

  // --- Banks & Bindings ---

  Future<List<BankSettingDto>> getBanks() async {
    final res = await _httpClient.get(
      Uri.parse(_cleanUrl('/banks')),
      headers: await _headers(),
    );
    _handleError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => BankSettingDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<BankBindingDto>> getBankBindings() async {
    final res = await _httpClient.get(
      Uri.parse(_cleanUrl('/bank-bindings')),
      headers: await _headers(),
    );
    _handleError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => BankBindingDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BankBindingDto> createBankBinding(String bankCode, String accountNumber) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/bank-bindings')),
      headers: await _headers(),
      body: jsonEncode({'bank_code': bankCode, 'account_number': accountNumber}),
    );
    _handleError(res);
    return BankBindingDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<BankBindingDto> updateBankBinding(String id, String accountNumber) async {
    final res = await _httpClient.patch(
      Uri.parse(_cleanUrl('/bank-bindings/$id')),
      headers: await _headers(),
      body: jsonEncode({'account_number': accountNumber}),
    );
    _handleError(res);
    return BankBindingDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Pending Events ---

  Future<List<PendingBankEventDto>> getPendingEvents() async {
    final res = await _httpClient.get(
      Uri.parse(_cleanUrl('/pending-events')),
      headers: await _headers(),
    );
    _handleError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => PendingBankEventDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> acceptPendingEvent({
    required String eventId,
    required String operationId,
    required String transactionId,
    required String categoryId,
    required List<String> tagIds,
    String userNote = '',
  }) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/pending-events/$eventId/accept')),
      headers: await _headers(),
      body: jsonEncode({
        'operation_id': operationId,
        'transaction_id': transactionId,
        'category_id': categoryId,
        'tag_ids': tagIds,
        'user_note': userNote,
      }),
    );
    _handleError(res);
  }

  Future<void> discardPendingEvent({
    required String eventId,
    required String operationId,
  }) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/pending-events/$eventId/discard')),
      headers: await _headers(),
      body: jsonEncode({'operation_id': operationId}),
    );
    _handleError(res);
  }

  // --- Sync ---

  Future<Map<String, dynamic>> getSnapshot({int? knownRevision}) async {
    final query = knownRevision != null ? {'known_revision': knownRevision.toString()} : null;
    final uri = Uri.parse(_cleanUrl('/sync/snapshot')).replace(queryParameters: query);
    final res = await _httpClient.get(uri, headers: await _headers());
    _handleError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> postOperations(List<Map<String, dynamic>> operations) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/sync/operations')),
      headers: await _headers(),
      body: jsonEncode({'operations': operations}),
    );
    _handleError(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // --- Widget ---


  Future<WidgetSummaryDto> getWidgetSummary() async {
    final res = await _httpClient.get(
      Uri.parse(_cleanUrl('/widget/summary')),
      headers: await _headers(),
    );
    _handleError(res);
    return WidgetSummaryDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // --- Admin ---

  Future<List<UserDto>> listUsers([String? status]) async {
    final uri = Uri.parse(_cleanUrl('/admin/users')).replace(
      queryParameters: status != null ? {'status': status} : null,
    );
    final res = await _httpClient.get(uri, headers: await _headers());
    _handleError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => UserDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> approveUser(String userId) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/admin/users/$userId/approve')),
      headers: await _headers(),
    );
    _handleError(res);
  }

  Future<void> toggleCapture(String userId, bool enabled) async {
    final res = await _httpClient.patch(
      Uri.parse(_cleanUrl('/admin/users/$userId/capture')),
      headers: await _headers(),
      body: jsonEncode({'enabled': enabled}),
    );
    _handleError(res);
  }

  Future<String> setTemporaryPassword(String userId, [String? password]) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/admin/users/$userId/temporary-password')),
      headers: await _headers(),
      body: jsonEncode({'temporary_password': password}),
    );
    _handleError(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['temporary_password'] as String;
  }

  Future<void> deleteUser(String userId) async {
    final res = await _httpClient.delete(
      Uri.parse(_cleanUrl('/admin/users/$userId')),
      headers: await _headers(),
    );
    _handleError(res);
  }

  Future<void> restoreUser(String userId) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/admin/users/$userId/restore')),
      headers: await _headers(),
    );
    _handleError(res);
  }

  Future<void> purgeUser(String userId) async {
    final res = await _httpClient.post(
      Uri.parse(_cleanUrl('/admin/users/$userId/purge')),
      headers: await _headers(),
    );
    _handleError(res);
  }

  Future<List<Map<String, dynamic>>> getAdminBanks() async {
    final res = await _httpClient.get(
      Uri.parse(_cleanUrl('/admin/banks')),
      headers: await _headers(),
    );
    _handleError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> updateAdminBank(
    String bankCode, {
    bool enabled = true,
    String? receiverAccount,
    String? receiverName,
    String? instructions,
  }) async {
    final res = await _httpClient.put(
      Uri.parse(_cleanUrl('/admin/banks/$bankCode')),
      headers: await _headers(),
      body: jsonEncode({
        'enabled': enabled,
        'receiver_account': receiverAccount,
        'receiver_name': receiverName,
        'instructions': instructions,
      }),
    );
    _handleError(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

