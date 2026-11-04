import 'package:cafe_dunyam/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeSupabase();
  });

  test('auth failure messages preserve the actual server or network detail', () {
    expect(
      authFailureMessage(const AuthException('Signups not allowed')),
      contains('Signups not allowed'),
    );
    expect(
      authFailureMessage(StateError('SocketException: Failed host lookup')),
      contains('Failed host lookup'),
    );
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

  testWidgets('customer registration asks only for full name, email, phone and password', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthPage(register: true, initialRole: 'customer', onDone: (_) {}),
    ));
    await tester.pump();

    expect(find.text('Ad Soyad'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
    expect(find.text('Telefon numarası'), findsOneWidget);
    expect(find.text('Parola'), findsOneWidget);
    expect(find.text('Yetkili kişinin adı soyadı'), findsNothing);
    expect(find.text('İşletme bilgileri'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(4));
  });

  testWidgets('business registration identifies the authorized person separately', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AuthPage(register: true, initialRole: 'business', onDone: (_) {}),
    ));
    await tester.pump();

    expect(find.text('Yetkili kişinin adı soyadı'), findsOneWidget);
    expect(find.text('İşletme / kafe adı'), findsOneWidget);
    expect(find.text('Ad Soyad'), findsNothing);
  });
  test('business analytics counts unique and repeat stamp customers accurately', () {
    final summary = BusinessAnalyticsSummary.fromRows(
      events: [
        {'customer_id': 'a', 'campaign_id': 'c1'},
        {'customer_id': 'a', 'campaign_id': 'c1'},
        {'customer_id': 'b', 'campaign_id': 'c2'},
        {'customer_id': 'c', 'campaign_id': 'c2'},
        {'customer_id': 'c', 'campaign_id': 'c2'},
        {'customer_id': 'c', 'campaign_id': 'c2'},
      ],
      campaigns: [
        {'id': 'c1', 'title': 'Kahve', 'is_active': true},
        {'id': 'c2', 'title': 'Tatlı', 'is_active': false},
      ],
      redeemedRewards: 2,
    );
    expect(summary.totalStamps, 6);
    expect(summary.uniqueCustomers, 3);
    expect(summary.repeatCustomers, 2);
    expect(summary.redeemedRewards, 2);
    expect(summary.campaignCount, 2);
    expect(summary.activeCampaignCount, 1);
    expect(summary.stampsByCampaign['Kahve'], 2);
    expect(summary.stampsByCampaign['Tatlı'], 4);
  });

  test('campaign relation handles object and list responses without losing the campaign id', () {
    final object = campaignRelationMap({'id': 'campaign-123', 'stamps_required': 5});
    final list = campaignRelationMap([{'id': 'campaign-456', 'stamps_required': 5}]);
    expect(object?['id'], 'campaign-123');
    expect(object?['stamps_required'], 5);
    expect(list?['id'], 'campaign-456');
    expect(campaignRelationMap(null), isNull);
    expect(campaignRelationMap([]), isNull);
  });

  test('Cafe Dünyam QR payload accepts only 256-bit lowercase hex tokens', () {
    final token = List.filled(64, 'a').join();
    expect(cafeQrTokenFromPayload('CDQR:' + token), token);
    expect(cafeQrTokenFromPayload('CDQR:' + List.filled(64, 'A').join()), isNull);
    expect(cafeQrTokenFromPayload('OTHER:' + token), isNull);
    expect(cafeQrTokenFromPayload('CDQR:short'), isNull);
    expect(cafeQrTokenFromPayload(null), isNull);
  });

}
