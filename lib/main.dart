import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/product_sync_service.dart';
import 'database/database_helper.dart';
import 'screens/products_screen.dart';
import 'screens/inventory/inventory_module_screen.dart';
import 'screens/adjustment/adjustment_module_screen.dart';
import 'screens/received_delivery/received_delivery_module_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await DatabaseHelper.instance.initialize();

    final databasePath = await DatabaseHelper.instance.getDatabasePath();

    debugPrint('SQLite initialized: $databasePath');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      await FirebaseDatabase.instance.ref('products').keepSynced(true);
    } catch (_) {}
  }
  if (!kIsWeb) {
    unawaited(ProductSyncService.instance.start());
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

  static const double _phoneBreakpoint = 600;
  static const double _desktopBreakpoint = 1024;
  static const double _maximumContentWidth = 1400;

  @override
  Widget build(BuildContext context) {
    final modules = _createModules(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            if (width >= _desktopBreakpoint) {
              return _buildDesktopDashboard(
                context,
                modules: modules,
                wide: width >= 1440,
              );
            }

            return _buildCompactDashboard(
              context,
              modules: modules,
              tablet: width >= _phoneBreakpoint,
            );
          },
        ),
      ),
    );
  }

  List<_DashboardModule> _createModules(BuildContext context) {
    return <_DashboardModule>[
      _DashboardModule(
        title: 'Cashiering',
        subtitle: 'Create a new sale',
        icon: Icons.point_of_sale,
        color: const Color(0xFF5B5CEB),
        onTap: () {
          _showComingSoon(context, 'Cashiering');
        },
      ),
      _DashboardModule(
        title: 'Products',
        subtitle: 'Manage product list',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF7C3AED),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const ProductsScreen()),
          );
        },
      ),
      _DashboardModule(
        title: 'Inventory',
        subtitle: 'View current stocks',
        icon: Icons.warehouse_outlined,
        color: const Color(0xFF0F766E),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const InventoryModuleScreen(),
            ),
          );
        },
      ),
      _DashboardModule(
        title: 'Adjustment',
        subtitle: 'Manage stock corrections',
        icon: Icons.tune,
        color: const Color(0xFF2563EB),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const AdjustmentModuleScreen(),
            ),
          );
        },
      ),
      _DashboardModule(
        title: 'Received Delivery',
        subtitle: 'Receive supplier stock',
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF0F766E),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ReceivedDeliveryModuleScreen(),
            ),
          );
        },
      ),
      _DashboardModule(
        title: 'Sales History',
        subtitle: 'Review transactions',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFFF97316),
        onTap: () {
          _showComingSoon(context, 'Sales History');
        },
      ),
    ];
  }

  Widget _buildCompactDashboard(
    BuildContext context, {
    required List<_DashboardModule> modules,
    required bool tablet,
  }) {
    final horizontalPadding = tablet ? 32.0 : 16.0;

    final columnCount = tablet ? 3 : 2;

    return Column(
      children: [
        _CompactDashboardHeader(tablet: tablet),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              tablet ? 28 : 18,
              horizontalPadding,
              28,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: tablet ? 920 : 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Simple POS',
                      style: TextStyle(
                        color: const Color(0xFF111827),
                        fontSize: tablet ? 30 : 24,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Firebase connection is ready.',
                      style: TextStyle(
                        color: const Color(0xFF64748B),
                        fontSize: tablet ? 16 : 14,
                      ),
                    ),
                    SizedBox(height: tablet ? 26 : 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: modules.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columnCount,
                        crossAxisSpacing: tablet ? 18 : 14,
                        mainAxisSpacing: tablet ? 18 : 14,
                        childAspectRatio: tablet ? 1.20 : 0.98,
                      ),
                      itemBuilder: (context, index) {
                        return _DashboardModuleCard(
                          module: modules[index],
                          compact: !tablet,
                        );
                      },
                    ),
                    SizedBox(height: tablet ? 24 : 20),
                    const _FirebaseStatusCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopDashboard(
    BuildContext context, {
    required List<_DashboardModule> modules,
    required bool wide,
  }) {
    return Row(
      children: [
        _DashboardSidebar(modules: modules, wide: wide),
        Expanded(
          child: Column(
            children: [
              const _DesktopTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 40 : 28,
                    vertical: 32,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maximumContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome to Simple POS',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Manage sales, products, '
                            'inventory, and transactions '
                            'from one dashboard.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 30),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: modules.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: wide ? 22 : 18,
                                  mainAxisSpacing: wide ? 22 : 18,
                                  childAspectRatio: wide ? 1.28 : 1.08,
                                ),
                            itemBuilder: (context, index) {
                              return _DashboardModuleCard(
                                module: modules[index],
                                compact: false,
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          const _FirebaseStatusCard(desktop: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String module) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$module module will be added next.'),
        ),
      );
  }
}

class _DashboardModule {
  const _DashboardModule({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _CompactDashboardHeader extends StatelessWidget {
  const _CompactDashboardHeader({required this.tablet});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: tablet ? 32 : 16,
        vertical: tablet ? 18 : 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF5B5CEB), Color(0xFF7C3AED)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tablet ? 920 : 600),
          child: Row(
            children: [
              Container(
                width: tablet ? 46 : 40,
                height: tablet ? 46 : 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.point_of_sale, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simple POS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Main Branch',
                      style: TextStyle(
                        color: Color(0xFFE0E7FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: const Row(
        children: [
          Text(
            'Dashboard',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Spacer(),
          Icon(Icons.notifications_none, color: Color(0xFF64748B)),
          SizedBox(width: 18),
          CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFEDE9FE),
            child: Icon(
              Icons.person_outline,
              color: Color(0xFF6D28D9),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({required this.modules, required this.wide});

  final List<_DashboardModule> modules;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final width = wide ? 270.0 : 240.0;

    return Container(
      width: width,
      color: const Color(0xFF29245C),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF5B5CEB), Color(0xFF7C3AED)],
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.point_of_sale, color: Colors.white, size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simple POS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Main Branch',
                        style: TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 22, 18, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MODULES',
                style: TextStyle(
                  color: Color(0xFFA5B4FC),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: modules.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 6);
              },
              itemBuilder: (context, index) {
                final module = modules[index];

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: module.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            module.icon,
                            color: const Color(0xFFE0E7FF),
                            size: 21,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Text(
                              module.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF8B85BB),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(18),
            child: _SidebarConnectionStatus(),
          ),
        ],
      ),
    );
  }
}

class _SidebarConnectionStatus extends StatelessWidget {
  const _SidebarConnectionStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Firebase Connected',
              style: TextStyle(
                color: Color(0xFFD1FAE5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardModuleCard extends StatelessWidget {
  const _DashboardModuleCard({required this.module, required this.compact});

  final _DashboardModule module;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: module.onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 40 : 46,
                height: compact ? 40 : 46,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  module.icon,
                  color: module.color,
                  size: compact ? 22 : 25,
                ),
              ),
              const Spacer(),
              Text(
                module.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF111827),
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                module.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: compact ? 11 : 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirebaseStatusCard extends StatelessWidget {
  const _FirebaseStatusCard({this.desktop = false});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 20 : 16,
        vertical: desktop ? 17 : 15,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.cloud_done_outlined,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firebase Connected',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Project: pos-software-ef89c',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
