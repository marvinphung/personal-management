abstract class SessionStore {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> clear();
}

class InMemorySessionStore implements SessionStore {
  String? _token;

  InMemorySessionStore([this._token]);

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async {
    return _token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}
