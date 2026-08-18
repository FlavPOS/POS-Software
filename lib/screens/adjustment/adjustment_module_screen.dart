import 'package:flutter/material.dart';

class AdjustmentModuleScreen extends StatefulWidget {
  const AdjustmentModuleScreen({super.key});

  @override
  State<AdjustmentModuleScreen> createState() => _AdjustmentModuleScreenState();
}

class _AdjustmentModuleScreenState extends State<AdjustmentModuleScreen> {
  int _selectedIndex = 0;

  static const List<_AdjustmentSection> _sections = <_AdjustmentSection>[
    _AdjustmentSection(title: 'Adjustments', icon: Icons.tune),
    _AdjustmentSection(
      title: 'Adjustment Types',
      icon: Icons.settings_suggest_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Adjustment Module'),
        backgroundColor: const Color(0xFF2563EB),
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
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List<Widget>.generate(_sections.length, (index) {
          final section = _sections[index];

          final selected = index == _selectedIndex;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == 0 ? 6 : 0,
                left: index == 1 ? 6 : 0,
              ),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                avatar: Icon(
                  section.icon,
                  size: 18,
                  color: selected ? Colors.white : const Color(0xFF2563EB),
                ),
                label: Text(section.title),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF374151),
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: const Color(0xFFF3F4F6),
                side: BorderSide.none,
                onSelected: (_) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            ),
          );
        }),
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
                'ADJUSTMENT',
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
        return const _AdjustmentOverview();
      case 1:
        return const _AdjustmentTypesOverview();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _AdjustmentOverview extends StatelessWidget {
  const _AdjustmentOverview();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: EdgeInsets.all(mobile ? 16 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdjustmentHeader(mobile: mobile),
                  const SizedBox(height: 20),
                  const _AdjustmentFilters(),
                  const SizedBox(height: 18),
                  const _AdjustmentEmptyState(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AdjustmentHeader extends StatelessWidget {
  const _AdjustmentHeader({required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final titleBlock = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adjustments',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Create and review cost-based '
          'inventory corrections.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    );

    final button = FilledButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                'New Adjustment form will '
                'be connected next.',
              ),
            ),
          );
      },
      icon: const Icon(Icons.add),
      label: const Text('NEW ADJUSTMENT'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
    );

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: button),
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
                'Adjustments',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Create and review cost-based '
                'inventory corrections.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
        ),
        button,
      ],
    );
  }
}

class _AdjustmentFilters extends StatelessWidget {
  const _AdjustmentFilters();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: const [
          _StatusChip(label: 'All', selected: true),
          _StatusChip(label: 'Draft'),
          _StatusChip(label: 'Submitted'),
          _StatusChip(label: 'Approved'),
          _StatusChip(label: 'Rejected'),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        backgroundColor: selected ? const Color(0xFFDBEAFE) : Colors.white,
        side: BorderSide(
          color: selected ? const Color(0xFF93C5FD) : const Color(0xFFE5E7EB),
        ),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF4B5563),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdjustmentEmptyState extends StatelessWidget {
  const _AdjustmentEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.tune, color: Color(0xFF2563EB), size: 48),
          SizedBox(height: 16),
          Text(
            'No Adjustments Yet',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create an Adjustment to correct '
            'inventory using Cost Price.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), height: 1.45),
          ),
          SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _AdjustmentRuleChip(label: 'Draft → Submitted'),
              _AdjustmentRuleChip(label: 'Approved updates inventory'),
              _AdjustmentRuleChip(label: 'Cost Price only'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdjustmentTypesOverview extends StatelessWidget {
  const _AdjustmentTypesOverview();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Adjustment Types',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Manage configurable Increase '
                'and Decrease adjustment types.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.settings_suggest_outlined,
                      color: Color(0xFF2563EB),
                      size: 44,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Adjustment Types Model Ready',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Firebase repository and '
                      'management actions will be '
                      'connected in the next stage.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B), height: 1.45),
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

class _AdjustmentRuleChip extends StatelessWidget {
  const _AdjustmentRuleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdjustmentSection {
  const _AdjustmentSection({required this.title, required this.icon});

  final String title;
  final IconData icon;
}
