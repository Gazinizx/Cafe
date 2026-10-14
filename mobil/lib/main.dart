import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() => runApp(const CafeDunyamApp());

const forest = Color(0xFF174C3C);
const cream = Color(0xFFF7F1E5);
const cocoa = Color(0xFF795548);

class CafeDunyamApp extends StatelessWidget {
  const CafeDunyamApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cafe Dünyam',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: forest, surface: cream), scaffoldBackgroundColor: cream, useMaterial3: true),
    home: const MainShell(),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int tab = 0;
  final pages = const [HomePage(), CardsPage(), OffersPage(), ProfilePage()];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: IndexedStack(index: tab, children: pages)),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (v) => setState(() => tab = v),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Ana Sayfa'),
        NavigationDestination(icon: Icon(Icons.loyalty_outlined), selectedIcon: Icon(Icons.loyalty), label: 'Kartlarım'),
        NavigationDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: 'Fırsatlar'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profil'),
      ],
    ),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('CAFE DÜNYAM', style: TextStyle(color: forest, fontWeight: FontWeight.w900, letterSpacing: 2)),
    const SizedBox(height: 18),
    Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: forest, borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.coffee, color: cream, size: 34),
      SizedBox(height: 14),
      Text('Kahve molan,\navantajın olsun.', style: TextStyle(color: cream, fontSize: 27, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('Sevdiğin kafelerin kampanyalarını keşfet.', style: TextStyle(color: cream)),
    ])),
    const SizedBox(height: 24),
    const SectionTitle('Öne çıkan kafeler'),
    const CafeTile(name: 'Kahve Durağı', subtitle: 'Kahve ve tatlılarda fırsatlar', icon: Icons.local_cafe),
    const CafeTile(name: 'Mola Coffee', subtitle: 'Öğrencilere özel indirimler', icon: Icons.coffee),
    const CafeTile(name: 'Kitap & Kahve', subtitle: 'Her 8 kahvede 1 kahve hediye', icon: Icons.menu_book),
    const SizedBox(height: 20),
    const SectionTitle('Günün kampanyaları'),
    const OfferTile(title: 'Öğrenci indirimi', subtitle: 'Öğrenci kimliğinle seçili içeceklerde %15 indirim', icon: Icons.school),
    const OfferTile(title: 'Kahven yanında tatlı', subtitle: 'Seçili kahvelerde tatlı fırsatları', icon: Icons.cake),
  ]);
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: forest)));
}
class CafeTile extends StatelessWidget {
  final String name, subtitle;
  final IconData icon;
  const CafeTile({required this.name, required this.subtitle, required this.icon, super.key});
  @override
  Widget build(BuildContext context) => Card(color: Colors.white, child: ListTile(leading: CircleAvatar(backgroundColor: cream, child: Icon(icon, color: forest)), title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(title: name, description: subtitle)))));
}
class OfferTile extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const OfferTile({required this.title, required this.subtitle, required this.icon, super.key});
  @override
  Widget build(BuildContext context) => Card(color: Colors.white, child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE8DCC7), child: Icon(icon, color: cocoa)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(title: title, description: subtitle)))));
}
class DetailPage extends StatelessWidget {
  final String title, description;
  const DetailPage({required this.title, required this.description, super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.coffee, size: 54, color: forest), const SizedBox(height: 20), Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Text(description), const SizedBox(height: 24), const Text('Demo içerik: kampanyalar henüz sunucuya bağlı değildir.')]))); 
}
class CardsPage extends StatelessWidget {
  const CardsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const SectionTitle('Sadakat kartlarım'),
    const Text('Her kafenin kartı ayrıdır. Damgalar gerçek alışveriş doğrulamasıyla eklenmelidir.'),
    const SizedBox(height: 12),
    const LoyaltyTile(name: 'Kahve Durağı', stamps: 5, target: 8),
    const LoyaltyTile(name: 'Mola Coffee', stamps: 2, target: 6),
    const LoyaltyTile(name: 'Kitap & Kahve', stamps: 7, target: 8),
    const SizedBox(height: 20),
    FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: forest), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanPage())), icon: const Icon(Icons.qr_code_scanner), label: const Text('QR kod tara')),
  ]);
}
class LoyaltyTile extends StatelessWidget {
  final String name;
  final int stamps, target;
  const LoyaltyTile({required this.name, required this.stamps, required this.target, super.key});
  @override
  Widget build(BuildContext context) => Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Icon(Icons.loyalty, color: forest), const SizedBox(width: 8), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))), Text('$stamps/$target')]),
    const SizedBox(height: 12),
    Row(children: List.generate(target, (i) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), height: 27, decoration: BoxDecoration(color: i < stamps ? forest : cream, shape: BoxShape.circle), child: Icon(i < stamps ? Icons.check : Icons.coffee, size: 15, color: i < stamps ? Colors.white : cocoa))))),
    const SizedBox(height: 8), Text('Hedefe ulaşınca ödül kazanırsın.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
  ])));
}
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}
class _ScanPageState extends State<ScanPage> {
  String? value;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('QR kod tara')), body: Column(children: [
    Expanded(child: MobileScanner(onDetect: (capture) { final codes = capture.barcodes; if (codes.isNotEmpty && codes.first.rawValue != null && value == null) setState(() => value = codes.first.rawValue); })),
    Padding(padding: const EdgeInsets.all(18), child: Text(value == null ? 'Kafenin QR kodunu kameraya göster.' : 'Okunan kod: $value\nBu prototip gerçek damga eklemez; sunucu doğrulaması henüz bağlı değil.', textAlign: TextAlign.center)),
  ]));
}
class OffersPage extends StatelessWidget {
  const OffersPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: const [SectionTitle('Fırsatlar'), OfferTile(title: 'Öğrenci indirimi', subtitle: 'Seçili içeceklerde %15 indirim', icon: Icons.school), OfferTile(title: 'Tatlı molası', subtitle: 'Kahvenin yanında seçili tatlılarda fırsat', icon: Icons.cake), OfferTile(title: 'Sadakat ödülü', subtitle: 'Kendi kartındaki damgaları takip et', icon: Icons.card_giftcard)]);
}
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    const SectionTitle('Profil'),
    const CircleAvatar(radius: 38, backgroundColor: forest, child: Icon(Icons.person, color: cream, size: 40)),
    const SizedBox(height: 12),
    const Text('Cafe Dünyam kullanıcısı', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Demo sürümü'), subtitle: Text('Giriş, hesap kaydı ve veri eşitleme henüz aktif değil.'))),
    Card(child: ListTile(leading: const Icon(Icons.help_outline), title: const Text('Yardım ve destek'), onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Destek'), content: Text('Destek sayfası daha sonra eklenecek.'))))),
  ]);
}
