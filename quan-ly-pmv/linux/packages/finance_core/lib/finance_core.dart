library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'app/providers.dart';
import 'core/config/client_config.dart';
import 'features/auth/secure_session_storage.dart';
export 'core/config/client_config.dart';

Future<void> launchFinance({ClientConfig? config}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = config ?? ClientConfig.environment();
  final error = settings.error;
  if (error != null) {
    runApp(ConfigurationError(message: error));
    return;
  }
  try {
    await Supabase.initialize(
      debug: false,
      url: settings.url,
      publishableKey: settings.key,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(),
      ),
    );
    final preferences = await SharedPreferences.getInstance();
    runApp(
      ProviderScope(
        overrides: [preferencesProvider.overrideWithValue(preferences)],
        child: const FinanceApp(),
      ),
    );
  } catch (_) {
    runApp(
      const ConfigurationError(
        message:
            'Unable to initialize secure session storage. On Linux, ensure a Secret Service keyring is installed and unlocked. Check the Supabase client configuration, then restart.',
      ),
    );
  }
}

class ConfigurationError extends StatelessWidget {
  final String message;
  const ConfigurationError({super.key, required this.message});
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_outlined, size: 48),
                const SizedBox(height: 20),
                Text(
                  'Configuration required',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
