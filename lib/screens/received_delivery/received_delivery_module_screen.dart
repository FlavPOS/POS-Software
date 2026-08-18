import 'package:flutter/material.dart';

const Color _receivedDeliveryGreen = Color(0xFF07834F);

class ReceivedDeliveryModuleScreen extends StatefulWidget {
  const ReceivedDeliveryModuleScreen({super.key});

  @override
  State<ReceivedDeliveryModuleScreen> createState() =>
      _ReceivedDeliveryModuleScreenState();
}

class _ReceivedDeliveryModuleScreenState
    extends State<ReceivedDeliveryModuleScreen> {
  static const Color _teal = Color(0xFF047D68);

  final TextEditingController _searchController = TextEditingController();

  _DeliveryStatusFilter _selectedFilter = _DeliveryStatusFilter.all;

  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FC),
      appBar: AppBar(
        toolbarHeight: 66,
        titleSpacing: 0,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF137F72), Color(0xFF00765F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            Navigator.maybePop(context);
          },
          icon: const Icon(Icons.arrow_back, size: 29),
        ),
        title: const Text(
          'Received Delivery',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phone = constraints.maxWidth < 600;

            final tablet =
                constraints.maxWidth >= 600 && constraints.maxWidth < 1100;

            final horizontalPadding = phone
                ? 16.0
                : tablet
                ? 26.0
                : 34.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    phone ? 18 : 26,
                    horizontalPadding,
                    20,
                  ),
                  child: Column(
                    children: [
                      _buildNewDeliveryButton(phone: phone),
                      SizedBox(height: phone ? 18 : 22),
                      _buildSearchField(),
                      SizedBox(height: phone ? 14 : 18),
                      _buildStatusFilters(phone: phone),
                      SizedBox(height: phone ? 18 : 22),
                      Expanded(child: _buildContent(phone: phone)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNewDeliveryButton({required bool phone}) {
    return SizedBox(
      width: double.infinity,
      height: phone ? 58 : 68,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF047F6A), Color(0xFF008969)],
          ),
          borderRadius: BorderRadius.circular(phone ? 14 : 18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26006452),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(phone ? 14 : 18),
            onTap: _showNewDeliveryNotice,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: phone ? 25 : 34),
                SizedBox(width: phone ? 9 : 15),
                Text(
                  'NEW RECEIVED DELIVERY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: phone ? 14 : 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search DR Number or Supplier',
        hintStyle: const TextStyle(color: Color(0xFF8A91A3), fontSize: 15),
        prefixIcon: const Icon(
          Icons.search,
          color: Color(0xFF69738F),
          size: 25,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchText.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchText = '';
                  });
                },
                icon: const Icon(Icons.close, color: Color(0xFF69738F)),
              ),
            Container(width: 1, height: 32, color: const Color(0xFFD6DDEA)),
            IconButton(
              tooltip: 'Delivery filters',
              onPressed: _showFilterInformation,
              icon: const Icon(
                Icons.filter_list_rounded,
                color: _teal,
                size: 28,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD5DDEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD5DDEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _teal, width: 2),
        ),
      ),
    );
  }

  Widget _buildStatusFilters({required bool phone}) {
    return SizedBox(
      height: phone ? 49 : 57,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _DeliveryStatusFilter.values.length,
        separatorBuilder: (context, index) {
          return SizedBox(width: phone ? 6 : 12);
        },
        itemBuilder: (context, index) {
          final filter = _DeliveryStatusFilter.values[index];

          final selected = filter == _selectedFilter;

          return _DeliveryFilterButton(
            filter: filter,
            selected: selected,
            phone: phone,
            onTap: () {
              setState(() {
                _selectedFilter = filter;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildContent({required bool phone}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(phone ? 18 : 26),
        border: Border.all(color: const Color(0xFFDCE4EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F3A5A),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: phone ? 20 : 34,
          vertical: phone ? 32 : 42,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                _buildDeliveryIcon(phone: phone),
                SizedBox(height: phone ? 18 : 24),
                Text(
                  _emptyStateTitle(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF09132D),
                    fontSize: phone ? 19 : 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                SizedBox(height: phone ? 10 : 16),
                Text(
                  _emptyStateMessage(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF53617F),
                    fontSize: phone ? 13 : 18,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: phone ? 24 : 36),
                _buildRuleCards(phone: phone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryIcon({required bool phone}) {
    return Container(
      width: phone ? 66 : 112,
      height: phone ? 66 : 112,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD9FAE9), Color(0xFFC9F7E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(phone ? 18 : 30),
      ),
      child: Icon(
        Icons.local_shipping_outlined,
        size: phone ? 34 : 59,
        color: _receivedDeliveryGreen,
      ),
    );
  }

  Widget _buildRuleCards({required bool phone}) {
    const rules = <_DeliveryRuleData>[
      _DeliveryRuleData(
        icon: Icons.description_outlined,
        label: 'Draft → Submitted',
      ),
      _DeliveryRuleData(
        icon: Icons.trending_up,
        label: 'Approved Increases SOH',
      ),
      _DeliveryRuleData(
        icon: Icons.calculate_outlined,
        label: 'Received Qty × Cost Price',
      ),
      _DeliveryRuleData(
        icon: Icons.storefront_outlined,
        label: 'No Retail Price',
      ),
    ];

    if (phone) {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 9,
        children: rules.map((rule) {
          return _DeliveryRuleCard(rule: rule, compact: true);
        }).toList(),
      );
    }

    return GridView.builder(
      itemCount: rules.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 18,
        mainAxisSpacing: 16,
        mainAxisExtent: 76,
      ),
      itemBuilder: (context, index) {
        return _DeliveryRuleCard(rule: rules[index], compact: false);
      },
    );
  }

  String _emptyStateTitle() {
    if (_selectedFilter == _DeliveryStatusFilter.all) {
      return 'No Received Deliveries Yet';
    }

    return 'No ${_selectedFilter.label} '
        'Deliveries';
  }

  String _emptyStateMessage() {
    if (_searchText.trim().isNotEmpty) {
      return 'No Received Delivery matches '
          'the current search.';
    }

    return 'Create a Received Delivery to '
        'record supplier stock received '
        'at Cost Price.';
  }

  void _showNewDeliveryNotice() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'New Received Delivery form '
            'will be connected next.',
          ),
        ),
      );
  }

  void _showFilterInformation() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Additional Received Delivery '
            'filters will be connected with '
            'the repository.',
          ),
        ),
      );
  }
}

class _DeliveryFilterButton extends StatelessWidget {
  const _DeliveryFilterButton({
    required this.filter,
    required this.selected,
    required this.phone,
    required this.onTap,
  });

  final _DeliveryStatusFilter filter;
  final bool selected;
  final bool phone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFFDCFFEC), Color(0xFFC9F8E0)],
              )
            : null,
        color: selected ? null : Colors.white,
        borderRadius: BorderRadius.circular(phone ? 12 : 18),
        border: Border.all(
          color: selected ? const Color(0xFFA7EFD0) : const Color(0xFFDCE3EF),
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x16008762),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(phone ? 12 : 18),
          child: Container(
            constraints: BoxConstraints(minWidth: phone ? 54 : 126),
            padding: EdgeInsets.symmetric(
              horizontal: phone ? 8 : 20,
              vertical: phone ? 10 : 14,
            ),
            decoration: BoxDecoration(
              border: selected
                  ? const Border(
                      bottom: BorderSide(
                        color: _receivedDeliveryGreen,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  filter.icon,
                  size: phone ? 16 : 24,
                  color: selected
                      ? _receivedDeliveryGreen
                      : const Color(0xFF64708D),
                ),
                SizedBox(width: phone ? 5 : 10),
                Text(
                  filter.label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF07381F)
                        : const Color(0xFF161D31),
                    fontSize: phone ? 12 : 16,
                    fontWeight: FontWeight.w700,
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

class _DeliveryRuleCard extends StatelessWidget {
  const _DeliveryRuleCard({required this.rule, required this.compact});

  final _DeliveryRuleData rule;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 38 : 68),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 9 : 13,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE2FFF0), Color(0xFFD4FAE8)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(
            rule.icon,
            color: _receivedDeliveryGreen,
            size: compact ? 18 : 28,
          ),
          SizedBox(width: compact ? 8 : 12),
          Flexible(
            child: Text(
              rule.label,
              style: TextStyle(
                color: const Color(0xFF006935),
                fontSize: compact ? 11 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryRuleData {
  const _DeliveryRuleData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

enum _DeliveryStatusFilter { all, draft, submitted, approved, rejected }

extension on _DeliveryStatusFilter {
  String get label {
    switch (this) {
      case _DeliveryStatusFilter.all:
        return 'All';
      case _DeliveryStatusFilter.draft:
        return 'Draft';
      case _DeliveryStatusFilter.submitted:
        return 'Submitted';
      case _DeliveryStatusFilter.approved:
        return 'Approved';
      case _DeliveryStatusFilter.rejected:
        return 'Rejected';
    }
  }

  IconData get icon {
    switch (this) {
      case _DeliveryStatusFilter.all:
        return Icons.grid_view_rounded;
      case _DeliveryStatusFilter.draft:
        return Icons.description_outlined;
      case _DeliveryStatusFilter.submitted:
        return Icons.send_outlined;
      case _DeliveryStatusFilter.approved:
        return Icons.check_circle_outline;
      case _DeliveryStatusFilter.rejected:
        return Icons.cancel_outlined;
    }
  }
}
