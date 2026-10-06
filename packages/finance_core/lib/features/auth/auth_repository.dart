import 'package:api_client/api_client.dart';

class AuthRepository {
  final ApiClient client;

  AuthRepository(this.client);

  Future<AuthResponseDto> signIn(String username, String password) {
    return client.login(username, password);
  }

  Future<RegisterResponseDto> signUp(String username, String password) {
    return client.register(username, password);
  }

  Future<void> signOut({String? tokenToRevoke}) {
    return client.logout(tokenToRevoke: tokenToRevoke);
  }

  Future<UserDto> getCurrentUser() {
    return client.getMe();
  }

  Future<void> changePassword(String oldPassword, String newPassword) {
    return client.changePassword(oldPassword, newPassword);
  }
}
