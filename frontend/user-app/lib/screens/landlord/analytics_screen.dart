import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/api_client.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _client = ApiClient.instance;
  bool _isLoading = true;

  Map<String, dynamic> _summary = {};
  List<dynamic> _monthlyRevenue = [];
  List<dynamic> _properties = [];
  Map<String, dynamic> _occupancy = {};
  List<dynamic> _insights = [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _client.get('/landlords/analytics/summary'),
        _client.get('/landlords/analytics/revenue'),
        _client.get('/landlords/analytics/properties'),
        _client.get('/landlords/analytics/occupancy'),
        _client.get('/landlords/analytics/insights'),
      ]);

      final summaryData = results[0].data as Map<String, dynamic>;
      final revenueData = results[1].data as Map<String, dynamic>;
      final propertiesData = results[2].data as Map<String, dynamic>;
      final occupancyData = results[3].data as Map<String, dynamic>;
      final insightsData = results[4].data as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _summary = summaryData['data'] as Map<String, dynamic>? ?? {};
          _monthlyRevenue = (revenueData['data'] as Map<String, dynamic>? ?? {})['monthlyRevenue'] as List<dynamic>? ?? [];
          _properties = (propertiesData['data'] as Map<String, dynamic>? ?? {})['properties'] as List<dynamic>? ?? [];
          _occupancy = occupancyData['data'] as Map<String, dynamic>? ?? {};
          _insights = (insightsData['data'] as Map<String, dynamic>? ?? {})['insights'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildSummaryCards(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Revenue Overview'),
                  const SizedBox(height: 14),
                  _buildRevenueChart(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Property Performance'),
                  const SizedBox(height: 14),
                  _buildPropertyList(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Occupancy Rates'),
                  const SizedBox(height: 14),
                  _buildOccupancySection(),
                  const SizedBox(height: 28),
                  _buildSectionTitle('Key Insights'),
                  const SizedBox(height: 14),
                  _buildInsights(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3));
  }

  String _formatCurrency(dynamic value) {
    final amount = (value is num) ? value.toInt() : 0;
    if (amount >= 1000000) return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '₦${(amount / 1000).toStringAsFixed(0)}K';
    return '₦$amount';
  }

  Widget _buildSummaryCards() {
    final totalRevenue = _summary['totalRevenue'] ?? 0;
    final avgMonthly = _summary['avgMonthly'] ?? 0;
    final occupancyRate = _summary['occupancyRate'] ?? 0;
    final growthPercent = _summary['growthPercent'] ?? 0;

    final cards = [
      {'label': 'Total Revenue', 'value': _formatCurrency(totalRevenue), 'icon': Icons.account_balance_wallet_rounded, 'color': AppColors.primary},
      {'label': 'Avg Monthly', 'value': _formatCurrency(avgMonthly), 'icon': Icons.trending_up_rounded, 'color': AppColors.success},
      {'label': 'Occupancy', 'value': '$occupancyRate%', 'icon': Icons.home_work_outlined, 'color': AppColors.warning},
      {'label': 'Growth', 'value': '$growthPercent%', 'icon': Icons.show_chart_rounded, 'color': growthPercent >= 0 ? AppColors.success : AppColors.error},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) {
        final c = cards[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: AppShadow.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (c['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(c['icon'] as IconData, size: 18, color: c['color'] as Color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['value'] as String,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(c['label'] as String,
                      style: const TextStyle(fontSize: 12, color: AppColors.subtitle)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevenueChart() {
    final data = _monthlyRevenue;
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.soft,
        ),
        child: const Center(child: Text('No revenue data yet', style: TextStyle(color: AppColors.subtitle))),
      );
    }
    final maxAmount = data.fold<int>(0, (max, e) {
      final v = ((e as Map<String, dynamic>)['amount'] as int?) ?? 0;
      return v > max ? v : max;
    });
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Last 12 Months', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Text('Monthly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (i) {
                final d = data[i] as Map<String, dynamic>;
                final amount = (d['amount'] as int?) ?? 0;
                final barHeight = maxAmount > 0 ? (amount / maxAmount) * 140.0 : 0.0;
                final isCurrentMonth = i == data.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(d['label'] as String? ?? '',
                            style: const TextStyle(fontSize: 8, color: AppColors.hint)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: isCurrentMonth ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(d['month'] as String? ?? '',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: isCurrentMonth ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrentMonth ? AppColors.primary : AppColors.subtitle)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList() {
    if (_properties.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.soft,
        ),
        child: const Center(child: Text('No properties yet', style: TextStyle(color: AppColors.subtitle))),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _properties.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.border),
        itemBuilder: (_, i) {
          final p = _properties[i] as Map<String, dynamic>;
          final occupancy = (p['occupancy'] as int?) ?? 0;
          final status = (p['status'] as String?) ?? 'vacant';
          final statusColor = status == 'occupied' ? AppColors.success : AppColors.warning;
          final maxRevenue = _properties.fold<int>(0, (max, e) {
            final v = ((e as Map<String, dynamic>)['revenueRaw'] as int?) ?? 0;
            return v > max ? v : max;
          });
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_propertyIcon(p['type'] as String? ?? ''), size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['name'] as String? ?? '',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                          const SizedBox(height: 2),
                          Text(p['revenue'] as String? ?? '',
                              style: const TextStyle(fontSize: 12, color: AppColors.subtitle)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(status == 'occupied' ? 'Occupied' : 'Vacant',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _propertyStat(Icons.visibility_outlined, '${p['views'] ?? 0} views'),
                    const SizedBox(width: 16),
                    _propertyStat(Icons.chat_bubble_outline_rounded, '${p['inquiries'] ?? 0} inquiries'),
                    const Spacer(),
                    Text('$occupancy%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: occupancy >= 80 ? AppColors.success : AppColors.warning)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: occupancy / 100,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(
                        occupancy >= 80 ? AppColors.success : AppColors.warning),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _propertyStat(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.hint),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: AppColors.hint)),
      ],
    );
  }

  IconData _propertyIcon(String type) {
    switch (type) {
      case 'house':
        return Icons.house_rounded;
      case 'studio':
        return Icons.apartment_rounded;
      default:
        return Icons.home_work_outlined;
    }
  }

  Widget _buildOccupancySection() {
    final avgOccupancy = (_occupancy['avgOccupancy'] as int?) ?? 0;
    final occupiedUnits = (_occupancy['occupiedUnits'] as String?) ?? '0 units';
    final vacantUnits = (_occupancy['vacantUnits'] as String?) ?? '0 units';
    final totalProperties = (_occupancy['totalProperties'] as String?) ?? '0 properties';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: avgOccupancy / 100,
                        strokeWidth: 10,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation(AppColors.success),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$avgOccupancy%',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
                        const Text('Avg',
                            style: TextStyle(fontSize: 11, color: AppColors.hint)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _occupancyRow('Occupied', occupiedUnits, AppColors.success),
                    const SizedBox(height: 10),
                    _occupancyRow('Vacant', vacantUnits, AppColors.warning),
                    const SizedBox(height: 10),
                    _occupancyRow('Total', totalProperties, AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _occupancyRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.subtitle)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
      ],
    );
  }

  Widget _buildInsights() {
    if (_insights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.soft,
        ),
        child: const Center(child: Text('No insights yet', style: TextStyle(color: AppColors.subtitle))),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _insights.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 60, color: AppColors.border),
        itemBuilder: (_, i) {
          final ins = _insights[i] as Map<String, dynamic>;
          final color = _insightColor(ins['color'] as String? ?? 'primary');
          final icon = _insightIcon(ins['icon'] as String? ?? 'info');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ins['title'] as String? ?? '',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 4),
                      Text(ins['subtitle'] as String? ?? '',
                          style: const TextStyle(fontSize: 12, color: AppColors.hint, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _insightColor(String color) {
    switch (color) {
      case 'success': return AppColors.success;
      case 'warning': return AppColors.warning;
      case 'error': return AppColors.error;
      default: return AppColors.primary;
    }
  }

  IconData _insightIcon(String icon) {
    switch (icon) {
      case 'trending_up': return Icons.trending_up_rounded;
      case 'home_work': return Icons.home_work_outlined;
      case 'speed': return Icons.speed_rounded;
      case 'check_circle': return Icons.check_circle_rounded;
      case 'lightbulb': return Icons.lightbulb_rounded;
      default: return Icons.info_outline_rounded;
    }
  }
}
