import 'package:flutter/material.dart';

class InventoryModuleScreen extends StatefulWidget {
  const InventoryModuleScreen({super.key});

  @override
  State<InventoryModuleScreen> createState() => _InventoryModuleScreenState();
}

class _InventoryModuleScreenState extends State<InventoryModuleScreen> {
  int _selectedIndex = 0;

  static const List<_InventorySection> _sections = <_InventorySection>[
    _InventorySection(title: 'Inventory', icon: Icons.inventory_2_outlined),
    _InventorySection(title: 'Adjustment', icon: Icons.tune),
    _InventorySection(
      title: 'Received Delivery',
      icon: Icons.local_shipping_outlined,
    ),
    _InventorySection(
      title: 'Adjustment Types',
      icon: Icons.settings_suggest_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Inventory Module'),
        backgroundColor: const Color(0xFF5B5CEB),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1024;

            if (desktop) {
              return Row(
                children: [
                  _buildDesktopNavigation(),
                  Expanded(child: _buildSelectedPage()),
                ],
              );
            }

            return Column(
              children: [
                _buildCompactNavigation(),
                Expanded(child: _buildSelectedPage()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompactNavigation() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: List<Widget>.generate(_sections.length, (index) {
            final section = _sections[index];

            final selected = index == _selectedIndex;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                avatar: Icon(
                  section.icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF5B5CEB),
                ),
                label: Text(section.title),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: const Color(0xFF5B5CEB),
                backgroundColor: const Color(0xFFF3F4F6),
                side: BorderSide.none,
                onSelected: (_) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDesktopNavigation() {
    return Container(
      width: 250,
      color: const Color(0xFF29245C),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'INVENTORY',
                style: TextStyle(
                  color: Color(0xFFA5B4FC),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _sections.length,
              itemBuilder: (context, index) {
                final section = _sections[index];

                final selected = index == _selectedIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              section.icon,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFC7D2FE),
                              size: 21,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                section.title,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : const Color(0xFFE0E7FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const _InventoryOverview();
      case 1:
        return const _ModuleDevelopmentPage(
          title: 'Adjustment',
          description:
              'Create, submit, approve, '
              'or reject cost-based '
              'inventory adjustments.',
          icon: Icons.tune,
          completedFeatures: <String>[
            'Cost Price calculation model',
            'Increase and Decrease direction',
            'Draft, Submitted, Approved, '
                'and Rejected workflow',
            'Negative inventory protection',
            'One-time processing protection',
          ],
        );
      case 2:
        return const _ModuleDevelopmentPage(
          title: 'Received Delivery',
          description:
              'Receive supplier deliveries '
              'using quantity and Cost Price.',
          icon: Icons.local_shipping_outlined,
          completedFeatures: <String>[
            'Cost-only inventory rules ready',
            'DELIVERY movement type ready',
            'Approval workflow foundation ready',
            'Firebase repository pending',
            'Received Delivery form pending',
          ],
        );
      case 3:
        return const _ModuleDevelopmentPage(
          title: 'Adjustment Types',
          description:
              'Manage configurable Increase '
              'and Decrease adjustment types.',
          icon: Icons.settings_suggest_outlined,
          completedFeatures: <String>[
            'Configurable type model ready',
            'Increase (+) and Decrease (-)',
            'Active and Inactive status',
            'Delete unused type rule',
            'Deactivate used type rule',
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _InventoryOverview extends StatelessWidget {
  const _InventoryOverview();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;

        final tablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

        final padding = mobile
            ? 16.0
            : tablet
            ? 24.0
            : 32.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(mobile: mobile),
                  const SizedBox(height: 22),
                  _buildSummaryCards(mobile: mobile, tablet: tablet),
                  const SizedBox(height: 22),
                  _buildSearchAndFilters(mobile: mobile),
                  const SizedBox(height: 18),
                  _buildInventoryContent(mobile: mobile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({required bool mobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current Inventory',
          style: TextStyle(
            color: const Color(0xFF111827),
            fontSize: mobile ? 24 : 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Monitor on-hand quantities and '
          'inventory value using Cost Price.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSummaryCards({required bool mobile, required bool tablet}) {
    final cards = const <_InventorySummaryData>[
      _InventorySummaryData(
        label: 'Total SKUs',
        value: 'Product Masterfile',
        icon: Icons.qr_code_2,
        color: Color(0xFF5B5CEB),
      ),
      _InventorySummaryData(
        label: 'Total Quantity',
        value: 'Current OH',
        icon: Icons.inventory_outlined,
        color: Color(0xFF0F766E),
      ),
      _InventorySummaryData(
        label: 'Total Inventory Cost',
        value: 'OH × Cost Price',
        icon: Icons.account_balance_wallet_outlined,
        color: Color(0xFFF97316),
      ),
    ];

    final columns = mobile
        ? 1
        : tablet
        ? 3
        : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: mobile ? 3.2 : 2.2,
      ),
      itemBuilder: (context, index) {
        return _InventorySummaryCard(data: cards[index]);
      },
    );
  }

  Widget _buildSearchAndFilters({required bool mobile}) {
    final search = TextField(
      enabled: false,
      decoration: InputDecoration(
        hintText: 'Search SKU, Product Name, or Brand',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );

    final filter = OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.filter_list),
      label: const Text('Filters'),
    );

    if (mobile) {
      return Column(
        children: [
          search,
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: filter),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: 12),
        filter,
      ],
    );
  }

  Widget _buildInventoryContent({required bool mobile}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFF6D28D9),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Inventory Module Connected',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The Product Masterfile data stream '
            'will be connected in the next Inventory '
            'repository stage.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 16),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _RuleChip(label: 'Inventory Value = OH × Cost Price'),
              _RuleChip(label: 'No Retail Price'),
              _RuleChip(label: 'Movement Audit Required'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventorySummaryData {
  const _InventorySummaryData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _InventorySummaryCard extends StatelessWidget {
  const _InventorySummaryCard({required this.data});

  final _InventorySummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

class _ModuleDevelopmentPage extends StatelessWidget {
  const _ModuleDevelopmentPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.completedFeatures,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<String> completedFeatures;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF6D28D9)),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                ...completedFeatures.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF059669),
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feature,
                            style: const TextStyle(color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6D28D9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InventorySection {
  const _InventorySection({required this.title, required this.icon});

  final String title;
  final IconData icon;
}
