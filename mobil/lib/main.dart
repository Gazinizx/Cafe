import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CafeDunyamApp());

const forest = Color(0xFF174C3C);
const cream = Color(0xFFF7F1E5);
const brown = Color(0xFF795548);
const usersKey = 'cd_local_users_v1';
const sessionKey = 'cd_local_session_v1';
const cafesKey = 'cd_local_cafes_v1';
const dealsKey = 'cd_local_deals_v1';
const stampsKey = 'cd_local_stamps_v1';

class CafeDunyamApp extends StatelessWidget {
  const CafeDunyamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cafe Dünyam',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: forest, surface: cream),
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: forest),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
    ),
    home: const GatePage(),
  );
}

class LocalData {
  static Future<List<Map<String, dynamic>>> list(String key, List<Map<String, dynamic>> defaults) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key);
    if (raw == null) { await p.setString(key, jsonEncode(defaults)); return defaults; }
    try { return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); }
    catch (_) { return defaults; }
  }
  static Future<void> saveList(String key, List<Map<String, dynamic>> value) async {
    final p = await SharedPreferences.getInstance(); await p.setString(key, jsonEncode(value));
  }
  static Future<Map<String, int>> stamps() async {
    final p = await SharedPreferences.getInstance();
    try { return (jsonDecode(p.getString(stampsKey) ?? '{}') as Map).map((k,v) => MapEntry(k.toString(), (v as num).toInt())); }
    catch (_) { return {}; }
  }
  static Future<void> saveStamps(Map<String,int> value) async {
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
    await LocalData.list(cafesKey, starterCafes);
    await LocalData.list(dealsKey, starterDeals);
    if (!mounted) return;
    setState(() => loading = false);
    final email = p.getString(sessionKey);
    if (email != null && mounted) {
      final users = await LocalData.list(usersKey, []);
      final found = users.where((u) => u['email'] == email).toList();
      if (found.isNotEmpty && mounted) _open(found.first);
    }
  }
  void _open(Map<String,dynamic> user) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => user['role'] == 'business'
      ? BusinessShell(user: user) : CustomerShell(user: user)));
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
    Container(padding: const EdgeInsets.all(26), decoration: BoxDecoration(color: forest, borderRadius: BorderRadius.circular(28)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.coffee, color: Color(0xFFE7D4B2), size: 48), SizedBox(height: 18),
      Text('Kahve molan, avantajın olsun.', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
      SizedBox(height: 10), Text('Kafeleri keşfet, fırsatları yakala ve sadakat kartlarını tek yerde takip et.', style: TextStyle(color: Colors.white70, fontSize: 16)),
    ])),
    const SizedBox(height: 28), const Text('Cafe Dünyam’a hoş geldin', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: forest)),
    const SizedBox(height: 8), const Text('Devam etmek için giriş yap veya yeni bir yerel test hesabı oluştur.'),
    const SizedBox(height: 18),
    FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(register: false, onDone: onDone))), icon: const Icon(Icons.login), label: const Text('Giriş yap')),
    OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AuthPage(register: true, onDone: onDone))), icon: const Icon(Icons.person_add_alt_1), label: const Text('Hesap oluştur')),
    const SizedBox(height: 20), const LocalModeNote(),
  ])));
}

class AuthPage extends StatefulWidget {
  final bool register;
  final ValueChanged<Map<String,dynamic>> onDone;
  const AuthPage({required this.register, required this.onDone, super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController(), cafeName = TextEditingController(), city = TextEditingController();
  String role = 'customer'; bool busy = false, hide = true;
  @override void dispose() { name.dispose(); email.dispose(); password.dispose(); cafeName.dispose(); city.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    final users = await LocalData.list(usersKey, []);
    final mail = email.text.trim().toLowerCase();
    if (widget.register) {
      if (users.any((u) => u['email'] == mail)) { setState(() => busy = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu e-posta ile yerel hesap zaten var.'))); return; }
      final user = <String,dynamic>{'name':name.text.trim(),'email':mail,'password':password.text,'role':role,'cafeName':cafeName.text.trim(),'city':city.text.trim()};
      users.add(user); await LocalData.saveList(usersKey, users);
      final p = await SharedPreferences.getInstance(); await p.setString(sessionKey, mail);
      if (mounted) widget.onDone(user);
    } else {
      final matches = users.where((u) => u['email'] == mail && u['password'] == password.text).toList();
      if (matches.isEmpty) { setState(() => busy = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-posta veya parola eşleşmedi. Bu cihazda hesap oluşturduğundan emin ol.'))); return; }
      final p = await SharedPreferences.getInstance(); await p.setString(sessionKey, mail);
      if (mounted) widget.onDone(matches.first);
    }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.register ? 'Hesap oluştur' : 'Giriş yap')), body: Form(key: form, child: ListView(padding: const EdgeInsets.all(22), children: [
    Text(widget.register ? 'Sana uygun hesabı oluştur' : 'Tekrar hoş geldin', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: forest)),
    const SizedBox(height: 8), const LocalModeNote(), const SizedBox(height: 18),
    if (widget.register) ...[
      TextFormField(controller:name, decoration:const InputDecoration(labelText:'Ad soyad'), validator:(v)=>v==null||v.trim().isEmpty?'Adını yaz.':null),
      const SizedBox(height:12),
      const Text('Hesap türü', style: TextStyle(fontWeight:FontWeight.bold)),
      RadioListTile<String>(value:'customer', groupValue:role, onChanged:(v)=>setState(()=>role=v!), title:const Text('Müşteri'), subtitle:const Text('Kafeleri keşfet, fırsatları kaydet ve kartlarını takip et.'), contentPadding:EdgeInsets.zero),
      RadioListTile<String>(value:'business', groupValue:role, onChanged:(v)=>setState(()=>role=v!), title:const Text('İşletme'), subtitle:const Text('İşletme panelini ve kampanya taslaklarını yönet.'), contentPadding:EdgeInsets.zero),
      if(role=='business') ...[
        TextFormField(controller:cafeName, decoration:const InputDecoration(labelText:'İşletme / kafe adı'), validator:(v)=>role=='business'&&(v==null||v.trim().isEmpty)?'İşletme adını yaz.':null),
        const SizedBox(height:12), TextFormField(controller:city, decoration:const InputDecoration(labelText:'Şehir'), validator:(v)=>role=='business'&&(v==null||v.trim().isEmpty)?'Şehir yaz.':null),
      ],
    ],
    TextFormField(controller:email, keyboardType:TextInputType.emailAddress, decoration:const InputDecoration(labelText:'E-posta', prefixIcon:Icon(Icons.email_outlined)), validator:(v)=>v==null||!v.contains('@')?'Geçerli e-posta yaz.':null),
    const SizedBox(height:12),
    TextFormField(controller:password, obscureText:hide, decoration:InputDecoration(labelText:'Parola', prefixIcon:const Icon(Icons.lock_outline), suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide), icon:Icon(hide?Icons.visibility:Icons.visibility_off))), validator:(v)=>v==null||v.length<6?'En az 6 karakter kullan.':null),
    const SizedBox(height:22), FilledButton(onPressed:busy?null:submit, child:Text(busy?'İşleniyor…':widget.register?'Hesabı oluştur':'Giriş yap')),
  ])));
}

class LocalModeNote extends StatelessWidget {
  const LocalModeNote({super.key});
  @override Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(13), decoration:BoxDecoration(color:const Color(0xFFE8DCC7), borderRadius:BorderRadius.circular(13)), child:const Text('Yerel test sürümü: hesaplar ve içerikler yalnızca bu cihazda saklanır. Başka cihazlarla senkronizasyon ve güvenli sunucu doğrulaması yoktur.', style:TextStyle(fontSize:13)));
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
 return Column(children:items.map((c)=>Card(child:ListTile(leading:const CircleAvatar(backgroundColor:cream,child:Icon(Icons.local_cafe,color:forest)),title:Text('${c['name']}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${c['city']} • ${c['type']}'),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>CafeDetailPage(cafe:c))))).toList());
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
 return Column(children:deals.take(3).map((d)=>Card(child:ListTile(leading:const CircleAvatar(backgroundColor:cream,child:Icon(Icons.local_offer,color:forest)),title:Text('${d['title']}'),subtitle:Text('${d['benefit']} • ${d['audience']}'))).toList());
});}

class CustomerDeals extends StatefulWidget{const CustomerDeals({super.key});@override State<CustomerDeals> createState()=>_CustomerDealsState();}
class _CustomerDealsState extends State<CustomerDeals>{
 Set<String> saved={};
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final p=await SharedPreferences.getInstance();if(mounted)setState(()=>saved=(p.getStringList('cd_saved_deals')??[]).toSet());}
 Future<void> _toggle(String id)async{setState(()=>saved.contains(id)?saved.remove(id):saved.add(id));final p=await SharedPreferences.getInstance();await p.setStringList('cd_saved_deals',saved.toList());}
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
 Future<void> _logout(BuildContext context)async{final p=await SharedPreferences.getInstance();await p.remove(sessionKey);if(context.mounted)Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const GatePage()),(r)=>false);}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('Profil','Hesap bilgilerin ve uygulama ayarları.'),
 Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text('${user['name']}'),subtitle:Text('${user['email']}'))),
 const Card(child:ListTile(leading:Icon(Icons.phone_android,color:forest),title:Text('Yerel test hesabı'),subtitle:Text('Bu cihazda kayıtlı; çevrim içi kimlik doğrulaması yok.'))),
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
 const Icon(Icons.storefront,color:cream,size:35),const SizedBox(height:12),Text('${user['cafeName']}',style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),Text('${user['city']}',style:const TextStyle(color:Colors.white70)),const SizedBox(height:12),const Text('İşletme profili yerel taslaktır; doğrulanmış işletme hesabı değildir.',style:TextStyle(color:Colors.white70)),
 ])),
 const SizedBox(height:16),const Text('Yönetim araçları',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800,color:forest)),
 const Card(child:ListTile(leading:Icon(Icons.campaign,color:forest),title:Text('Kampanya yönetimi'),subtitle:Text('Kampanya oluştur, düzenle ve yayından kaldır.'))),
 const Card(child:ListTile(leading:Icon(Icons.loyalty,color:forest),title:Text('Sadakat programı'),subtitle:Text('Kart ve ödül yapısı sonraki doğrulama adımına hazır taslak olarak ele alınır.'))),
 const LocalModeNote(),
 ]);
}
class BusinessDeals extends StatefulWidget{final Map<String,dynamic> user;const BusinessDeals({required this.user,super.key});@override State<BusinessDeals> createState()=>_BusinessDealsState();}
class _BusinessDealsState extends State<BusinessDeals>{
 final title=TextEditingController(),benefit=TextEditingController();String audience='Herkes';bool busy=false;
 @override void dispose(){title.dispose();benefit.dispose();super.dispose();}
 Future<void> _add()async{if(title.text.trim().isEmpty||benefit.text.trim().isEmpty)return;setState(()=>busy=true);final deals=await LocalData.list(dealsKey,starterDeals);deals.insert(0,{'id':'local-${DateTime.now().microsecondsSinceEpoch}','title':title.text.trim(),'benefit':benefit.text.trim(),'audience':audience,'cafeId':'','active':true,'ownerEmail':widget.user['email']});await LocalData.saveList(dealsKey,deals);title.clear();benefit.clear();if(mounted)setState(()=>busy=false);}
 Future<void> _toggle(Map<String,dynamic> d)async{final deals=await LocalData.list(dealsKey,starterDeals);final i=deals.indexWhere((x)=>x['id']==d['id']);if(i>=0){deals[i]['active']=!(deals[i]['active']==true);await LocalData.saveList(dealsKey,deals);if(mounted)setState(()=>{});}}
 Future<void> _delete(String id)async{final deals=await LocalData.list(dealsKey,starterDeals);deals.removeWhere((d)=>d['id']==id);await LocalData.saveList(dealsKey,deals);if(mounted)setState(()=>{});}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('Kampanyalar','Bu cihazdaki örnek kampanyaları yönet.'),
 TextField(controller:title,decoration:const InputDecoration(labelText:'Kampanya başlığı')),
 const SizedBox(height:10),TextField(controller:benefit,decoration:const InputDecoration(labelText:'İndirim / avantaj açıklaması')),
 const SizedBox(height:10),DropdownButtonFormField<String>(value:audience,decoration:const InputDecoration(labelText:'Hedef kitle'),items:const[DropdownMenuItem(value:'Herkes',child:Text('Herkes')),DropdownMenuItem(value:'Öğrenci',child:Text('Öğrenci')),DropdownMenuItem(value:'Yeni müşteriler',child:Text('Yeni müşteriler'))],onChanged:(v)=>setState(()=>audience=v??'Herkes')),
 const SizedBox(height:12),FilledButton.icon(onPressed:busy?null:_add,icon:const Icon(Icons.add),label:Text(busy?'Kaydediliyor…':'Kampanya taslağı oluştur')),
 const SizedBox(height:16),const Text('Kayıtlı kampanyalar',style:TextStyle(fontWeight:FontWeight.bold,fontSize:19)),
 FutureBuilder<List<Map<String,dynamic>>>(future:LocalData.list(dealsKey,starterDeals),builder:(context,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());return Column(children:s.data!.map((d)=>Card(child:ListTile(title:Text('${d['title']}'),subtitle:Text('${d['benefit']}\nDurum: ${d['active']==true?'Aktif (yerel)':'Pasif'}'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v)=>v=='toggle'?_toggle(d):_delete('${d['id']}'),itemBuilder:(_)=>const[PopupMenuItem(value:'toggle',child:Text('Aktif / pasif değiştir')),PopupMenuItem(value:'delete',child:Text('Sil'))]))).toList());}),
 const LocalModeNote(),
 ]);
}
class BusinessSettings extends StatelessWidget{
 final Map<String,dynamic> user;const BusinessSettings({required this.user,super.key});
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
 const Heading('İşletmem','İşletme bilgileri ve yerel ayarlar.'),
 Card(child:ListTile(leading:const Icon(Icons.store,color:forest),title:Text('${user['cafeName']}'),subtitle:Text('${user['city']}'))),
 Card(child:ListTile(leading:const Icon(Icons.email,color:forest),title:Text('${user['email']}'),subtitle:const Text('Hesap e-postası'))),
 const LocalModeNote(),
 const Text('Önemli: Bu ekranlar test için çalışır. İşletme sahipliği doğrulaması, gerçek satış onayı, sunucu, cihazlar arası eşitleme ve güvenli kullanıcı yetkilendirmesi bu yerel sürümde bulunmaz.'),
 ]);
}
