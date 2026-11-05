import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient client;
  AuthRepository(this.client);
  Future<void> signIn(String email, String password) => client.auth
      .signInWithPassword(email: email, password: password)
      .then((_) {});

  /// True when email confirmation is still required.
  Future<bool> signUp(String email, String password) async =>
      (await client.auth.signUp(email: email, password: password)).session ==
      null;
}
