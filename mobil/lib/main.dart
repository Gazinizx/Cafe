import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
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

SupabaseClient? _fallbackCloud;
bool _supabaseInitialized = false;

Future<void> initializeSupabase() async {
  try {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabasePublishableKey);
    _supabaseInitialized = true;
  } catch (error, stackTrace) {
    // Do not let a cloud startup issue prevent the local entry screen.
    debugPrint('Supabase initialization failed; starting in local mode: $error');
    debugPrintStack(stackTrace: stackTrace);
    _fallbackCloud = SupabaseClient(supabaseUrl, supabasePublishableKey);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeSupabase();
  runApp(const CafeDunyamApp());
}

SupabaseClient get cloud {
  if (_supabaseInitialized) return Supabase.instance.client;
  final fallback = _fallbackCloud;
  if (fallback != null) return fallback;
  throw StateError('Supabase has not been initialized. Call initializeSupabase() first.');
}

Future<Map<String, dynamic>> cloudProfile(User authUser) async {
  final row = await cloud.from('profiles').select().eq('id', authUser.id).maybeSingle();
  if (row == null) {
    throw StateError('Hesap profili bulunamadı. Yönetici desteği gerekli.');
  }
  // Authorization comes only from the server-managed profiles row, never user-editable metadata.
  final role = (row['role'] ?? 'customer').toString();
  final user = <String, dynamic>{
    'id': authUser.id,
    'name': (row['full_name'] ?? authUser.email ?? 'Kullanıcı').toString(),
    'email': (row['email'] ?? authUser.email ?? '').toString(),
    'role': role,
    'approvalStatus': (row['approval_status'] ?? 'pending').toString(),
    'cloudAccount': true,
  };
  if (role == 'business') {
    final app = await cloud.from('business_applications').select().eq('business_id', authUser.id).maybeSingle();
    final cafe = await cloud.from('cafes').select('id,name,city').eq('owner_id', authUser.id).order('is_main_branch', ascending: false).order('created_at', ascending: true).limit(1).maybeSingle();
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
  } else if (role == 'customer') {
    final employeeRows = await cloud.from('business_employees')
      .select('business_id,branch_id,display_name')
      .eq('employee_id', authUser.id).eq('is_active', true)
      .order('created_at', ascending: false).limit(1);
    if ((employeeRows as List).isNotEmpty) {
      final employee = Map<String,dynamic>.from(employeeRows.first as Map);
      user['role'] = 'employee';
      user['businessId'] = employee['business_id'];
      user['branchId'] = employee['branch_id'];
      user['employeeName'] = employee['display_name'] ?? user['name'];
    }
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
        final rows = await cloud.from('cafes')
          .select('*, cafe_rewards(stamps_required,reward_title,reward_description,is_active)')
          .order('name');
        return (rows as List).map((raw) {
          final r = Map<String,dynamic>.from(raw as Map);
          final rewardRaw = r['cafe_rewards'];
          final reward = rewardRaw is List
            ? (rewardRaw.isNotEmpty ? Map<String,dynamic>.from(rewardRaw.first as Map) : <String,dynamic>{})
            : rewardRaw is Map ? Map<String,dynamic>.from(rewardRaw) : <String,dynamic>{};
          final rewardActive = reward['is_active'] == true;
          final goal = rewardActive ? (reward['stamps_required'] as num?)?.toInt() ?? 0 : 0;
          return <String,dynamic>{
            'id': r['id'], 'name': r['name'], 'city': r['city'],
            'type': r['category'] ?? 'Kafe', 'goal': goal,
            'reward': rewardActive ? (reward['reward_title'] ?? 'Ödül') : 'Ödül henüz tanımlanmadı',
            'active': r['is_active'] == true,
            'ownerId': r['owner_id'], 'businessId': r['business_id'], 'address': r['address'],
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
        final cafe = await cloud.from('cafes').select('id').eq('owner_id', auth.id).order('is_main_branch', ascending: false).order('created_at', ascending: true).limit(1).maybeSingle();
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
    // Never silently persist a cloud account's data on this device. If a
    // cloud-backed write was not handled above (for example, a business has
    // no linked cafe yet), fail visibly instead of creating an iOS-only or
    // Android-only copy in SharedPreferences.
    if (_cloudReady) {
      throw StateError('Bulut eşitlemesi yapılamadı ($key). Hesap ve işletme bağlantısını kontrol et.');
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
        // If the cloud profile cannot be loaded, keep the entry screen available.
      }
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
    } else if (user['role'] == 'employee') {
      page = EmployeeShell(user: user);
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
  static const int tagCount = 1;
  bool busy = false, hide = true;
  static const int packagePrice = 0;
  static const int shippingPrice = 0;
  int get orderTotal => packagePrice + shippingPrice;

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
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) {
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
              'package_price_try': '$packagePrice',
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
            'packagePriceTry': packagePrice, 'shippingTry': shippingPrice,
            'totalTry': orderTotal, 'paymentMethod': 'Nakit / banka havalesi (yönetici onaylı)',
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
          sectionTitle('NFC etiketi'),
          const Card(child: Padding(padding: EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Her işletmeye tek NFC etiketi tanımlanır.', style: TextStyle(fontWeight: FontWeight.w800, color: forest)),
            SizedBox(height: 6),
            Text('Kasiyer etiketi müşteriye verir. Müşteri telefonuyla okutur ve etiketi kasiyere geri verir. Aynı müşteri aynı şubede 10 dakika içinde yeniden damga alamaz.'),
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
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFE8DCC7), borderRadius: BorderRadius.circular(14)), child: const Text('Çevrim içi ödeme alınmaz. İşletme başvurusu onaylandıktan sonra nakit veya banka havalesiyle tahsilat yönetici tarafından doğrulanır.')),
          const SizedBox(height: 10),
          const Text('Başvuru ve sipariş bilgilerin kayıt sırasında hesabına bağlı bulut sistemine gönderilir. Onaylanana kadar işletme özellikleri kısıtlıdır.'),
        ] else ...[
          sectionTitle('Müşteri bilgileri'),
        ],
      ] else ...[
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? 'Geçerli e-posta adresini yaz.' : null),
        const SizedBox(height: 12),
        TextFormField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Parola', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off))), validator: (v) => v == null || v.isEmpty ? 'Parolanı yaz.' : null),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: busy ? null : _resetPassword, child: const Text('Parolamı unuttum'))),
      ],
      const SizedBox(height: 22),
      FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'İşleniyor…' : widget.register ? (role == 'business' ? 'İşletme kaydını oluştur' : 'Müşteri hesabını oluştur') : 'Giriş yap')),
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
 bool _scanning = false;

 Uri? _readSecureTagUri(NdefRecord record) {
   if (String.fromCharCodes(record.type) != 'U' || record.payload.isEmpty) return null;
   const prefixes = <int, String>{
     0x00: '', 0x01: 'http://www.', 0x02: 'https://www.',
     0x03: 'http://', 0x04: 'https://',
   };
   final prefix = prefixes[record.payload.first];
   if (prefix == null || !prefix.startsWith('https://')) return null;
   try {
     final suffix = utf8.decode(record.payload.sublist(1), allowMalformed: false);
     final uri = Uri.tryParse('$prefix$suffix');
     return uri != null && uri.scheme == 'https' ? uri : null;
   } catch (_) {
     return null;
   }
 }

 void _message(String value) {
   if (!mounted) return;
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
 }

 Future<void> _scanNfc() async {
   if (cloud.auth.currentUser == null) {
     _message('NFC damgası almak için müşteri hesabınla giriş yapmalısın.');
     return;
   }
   try {
     final available = await NfcManager.instance.isAvailable();
     if (!available) {
       _message('Bu telefonda NFC bulunmuyor veya NFC kapalı.');
       return;
     }
     setState(() => _scanning = true);
     var handled = false;
     await NfcManager.instance.startSession(
       onDiscovered: (NfcTag tag) async {
         if (handled) return;
         handled = true;
         try {
           final ndef = Ndef.from(tag);
           if (ndef == null) throw Exception('Bu etiket NDEF desteklemiyor.');
           final message = ndef.cachedMessage;
           if (message == null) throw Exception('Etiketten güvenli bağlantı okunamadı.');
           Uri? secureUri;
           for (final record in message.records) {
             secureUri = _readSecureTagUri(record);
             if (secureUri != null) break;
           }
           if (secureUri == null) throw Exception('Bu, kayıtlı Cafe Dünyam güvenli NFC etiketi değil.');
           await NfcManager.instance.stopSession();
           final response = await cloud.functions.invoke(
             'verify-nfc-stamp',
             body: {'url': secureUri.toString()},
           );
           final data = response.data;
           if (response.status != 200 || data is! Map) {
             throw Exception('NFC doğrulaması tamamlanamadı.');
           }
           if (data['success'] == true) {
             _message('Damgan eklendi. Toplam damgan: ${data['stamps'] ?? 0}');
           } else {
             _message((data['message'] ?? data['error'] ?? 'Bu NFC okutması kabul edilmedi.').toString());
           }
           if (mounted) setState(() {});
         } catch (error) {
           try { await NfcManager.instance.stopSession(errorMessage: 'NFC işlemi tamamlanamadı.'); } catch (_) {}
           _message(error.toString().replaceFirst('Exception: ', ''));
         } finally {
           if (mounted) setState(() => _scanning = false);
         }
       },
       onError: (error) {
         if (mounted) setState(() => _scanning = false);
         _message('NFC oturumu tamamlanamadı. Tekrar dene.');
       },
     );
   } catch (error) {
     try { await NfcManager.instance.stopSession(); } catch (_) {}
     if (mounted) setState(() => _scanning = false);
     _message('NFC başlatılamadı. Telefon ayarlarını kontrol et.');
   }
 }

 Future<void> _claimReward(String cafeId) async {
   try {
     final response = await cloud.functions.invoke('claim-cafe-reward', body: {'cafeId': cafeId});
     final data = response.data;
     if (response.status == 200 && data is Map && data['success'] == true) {
       final claimId = (data['claimId'] ?? '').toString();
       final shortCode = claimId.length >= 8 ? claimId.substring(0, 8).toUpperCase() : claimId;
       _message('Ödül talebin oluşturuldu. Kasiyere kodunu göster: $shortCode');
       if (mounted) setState(() {});
     } else {
       _message(data is Map ? (data['error'] ?? 'Ödül talebi oluşturulamadı.').toString() : 'Ödül talebi oluşturulamadı.');
     }
   } catch (error) {
     _message('Ödül talebi gönderilemedi: $error');
   }
 }

 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('Kartlarım','Her kafenin damga kartı ayrıdır.'),
 FilledButton.icon(
   onPressed: _scanning ? null : _scanNfc,
   icon: const Icon(Icons.nfc),
   label: Text(_scanning ? 'Etiketi okut...' : 'NFC ile damga kazan'),
 ),
 const Padding(
   padding: EdgeInsets.only(top: 8, bottom: 12),
   child: Text('Kasiyerden tek NFC etiketini al, telefonunun NFC alanına yaklaştır ve işlem bitince etiketi geri ver.'),
 ),
 FutureBuilder<List<Object>>(future:Future.wait([LocalData.list(cafesKey,starterCafes),LocalData.stamps()]),builder:(context,s){
 if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final cafes=s.data![0] as List<Map<String,dynamic>>;final stamps=s.data![1] as Map<String,int>;
 return Column(children:cafes.map((c){
 final count=stamps[c['id']]??0;final goal=(c['goal'] as num?)?.toInt()??0;
 return Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 Text('${c['name']}',style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),const SizedBox(height:10),
 LinearProgressIndicator(value:goal > 0 ? (count/goal).clamp(0.0,1.0) : 0.0,minHeight:8),
 const SizedBox(height:8),Text(goal > 0 ? '$count / $goal damga • ${c['reward']}' : c['reward'].toString()),
 if (goal > 0 && count >= goal) Padding(padding: const EdgeInsets.only(top: 10), child: FilledButton.icon(onPressed: () => _claimReward(c['id'].toString()), icon: const Icon(Icons.card_giftcard), label: const Text('Ödülü kullan'))),
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
 BusinessRewardSettings(user:widget.user),
 BusinessBilling(user:widget.user),
 BusinessSettings(user:widget.user),
 ])),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
 NavigationDestination(icon:Icon(Icons.dashboard_outlined),label:'Panel'),
 NavigationDestination(icon:Icon(Icons.campaign_outlined),label:'Kampanyalar'),
 NavigationDestination(icon:Icon(Icons.card_giftcard_outlined),label:'Ödül'),
 NavigationDestination(icon:Icon(Icons.payments_outlined),label:'Paket'),
 NavigationDestination(icon:Icon(Icons.storefront_outlined),label:'İşletmem'),
 ]));
}

class BusinessRewardSettings extends StatefulWidget {
  final Map<String,dynamic> user;
  const BusinessRewardSettings({required this.user, super.key});
  @override State<BusinessRewardSettings> createState() => _BusinessRewardSettingsState();
}
class _BusinessRewardSettingsState extends State<BusinessRewardSettings> {
  final _goal = TextEditingController(text: '8');
  final _title = TextEditingController();
  final _description = TextEditingController();
  bool _loading = true, _saving = false, _active = true;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _goal.dispose(); _title.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final cafeId = widget.user['cafeId']?.toString();
      if (cafeId == null) throw StateError('İşletme şubesi bulunamadı.');
      final row = await cloud.from('cafe_rewards').select().eq('cafe_id', cafeId).maybeSingle();
      if (row != null) {
        _goal.text = (row['stamps_required'] ?? 8).toString();
        _title.text = (row['reward_title'] ?? '').toString();
        _description.text = (row['reward_description'] ?? '').toString();
        _active = row['is_active'] == true;
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ödül ayarları yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final cafeId = widget.user['cafeId']?.toString();
    final goal = int.tryParse(_goal.text.trim());
    if (cafeId == null || goal == null || goal < 1 || goal > 100 || _title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('1–100 arasında damga sayısı ve ödül adı gir.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await cloud.from('cafe_rewards').upsert({
        'cafe_id': cafeId,
        'stamps_required': goal,
        'reward_title': _title.text.trim(),
        'reward_description': _description.text.trim(),
        'is_active': _active,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sadakat ödülü kaydedildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ödül kaydedilemedi: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<List<Map<String,dynamic>>> _pendingClaims() async {
    final cafeId = widget.user['cafeId']?.toString();
    if (cafeId == null) return [];
    final rows = await cloud.from('reward_claims')
      .select('id,stamps_spent,reward_snapshot,created_at')
      .eq('cafe_id', cafeId).eq('status', 'issued')
      .order('created_at', ascending: false);
    return (rows as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
  }

  Future<void> _redeem(String claimId) async {
    try {
      final response = await cloud.functions.invoke('redeem-cafe-reward', body: {'claimId': claimId});
      final data = response.data;
      if (response.status == 200 && data is Map && data['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödül teslim edildi olarak işaretlendi.')));
        if (mounted) setState(() {});
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data is Map ? (data['error'] ?? 'Ödül teslim edilemedi.').toString() : 'Ödül teslim edilemedi.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ödül teslim edilemedi: $error')));
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Heading('Sadakat ödülü', 'Müşterinin kaç damgada hangi ödülü kazanacağını belirle.'),
      TextField(controller: _goal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gerekli damga sayısı (1–100)')),
      const SizedBox(height: 12),
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Ödül adı', hintText: 'Örn. Ücretsiz kahve')),
      const SizedBox(height: 12),
      TextField(controller: _description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Ödül açıklaması')),
      const SizedBox(height: 12),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ödül programı aktif'),
        value: _active,
        onChanged: (value) => setState(() => _active = value),
      ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Kaydediliyor…' : 'Ödül ayarlarını kaydet'),
      ),
      const SizedBox(height: 24),
      const Text('Bekleyen ödül talepleri', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: forest)),
      FutureBuilder<List<Map<String,dynamic>>>(
        future: _pendingClaims(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          if (snapshot.hasError) return const Text('Ödül talepleri yüklenemedi.');
          final claims = snapshot.data ?? [];
          if (claims.isEmpty) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('Bekleyen ödül talebi yok.'));
          return Column(children: claims.map((claim) {
            final id = claim['id'].toString();
            final code = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;
            final reward = claim['reward_snapshot'] is Map ? Map<String,dynamic>.from(claim['reward_snapshot'] as Map) : <String,dynamic>{};
            return Card(child: ListTile(
              title: Text((reward['title'] ?? 'Ödül talebi').toString()),
              subtitle: Text('Kod: $code • ${claim['stamps_spent'] ?? 0} damga'),
              trailing: TextButton(onPressed: () => _redeem(id), child: const Text('Teslim edildi')),
            ));
          }).toList());
        },
      ),
    ]);
  }
}
class BusinessBilling extends StatefulWidget {
  final Map<String,dynamic> user;
  const BusinessBilling({required this.user, super.key});
  @override State<BusinessBilling> createState() => _BusinessBillingState();
}
class _BusinessBillingState extends State<BusinessBilling> {
  List<Map<String,dynamic>> _packages = [];
  List<Map<String,dynamic>> _payments = [];
  List<Map<String,dynamic>> _subscriptions = [];
  String? _selectedPackage;
  String _method = 'cash';
  bool _loading = true, _requesting = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final packageRows = await cloud.from('subscription_packages').select().eq('is_active', true).order('price_try');
      final paymentRows = await cloud.from('manual_payments').select('*, subscription_packages(name,billing_period)')
        .eq('business_id', widget.user['id']).order('created_at', ascending: false);
      final subscriptionRows = await cloud.from('business_subscriptions').select('*, subscription_packages(name,billing_period)')
        .eq('business_id', widget.user['id']).order('created_at', ascending: false);
      _packages = (packageRows as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
      _payments = (paymentRows as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
      _subscriptions = (subscriptionRows as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
      if (_selectedPackage == null || !_packages.any((p) => p['id'].toString() == _selectedPackage)) {
        _selectedPackage = _packages.isEmpty ? null : _packages.first['id'].toString();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paket bilgileri yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _period(Map<String,dynamic> row) => row['billing_period'] == 'yearly' ? 'yıllık' : 'aylık';
  String _paymentStatus(String? status) => switch (status) {
    'confirmed' => 'Tahsilat onaylandı',
    'rejected' => 'Reddedildi',
    _ => 'Onay bekliyor',
  };

  Future<void> _requestPayment() async {
    final packageRows = _packages.where((p) => p['id'].toString() == _selectedPackage).toList();
    if (packageRows.isEmpty) return;
    final package = packageRows.first;
    setState(() => _requesting = true);
    try {
      await cloud.from('manual_payments').insert({
        'business_id': widget.user['id'],
        'package_id': package['id'],
        'amount_try': (package['price_try'] as num).toDouble(),
        'payment_method': _method,
        'status': 'pending',
      });
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tahsilat talebin yöneticiye iletildi. Ödeme onaylanınca paket etkinleşir.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tahsilat talebi oluşturulamadı: $error')));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Heading('Paket ve ödeme', 'Paket seç; ödemeyi nakit veya banka havalesiyle yap.'),
      if (_packages.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Henüz satışa açık paket bulunmuyor. Cafe Dünyam yöneticisi paket eklediğinde burada görünecek.'))),
      if (_packages.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          value: _selectedPackage,
          decoration: const InputDecoration(labelText: 'Abonelik paketi'),
          items: _packages.map((p) => DropdownMenuItem(
            value: p['id'].toString(),
            child: Text('${p['name']} • ${(p['price_try'] as num).toStringAsFixed(2)} TL / ${_period(p)}'),
          )).toList(),
          onChanged: (value) => setState(() => _selectedPackage = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _method,
          decoration: const InputDecoration(labelText: 'Ödeme yöntemi'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Nakit')),
            DropdownMenuItem(value: 'bank_transfer', child: Text('Banka havalesi')),
          ],
          onChanged: (value) => setState(() => _method = value ?? 'cash'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _requesting ? null : _requestPayment,
          icon: const Icon(Icons.receipt_long),
          label: Text(_requesting ? 'Gönderiliyor…' : 'Tahsilat talebi oluştur'),
        ),
      ],
      const SizedBox(height: 24),
      const Text('Aboneliklerim', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: forest)),
      if (_subscriptions.isEmpty) const Text('Henüz etkin aboneliğin yok.'),
      ..._subscriptions.map((s) {
        final package = s['subscription_packages'] is Map ? Map<String,dynamic>.from(s['subscription_packages'] as Map) : <String,dynamic>{};
        return Card(child: ListTile(
          title: Text((package['name'] ?? 'Abonelik').toString()),
          subtitle: Text('Durum: ${s['status']} • Bitiş: ${s['ends_at'] ?? 'Belirtilmedi'}'),
        ));
      }),
      const SizedBox(height: 20),
      const Text('Tahsilat geçmişi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: forest)),
      if (_payments.isEmpty) const Text('Henüz tahsilat talebin yok.'),
      ..._payments.map((p) {
        final package = p['subscription_packages'] is Map ? Map<String,dynamic>.from(p['subscription_packages'] as Map) : <String,dynamic>{};
        return Card(child: ListTile(
          leading: const Icon(Icons.payments_outlined, color: forest),
          title: Text('${package['name'] ?? 'Paket'} • ${(p['amount_try'] as num).toStringAsFixed(2)} TL'),
          subtitle: Text('${p['payment_method'] == 'cash' ? 'Nakit' : 'Banka havalesi'} • ${_paymentStatus(p['status']?.toString())}'),
        ));
      }),
      const Padding(padding: EdgeInsets.only(top: 12), child: Text('Çevrim içi kart tahsilatı şu aşamada kapalıdır. Paket, yönetici nakit veya havale tahsilatını onayladıktan sonra etkinleşir.')),
    ]);
  }
}

class BusinessDashboard extends StatelessWidget{
 final Map<String,dynamic> user;const BusinessDashboard({required this.user,super.key});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 Heading('Merhaba, ${user['name']}','İşletme yönetim panelin.'),
 Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:forest,borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Icon(Icons.storefront,color:cream,size:35),const SizedBox(height:12),Text('${user['cafeName']}',style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),Text('${user['city']}',style:const TextStyle(color:Colors.white70)),const SizedBox(height:12),const Text('İşletme bilgileri bulut hesabındaki başvurundan yüklenir.',style:TextStyle(color:Colors.white70)),
 ])),
 Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
 const Text('NFC etiketi',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900,color:forest)),
 const SizedBox(height:8),
 const Text('İşletme başına tek NFC etiketi tanımlanır.'),
 const SizedBox(height:6),
 const Text('Kasiyer etiketi müşteriye verir; müşteri okuttuktan sonra etiketi geri alır.'),
 const Text('Etiket kaydı ve etkinleştirme yönetici tarafından yapılır.',style:TextStyle(fontSize:12)),
]))),
 const SizedBox(height:16),const Text('Yönetim araçları',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:forest)),
 const Card(child:ListTile(leading:Icon(Icons.campaign,color:forest),title:Text('Kampanya yönetimi'),subtitle:Text('Kampanya oluştur, düzenle ve yayından kaldır.'))),
 const Card(child:ListTile(leading:Icon(Icons.loyalty,color:forest),title:Text('Sadakat programı'),subtitle:Text('Kart ve ödül yapısı sonraki doğrulama adımına hazır taslak olarak ele alınır.'))),
 if (user['approvalStatus'] == 'approved') const Card(child: Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Başvuru onaylandı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: forest)),
    SizedBox(height: 8),
    Text('Ödemeler şu aşamada nakit veya banka havalesiyle alınır.'),
    Text('Tahsilat, Cafe Dünyam yöneticisi tarafından doğrulanınca hesabına işlenir.'),
    Text('Uygulamada çevrim içi kart ödemesi alınmaz; doğrulanmamış IBAN veya ödeme bağlantısı gösterilmez.'),
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
  void _reportSyncError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Buluta kaydedilemedi: $error')),
    );
  }
  Future<void> _add() async {
    if (title.text.trim().isEmpty || benefit.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final deals = await LocalData.list(dealsKey, starterDeals);
      deals.insert(0, {'id':'local-${DateTime.now().microsecondsSinceEpoch}','title':title.text.trim(),'benefit':benefit.text.trim(),'audience':audience,'cafeId':widget.user['cafeId'] ?? widget.user['email'],'active':true,'ownerEmail':widget.user['email'],'ownerName':widget.user['cafeName'] ?? widget.user['name']});
      await LocalData.saveList(dealsKey, deals);
      title.clear(); benefit.clear();
      if (mounted) setState(() {});
    } catch (error) {
      _reportSyncError(error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
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
    try {
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
    } catch (error) {
      _reportSyncError(error);
    } finally {
      editTitle.dispose();
      editBenefit.dispose();
    }
  }
  Future<void> _toggle(Map<String,dynamic> d) async {
    if (!_canManage(d)) return;
    try {
      final deals = await LocalData.list(dealsKey, starterDeals);
      final i = deals.indexWhere((x) => x['id'] == d['id']);
      if (i >= 0) {
        deals[i]['active'] = !(deals[i]['active'] == true);
        await LocalData.saveList(dealsKey, deals);
        if (mounted) setState(() {});
      }
    } catch (error) {
      _reportSyncError(error);
    }
  }
  Future<void> _delete(String id) async {
    try {
      final deals = await LocalData.list(dealsKey, starterDeals);
      final target = deals.where((d) => d['id'] == id).toList();
      if (target.isEmpty || !_canManage(target.first)) return;
      deals.removeWhere((d) => d['id'] == id);
      await LocalData.saveList(dealsKey, deals);
      if (mounted) setState(() {});
    } catch (error) {
      _reportSyncError(error);
    }
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

class BusinessSettings extends StatefulWidget {
  final Map<String,dynamic> user;
  const BusinessSettings({required this.user, super.key});
  @override State<BusinessSettings> createState() => _BusinessSettingsState();
}
class _BusinessSettingsState extends State<BusinessSettings> {
  final _branchName = TextEditingController();
  final _branchCity = TextEditingController();
  final _branchDistrict = TextEditingController();
  final _branchAddress = TextEditingController();
  final _employeeEmail = TextEditingController();
  List<Map<String,dynamic>> _branches = [];
  List<Map<String,dynamic>> _employees = [];
  String? _selectedBranchId;
  bool _loading = true, _savingBranch = false, _savingEmployee = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    _branchName.dispose(); _branchCity.dispose(); _branchDistrict.dispose();
    _branchAddress.dispose(); _employeeEmail.dispose(); super.dispose();
  }

  Future<void> _load() async {
    try {
      final businessId = widget.user['id'].toString();
      final branches = await cloud.from('cafes').select().eq('business_id', businessId)
        .order('is_main_branch', ascending: false).order('created_at', ascending: true);
      final employees = await cloud.from('business_employees').select()
        .eq('business_id', businessId).order('created_at', ascending: false);
      _branches = (branches as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
      _employees = (employees as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
      if (_selectedBranchId == null || !_branches.any((b) => b['id'].toString() == _selectedBranchId)) {
        _selectedBranchId = _branches.isEmpty ? null : _branches.first['id'].toString();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Şube ve çalışan bilgileri yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBranch() async {
    if (_branchName.text.trim().isEmpty || _branchCity.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şube adı ve şehir gerekli.')));
      return;
    }
    setState(() => _savingBranch = true);
    try {
      await cloud.from('cafes').insert({
        'owner_id': widget.user['id'],
        'business_id': widget.user['id'],
        'name': _branchName.text.trim(),
        'city': _branchCity.text.trim(),
        'district': _branchDistrict.text.trim(),
        'address': _branchAddress.text.trim(),
        'category': widget.user['businessType'] ?? 'Kafe',
        'is_active': true,
        'is_main_branch': false,
      });
      _branchName.clear(); _branchCity.clear(); _branchDistrict.clear(); _branchAddress.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeni şube eklendi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Şube eklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _savingBranch = false);
    }
  }

  Future<void> _addEmployee() async {
    final email = _employeeEmail.text.trim();
    if (email.isEmpty || _selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan e-postası ve şube seçmelisin.')));
      return;
    }
    setState(() => _savingEmployee = true);
    try {
      final response = await cloud.functions.invoke('find-business-employee', body: {'email': email});
      final data = response.data;
      if (response.status != 200 || data is! Map || data['employeeId'] == null) {
        throw StateError(data is Map ? (data['error'] ?? 'Çalışan bulunamadı.').toString() : 'Çalışan bulunamadı.');
      }
      await cloud.from('business_employees').insert({
        'business_id': widget.user['id'],
        'employee_id': data['employeeId'],
        'branch_id': _selectedBranchId,
        'display_name': data['displayName'] ?? email,
        'is_active': true,
      });
      _employeeEmail.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çalışan eklendi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Çalışan eklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _savingEmployee = false);
    }
  }

  Future<void> _deactivateEmployee(String id) async {
    try {
      await cloud.from('business_employees').update({'is_active': false}).eq('id', id);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Çalışan kaldırılamadı: $error')));
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Heading('İşletmem', 'İşletme bilgileri, şubeler ve çalışanlar.'),
      Card(child: ListTile(leading: const Icon(Icons.store, color: forest), title: Text('${widget.user['cafeName']}'), subtitle: Text('${widget.user['city']}'))),
      Card(child: ListTile(leading: const Icon(Icons.email, color: forest), title: Text('${widget.user['email']}'), subtitle: const Text('Hesap e-postası'))),
      Card(child: ListTile(leading: const Icon(Icons.phone, color: forest), title: Text('${widget.user['phone'] ?? 'Telefon girilmedi'}'), subtitle: const Text('İşletme telefonu'))),
      Card(child: ListTile(leading: const Icon(Icons.location_on, color: forest), title: Text('${widget.user['businessAddress'] ?? 'Adres girilmedi'}'), subtitle: Text('${widget.user['district'] ?? ''} / ${widget.user['province'] ?? ''}'))),
      const SizedBox(height: 20),
      const Text('Şube yönetimi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: forest)),
      ..._branches.map((branch) => Card(child: ListTile(
        leading: Icon(branch['is_main_branch'] == true ? Icons.home_work : Icons.storefront, color: forest),
        title: Text(branch['name'].toString()),
        subtitle: Text('${branch['city'] ?? ''} • ${branch['is_active'] == true ? 'Aktif' : 'Pasif'}${branch['is_main_branch'] == true ? ' • Ana şube' : ''}'),
      ))),
      const SizedBox(height: 8),
      TextField(controller: _branchName, decoration: const InputDecoration(labelText: 'Yeni şube adı')),
      const SizedBox(height: 8),
      TextField(controller: _branchCity, decoration: const InputDecoration(labelText: 'Şehir')),
      const SizedBox(height: 8),
      TextField(controller: _branchDistrict, decoration: const InputDecoration(labelText: 'İlçe')),
      const SizedBox(height: 8),
      TextField(controller: _branchAddress, decoration: const InputDecoration(labelText: 'Adres')),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _savingBranch ? null : _addBranch, icon: const Icon(Icons.add_business), label: Text(_savingBranch ? 'Ekleniyor…' : 'Şube ekle')),
      const SizedBox(height: 24),
      const Text('Çalışan yönetimi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: forest)),
      if (_branches.isNotEmpty) DropdownButtonFormField<String>(
        value: _selectedBranchId,
        decoration: const InputDecoration(labelText: 'Çalışanın bağlı olacağı şube'),
        items: _branches.map((b) => DropdownMenuItem(value: b['id'].toString(), child: Text(b['name'].toString()))).toList(),
        onChanged: (value) => setState(() => _selectedBranchId = value),
      ),
      const SizedBox(height: 8),
      TextField(controller: _employeeEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Çalışan hesap e-postası')),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _savingEmployee || _branches.isEmpty ? null : _addEmployee, icon: const Icon(Icons.person_add_alt_1), label: Text(_savingEmployee ? 'Ekleniyor…' : 'Çalışan ekle')),
      const Text('Çalışan önce Cafe Dünyam müşteri hesabı oluşturmalıdır. Şube ve çalışan limitleri seçili abonelik paketine göre uygulanır.', style: TextStyle(fontSize: 12)),
      ..._employees.where((e) => e['is_active'] == true).map((employee) {
        final branch = _branches.where((b) => b['id'] == employee['branch_id']).toList();
        return Card(child: ListTile(
          leading: const Icon(Icons.person_outline, color: forest),
          title: Text((employee['display_name'] ?? 'Çalışan').toString()),
          subtitle: Text(branch.isEmpty ? 'Tüm şubeler' : branch.first['name'].toString()),
          trailing: IconButton(tooltip: 'Çalışanı kaldır', onPressed: () => _deactivateEmployee(employee['id'].toString()), icon: const Icon(Icons.person_remove_alt_1)),
        ));
      }),
      const LocalModeNote(),
    ]);
  }
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
      const Text('İşletme başvurunuz alındı. Yönetici onayı gelene kadar işletme ana sayfasına geçemezsiniz. Onaydan sonra işletme başına tek NFC etiketi atanır; tahsilat nakit veya banka havalesiyle yapılır.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
      const SizedBox(height: 24),
      Card(child: ListTile(leading: const Icon(Icons.storefront, color: forest), title: Text('${user['cafeName'] ?? 'İşletmeniz'}'), subtitle: Text('${user['email']}'))),
      Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined, color: forest), title: const Text('NFC etiketi'), subtitle: const Text('İşletme başına tek etiket • Yönetici onayı sonrası etkinleştirilir'))),
      const SizedBox(height: 12),
      const LocalModeNote(),
    ])),
  );
}
class EmployeeShell extends StatefulWidget {
  final Map<String,dynamic> user;
  const EmployeeShell({required this.user, super.key});
  @override State<EmployeeShell> createState() => _EmployeeShellState();
}
class _EmployeeShellState extends State<EmployeeShell> {
  bool _loading = true;
  List<Map<String,dynamic>> _claims = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final businessId = widget.user['businessId']?.toString();
      final branchId = widget.user['branchId']?.toString();
      if (businessId == null) throw StateError('Çalışan işletmesi bulunamadı.');
      final branches = await cloud.from('cafes').select('id').eq('business_id', businessId).eq('is_active', true);
      final branchIds = (branches as List).map((r) => r['id'].toString()).toList();
      if (branchIds.isEmpty) {
        _claims = [];
      } else {
        var query = cloud.from('reward_claims')
          .select('id,cafe_id,stamps_spent,reward_snapshot,created_at,cafes(name)')
          .eq('status', 'issued');
        final rows = branchId != null
          ? await query.eq('cafe_id', branchId).order('created_at', ascending: false)
          : await query.inFilter('cafe_id', branchIds).order('created_at', ascending: false);
        _claims = (rows as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ödül talepleri yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _redeem(String claimId) async {
    try {
      final response = await cloud.functions.invoke('redeem-cafe-reward', body: {'claimId': claimId});
      final data = response.data;
      if (response.status == 200 && data is Map && data['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödül teslim edildi olarak işaretlendi.')));
        await _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data is Map ? (data['error'] ?? 'Ödül teslim edilemedi.').toString() : 'Ödül teslim edilemedi.')));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ödül teslim edilemedi: $error')));
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Cafe Dünyam • Çalışan')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Heading('Merhaba, ${widget.user['employeeName'] ?? widget.user['name']}', 'Bekleyen ödül taleplerini doğrula ve teslim et.'),
        if (_claims.isEmpty) const Text('Bekleyen ödül talebi yok.'),
        ..._claims.map((claim) {
          final id = claim['id'].toString();
          final code = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id;
          final reward = claim['reward_snapshot'] is Map ? Map<String,dynamic>.from(claim['reward_snapshot'] as Map) : <String,dynamic>{};
          final cafe = claim['cafes'] is Map ? Map<String,dynamic>.from(claim['cafes'] as Map) : <String,dynamic>{};
          return Card(child: ListTile(
            title: Text((reward['title'] ?? 'Ödül').toString()),
            subtitle: Text('${cafe['name'] ?? 'Şube'} • Kod: $code • ${claim['stamps_spent']} damga'),
            trailing: IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'Teslim edildi', onPressed: () => _redeem(id)),
          ));
        }),
      ]),
    );
  }
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
    body: IndexedStack(index: tab, children: const [AdminDashboard(), AdminApplications(), AdminCampaigns(), AdminUsers(), AdminOrders(), AdminBilling(), AdminSettings()]),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.space_dashboard_rounded), label: 'Özet'),
      NavigationDestination(icon: Icon(Icons.fact_check_outlined), label: 'Başvurular'),
      NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Kampanyalar'),
      NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Kullanıcılar'),
      NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Siparişler'),
      NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Paket & ödeme'),
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
  Future<void> _updateOrder(Map<String,dynamic> order, String key, String value) async {
    final orders = await LocalData.list(businessOrdersKey, []);
    final i = orders.indexWhere((o) => o['id'] == order['id']);
    if (i < 0) return;
    orders[i][key] = value;
    await LocalData.saveList(businessOrdersKey, orders);
    if (mounted) setState(() {});
  }
  @override Widget build(BuildContext context)=>FutureBuilder<List<Map<String,dynamic>>>(future:LocalData.list(businessOrdersKey,[]),builder:(context,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final orders=s.data!;
    return ListView(padding:const EdgeInsets.all(18),children:[
      Heading('Sipariş ve NFC talepleri','Örnek fiyatlı sipariş kayıtları; ödeme alınmaz.'),
      if(orders.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(18),child:Text('Henüz sipariş talebi yok.'))),
      ...orders.map((o)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${o['businessName'] ?? 'İşletme'}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
        Text('${o['businessEmail'] ?? ''} • İşletme başına tek NFC etiketi'),
        Text('Teslimat: ${o['recipientName'] ?? ''} • ${o['province'] ?? ''} / ${o['district'] ?? ''}'),
        Text('Adres: ${o['address'] ?? ''}'),
        Text('Ödeme yöntemi: ${o['paymentMethod'] ?? 'Belirtilmedi'}'),
        DropdownButtonFormField<String>(
          value: ['cash', 'bank_transfer'].contains(o['paymentMethod']) ? o['paymentMethod'] : 'cash',
          decoration: const InputDecoration(labelText: 'Tahsilat yöntemi'),
          items: const [
            DropdownMenuItem(value: 'cash', child: Text('Nakit')),
            DropdownMenuItem(value: 'bank_transfer', child: Text('Banka havalesi')),
          ],
          onChanged: (v) { if (v != null) _updateOrder(o, 'paymentMethod', v); },
        ),
        DropdownButtonFormField<String>(
          value: ['pending', 'confirmed', 'rejected'].contains(o['paymentStatus']) ? o['paymentStatus'] : 'pending',
          decoration: const InputDecoration(labelText: 'Tahsilat durumu'),
          items: const [
            DropdownMenuItem(value: 'pending', child: Text('Ödeme bekliyor')),
            DropdownMenuItem(value: 'confirmed', child: Text('Tahsilat doğrulandı')),
            DropdownMenuItem(value: 'rejected', child: Text('Ödeme doğrulanmadı')),
          ],
          onChanged: (v) { if (v != null) _updateOrder(o, 'paymentStatus', v); },
        ),
        Text('Sipariş durumu: ${o['orderStatus'] ?? 'İncelemede'}'),
        DropdownButtonFormField<String>(
          value: ['İncelemede','Onaylandı — ödeme bekliyor','Hazırlanıyor','Kargoya verildi','Teslim edildi','Başvuru reddedildi'].contains(o['orderStatus']) ? o['orderStatus'] : 'İncelemede',
          decoration: const InputDecoration(labelText: 'Sipariş durumu'),
          items: const ['İncelemede','Onaylandı — ödeme bekliyor','Hazırlanıyor','Kargoya verildi','Teslim edildi','Başvuru reddedildi'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) { if (v != null) _updateOrder(o, 'orderStatus', v); },
        ),
      ])))),
      const LocalModeNote(),
    ]);
  });
}

class AdminBilling extends StatefulWidget {
  const AdminBilling({super.key});
  @override State<AdminBilling> createState() => _AdminBillingState();
}
class _AdminBillingState extends State<AdminBilling> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _branches = TextEditingController(text: '1');
  final _employees = TextEditingController(text: '2');
  String _period = 'monthly';
  bool _loading = true, _saving = false;
  List<Map<String,dynamic>> _packages = [];
  List<Map<String,dynamic>> _payments = [];

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _name.dispose(); _description.dispose(); _price.dispose(); _branches.dispose(); _employees.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final packageRows = await cloud.from('subscription_packages').select().order('created_at', ascending: false);
      final paymentRows = await cloud.from('manual_payments')
        .select('*, profiles(full_name,email), subscription_packages(name,billing_period)')
        .order('created_at', ascending: false);
      _packages = (packageRows as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
      _payments = (paymentRows as List).map((r) => Map<String,dynamic>.from(r as Map)).toList();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paket ve tahsilatlar yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPackage() async {
    final price = num.tryParse(_price.text.trim().replaceAll(',', '.'));
    final branches = int.tryParse(_branches.text.trim());
    final employees = int.tryParse(_employees.text.trim());
    if (_name.text.trim().isEmpty || price == null || price < 0 || branches == null || branches < 1 || employees == null || employees < 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paket adı, geçerli fiyat ve kullanım limitleri gir.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await cloud.from('subscription_packages').insert({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'price_try': price,
        'billing_period': _period,
        'branch_limit': branches,
        'employee_limit': employees,
        'is_active': true,
      });
      _name.clear(); _description.clear(); _price.clear();
      _branches.text = '1'; _employees.text = '2';
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paket eklendi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paket eklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editPackage(Map<String,dynamic> package) async {
    final name = TextEditingController(text: package['name']?.toString() ?? '');
    final description = TextEditingController(text: package['description']?.toString() ?? '');
    final price = TextEditingController(text: (package['price_try'] as num).toString());
    final branches = TextEditingController(text: package['branch_limit'].toString());
    final employees = TextEditingController(text: package['employee_limit'].toString());
    var period = package['billing_period']?.toString() ?? 'monthly';
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Paketi düzenle'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Paket adı')),
          TextField(controller: description, decoration: const InputDecoration(labelText: 'Açıklama')),
          TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fiyat (TL)')),
          DropdownButtonFormField<String>(
            value: period,
            decoration: const InputDecoration(labelText: 'Dönem'),
            items: const [DropdownMenuItem(value: 'monthly', child: Text('Aylık')), DropdownMenuItem(value: 'yearly', child: Text('Yıllık'))],
            onChanged: (value) => setDialogState(() => period = value ?? 'monthly'),
          ),
          TextField(controller: branches, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Şube limiti')),
          TextField(controller: employees, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Çalışan limiti')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () async {
            final amount = num.tryParse(price.text.trim().replaceAll(',', '.'));
            final branchLimit = int.tryParse(branches.text.trim());
            final employeeLimit = int.tryParse(employees.text.trim());
            if (name.text.trim().isEmpty || amount == null || amount < 0 || branchLimit == null || branchLimit < 1 || employeeLimit == null || employeeLimit < 1) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Paket bilgilerini kontrol et.')));
              return;
            }
            try {
              await cloud.from('subscription_packages').update({
                'name': name.text.trim(), 'description': description.text.trim(),
                'price_try': amount, 'billing_period': period,
                'branch_limit': branchLimit, 'employee_limit': employeeLimit,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).eq('id', package['id']);
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (error) {
              if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Paket güncellenemedi: $error')));
            }
          }, child: const Text('Kaydet')),
        ],
      ),
    ));
    name.dispose(); description.dispose(); price.dispose(); branches.dispose(); employees.dispose();
    if (saved == true) await _load();
  }

  Future<void> _togglePackage(Map<String,dynamic> package, bool active) async {
    try {
      await cloud.from('subscription_packages').update({'is_active': active, 'updated_at': DateTime.now().toUtc().toIso8601String()}).eq('id', package['id']);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paket durumu değiştirilemedi: $error')));
    }
  }

  Future<void> _confirmPayment(String id) async {
    try {
      await cloud.rpc('confirm_manual_payment', params: {'p_payment_id': id});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tahsilat onaylandı ve abonelik etkinleştirildi.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tahsilat onaylanamadı: $error')));
    }
  }

  Future<void> _rejectPayment(String id) async {
    try {
      await cloud.from('manual_payments').update({'status': 'rejected'}).eq('id', id).eq('status', 'pending');
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tahsilat reddedilemedi: $error')));
    }
  }

  @override Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Heading('Paketler ve tahsilatlar', 'Paket fiyatlarını belirle; nakit veya havale tahsilatlarını doğrula.'),
      const Text('Yeni abonelik paketi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: forest)),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'Paket adı')),
      const SizedBox(height: 8),
      TextField(controller: _description, decoration: const InputDecoration(labelText: 'Açıklama')),
      const SizedBox(height: 8),
      TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fiyat (TL)')),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _period,
        decoration: const InputDecoration(labelText: 'Abonelik dönemi'),
        items: const [DropdownMenuItem(value: 'monthly', child: Text('Aylık')), DropdownMenuItem(value: 'yearly', child: Text('Yıllık'))],
        onChanged: (value) => setState(() => _period = value ?? 'monthly'),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: TextField(controller: _branches, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Şube limiti'))),
        const SizedBox(width: 10),
        Expanded(child: TextField(controller: _employees, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Çalışan limiti'))),
      ]),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: _saving ? null : _addPackage, icon: const Icon(Icons.add), label: Text(_saving ? 'Ekleniyor…' : 'Paketi ekle')),
      const SizedBox(height: 22),
      const Text('Mevcut paketler', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: forest)),
      if (_packages.isEmpty) const Text('Henüz paket eklenmedi.'),
      ..._packages.map((p) => Card(child: ListTile(
        title: Text('${p['name']} • ${(p['price_try'] as num).toStringAsFixed(2)} TL'),
        subtitle: Text('${p['billing_period'] == 'yearly' ? 'Yıllık' : 'Aylık'} • ${p['branch_limit']} şube • ${p['employee_limit']} çalışan'),
        trailing: Wrap(mainAxisSize: MainAxisSize.min, crossAxisAlignment: WrapCrossAlignment.center, children: [
          IconButton(tooltip: 'Düzenle', onPressed: () => _editPackage(p), icon: const Icon(Icons.edit_outlined)),
          Switch(value: p['is_active'] == true, onChanged: (value) => _togglePackage(p, value)),
        ]),
      ))),
      const SizedBox(height: 24),
      const Text('Tahsilat talepleri', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: forest)),
      if (_payments.isEmpty) const Text('Henüz tahsilat talebi yok.'),
      ..._payments.map((p) {
        final business = p['profiles'] is Map ? Map<String,dynamic>.from(p['profiles'] as Map) : <String,dynamic>{};
        final package = p['subscription_packages'] is Map ? Map<String,dynamic>.from(p['subscription_packages'] as Map) : <String,dynamic>{};
        final pending = p['status'] == 'pending';
        return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((business['full_name'] ?? business['email'] ?? 'İşletme').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('${package['name'] ?? 'Paket'} • ${(p['amount_try'] as num).toStringAsFixed(2)} TL'),
          Text('${p['payment_method'] == 'cash' ? 'Nakit' : 'Banka havalesi'} • ${p['status'] == 'confirmed' ? 'Onaylandı' : p['status'] == 'rejected' ? 'Reddedildi' : 'Onay bekliyor'}'),
          if (pending) Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _rejectPayment(p['id'].toString()), child: const Text('Reddet'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: () => _confirmPayment(p['id'].toString()), child: const Text('Tahsilatı onayla'))),
          ]),
        ])));
      }),
    ]);
  }
}

class AdminSettings extends StatelessWidget {
  const AdminSettings({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Heading('Yönetim ayarları','Yönetici erişimi ve hizmet yapılandırması.'),
    const Card(child:ListTile(leading:Icon(Icons.shield_outlined,color:forest),title:Text('Yönetici erişimi'),subtitle:Text('Yönetici girişi yalnızca onaylı yönetici rolüne sahip bulut hesabıyla yapılır.'))),
    const Card(child:ListTile(leading:Icon(Icons.payments_outlined,color:brown),title:Text('Manuel tahsilat'),subtitle:Text('Şimdilik çevrim içi ödeme yok. İşletme ödemeleri nakit veya banka havalesiyle alınır; yönetici tahsilatı panelden onaylar.'))),
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
          const Text('NFC etiketi: İşletme başına tek adet • Tahsilat: Nakit / banka havalesi'),
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
