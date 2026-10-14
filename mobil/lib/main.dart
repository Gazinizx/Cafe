import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CafeDunyamApp());

const green = Color(0xFF174C3C);
const cream = Color(0xFFF7F1E5);
const brown = Color(0xFF795548);
const storageKey = 'cafe_dunyam_stamps_v1';

class Cafe {
  final String name, city, type, reward, nfcCode;
  final int goal;
  final IconData icon;
  const Cafe(this.name, this.city, this.type, this.reward, this.goal, this.icon, this.nfcCode);
}

const cafes = <Cafe>[
  Cafe('Kahve Durağı', 'İstanbul', 'Kahve ve tatlı', '8 damgada 1 kahve hediye', 8, Icons.local_cafe, 'CAFE_DUNYAM:KAHVE_DURAGI'),
  Cafe('Mola Coffee', 'Ankara', 'Modern kahve', '6 damgada sürpriz ödül', 6, Icons.coffee, 'CAFE_DUNYAM:MOLA_COFFEE'),
  Cafe('Kitap & Kahve', 'İzmir', 'Kitap kafe', '8 damgada filtre kahve hediye', 8, Icons.menu_book, 'CAFE_DUNYAM:KITAP_KAHVE'),
  Cafe('Fincan Atölyesi', 'Kayseri', 'Üçüncü nesil kahve', '7 damgada özel fırsat', 7, Icons.coffee_maker, 'CAFE_DUNYAM:FINCAN_ATOLYESI'),
  Cafe('Pasta Molası', 'Bursa', 'Kahve ve pastane', '5 damgada tatlı avantajı', 5, Icons.cake, 'CAFE_DUNYAM:PASTA_MOLASI'),
];

class CafeDunyamApp extends StatelessWidget {
  const CafeDunyamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cafe Dünyam',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: cream),
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(backgroundColor: cream, foregroundColor: green),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
    ),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  final Map<String, int> stamps = {for (final cafe in cafes) cafe.name: 0};
  final Set<String> savedDeals = {};
  String status = 'Yerel test modu: veriler yalnızca bu telefonda saklanır.';
  @override
  void initState() {
    super.initState();
    _loadStamps();
    _loadSavedDeals();
  }
  Future<void> _loadStamps() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || !mounted) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      setState(() {
        for (final cafe in cafes) {
          stamps[cafe.name] = (data[cafe.name] as num?)?.toInt() ?? 0;
        }
      });
    } catch (_) {}
  }
  Future<void> _saveStamps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(stamps));
  }
  Future<void> _loadSavedDeals() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList('cafe_dunyam_saved_deals_v1') ?? <String>[];
    if (!mounted) return;
    setState(() => savedDeals.addAll(items));
  }
  Future<void> _toggleSavedDeal(String title) async {
    setState(() {
      if (!savedDeals.add(title)) savedDeals.remove(title);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cafe_dunyam_saved_deals_v1', savedDeals.toList()..sort());
  }
  Future<void> _handleNfcCode(String code) async {
    final normalized = code.trim().toUpperCase();
    Cafe? match;
    for (final cafe in cafes) {
      if (cafe.nfcCode.toUpperCase() == normalized) { match = cafe; break; }
    }
    if (match == null) {
      setState(() => status = 'Bu NFC kodu tanınmadı: $code');
      return;
    }
    final cafe = match;
    if (cafe == null) return;
    setState(() {
      stamps[cafe.name] = (stamps[cafe.name] ?? 0) + 1;
      status = '${cafe.name} kartına 1 damga eklendi.';
    });
    await _saveStamps();
  }
  void _openCafe(Cafe cafe) => Navigator.push(context, MaterialPageRoute(builder: (_) => CafeDetail(cafe: cafe)));
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: tab, children: [
      HomePage(openCafe: _openCafe, goTab: (v) => setState(() => tab = v)),
      CafeListPage(openCafe: _openCafe),
      CardsPage(stamps: stamps, status: status, scan: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NfcReader(onCode: _handleNfcCode)))),
      DealsPage(saved: savedDeals, toggle: _toggleSavedDeal),
      const ProfilePage(),
    ])),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Ana Sayfa'),
        NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Kafeler'),
        NavigationDestination(icon: Icon(Icons.loyalty_outlined), label: 'Kartlarım'),
        NavigationDestination(icon: Icon(Icons.local_offer_outlined), label: 'Fırsatlar'),
        NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  const PageHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('CAFE DÜNYAM', style: TextStyle(color: brown, fontWeight: FontWeight.w900, letterSpacing: 2)),
      const SizedBox(height: 7),
      Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: green)),
      Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
    ]),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(title, style: const TextStyle(color: green, fontWeight: FontWeight.w800, fontSize: 20)),
  );
}

class HomePage extends StatelessWidget {
  final ValueChanged<Cafe> openCafe;
  final ValueChanged<int> goTab;
  const HomePage({required this.openCafe, required this.goTab, super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    Container(
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(25)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.coffee, color: Color(0xFFE7D4B2), size: 36),
        SizedBox(height: 13),
        Text('Kahve molan, avantajın olsun.', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
        SizedBox(height: 10),
        Text('Kafeleri keşfet, kampanyaları yakala, sadakat kartlarını takip et.', style: TextStyle(color: Colors.white70)),
      ]),
    ),
    Row(children: [const Expanded(child: SectionTitle('Öne çıkan kafeler')), TextButton(onPressed: () => goTab(1), child: const Text('Tümünü gör'))]),
    ...cafes.take(3).map((cafe) => CafeTile(cafe: cafe, onTap: () => openCafe(cafe))),
    const SectionTitle('Günün kampanyaları'),
    const DealTile('Öğrenci indirimi', 'Seçili içeceklerde %15 indirim', Icons.school),
    const DealTile('Tatlı molası', 'Kahve yanında tatlı fırsatı', Icons.cake),
  ]);
}

class CafeTile extends StatelessWidget {
  final Cafe cafe;
  final VoidCallback onTap;
  const CafeTile({required this.cafe, required this.onTap, super.key});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: CircleAvatar(backgroundColor: cream, child: Icon(cafe.icon, color: green)),
    title: Text(cafe.name, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text('${cafe.city} • ${cafe.type}'),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  ));
}

class CafeListPage extends StatefulWidget {
  final ValueChanged<Cafe> openCafe;
  const CafeListPage({required this.openCafe, super.key});
  @override State<CafeListPage> createState() => _CafeListPageState();
}
class _CafeListPageState extends State<CafeListPage> {
  String query = '', city = 'Tümü';
  @override
  Widget build(BuildContext context) {
    final cities = ['Tümü', ...cafes.map((c) => c.city).toSet()];
    final filtered = cafes.where((c) => (city == 'Tümü' || c.city == city) && (c.name.toLowerCase().contains(query.toLowerCase()) || c.type.toLowerCase().contains(query.toLowerCase())));
    return ListView(padding: const EdgeInsets.all(20), children: [
      const PageHeading('Kafeleri keşfet', 'Şehir ve kategoriye göre ara.'),
      TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Kafe ara', filled: true, fillColor: Colors.white)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, children: cities.map((v) => ChoiceChip(label: Text(v), selected: city == v, onSelected: (_) => setState(() => city = v))).toList()),
      ...filtered.map((c) => CafeTile(cafe: c, onTap: () => widget.openCafe(c))),
    ]);
  }
}

class CafeDetail extends StatelessWidget {
  final Cafe cafe;
  const CafeDetail({required this.cafe, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kafe detayları')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Container(height: 140, decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(22)), child: Icon(cafe.icon, color: cream, size: 65)),
      const SizedBox(height: 18),
      Text(cafe.name, style: const TextStyle(color: green, fontSize: 28, fontWeight: FontWeight.w900)),
      Text('${cafe.city} • ${cafe.type}'),
      const SectionTitle('Sadakat ödülü'),
      Text(cafe.reward),
      const SizedBox(height: 20),
      const Text('Damga, kasada işletmenin NFC tag’i okutulduğunda eklenir.'),
    ]),
  );
}

class CardsPage extends StatelessWidget {
  final Map<String, int> stamps;
  final String status;
  final VoidCallback scan;
  const CardsPage({required this.stamps, required this.status, required this.scan, super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const PageHeading('Kartlarım', 'Her kafenin damga kartı ayrıdır.'),
    ...cafes.map((cafe) {
      final count = stamps[cafe.name] ?? 0;
      return Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [
        Row(children: [Expanded(child: Text(cafe.name, style: const TextStyle(fontWeight: FontWeight.bold)),), Text('$count/${cafe.goal}')]),
        const SizedBox(height: 12),
        Row(children: List.generate(cafe.goal, (i) => Expanded(child: Container(
          height: 27, margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, color: i < count ? green : cream),
          child: Icon(i < count ? Icons.check : Icons.coffee, size: 14, color: i < count ? Colors.white : brown),
        )))),
        Text(cafe.reward),
      ])));
    }),
    FilledButton.icon(onPressed: scan, icon: const Icon(Icons.nfc), label: const Text('Kasada NFC ile damga al')),
    Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(status))),
    const Text('Test sürümü: damgalar yalnızca bu telefonda saklanır. Sabit NFC kodu kopyalanabilir.'),
  ]);
}

class NfcReader extends StatefulWidget {
  final Future<void> Function(String code) onCode;
  const NfcReader({required this.onCode, super.key});
  @override State<NfcReader> createState() => _NfcReaderState();
}
class _NfcReaderState extends State<NfcReader> {
  String message = 'Telefonunu kasadaki NFC tag’e yaklaştır.';
  bool reading = false, handled = false;
  @override
  void initState() { super.initState(); _startReading(); }
  Future<void> _startReading() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!available) {
        if (mounted) setState(() => message = 'Bu telefonda NFC bulunamadı veya kapalı. Ayarlardan NFC’yi aç.');
        return;
      }
      if (!mounted) return;
      setState(() { reading = true; message = 'NFC tag bekleniyor…'; });
      await NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
        if (handled) return;
        handled = true;
        String? textValue;
        try {
          final ndef = Ndef.from(tag);
          final records = ndef?.cachedMessage?.records ?? [];
          for (final record in records) {
            final payload = record.payload;
            if (payload.isEmpty) continue;
            final statusByte = payload[0];
            final languageLength = statusByte & 0x3F;
            if (payload.length > languageLength + 1) {
              final decoded = utf8.decode(payload.sublist(languageLength + 1), allowMalformed: true).trim();
              if (decoded.isNotEmpty) { textValue = decoded; break; }
            }
            final fallback = utf8.decode(payload, allowMalformed: true).trim();
            if (fallback.isNotEmpty) { textValue = fallback; break; }
          }
          await NfcManager.instance.stopSession();
          if (textValue == null) {
            if (mounted) setState(() { reading = false; message = 'Tag okunamadı. NFC tag’e CAFE_DUNYAM:ISLETME_KODU biçiminde metin kaydedin.'; });
            return;
          }
          await widget.onCode(textValue);
          if (mounted) setState(() { reading = false; message = 'Okunan kod: $textValue\nKartlarım ekranındaki sonucu kontrol et.'; });
        } catch (e) {
          try { await NfcManager.instance.stopSession(); } catch (_) {}
          if (mounted) setState(() { reading = false; message = 'NFC okuma hatası: $e'; });
        }
      });
    } catch (e) {
      if (mounted) setState(() { reading = false; message = 'NFC başlatılamadı: $e'; });
    }
  }
  @override
  void dispose() {
    if (reading) { NfcManager.instance.stopSession().catchError((_) {}); }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('NFC ile damga')),
    body: Center(child: Padding(padding: const EdgeInsets.all(26), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.nfc, size: 100, color: green),
      const SizedBox(height: 22),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
      const SizedBox(height: 18),
      if (reading) const CircularProgressIndicator(),
      const SizedBox(height: 16),
      const Text('Tag içeriği, işletmenin aşağıdaki sabit kodlarından biri olmalı. NFC tag NDEF metin kaydı olarak yazılmalıdır.', textAlign: TextAlign.center),
      const SizedBox(height: 10),
      const Text('Örnek: CAFE_DUNYAM:KAHVE_DURAGI', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
    ]))),
  );
}

class DealsPage extends StatelessWidget {
  final Set<String> saved;
  final ValueChanged<String> toggle;
  const DealsPage({required this.saved, required this.toggle, super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const PageHeading('Fırsatlar', 'Kampanyaları keşfet ve kaydet.'),
    DealTile('Öğrenci indirimi', 'Seçili içeceklerde %15 indirim', Icons.school, saved: saved.contains('Öğrenci indirimi'), onToggle: () => toggle('Öğrenci indirimi')),
    DealTile('Tatlı molası', 'Kahve yanında tatlı fırsatı', Icons.cake, saved: saved.contains('Tatlı molası'), onToggle: () => toggle('Tatlı molası')),
    const SectionTitle('Kaydedilen fırsatlar'),
    if (saved.isEmpty)
      const Card(child: ListTile(leading: Icon(Icons.bookmark_border), title: Text('Henüz fırsat kaydetmedin.'), subtitle: Text('Bir fırsatın yanındaki yer imi simgesine dokun.')))
    else
      ...([...saved]..sort()).map((title) => Card(child: ListTile(leading: const Icon(Icons.bookmark, color: green), title: Text(title)))),
    const Padding(padding: EdgeInsets.only(top: 10), child: Text('Fırsatlar örnek veridir. Gerçek işletme kampanyaları henüz bağlı değildir.', style: TextStyle(color: Colors.black54))),
  ]);
}

class DealTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool saved;
  final VoidCallback? onToggle;
  const DealTile(this.title, this.subtitle, this.icon, {this.saved = false, this.onToggle, super.key});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: CircleAvatar(backgroundColor: cream, child: Icon(icon, color: green)),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: onToggle == null ? null : IconButton(
      tooltip: saved ? 'Fırsatı kaydedilenlerden çıkar' : 'Fırsatı kaydet',
      onPressed: onToggle,
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: green),
    ),
  ));
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const PageHeading('Profil', 'Cafe Dünyam test sürümü'),
    const Card(child: ListTile(leading: Icon(Icons.phone_android, color: green), title: Text('Yerel test modu'), subtitle: Text('Sunucu veya hesap bağlantısı yok.'))),
    const SectionTitle('NFC tag kodları'),
    ...cafes.map((c) => Card(child: ListTile(title: Text(c.name), subtitle: SelectableText(c.nfcCode)))),
    const SizedBox(height: 8),
    const Text('Bu kodları NFC tag’e NDEF metin kaydı olarak yazın. Gerçek işletme kodları sonraki aşamada yönetim sisteminden tanımlanacak.'),
  ]);
}
