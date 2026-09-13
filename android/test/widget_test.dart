import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_core/finance_core.dart';
void main(){testWidgets('missing configuration is actionable',(tester) async {await tester.pumpWidget(const ConfigurationError(message:'Missing SUPABASE_URL and SUPABASE_ANON_KEY'));expect(find.text('Configuration required'),findsOneWidget);expect(find.byType(Scaffold),findsOneWidget);});}
