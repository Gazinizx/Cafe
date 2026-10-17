import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://phsmojbrbszobpyeeipc.supabase.co',
);
const supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_qOXjE2ZLsFcD3Eg0_XnfVA_Q106MWe_',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
  runApp(const CafeDunyamApp());
}

SupabaseClient get cloud => Supabase.instance.client;

Future<Map<String, dynamic>> cloudProfile(User authUser) async {
  final row = await cloud.from('profiles').select().eq('id', authUser.id).maybeSingle();
  final meta = authUser.userMetadata ?? <String, dynamic>{};
  final role = (row?['role'] ?? meta['role'] ?? 'customer').toString();
  final user = <String, dynamic>{
    'id': authUser.id,
    'name': (row?['full_name'] ?? meta['full_name'] ?? authUser.email ?? 'Kullanıcı').toString(),
    'email': (row?['email'] ?? authUser.email ?? '').toString(),
    'role': role,
    'approvalStatus': (row?['approval_status'] ?? (role == 'business' ? 'pending' : 'approved')).toString(),
    'cloudAccount': true,
  };
  if (role == 'business') {
    final app = await cloud.from('business_applications').select().eq('business_id', authUser.id).maybeSingle();
    final cafe = await cloud.from('cafes').select('id,name,city').eq('owner_id', authUser.id).maybeSingle();
    if (app != null) {
      user.addAll({
        'cafeName': app['cafe_name'] ?? 'İşletmem',
        'phone': app['phone'] ?? '',
        'businessType': app['business_type'] ?? '',
        'taxOffice': app['tax_office'] ?? '',
        'taxNumber': app['tax_number'] ?? '',
        'province': app['province'] ?? '',
        'district': app['district'] ?? '',
        'businessAddress': app['business_address'] ?? '',
        'deliveryName': app['delivery_name'] ?? '',
        'deliveryPhone': app['delivery_phone'] ?? '',
        'deliveryProvince': app['delivery_province'] ?? '',
        'deliveryDistrict': app['delivery_district'] ?? '',
        'deliveryAddress': app['delivery_address'] ?? '',
        'tagCount': app['tag_count'] ?? 0,
        'applicationStatus': app['application_status'] ?? 'pending',
      });
    }
    if (cafe != null) {
      user['cafeId'] = cafe['id'];
      user['cafeName'] = cafe['name'] ?? user['cafeName'];
      user['city'] = cafe['city'] ?? user['province'];
    }
    final order = await cloud.from('business_orders').select().eq('business_id', authUser.id).order('created_at', ascending: false).limit(1).maybeSingle();
    if (order != null) user['nfcOrder'] = Map<String,dynamic>.from(order['order_data'] as Map);
  }
  return user;
}

const forest = Color(0xFF211711);
const cream = Color(0xFFF7F0E5);
const brown = Color(0xFFB76532);
const gold = Color(0xFFE4B56B);
const usersKey = 'cd_local_users_v1';
const sessionKey = 'cd_local_session_v1';
const cafesKey = 'cd_local_cafes_v1';
const dealsKey = 'cd_local_deals_v1';
const stampsKey = 'cd_local_stamps_v1';
const businessOrdersKey = 'cd_local_business_orders_v1';

class CafeLogo extends StatelessWidget {
  final double size;
  final bool light;
  const CafeLogo({super.key, this.size = 42, this.light = false});
  @override Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: light ? const Color(0xFF352116) : forest,
      borderRadius: BorderRadius.circular(size * .28),
      border: Border.all(color: gold.withOpacity(.75), width: 1.2),
    ),
    padding: EdgeInsets.all(size * .10),
    child: CustomPaint(painter: CafeCupLogoPainter(), size: Size.square(size * .80)),
  );
}

class CafeCupLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);
    final creamPaint = Paint()..color = const Color(0xFFF7F0E5)..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final copperPaint = Paint()..color = const Color(0xFFE4A05D)..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final cup = Path()..moveTo(18, 43)..quadraticBezierTo(22, 76, 47, 76)..quadraticBezierTo(70, 76, 76, 43);
    canvas.drawPath(cup, creamPaint);
    canvas.drawLine(const Offset(15, 41), const Offset(79, 41), creamPaint);
    final handle = Path()..moveTo(75, 49)..cubicTo(98, 42, 98, 70, 75, 66);
    canvas.drawPath(handle, copperPaint);
    final steam1 = Path()..moveTo(40, 31)..cubicTo(25, 20, 48, 15, 43, 3);
    final steam2 = Path()..moveTo(56, 31)..cubicTo(43, 20, 65, 15, 60, 7);
    canvas.drawPath(steam1, copperPaint);
    canvas.drawPath(steam2, creamPaint);
    final saucer = Path()..moveTo(22, 84)..quadraticBezierTo(48, 95, 74, 84);
    canvas.drawPath(saucer, copperPaint);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CafeDunyamApp extends StatelessWidget {
  const CafeDunyamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cafe Dünyam',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: brown, surface: cream),
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: forest, centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE8DCCB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brown, width: 1.5))),
    ),
    home: const GatePage(),
  );
}

class LocalData {
  static bool get _cloudReady => cloud.auth.currentSession != null;
  static bool _uuid(String? value) => value != null && RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(value);

  static Future<List<Map<String, dynamic>>> list(String key, List<Map<String, dynamic>> defaults) async {
    if (_cloudReady) {
      final auth = cloud.auth.currentUser!;
      final profile = await cloud.from('profiles').select('role').eq('id', auth.id).maybeSingle();
      final isAdmin = profile?['role'] == 'admin';
      if (key == cafesKey) {
        final rows = await cloud.from('cafes').select().order('name');
        return (rows as List).map((raw) {
          final r = Map<String,dynamic>.from(raw as Map);
          return <String,dynamic>{
            'id': r['id'], 'name': r['name'], 'city': r['city'],
            'type': r['category'] ?? 'Kafe', 'goal': 8,
            'reward': '8 damgada ödül', 'active': r['is_active'] == true,
            'ownerId': r['owner_id'], 'address': r['address'],
          };
        }).toList();
      }
      if (key == dealsKey) {
        final rows = await cloud.from('campaigns').select('*, cafes(name, owner_id)').order('created_at', ascending: false);
        return (rows as List).map((raw) {
          final r = Map<String,dynamic>.from(raw as Map);
          final cafe = r['cafes'] is Map ? Map<String,dynamic>.from(r['cafes'] as Map) : <String,dynamic>{};
          return <String,dynamic>{
            'id': r['id'], 'title': r['title'], 'benefit': r['benefit'],
            'audience': r['audience'] ?? 'Herkes', 'cafeId': r['cafe_id'],
            'active': r['is_active'] == true, 'ownerId': cafe['owner_id'],
            'ownerEmail': cafe['owner_id'] == auth.id ? auth.email : '',
            'ownerName': cafe['name'] ?? 'Kafe',
          };
        }).toList();
      }
      if (key == usersKey && isAdmin) {
        final profiles = await cloud.from('profiles').select().order('created_at', ascending: false);
        final apps = await cloud.from('business_applications').select();
        final appById = <String,Map<String,dynamic>>{
          for (final a in (apps as List)) (a['business_id'] as String): Map<String,dynamic>.from(a as Map)
        };
        return (profiles as List).map((raw) {
          final r = Map<String,dynamic>.from(raw as Map);
          final app = appById[r['id']] ?? <String,dynamic>{};
          return <String,dynamic>{
            'id': r['id'], 'name': r['full_name'], 'email': r['email'] ?? '',
            'role': r['role'], 'approvalStatus': r['approval_status'],
            'cafeName': app['cafe_name'] ?? r['full_name'],
            'phone': app['phone'] ?? '', 'businessType': app['business_type'] ?? '',
            'taxOffice': app['tax_office'] ?? '', 'taxNumber': app['tax_number'] ?? '',
            'province': app['province'] ?? '', 'district': app['district'] ?? '',
            'businessAddress': app['business_address'] ?? '',
            'deliveryName': app['delivery_name'] ?? '', 'deliveryPhone': app['delivery_phone'] ?? '',
            'deliveryProvince': app['delivery_province'] ?? '', 'deliveryDistrict': app['delivery_district'] ?? '',
            'deliveryAddress': app['delivery_address'] ?? '', 'tagCount': app['tag_count'] ?? 0,
            'applicationStatus': app['application_status'] ?? r['approval_status'],
          };
        }).toList();
      }
      if (key == businessOrdersKey) {
        final rows = isAdmin
          ? await cloud.from('business_orders').select('*, profiles(email, full_name)').order('created_at', ascending: false)
          : await cloud.from('business_orders').select().eq('business_id', auth.id).order('created_at', ascending: false);
        return (rows as List).map((raw) {
          final r = Map<String,dynamic>.from(raw as Map);
          final data = r['order_data'] is Map ? Map<String,dynamic>.from(r['order_data'] as Map) : <String,dynamic>{};
          data['id'] = r['id']; data['businessId'] = r['business_id'];
          final owner = r['profiles'] is Map ? Map<String,dynamic>.from(r['profiles'] as Map) : <String,dynamic>{};
          data['businessEmail'] = owner['email'] ?? '';
          data['businessName'] ??= owner['full_name'] ?? 'İşletme';
          data['orderStatus'] = r['order_status']; data['paymentStatus'] = r['payment_status'];
          return data;
        }).toList();
      }
      if (key == usersKey || key == businessOrdersKey) return [];
    }
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) { await p.setString(key, jsonEncode(defaults)); return defaults; }
    try { return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); }
    catch (_) { return defaults; }
  }

  static Future<void> saveList(String key, List<Map<String, dynamic>> value) async {
    if (_cloudReady) {
      final auth = cloud.auth.currentUser!;
      final profile = await cloud.from('profiles').select('role').eq('id', auth.id).maybeSingle();
      final isAdmin = profile?['role'] == 'admin';
      if (key == dealsKey && isAdmin) {
        final rows = await cloud.from('campaigns').select('id');
        final ids = value.map((d) => d['id']?.toString()).whereType<String>().where(_uuid).toSet();
        for (final row in (rows as List)) {
          final id = row['id'].toString();
          if (!ids.contains(id)) await cloud.from('campaigns').delete().eq('id', id);
        }
        for (final d in value) {
          final id = d['id']?.toString();
          if (!_uuid(id)) continue;
          await cloud.from('campaigns').update({
            'title': d['title'] ?? '', 'benefit': d['benefit'] ?? '',
            'audience': d['audience'] ?? 'Herkes', 'is_active': d['active'] == true,
          }).eq('id', id!);
        }
        return;
      }
      if (key == dealsKey) {
        final cafe = await cloud.from('cafes').select('id').eq('owner_id', auth.id).maybeSingle();
        final ownedCafeId = cafe?['id']?.toString();
        if (ownedCafeId != null) {
          final desired = value.where((d) => d['cafeId'] == ownedCafeId || d['ownerId'] == auth.id || d['ownerEmail'] == auth.email || (d['id']?.toString().startsWith('local-') == true)).toList();
          final oldRows = await cloud.from('campaigns').select('id').eq('cafe_id', ownedCafeId);
          final desiredIds = desired.map((d) => d['id']?.toString()).whereType<String>().where(_uuid).toSet();
          for (final old in (oldRows as List)) {
            final id = old['id'].toString();
            if (!desiredIds.contains(id)) await cloud.from('campaigns').delete().eq('id', id);
          }
          for (final d in desired) {
            final payload = <String,dynamic>{
              'cafe_id': ownedCafeId, 'title': d['title'] ?? '',
              'benefit': d['benefit'] ?? '', 'audience': d['audience'] ?? 'Herkes',
              'is_active': d['active'] == true,
            };
            if (_uuid(d['id']?.toString())) payload['id'] = d['id'];
            await cloud.from('campaigns').upsert(payload);
          }
          return;
        }
      }
      if (key == usersKey && isAdmin) {
        for (final u in value) {
          final id = u['id']?.toString();
          if (!_uuid(id)) continue;
          final status = (u['approvalStatus'] ?? 'pending').toString();
          await cloud.from('profiles').update({'approval_status': status}).eq('id', id!);
          if (u['role'] == 'business') {
            await cloud.from('business_applications').update({'application_status': status}).eq('business_id', id);
            await cloud.from('cafes').update({'is_active': status == 'approved'}).eq('owner_id', id);
          }
        }
        return;
      }
      if (key == businessOrdersKey && isAdmin) {
        for (final o in value) {
          final id = o['id']?.toString();
          if (!_uuid(id)) continue;
          final data = Map<String,dynamic>.from(o)..remove('id')..remove('businessId')..remove('orderStatus')..remove('paymentStatus');
          await cloud.from('business_orders').update({
            'order_data': data, 'order_status': o['orderStatus'] ?? 'pending',
            'payment_status': o['paymentStatus'] ?? 'pending',
          }).eq('id', id!);
        }
        return;
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(value));
  }

  static Future<Map<String, int>> stamps() async {
    if (_cloudReady) {
      final rows = await cloud.from('cafe_memberships').select('cafe_id, stamps').eq('customer_id', cloud.auth.currentUser!.id);
      return {for (final r in (rows as List)) r['cafe_id'].toString(): (r['stamps'] as num).toInt()};
    }
    final p = await SharedPreferences.getInstance();
    try { return (jsonDecode(p.getString(stampsKey) ?? '{}') as Map).map((k,v) => MapEntry(k.toString(), (v as num).toInt())); }
    catch (_) { return {}; }
  }
  static Future<void> saveStamps(Map<String,int> value) async {
    if (_cloudReady) return; // Stamp issuance is intentionally server-controlled.
    final p = await SharedPreferences.getInstance(); await p.setString(stampsKey, jsonEncode(value));
  }
}

const starterCafes = <Map<String,dynamic>>[
  {'id':'kahve-duragi','name':'Kahve Durağı','city':'İstanbul','type':'Kahve ve tatlı','goal':8,'reward':'8 damgada 1 kahve hediye'},
  {'id':'mola-coffee','name':'Mola Coffee','city':'Ankara','type':'Modern kahve','goal':6,'reward':'6 damgada sürpriz ödül'},
  {'id':'kitap-kahve','name':'Kitap & Kahve','city':'İzmir','type':'Kitap kafe','goal':8,'reward':'8 damgada filtre kahve hediye'},
  {'id':'fincan-atolyesi','name':'Fincan Atölyesi','city':'Kayseri','type':'Üçüncü nesil kahve','goal':7,'reward':'7 damgada özel fırsat'},
  {'id':'pasta-molasi','name':'Pasta Molası','city':'Bursa','type':'Kahve ve pastane','goal':5,'reward':'5 damgada tatlı avantajı'},
];
const starterDeals = <Map<String,dynamic>>[
  {'id':'student','title':'Öğrenci indirimi','benefit':'Seçili içeceklerde %15 indirim','audience':'Öğrenci','cafeId':'kahve-duragi','active':true},
  {'id':'sweet','title':'Tatlı molası','benefit':'Kahve yanında tatlı fırsatı','audience':'Herkes','cafeId':'pasta-molasi','active':true},
];

class GatePage extends StatefulWidget {
  const GatePage({super.key});
  @override State<GatePage> createState() => _GatePageState();
}
class _GatePageState extends State<GatePage> {
  bool loading = true;
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    try {
      await LocalData.list(cafesKey, starterCafes);
      await LocalData.list(dealsKey, starterDeals);
    } catch (_) {
      // Keep the entry screen usable if the cloud schema has not been applied yet.
    }
    if (!mounted) return;
    setState(() => loading = false);
    final authUser = cloud.auth.currentUser;
    if (authUser != null && mounted) {
      try {
        _open(await cloudProfile(authUser));
        return;
      } catch (_) {
        // Fall back to the local demo session if cloud profile lookup fails.
      }
    }
    final email = p.getString(sessionKey);
    if (email != null && mounted) {
      final found = users.where((u) => u['email'] == email).toList();
      if (found.isNotEmpty && mounted) _open(found.first);
    }
  }
  void _open(Map<String,dynamic> user) {
    final Widget page;
    if (user['role'] == 'admin') {
      page = AdminShell(user: user);
    } else if (user['role'] == 'business' && user['approvalStatus'] != 'approved') {
      page = BusinessReviewPage(user: user);
    } else if (user['role'] == 'business') {
      page = BusinessShell(user: user);
    } else {
      page = CustomerShell(user: user);
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }
  @override Widget build(BuildContext context) => loading
    ? const Scaffold(body: Center(child: CircularProgressIndicator()))
    : WelcomePage(onDone: _open);
}

class WelcomePage extends StatelessWidget {
  final ValueChanged<Map<String,dynamic>> onDone;
  const WelcomePage({required this.onDone, super.key});
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
    const SizedBox(height: 28),
    Container(padding: const EdgeInsets.all(26), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF211711), Color(0xFF4A2A1A)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x223B2417), blurRadius: 18, offset: Offset(0, 8))]), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CafeLogo(size: 76, light: true), SizedBox(height: 18),
      Text('Cafe Dünyam', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
      Text('Kafeler, sen ve daha fazlası…', style: TextStyle(color: gold, fontSize: 14, fontStyle: FontStyle.italic)),
      SizedBox(height: 18),
      Text('Kahve molan, avantajın olsun.', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)),
      SizedBox(height: 10), Text('Kafeleri keşfet, fırsatları yakala ve sadakat kartlarını tek yerde takip et.', style: TextStyle(color: Colors.white70, fontSize: 16)),
    ])),
    const SizedBox(height: 28), const Text('Cafe Dünyam’a hoş geldin', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: forest)),
    const SizedBox(height: 8), const Text('Nasıl devam etmek istersin?'), const SizedBox(height: 18),
    FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(register: true, initialRole: 'customer', onDone: onDone))), icon: const Icon(Icons.person_outline), label: const Text('Müşteriyim')),
    const SizedBox(height: 8),
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(register: true, initialRole: 'business', onDone: onDone))), icon: const Icon(Icons.storefront_outlined), label: const Text('İşletmeyim')),
    const SizedBox(height: 8),
    TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(register: false, onDone: onDone))), icon: const Icon(Icons.login), label: const Text('Hesabım var — giriş yap')),
    const SizedBox(height: 20), const LocalModeNote(),
  ])));
}

class AuthPage extends StatefulWidget {
  final bool register;
  final String initialRole;
  final ValueChanged<Map<String,dynamic>> onDone;
  const AuthPage({required this.register, this.initialRole = 'customer', required this.onDone, super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController();
  final cafeName = TextEditingController(), phone = TextEditingController(), businessType = TextEditingController();
  final taxOffice = TextEditingController(), taxNumber = TextEditingController();
  final province = TextEditingController(), district = TextEditingController(), address = TextEditingController();
  final deliveryName = TextEditingController(), deliveryPhone = TextEditingController();
  final deliveryProvince = TextEditingController(), deliveryDistrict = TextEditingController(), deliveryAddress = TextEditingController();
  String role = 'customer';
  int tagCount = 10;
  bool busy = false, hide = true;
  static const Map<int,int> packagePrices = {10: 499, 25: 999, 50: 1799, 100: 2999};
  static const int shippingPrice = 99;
  int get orderTotal => (packagePrices[tagCount] ?? 499) + shippingPrice;

  @override void initState() { super.initState(); role = widget.initialRole; }
  @override void dispose() {
    name.dispose(); email.dispose(); password.dispose(); cafeName.dispose(); phone.dispose();
    businessType.dispose(); taxOffice.dispose(); taxNumber.dispose(); province.dispose();
    district.dispose(); address.dispose(); deliveryName.dispose(); deliveryPhone.dispose();
    deliveryProvince.dispose(); deliveryDistrict.dispose(); deliveryAddress.dispose();
    super.dispose();
  }
  String? requiredText(String? value, String label) => value == null || value.trim().isEmpty ? '$label alanını doldur.' : null;
  Widget sectionTitle(String text) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: forest)));

  Future<void> _resetPassword() async {
    final mail = email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$').hasMatch(mail)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parola sıfırlama bağlantısı için geçerli e-posta adresini yaz.')));
      return;
    }
    setState(() => busy = true);
    try {
      await cloud.auth.resetPasswordForEmail(mail);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-posta adresin kayıtlıysa parola sıfırlama bağlantısı gönderildi. Gelen kutunu ve spam klasörünü kontrol et.')));
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Parola sıfırlama başlatılamadı: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    final mail = email.text.trim().toLowerCase();
    try {
      if (widget.register) {
        final response = await cloud.auth.signUp(
          email: mail,
          password: password.text,
          data: {
            'full_name': name.text.trim(),
            'role': role,
            if (role == 'business') ...{
              'cafe_name': cafeName.text.trim(),
              'phone': phone.text.trim(),
              'business_type': businessType.text.trim(),
              'tax_office': taxOffice.text.trim(),
              'tax_number': taxNumber.text.trim(),
              'province': province.text.trim(),
              'district': district.text.trim(),
              'business_address': address.text.trim(),
              'delivery_name': deliveryName.text.trim(),
              'delivery_phone': deliveryPhone.text.trim(),
              'delivery_province': deliveryProvince.text.trim(),
              'delivery_district': deliveryDistrict.text.trim(),
              'delivery_address': deliveryAddress.text.trim(),
              'tag_count': '$tagCount',
              'package_price_try': '${packagePrices[tagCount] ?? 0}',
              'shipping_try': '$shippingPrice',
              'order_total_try': '$orderTotal',
            },
          },
        );
        final authUser = response.user;
        if (authUser == null) throw const AuthException('Hesap oluşturulamadı. Lütfen tekrar dene.');
        final user = <String,dynamic>{
          'id': authUser.id, 'name': name.text.trim(), 'email': mail, 'role': role,
          'approvalStatus': role == 'business' ? 'pending' : 'approved',
          'cloudAccount': true, 'cafeName': cafeName.text.trim(), 'city': province.text.trim(),
          if (role == 'business') ...{
            'applicationStatus': 'Başvurunuz inceleniyor',
            'applicationSubmittedAt': DateTime.now().toIso8601String(),
            'phone': phone.text.trim(), 'businessType': businessType.text.trim(),
            'taxOffice': taxOffice.text.trim(), 'taxNumber': taxNumber.text.trim(),
            'province': province.text.trim(), 'district': district.text.trim(),
            'businessAddress': address.text.trim(), 'deliveryName': deliveryName.text.trim(),
            'deliveryPhone': deliveryPhone.text.trim(), 'deliveryProvince': deliveryProvince.text.trim(),
            'deliveryDistrict': deliveryDistrict.text.trim(), 'deliveryAddress': deliveryAddress.text.trim(),
            'tagCount': tagCount,
          },
        };
        if (cloud.auth.currentSession == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Hesap oluşturuldu. Devam etmek için e-posta doğrulama bağlantısını aç.')),
            );
            Navigator.of(context).pop();
          }
          return;
        }
        if (role == 'business') {
          user['cafeId'] = (await cloud.from('cafes').select('id').eq('owner_id', authUser.id).single())['id'];
          user['nfcOrder'] = {
            'businessName': cafeName.text.trim(), 'tagCount': tagCount,
            'packagePriceTry': packagePrices[tagCount] ?? 0, 'shippingTry': shippingPrice,
            'totalTry': orderTotal, 'paymentMethod': 'IBAN havale/EFT',
            'paymentStatus': 'Ödeme bekliyor', 'orderStatus': 'Başvuru inceleniyor',
            'recipientName': deliveryName.text.trim(), 'recipientPhone': deliveryPhone.text.trim(),
            'province': deliveryProvince.text.trim(), 'district': deliveryDistrict.text.trim(),
            'address': deliveryAddress.text.trim(), 'createdAt': DateTime.now().toIso8601String(),
          };
        }
        final p = await SharedPreferences.getInstance();
        await p.remove(sessionKey);
        if (mounted) widget.onDone(user);
      } else {
        final response = await cloud.auth.signInWithPassword(email: mail, password: password.text);
        final authUser = response.user;
        if (authUser == null) throw const AuthException('Giriş başarısız. Bilgilerini kontrol et.');
        final user = await cloudProfile(authUser);
        if (mounted) widget.onDone(user);
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on PostgrestException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulut veritabanı hatası: ${e.message}. Supabase şema kurulumunu kontrol et.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.register ? (role == 'business' ? 'İşletme kaydı' : 'Müşteri kaydı') : 'Giriş yap')),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(22), children: [
      Text(widget.register ? (role == 'business' ? 'İşletmeni Cafe Dünyam’a kaydet' : 'Müşteri hesabını oluştur') : 'Tekrar hoş geldin', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: forest)),
      const SizedBox(height: 8), const LocalModeNote(),
      if (widget.register) ...[
        sectionTitle('Hesap bilgileri'),
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Yetkili kişinin adı soyadı'), validator: (v) => requiredText(v, 'Ad soyad')),
        const SizedBox(height: 12),
        TextFormField(controller: email, keyboardType: widget.register ? TextInputType.emailAddress : TextInputType.text, decoration: InputDecoration(labelText: widget.register ? 'E-posta' : 'Kullanıcı adı veya e-posta', prefixIcon: const Icon(Icons.email_outlined)), validator: (v) => widget.register ? (v == null || !v.contains('@') ? 'Geçerli e-posta yaz.' : null) : (v == null || v.trim().isEmpty ? 'Kullanıcı adı veya e-posta yaz.' : null)),
        const SizedBox(height: 12),
        TextFormField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Parola', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off))), validator: (v) => v == null || v.length < 6 ? 'En az 6 karakter kullan.' : null),
        if (role == 'business') ...[
          sectionTitle('İşletme bilgileri'),
          TextFormField(controller: cafeName, decoration: const InputDecoration(labelText: 'İşletme / kafe adı'), validator: (v) => requiredText(v, 'İşletme adı')),
          const SizedBox(height: 12),
          TextFormField(controller: businessType, decoration: const InputDecoration(labelText: 'İşletme türü (kafe, pastane vb.)'), validator: (v) => requiredText(v, 'İşletme türü')),
          const SizedBox(height: 12),
          TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'İşletme telefonu'), validator: (v) => requiredText(v, 'İşletme telefonu')),
          const SizedBox(height: 12),
          TextFormField(controller: taxOffice, decoration: const InputDecoration(labelText: 'Vergi dairesi (örnek kayıt alanı)')),
          const SizedBox(height: 12),
          TextFormField(controller: taxNumber, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Vergi no (örnek kayıt alanı)')),
          sectionTitle('İşletme adresi'),
          TextFormField(controller: province, decoration: const InputDecoration(labelText: 'İl'), validator: (v) => requiredText(v, 'İl')),
          const SizedBox(height: 12),
          TextFormField(controller: district, decoration: const InputDecoration(labelText: 'İlçe'), validator: (v) => requiredText(v, 'İlçe')),
          const SizedBox(height: 12),
          TextFormField(controller: address, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'İşletmenin açık adresi'), validator: (v) => requiredText(v, 'İşletme adresi')),
          sectionTitle('NFC tag siparişi'),
          const Text('Bunlar test fiyatlarıdır, gerçek satış fiyatı değildir. Kargo bedeli de örnektir.'),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            value: tagCount, decoration: const InputDecoration(labelText: 'Kaç adet NFC tag istiyorsun?'),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10 adet — 499 TL')),
              DropdownMenuItem(value: 25, child: Text('25 adet — 999 TL')),
              DropdownMenuItem(value: 50, child: Text('50 adet — 1.799 TL')),
              DropdownMenuItem(value: 100, child: Text('100 adet — 2.999 TL')),
            ],
            onChanged: (v) => setState(() => tagCount = v ?? 10),
          ),
          const SizedBox(height: 8),
          Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Paket: ' + packagePrices[tagCount].toString() + ' TL'),
            Text('Örnek kargo: ' + shippingPrice.toString() + ' TL'),
            const Divider(),
            Text('Örnek toplam: ' + orderTotal.toString() + ' TL', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: forest)),
          ]))),
          sectionTitle('Teslimat bilgileri'),
          TextFormField(controller: deliveryName, decoration: const InputDecoration(labelText: 'Teslim alacak kişinin adı soyadı'), validator: (v) => requiredText(v, 'Teslim alacak kişi')),
          const SizedBox(height: 12),
          TextFormField(controller: deliveryPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Teslimat telefonu'), validator: (v) => requiredText(v, 'Teslimat telefonu')),
          const SizedBox(height: 12),
          TextFormField(controller: deliveryProvince, decoration: const InputDecoration(labelText: 'Teslimat ili'), validator: (v) => requiredText(v, 'Teslimat ili')),
          const SizedBox(height: 12),
          TextFormField(controller: deliveryDistrict, decoration: const InputDecoration(labelText: 'Teslimat ilçesi'), validator: (v) => requiredText(v, 'Teslimat ilçesi')),
          const SizedBox(height: 12),
          TextFormField(controller: deliveryAddress, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Teslimat açık adresi'), validator: (v) => requiredText(v, 'Teslimat adresi')),
          sectionTitle('Ödeme bilgileri'),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFE8DCC7), borderRadius: BorderRadius.circular(14)), child: const Text('IBAN ve ödeme talimatları işletme başvurusu onaylandıktan sonra gösterilecektir. Şimdilik sipariş talebin incelemeye alınır.')),
          const SizedBox(height: 10),
          const Text('Başvuru ve sipariş bilgilerin kayıt sırasında hesabına bağlı bulut sistemine gönderilir. Onaylanana kadar işletme özellikleri kısıtlıdır.'),
        ] else ...[
          sectionTitle('Müşteri bilgileri'),
        ],
      ] else ...[
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v == null || !RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$').hasMatch(v.trim()) ? 'Geçerli e-posta adresini yaz.' : null),
        const SizedBox(height: 12),
        TextFormField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Parola', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off))), validator: (v) => v == null || v.isEmpty ? 'Parolanı yaz.' : null),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : _resetPassword, child: const Text('Parolamı unuttum'))),
      ],
      const SizedBox(height: 22),
      FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'İşleniyor…' : widget.register ? (role == 'business' ? 'İşletme kaydını ve sipariş taslağını oluştur' : 'Müşteri hesabını oluştur') : 'Giriş yap')),
    ])),
  );
}

class LocalModeNote extends StatelessWidget {
  const LocalModeNote({super.key});
  @override Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(13), decoration:BoxDecoration(color:const Color(0xFFE8DCC7), borderRadius:BorderRadius.circular(13)), child:const Text('Hesap işlemleri bulut kimlik doğrulamasını kullanır. İşletme başvuruları yönetici onayına tabidir. Ödeme bilgileri yalnızca doğrulanmış resmî kanallardan paylaşılmalıdır.', style:TextStyle(fontSize:13)));
}

class CustomerShell extends StatefulWidget {
  final Map<String,dynamic> user;
  const CustomerShell({required this.user, super.key});
  @override State<CustomerShell> createState()=>_CustomerShellState();
}
class _CustomerShellState extends State<CustomerShell> {
  int tab=0;
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:IndexedStack(index:tab,children:[
    CustomerHome(user:widget.user,openTab:(i)=>setState(()=>tab=i)),
    ExplorePage(),
    CustomerCards(),
    CustomerDeals(),
    ProfilePage(user:widget.user),
  ])),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
    NavigationDestination(icon:Icon(Icons.home_outlined),label:'Ana Sayfa'),
    NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'Kafeler'),
    NavigationDestination(icon:Icon(Icons.loyalty_outlined),label:'Kartlarım'),
    NavigationDestination(icon:Icon(Icons.local_offer_outlined),label:'Fırsatlar'),
    NavigationDestination(icon:Icon(Icons.person_outline),label:'Profil'),
  ]));
}

class Heading extends StatelessWidget {
 final String title, subtitle;
 const Heading(this.title,this.subtitle,{super.key});
 @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('CAFE DÜNYAM',style:TextStyle(color:brown,fontWeight:FontWeight.w900,letterSpacing:2)),
 const SizedBox(height:6),Text(title,style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:forest)),
 Text(subtitle,style:TextStyle(color:Colors.grey.shade700)),
 ]));
}

class CustomerHome extends StatelessWidget {
 final Map<String,dynamic> user; final ValueChanged<int> openTab;
 const CustomerHome({required this.user,required this.openTab,super.key});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 Heading('Merhaba, ${user['name']}','Kahve molan için yeni avantajları keşfet.'),
 Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:forest,borderRadius:BorderRadius.circular(24)),child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Icon(Icons.coffee,color:Color(0xFFE7D4B2),size:36),SizedBox(height:12),
 Text('Kahve molan, avantajın olsun.',style:TextStyle(color:Colors.white,fontSize:26,fontWeight:FontWeight.w900)),
 SizedBox(height:8),Text('Kafeleri keşfet, kampanyaları yakala, sadakat kartlarını takip et.',style:TextStyle(color:Colors.white70)),
 ])),
 const SizedBox(height:16),Row(children:[const Expanded(child:Text('Öne çıkan kafeler',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:forest))),TextButton(onPressed:()=>openTab(1),child:const Text('Tümünü gör'))]),
 const CafePreviewList(limit:3),const SizedBox(height:12),
 Row(children:[const Expanded(child:Text('Günün fırsatları',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:forest))),TextButton(onPressed:()=>openTab(3),child:const Text('Tümü'))]),
 const DealPreviewList(),
 ]);
}

class CafePreviewList extends StatelessWidget {
 final int? limit; const CafePreviewList({this.limit,super.key});
 @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:LocalData.list(cafesKey,starterCafes),builder:(context,s){
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final items=limit==null?s.data!:s.data!.take(limit!).toList();
 if(items.isEmpty)return const Text('Henüz kafe eklenmedi.');
 return Column(children:items.map((c)=>Card(child:ListTile(leading:const CircleAvatar(backgroundColor:cream,child:Icon(Icons.local_cafe,color:forest)),title:Text('${c['name']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${c['city']} • ${c['type']}'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CafeDetailPage(cafe:c)))))).toList());
 });
}

class ExplorePage extends StatefulWidget { const ExplorePage({super.key}); @override State<ExplorePage> createState()=>_ExplorePageState(); }
class _ExplorePageState extends State<ExplorePage>{
 String query='',city='Tümü';
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('Kafeleri keşfet','Şehir veya kafe adına göre ara.'),
 TextField(onChanged:(v)=>setState(()=>query=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Kafe ara',filled:true,fillColor:Colors.white)),
 const SizedBox(height:10),
 FutureBuilder<List<Map<String,dynamic>>>(future:LocalData.list(cafesKey,starterCafes),builder:(context,s){
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final cities=['Tümü',...s.data!.map((e)=>'${e['city']}').toSet()];
 final matches=s.data!.where((c)=>(city=='Tümü'||c['city']==city)&&('${c['name']} ${c['type']} ${c['city']}'.toLowerCase().contains(query.toLowerCase()))).toList();
 return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Wrap(spacing:6,children:cities.map((v)=>ChoiceChip(label:Text(v),selected:city==v,onSelected:(_)=>setState(()=>city=v))).toList()),
 const SizedBox(height:8),if(matches.isEmpty)const Text('Aramana uygun kafe bulunamadı.'),
 ...matches.map((c)=>Card(child:ListTile(leading:const CircleAvatar(backgroundColor:cream,child:Icon(Icons.coffee,color:forest)),title:Text('${c['name']}'),subtitle:Text('${c['city']} • ${c['type']}'),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CafeDetailPage(cafe:c)))))),
 ]);
 }),
 ]);
}

class CafeDetailPage extends StatelessWidget{
 final Map<String,dynamic> cafe;const CafeDetailPage({required this.cafe,super.key});
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Kafe detayları')),body:ListView(padding:const EdgeInsets.all(22),children:[
 Container(height:150,decoration:BoxDecoration(color:forest,borderRadius:BorderRadius.circular(22)),child:const Icon(Icons.local_cafe,color:cream,size:70)),
 const SizedBox(height:18),Text('${cafe['name']}',style:const TextStyle(fontSize:28,fontWeight:FontWeight.w900,color:forest)),Text('${cafe['city']} • ${cafe['type']}'),
 const SizedBox(height:18),const Text('Sadakat ödülü',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),Text('${cafe['reward']}'),
 const SizedBox(height:16),const LocalModeNote(),
 ]));
}

class CustomerCards extends StatefulWidget{const CustomerCards({super.key});@override State<CustomerCards> createState()=>_CustomerCardsState();}
class _CustomerCardsState extends State<CustomerCards>{
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('Kartlarım','Her kafenin damga kartı ayrıdır.'),
 FutureBuilder<List<Object>>(future:Future.wait([LocalData.list(cafesKey,starterCafes),LocalData.stamps()]),builder:(context,s){
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final cafes=s.data![0] as List<Map<String,dynamic>>;final stamps=s.data![1] as Map<String,int>;
 return Column(children:cafes.map((c){
 final count=stamps[c['id']]??0;final goal=(c['goal'] as num).toInt();
 return Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('${c['name']}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),const SizedBox(height:10),
 LinearProgressIndicator(value:(count/goal).clamp(0.0,1.0),minHeight:8),
 const SizedBox(height:8),Text('$count / $goal damga • ${c['reward']}'),
 ])));
 }).toList());
 }),
 const LocalModeNote(),
 ]);
}
class DealPreviewList extends StatelessWidget{const DealPreviewList({super.key});@override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:LocalData.list(dealsKey,starterDeals),builder:(context,s){
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final deals=s.data!.where((d)=>d['active']==true).toList();
 return Column(children:deals.take(3).map((d)=>Card(child:ListTile(leading:const CircleAvatar(backgroundColor:cream,child:Icon(Icons.local_offer,color:forest)),title:Text('${d['title']}'),subtitle:Text('${d['benefit']} • ${d['audience']}')))).toList());
});}

class CustomerDeals extends StatefulWidget{const CustomerDeals({super.key});@override State<CustomerDeals> createState()=>_CustomerDealsState();}
class _CustomerDealsState extends State<CustomerDeals>{
 Set<String> saved={};
 @override void initState(){super.initState();_load();}
 Future<void> _load() async {
    if (cloud.auth.currentSession != null) {
      final rows = await cloud.from('saved_campaigns').select('campaign_id').eq('customer_id', cloud.auth.currentUser!.id);
      if (mounted) setState(() => saved = (rows as List).map((r) => r['campaign_id'].toString()).toSet());
      return;
    }
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => saved = (p.getStringList('cd_saved_deals') ?? []).toSet());
  }
  Future<void> _toggle(String id) async {
    if (cloud.auth.currentSession != null) {
      final customerId = cloud.auth.currentUser!.id;
      if (saved.contains(id)) {
        await cloud.from('saved_campaigns').delete().eq('customer_id', customerId).eq('campaign_id', id);
        setState(() => saved.remove(id));
      } else {
        await cloud.from('saved_campaigns').insert({'customer_id': customerId, 'campaign_id': id});
        setState(() => saved.add(id));
      }
      return;
    }
    setState(() => saved.contains(id) ? saved.remove(id) : saved.add(id));
    final p = await SharedPreferences.getInstance();
    await p.setStringList('cd_saved_deals', saved.toList());
  }
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('Fırsatlar','Kampanyaları keşfet ve kaydet.'),
 FutureBuilder<List<Object>>(future:Future.wait([LocalData.list(dealsKey,starterDeals),LocalData.list(cafesKey,starterCafes)]),builder:(context,s){
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final deals=s.data![0] as List<Map<String,dynamic>>;final cafes=s.data![1] as List<Map<String,dynamic>>;
 return Column(children:[
 ...deals.where((d)=>d['active']==true).map((d){final c=cafes.where((c)=>c['id']==d['cafeId']).toList();final cafe=c.isEmpty?'Cafe Dünyam':c.first['name'];return Card(child:ListTile(leading:const CircleAvatar(backgroundColor:cream,child:Icon(Icons.local_offer,color:forest)),title:Text('${d['title']}'),subtitle:Text('${d['benefit']}\n$cafe • ${d['audience']}'),isThreeLine:true,trailing:IconButton(onPressed:()=>_toggle('${d['id']}'),icon:Icon(saved.contains('${d['id']}')?Icons.bookmark:Icons.bookmark_border,color:forest))));}),
 const SizedBox(height:14),const Text('Kaydedilen fırsatlar',style:TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
 if(saved.isEmpty)const Text('Henüz kaydettiğin fırsat yok.') else ...deals.where((d)=>saved.contains('${d['id']}')).map((d)=>ListTile(leading:const Icon(Icons.bookmark,color:forest),title:Text('${d['title']}'))),
 ]);
 }),
 const LocalModeNote(),
 ]);
}
class ProfilePage extends StatelessWidget{final Map<String,dynamic> user;const ProfilePage({required this.user,super.key});
 Future<void> _logout(BuildContext context)async{await cloud.auth.signOut();final p=await SharedPreferences.getInstance();await p.remove(sessionKey);if(context.mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const GatePage()),(r)=>false);}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('Profil','Hesap bilgilerin ve uygulama ayarları.'),
 Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text('${user['name']}'),subtitle:Text('${user['email']}'))),
 Card(child:ListTile(leading:const Icon(Icons.cloud_done,color:forest),title:Text(user['cloudAccount'] == true ? 'Bulut hesabı' : 'Deneme hesabı'),subtitle:Text(user['cloudAccount'] == true ? 'Hesabın Supabase ile bağlı.' : 'Bu deneme hesabı yalnızca bu cihazda çalışır.'))),
 const SizedBox(height:12),OutlinedButton.icon(onPressed:()=>_logout(context),icon:const Icon(Icons.logout),label:const Text('Çıkış yap')),
 ]);
}

class BusinessShell extends StatefulWidget{final Map<String,dynamic> user;const BusinessShell({required this.user,super.key});@override State<BusinessShell> createState()=>_BusinessShellState();}
class _BusinessShellState extends State<BusinessShell>{
 int tab=0;
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Cafe Dünyam • İşletme')),body:SafeArea(child:IndexedStack(index:tab,children:[
 BusinessDashboard(user:widget.user),
 BusinessDeals(user:widget.user),
 BusinessSettings(user:widget.user),
 ])),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
 NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Panel'),
 NavigationDestination(icon:Icon(Icons.campaign_outlined),label:'Kampanyalar'),
 NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'İşletmem'),
 ]));
}
class BusinessDashboard extends StatelessWidget{
 final Map<String,dynamic> user;const BusinessDashboard({required this.user,super.key});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 Heading('Merhaba, ${user['name']}','İşletme yönetim panelin.'),
 Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:forest,borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Icon(Icons.storefront,color:cream,size:35),const SizedBox(height:12),Text('${user['cafeName']}',style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),Text('${user['city']}',style:const TextStyle(color:Colors.white70)),const SizedBox(height:12),const Text('İşletme bilgileri bulut hesabındaki başvurundan yüklenir.',style:TextStyle(color:Colors.white70)),
 ])),
 Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('NFC tag sipariş özeti',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:forest)),
 const SizedBox(height:8),
 Text('Talep: ${user['tagCount'] ?? 0} adet NFC tag'),
 Text('Paket: ${(user['nfcOrder'] as Map?)?['packagePriceTry'] ?? 0} TL • Kargo: ${(user['nfcOrder'] as Map?)?['shippingTry'] ?? 0} TL'),
 Text('Örnek toplam: ${(user['nfcOrder'] as Map?)?['totalTry'] ?? 0} TL'),
 const SizedBox(height:6), const Text('Durum: Yerel taslak / ödeme bekleniyor',style:TextStyle(fontWeight:FontWeight.bold)),
 const Text('Bu sipariş bize gönderilmedi; IBAN ve fiyatlar demo amaçlıdır.',style:TextStyle(fontSize:12)),
]))),
 const SizedBox(height:16),const Text('Yönetim araçları',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:forest)),
 const Card(child:ListTile(leading:Icon(Icons.campaign,color:forest),title:Text('Kampanya yönetimi'),subtitle:Text('Kampanya oluştur, düzenle ve yayından kaldır.'))),
 const Card(child:ListTile(leading:Icon(Icons.loyalty,color:forest),title:Text('Sadakat programı'),subtitle:Text('Kart ve ödül yapısı sonraki doğrulama adımına hazır taslak olarak ele alınır.'))),
 if (user['approvalStatus'] == 'approved') Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Başvuru onaylandı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: forest)),
    const SizedBox(height: 8),
    const Text('Ödeme yöntemi: IBAN havale / EFT'),
    const Text('Hesap sahibi: CAFE DÜNYAM (ÖRNEK)'),
    const SelectableText('IBAN: TR00 0000 0000 0000 0000 0000 00'),
    const Text('Bu IBAN ve fiyatlar yalnızca test içindir. Gerçek banka bilgisi girilmeden ödeme yapma.'),
    Text('Sipariş toplamı: ${(user['nfcOrder'] as Map?)?['totalTry'] ?? 0} TL (örnek fiyat)'),
  ]))),
  const LocalModeNote(),
 ]);
}
class BusinessDeals extends StatefulWidget {
  final Map<String,dynamic> user;
  const BusinessDeals({required this.user, super.key});
  @override State<BusinessDeals> createState() => _BusinessDealsState();
}
class _BusinessDealsState extends State<BusinessDeals> {
  final title = TextEditingController(), benefit = TextEditingController();
  String audience = 'Herkes';
  bool busy = false;
  @override void dispose() { title.dispose(); benefit.dispose(); super.dispose(); }
  bool _canManage(Map<String,dynamic> d) => widget.user['role'] == 'admin' || d['ownerEmail'] == widget.user['email'];
  Future<void> _add() async {
    if (title.text.trim().isEmpty || benefit.text.trim().isEmpty) return;
    setState(() => busy = true);
    final deals = await LocalData.list(dealsKey, starterDeals);
    deals.insert(0, {'id':'local-${DateTime.now().microsecondsSinceEpoch}','title':title.text.trim(),'benefit':benefit.text.trim(),'audience':audience,'cafeId':widget.user['cafeId'] ?? widget.user['email'],'active':true,'ownerEmail':widget.user['email'],'ownerName':widget.user['cafeName'] ?? widget.user['name']});
    await LocalData.saveList(dealsKey, deals);
    title.clear(); benefit.clear();
    if (mounted) setState(() => busy = false);
  }
  Future<void> _edit(Map<String,dynamic> d) async {
    if (!_canManage(d)) return;
    final editTitle = TextEditingController(text: '${d['title']}');
    final editBenefit = TextEditingController(text: '${d['benefit']}');
    final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Kampanyayı düzenle'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: editTitle, decoration: const InputDecoration(labelText: 'Kampanya başlığı')),
        TextField(controller: editBenefit, decoration: const InputDecoration(labelText: 'İndirim / avantaj')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet'))],
    ));
    if (result == true && editTitle.text.trim().isNotEmpty && editBenefit.text.trim().isNotEmpty) {
      final deals = await LocalData.list(dealsKey, starterDeals);
      final i = deals.indexWhere((x) => x['id'] == d['id']);
      if (i >= 0 && _canManage(deals[i])) {
        deals[i]['title'] = editTitle.text.trim();
        deals[i]['benefit'] = editBenefit.text.trim();
        await LocalData.saveList(dealsKey, deals);
        if (mounted) setState(() {});
      }
    }
    editTitle.dispose(); editBenefit.dispose();
  }
  Future<void> _toggle(Map<String,dynamic> d) async {
    if (!_canManage(d)) return;
    final deals = await LocalData.list(dealsKey, starterDeals);
    final i = deals.indexWhere((x) => x['id'] == d['id']);
    if (i >= 0) { deals[i]['active'] = !(deals[i]['active'] == true); await LocalData.saveList(dealsKey, deals); if (mounted) setState(() {}); }
  }
  Future<void> _delete(String id) async {
    final deals = await LocalData.list(dealsKey, starterDeals);
    final target = deals.where((d) => d['id'] == id).toList();
    if (target.isEmpty || !_canManage(target.first)) return;
    deals.removeWhere((d) => d['id'] == id);
    await LocalData.saveList(dealsKey, deals);
    if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Heading('Kampanyalar', 'Yalnızca kendi kampanyalarını yönetebilirsin.'),
    TextField(controller: title, decoration: const InputDecoration(labelText: 'Kampanya başlığı')),
    const SizedBox(height: 10),
    TextField(controller: benefit, decoration: const InputDecoration(labelText: 'İndirim / avantaj açıklaması')),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(value: audience, decoration: const InputDecoration(labelText: 'Hedef kitle'), items: const [
      DropdownMenuItem(value: 'Herkes', child: Text('Herkes')),
      DropdownMenuItem(value: 'Öğrenci', child: Text('Öğrenci')),
      DropdownMenuItem(value: 'Yeni müşteriler', child: Text('Yeni müşteriler')),
    ], onChanged: (v) => setState(() => audience = v ?? 'Herkes')),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: busy ? null : _add, icon: const Icon(Icons.add), label: Text(busy ? 'Kaydediliyor…' : 'Kampanya oluştur')),
    const SizedBox(height: 16),
    const Text('Yönetebildiğin kampanyalar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
    FutureBuilder<List<Map<String,dynamic>>>(future: LocalData.list(dealsKey, starterDeals), builder: (context, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final visible = s.data!.where((d) => _canManage(d)).toList();
      if (visible.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('Henüz sana ait kampanya yok.'));
      return Column(children: visible.map((d) => Card(child: ListTile(
        title: Text('${d['title']}'),
        subtitle: Text('${d['benefit']}\\nDurum: ${d['active'] == true ? 'Aktif (yerel)' : 'Pasif'}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(d); else if (v == 'toggle') _toggle(d); else _delete('${d['id']}'); }, itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
          PopupMenuItem(value: 'toggle', child: Text('Aktif / pasif değiştir')),
          PopupMenuItem(value: 'delete', child: Text('Sil')),
        ]),
      ))).toList());
    }),
    const LocalModeNote(),
  ]);
}

class BusinessSettings extends StatelessWidget{
 final Map<String,dynamic> user;const BusinessSettings({required this.user,super.key});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('İşletmem','İşletme bilgileri ve yerel ayarlar.'),
 Card(child:ListTile(leading:const Icon(Icons.store,color:forest),title:Text('${user['cafeName']}'),subtitle:Text('${user['city']}'))),
 Card(child:ListTile(leading:const Icon(Icons.email,color:forest),title:Text('${user['email']}'),subtitle:const Text('Hesap e-postası'))),
  Card(child:ListTile(leading:const Icon(Icons.phone,color:forest),title:Text('${user['phone'] ?? 'Telefon girilmedi'}'),subtitle:const Text('İşletme telefonu'))),
  Card(child:ListTile(leading:const Icon(Icons.location_on,color:forest),title:Text('${user['businessAddress'] ?? 'Adres girilmedi'}'),subtitle:Text('${user['district'] ?? ''} / ${user['province'] ?? ''}'))),
 const LocalModeNote(),
 const Text('Önemli: Bu ekranlar test için çalışır. İşletme sahipliği doğrulaması, gerçek satış onayı, sunucu, cihazlar arası eşitleme ve güvenli kullanıcı yetkilendirmesi bu yerel sürümde bulunmaz.'),
 ]);
}

class BusinessReviewPage extends StatelessWidget {
  final Map<String,dynamic> user;
  const BusinessReviewPage({required this.user, super.key});
  Future<void> _logout(BuildContext context) async {
    await cloud.auth.signOut();
    final p = await SharedPreferences.getInstance();
    await p.remove(sessionKey);
    if (context.mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GatePage()), (r) => false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Başvuru durumu'), actions: [IconButton(onPressed: () => _logout(context), icon: const Icon(Icons.logout))]),
    body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
      const SizedBox(height: 24),
      const Icon(Icons.hourglass_top_rounded, size: 72, color: forest),
      const SizedBox(height: 20),
      const Text('Başvurunuz inceleniyor', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: forest)),
      const SizedBox(height: 12),
      const Text('İşletme başvurunuz alındı. Yönetici onayı gelene kadar işletme ana sayfasına geçemezsiniz. Onaydan sonra sipariş ve ödeme talimatları gösterilecektir.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
      const SizedBox(height: 24),
      Card(child: ListTile(leading: const Icon(Icons.storefront, color: forest), title: Text('${user['cafeName'] ?? 'İşletmeniz'}'), subtitle: Text('${user['email']}'))),
      Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined, color: forest), title: const Text('NFC tag siparişi'), subtitle: Text('${user['tagCount'] ?? 0} adet • Onay sonrası ödeme bilgileri'))),
      const SizedBox(height: 12),
      const LocalModeNote(),
    ])),
  );
}
class AdminShell extends StatefulWidget {
  final Map<String,dynamic> user;
  const AdminShell({required this.user, super.key});
  @override State<AdminShell> createState() => _AdminShellState();
}
class _AdminShellState extends State<AdminShell> {
  int tab = 0;
  Future<void> _logout() async {
    await cloud.auth.signOut();
    final p = await SharedPreferences.getInstance(); await p.remove(sessionKey);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const GatePage()), (r) => false);
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(leading: const Padding(padding: EdgeInsets.all(8), child: CafeLogo(size: 38)), title: const Text('Yönetim Merkezi', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(tooltip: 'Çıkış yap', onPressed: _logout, icon: const Icon(Icons.logout))]),
    body: IndexedStack(index: tab, children: const [AdminDashboard(), AdminApplications(), AdminCampaigns(), AdminUsers(), AdminOrders(), AdminSettings()]),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.space_dashboard_rounded), label: 'Özet'),
      NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Başvurular'),
      NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Kampanyalar'),
      NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Kullanıcılar'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Siparişler'),
      NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Ayarlar'),
    ]),
  );
}

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: Future.wait([LocalData.list(usersKey, []), LocalData.list(dealsKey, starterDeals), LocalData.list(businessOrdersKey, [])]),
    builder: (context, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final users = s.data![0] as List<Map<String,dynamic>>;
      final deals = s.data![1] as List<Map<String,dynamic>>;
      final orders = s.data![2] as List<Map<String,dynamic>>;
      final pending = users.where((u) => u['role'] == 'business' && u['approvalStatus'] != 'approved' && u['approvalStatus'] != 'rejected').length;
      final approved = users.where((u) => u['role'] == 'business' && u['approvalStatus'] == 'approved').length;
      final active = deals.where((d) => d['active'] == true).length;
      Widget metric(String label, int value, IconData icon, Color color) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 26), const SizedBox(height: 12), Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 12))]))));
      return ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF211711), Color(0xFF684025)]), borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CafeLogo(size: 54, light: true), SizedBox(height: 16),
          Text('Kontrol sende.', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
          SizedBox(height: 6), Text('Cafe Dünyam işletmelerini, kampanyalarını ve sipariş taleplerini tek merkezden yönet.', style: TextStyle(color: Colors.white70)),
        ])),
        const SizedBox(height: 12),
        Row(children: [metric('Bekleyen başvuru', pending, Icons.pending_actions, brown), const SizedBox(width: 8), metric('Onaylı işletme', approved, Icons.storefront, forest)]),
        Row(children: [metric('Aktif kampanya', active, Icons.campaign, brown), const SizedBox(width: 8), metric('Sipariş talebi', orders.length, Icons.receipt_long, forest)]),
        const SizedBox(height: 12),
        const Heading('Yönetim kısayolları', 'Sık kullanılan işlemlere hızlı erişim.'),
        Card(child: ListTile(leading: const Icon(Icons.fact_check, color: brown), title: const Text('Başvuruları incele'), subtitle: Text('$pending başvuru inceleme bekliyor'), trailing: const Icon(Icons.chevron_right), onTap: () {})),
        Card(child: ListTile(leading: const Icon(Icons.campaign, color: brown), title: const Text('Kampanya denetimi'), subtitle: Text('$active aktif kampanya'), trailing: const Icon(Icons.chevron_right))),
        const LocalModeNote(),
      ]);
    },
  );
}

class AdminUsers extends StatefulWidget { const AdminUsers({super.key}); @override State<AdminUsers> createState()=>_AdminUsersState(); }
class _AdminUsersState extends State<AdminUsers> {
  Future<void> _remove(Map<String,dynamic> u) async {
    final ok = await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: const Text('Kullanıcıyı sil?'), content: Text('${u['email']} hesabı bu cihazdan kaldırılacak.'), actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Sil'))]));
    if (ok != true || u['role'] == 'admin') return;
    if (cloud.auth.currentSession != null && LocalData._uuid(u['id']?.toString())) {
      try {
        await cloud.rpc('admin_delete_user', params: {'target_id': u['id']});
        if (mounted) setState(() {});
      } on PostgrestException catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hesap silinemedi: ${e.message}')));
      }
      return;
    }
    final users = await LocalData.list(usersKey, []);
    users.removeWhere((x) => x['email'] == u['email']);
    await LocalData.saveList(usersKey, users);
    if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:LocalData.list(usersKey, []),builder:(context,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final users=s.data!;
    return ListView(padding:const EdgeInsets.all(18),children:[
      Heading('Kullanıcı yönetimi','Yerel cihazda kayıtlı müşteri ve işletme hesapları.'),
      Card(child:ListTile(leading:const Icon(Icons.people,color:brown),title:Text('${users.length} hesap'),subtitle:const Text('Yönetici hesabı silinemez.'))),
      ...users.map((u)=>Card(child:ListTile(leading:CircleAvatar(backgroundColor:const Color(0xFFF0E1CF),child:Icon(u['role']=='business'?Icons.storefront:u['role']=='admin'?Icons.admin_panel_settings:Icons.person,color:forest)),title:Text('${u['cafeName'] ?? u['name'] ?? 'Kullanıcı'}'),subtitle:Text('${u['email']}\nRol: ${u['role']} • Durum: ${u['approvalStatus'] ?? 'Aktif'}'),isThreeLine:true,trailing:u['role']=='admin'?null:IconButton(tooltip:'Hesabı sil',onPressed:()=>_remove(u),icon:const Icon(Icons.delete_outline,color:Colors.red))))),
      const LocalModeNote(),
    ]);
  });
}

class AdminOrders extends StatefulWidget { const AdminOrders({super.key}); @override State<AdminOrders> createState()=>_AdminOrdersState(); }
class _AdminOrdersState extends State<AdminOrders> {
  Future<void> _setStatus(Map<String,dynamic> order,String status) async {
    final orders=await LocalData.list(businessOrdersKey,[]); final i=orders.indexWhere((o)=>o['id']==order['id']); if(i<0)return;
    orders[i]['orderStatus']=status; await LocalData.saveList(businessOrdersKey,orders); if(mounted)setState((){});
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:LocalData.list(businessOrdersKey,[]),builder:(context,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final orders=s.data!;
    return ListView(padding:const EdgeInsets.all(18),children:[
      Heading('Sipariş ve NFC talepleri','Örnek fiyatlı sipariş kayıtları; ödeme alınmaz.'),
      if(orders.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Henüz sipariş talebi yok.'))),
      ...orders.map((o)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${o['businessName'] ?? 'İşletme'}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
        Text('${o['businessEmail'] ?? ''} • ${o['tagCount'] ?? 0} NFC tag'),
        Text('Toplam: ${o['totalTry'] ?? 0} TL (örnek)'),
        Text('Teslimat: ${o['recipientName'] ?? ''} • ${o['province'] ?? ''} / ${o['district'] ?? ''}'),
        Text('Adres: ${o['address'] ?? ''}'),
        Text('Durum: ${o['orderStatus'] ?? 'İncelemede'}'),
        DropdownButtonFormField<String>(value:['İncelemede','Onaylandı — ödeme bekliyor','Hazırlanıyor','Kargoya verildi','Teslim edildi','Başvuru reddedildi'].contains(o['orderStatus'])?o['orderStatus']:'İncelemede',decoration:const InputDecoration(labelText:'Sipariş durumu'),items:const ['İncelemede','Onaylandı — ödeme bekliyor','Hazırlanıyor','Kargoya verildi','Teslim edildi','Başvuru reddedildi'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)_setStatus(o,v);}),
      ])))),
      const LocalModeNote(),
    ]);
  });
}

class AdminSettings extends StatelessWidget {
  const AdminSettings({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Heading('Yönetim ayarları','Yönetici erişimi ve hizmet yapılandırması.'),
    const Card(child:ListTile(leading:Icon(Icons.shield_outlined,color:forest),title:Text('Yönetici erişimi'),subtitle:Text('Yönetici girişi yalnızca onaylı yönetici rolüne sahip bulut hesabıyla yapılır.'))),
    const Card(child:ListTile(leading:Icon(Icons.payments_outlined,color:brown),title:Text('IBAN / ödeme'),subtitle:Text('Gerçek IBAN tanımlanmadan ödeme bilgisi veya ödeme talebi yayımlanmaz.'))),
    const Card(child:ListTile(leading:Icon(Icons.storage_outlined,color:forest),title:Text('Veri saklama'),subtitle:Text('Oturum açan kullanıcıların bulut verileri Supabase erişim politikalarıyla korunur; yayından önce uçtan uca yetki testleri tamamlanmalıdır.'))),
    const LocalModeNote(),
  ]);
}
class AdminApplications extends StatefulWidget {
  const AdminApplications({super.key});
  @override State<AdminApplications> createState() => _AdminApplicationsState();
}
class _AdminApplicationsState extends State<AdminApplications> {
  Future<void> _setStatus(Map<String,dynamic> target, String status) async {
    final users = await LocalData.list(usersKey, []);
    final i = users.indexWhere((u) => u['email'] == target['email']);
    if (i < 0) return;
    users[i]['approvalStatus'] = status;
    users[i]['applicationStatus'] = status == 'approved' ? 'Onaylandı' : status == 'rejected' ? 'Reddedildi' : 'Başvurunuz inceleniyor';
    await LocalData.saveList(usersKey, users);
    final orders = await LocalData.list(businessOrdersKey, []);
    final oi = orders.indexWhere((o) => o['businessEmail'] == target['email']);
    if (oi >= 0) {
      orders[oi]['orderStatus'] = status == 'approved' ? 'Onaylandı — ödeme bekliyor' : status == 'rejected' ? 'Başvuru reddedildi' : 'İncelemede';
      orders[oi]['paymentStatus'] = status == 'approved' ? 'Ödeme bilgileri gösterilebilir' : 'Ödeme kapalı';
      await LocalData.saveList(businessOrdersKey, orders);
    }
    if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String,dynamic>>>(
    future: LocalData.list(usersKey, []),
    builder: (context, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final pending = s.data!.where((u) => u['role'] == 'business' && u['approvalStatus'] != 'approved' && u['approvalStatus'] != 'rejected').toList();
      final rejected = s.data!.where((u) => u['role'] == 'business' && u['approvalStatus'] == 'rejected').toList();
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Heading('İşletme başvuruları', 'Başvuruları incele ve onayla.'),
        if (pending.isEmpty) const Text('Bekleyen başvuru yok.'),
        ...pending.map((u) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${u['cafeName']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text('${u['name']} • ${u['email']}'),
          Text('${u['phone'] ?? ''} • ${u['province'] ?? ''} / ${u['district'] ?? ''}'),
          Text('${u['businessAddress'] ?? ''}'),
          Text('NFC tag: ${u['tagCount'] ?? 0} adet • Örnek toplam: ${(u['nfcOrder'] as Map?)?['totalTry'] ?? 0} TL'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton(onPressed: () => _setStatus(u, 'approved'), child: const Text('Onayla'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => _setStatus(u, 'rejected'), child: const Text('Reddet'))),
          ]),
        ])))),
        if (rejected.isNotEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Reddedilen başvurular', style: TextStyle(fontWeight: FontWeight.w800))),
        ...rejected.map((u) => ListTile(title: Text('${u['cafeName']}'), subtitle: Text('${u['email']} • Reddedildi'), trailing: TextButton(onPressed: () => _setStatus(u, 'pending'), child: const Text('Yeniden incele')))),
        const LocalModeNote(),
      ]);
    },
  );
}
class AdminCampaigns extends StatefulWidget {
  const AdminCampaigns({super.key});
  @override State<AdminCampaigns> createState() => _AdminCampaignsState();
}
class _AdminCampaignsState extends State<AdminCampaigns> {
  Future<void> _toggle(Map<String,dynamic> d) async {
    final deals = await LocalData.list(dealsKey, starterDeals);
    final i = deals.indexWhere((x) => x['id'] == d['id']);
    if (i >= 0) { deals[i]['active'] = !(deals[i]['active'] == true); await LocalData.saveList(dealsKey, deals); if (mounted) setState(() {}); }
  }
  Future<void> _delete(String id) async {
    final deals = await LocalData.list(dealsKey, starterDeals);
    deals.removeWhere((d) => d['id'] == id);
    await LocalData.saveList(dealsKey, deals);
    if (mounted) setState(() {});
  }
  Future<void> _edit(Map<String,dynamic> d) async {
    final title = TextEditingController(text: '${d['title']}');
    final benefit = TextEditingController(text: '${d['benefit']}');
    final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Kampanyayı düzenle'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Başlık')),
        TextField(controller: benefit, decoration: const InputDecoration(labelText: 'Avantaj')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kaydet'))],
    ));
    if (result == true && title.text.trim().isNotEmpty && benefit.text.trim().isNotEmpty) {
      final deals = await LocalData.list(dealsKey, starterDeals);
      final i = deals.indexWhere((x) => x['id'] == d['id']);
      if (i >= 0) { deals[i]['title'] = title.text.trim(); deals[i]['benefit'] = benefit.text.trim(); await LocalData.saveList(dealsKey, deals); if (mounted) setState(() {}); }
    }
    title.dispose(); benefit.dispose();
  }
  @override Widget build(BuildContext context) => FutureBuilder<List<Map<String,dynamic>>>(
    future: LocalData.list(dealsKey, starterDeals),
    builder: (context, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      return ListView(padding: const EdgeInsets.all(18), children: [
        const Heading('Tüm kampanyalar', 'Yönetici tüm işletmelerin kampanyalarını düzenleyebilir.'),
        ...s.data!.map((d) => Card(child: ListTile(
          title: Text('${d['title']}'),
          subtitle: Text('${d['benefit']} • Sahip: ${d['ownerName'] ?? d['ownerEmail'] ?? d['cafeId'] ?? 'Belirtilmemiş'}'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'toggle') _toggle(d); else if (v == 'edit') _edit(d); else _delete('${d['id']}'); }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Düzenle')),
            PopupMenuItem(value: 'toggle', child: Text('Aktif / pasif')),
            PopupMenuItem(value: 'delete', child: Text('Sil')),
          ]),
        ))),
        const LocalModeNote(),
      ]);
    },
  );
}
