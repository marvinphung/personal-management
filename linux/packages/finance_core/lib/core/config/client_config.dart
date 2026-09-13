import 'dart:convert';

class ClientConfig {
  final String url, key;
  const ClientConfig(this.url, this.key);
  factory ClientConfig.environment() => const ClientConfig(
    String.fromEnvironment('SUPABASE_URL'),
    String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  String? get error {
    final uri = Uri.tryParse(url);
    if (url.isEmpty || key.isEmpty) {
      return 'Missing SUPABASE_URL or SUPABASE_ANON_KEY. Obtain the project URL and publishable key from Supabase Dashboard, then pass only these two values using --dart-define. See README.';
    }
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'SUPABASE_URL must be an HTTPS project URL.';
    }
    if (key.startsWith('sb_secret_')) {
      return 'A secret key cannot be used in a client. Use a publishable key.';
    }
    if (!key.startsWith('sb_publishable_')) {
      try {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(key.split('.')[1]))),
        );
        if (payload['role'] != 'anon') {
          return 'Only the anon key or a publishable key is allowed.';
        }
      } catch (_) {
        return 'Invalid public Supabase key. Use the Dashboard publishable or legacy anon key.';
      }
    }
    return null;
  }
}
