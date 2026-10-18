import 'package:cafe_dunyam/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeSupabase();
  });

  testWidgets('Cafe Dünyam welcome screen offers customer and business paths', (tester) async {
    await tester.pumpWidget(const CafeDunyamApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cafe Dünyam'), findsOneWidget);
    expect(find.text('Müşteriyim'), findsOneWidget);
    expect(find.text('İşletmeyim'), findsOneWidget);
    expect(find.text('Yönetici demo girişi'), findsNothing);
  });

  testWidgets('login screen exposes email-based sign-in and password recovery', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthPage(register: false, onDone: (_) {}),
    ));
    await tester.pump();

    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Parolamı unuttum'), findsOneWidget);
    expect(find.text('Giriş yap'), findsWidgets);
  });
}
