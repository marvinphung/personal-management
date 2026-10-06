import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collector_app/features/auth/admin_login_screen.dart';
import 'package:collector_app/main.dart';

void main() {
  testWidgets('CollectorApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAdminProvider.overrideWith((ref) => Future.value(null)),
        ],
        child: const CollectorApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Quản lý Tao — Đăng nhập Máy chủ'), findsOneWidget);
  });
}
