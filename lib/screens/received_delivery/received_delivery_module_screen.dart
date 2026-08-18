import 'package:flutter/material.dart';

class ReceivedDeliveryModuleScreen extends StatefulWidget {
  const ReceivedDeliveryModuleScreen({super.key});

  @override
  State<ReceivedDeliveryModuleScreen> createState() =>
      _ReceivedDeliveryModuleScreenState();
}

class _ReceivedDeliveryModuleScreenState
    extends State<ReceivedDeliveryModuleScreen> {
  _DeliveryStatusFilter _selectedFilter = _DeliveryStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Received Delivery'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 600;

            final tablet =
                constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

            final horizontalPadding = mobile
                ? 16.0
                : tablet
                ? 24.0
                : 32.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                mobile ? 18 : 28,
                horizontalPadding,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, mobile: mobile),
                      const SizedBox(height: 20),
                      _buildSearch(mobile: mobile),
                      const SizedBox(height: 14),
                      _buildStatusFilters(),
                      const SizedBox(height: 18),
                      _buildContent(mobile: mobile),
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

  Widget _buildHeader(BuildContext context, {required bool mobile}) {
    final titleBlock = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Received Deliveries',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Receive supplier deliveries '
          'using quantities and Cost Price.',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ],
    );

    final newButton = FilledButton.icon(
      onPressed: () {
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
      },
      icon: const Icon(Icons.add),
      label: const Text('NEW RECEIVED DELIVERY'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: newButton),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Received Deliveries',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Receive supplier deliveries '
                'using quantities and Cost Price.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        newButton,
      ],
    );
  }

  Widget _buildSearch({required bool mobile}) {
    return TextField(
      enabled: false,
      decoration: InputDecoration(
        hintText: mobile
            ? 'Search DR Number or Supplier'
            : 'Search DR Number, Supplier, '
                  'or Invoice Number',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
      ),
    );
  }

  Widget _buildStatusFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _DeliveryStatusFilter.values.map((filter) {
          final selected = filter == _selectedFilter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              label: Text(filter.label),
              labelStyle: TextStyle(
                color: selected
                    ? const Color(0xFF065F46)
                    : const Color(0xFF4B5563),
                fontWeight: FontWeight.w700,
              ),
              selectedColor: const Color(0xFFD1FAE5),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFFE5E7EB),
              ),
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContent({required bool mobile}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 20 : 28,
        vertical: mobile ? 38 : 48,
      ),
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
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF047857),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == _DeliveryStatusFilter.all
                ? 'No Received Deliveries Yet'
                : 'No ${_selectedFilter.label} '
                      'Deliveries',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a Received Delivery '
            'to record supplier stock received '
            'at Cost Price.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 18),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _DeliveryRuleChip(label: 'Draft → Submitted'),
              _DeliveryRuleChip(label: 'Approved increases SOH'),
              _DeliveryRuleChip(label: 'Received Qty × Cost Price'),
              _DeliveryRuleChip(label: 'No Retail Price'),
            ],
          ),
        ],
      ),
    );
  }
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
}

class _DeliveryRuleChip extends StatelessWidget {
  const _DeliveryRuleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF047857),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
