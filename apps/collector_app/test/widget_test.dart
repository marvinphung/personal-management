import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:collector_app/main.dart';

void main() {
  testWidgets('CollectorApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CollectorApp()));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý Tao — Đăng nhập Máy chủ'), findsOneWidget);
  });
}
