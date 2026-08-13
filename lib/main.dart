import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/products_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      await FirebaseDatabase.instance.ref('products').keepSynced(true);
    } catch (_) {}
  }
  runApp(const SimplePosApp());
}

class SimplePosApp extends StatelessWidget {
  const SimplePosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Simple POS',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5CEB)),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
    ),
    home: const DashboardScreen(),
  );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Simple POS', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('Main Branch', style: TextStyle(fontSize: 12)),
        ],
      ),
      backgroundColor: const Color(0xFF5B5CEB),
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Welcome to Simple POS',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const Text('Firebase connection is ready.'),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _Card('Cashiering', 'Create a new sale', Icons.point_of_sale, null),
            _Card(
              'Products',
              'Manage product list',
              Icons.inventory_2,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductsScreen()),
              ),
            ),
            _Card('Inventory', 'View current stocks', Icons.warehouse, null),
            _Card(
              'Sales History',
              'Review transactions',
              Icons.receipt_long,
              null,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Firebase Connected\nProject: pos-software-ef89c',
            style: TextStyle(
              color: Color(0xFF047857),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card(this.title, this.subtitle, this.icon, this.action);
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap:
          action ??
          () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title module will be added next.')),
          ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(child: Icon(icon)),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}
