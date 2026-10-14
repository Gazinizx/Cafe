import 'package:cafe_dunyam/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://phsmojbrbszobpyeeipc.supabase.co',
      publishableKey: 'sb_publishable_qOXjE2ZLsFcD3Eg0_XnfVA_Q106MWe_',
    );
  });

  testWidgets('Cafe Dünyam welcome screen offers customer and business paths', (tester) async {
    await tester.pumpWidget(const CafeDunyamApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Cafe Dünyam'), findsOneWidget);
    expect(find.text('Müşteriyim'), findsOneWidget);
    expect(find.text('İşletmeyim'), findsOneWidget);
  });
}
