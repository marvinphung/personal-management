import 'package:api_client/api_client.dart';
import 'package:collector_app/features/auth/admin_login_screen.dart';
import 'package:collector_app/features/status/status_tab.dart';
import 'package:collector_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CollectorHomeScreen renders four navigation tabs', (tester) async {
    final mockAdmin = UserDto(
      id: 'admin-1',
      username: 'admin',
      role: 'admin',
      status: 'active',
      captureEnabled: true,
      mustChangePassword: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAdminProvider.overrideWith((ref) => Future.value(mockAdmin)),
        ],
        child: const CollectorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trạng thái thu thập'), findsOneWidget);
    expect(find.text('Trạng thái'), findsOneWidget);
    expect(find.text('Người dùng'), findsOneWidget);
    expect(find.text('Ngân hàng'), findsOneWidget);
    expect(find.text('Thiết bị'), findsOneWidget);

    // Switch to Người dùng tab
    await tester.tap(find.text('Người dùng'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý người dùng'), findsOneWidget);

    // Switch to Ngân hàng tab
    await tester.tap(find.text('Ngân hàng'));
    await tester.pumpAndSettle();
    expect(find.text('Cấu hình ngân hàng'), findsOneWidget);

    // Switch to Thiết bị tab
    await tester.tap(find.text('Thiết bị'));
    await tester.pumpAndSettle();
    expect(find.text('Thiết bị & Chuyển giao'), findsOneWidget);
  });

  testWidgets('StatusTab displays health metadata without payload leaks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusTab(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify health metrics are shown
    expect(find.text('Quyền truy cập thông báo'), findsOneWidget);
    expect(find.text('Hàng đợi tải lên máy chủ'), findsOneWidget);
    expect(find.textContaining('Bảo mật: Màn hình này không lưu trữ'), findsOneWidget);
  });
}
