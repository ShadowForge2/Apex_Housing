import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/admin_commission_service.dart';

class PlatformDeduction {
  final String id;
  final String propertyName;
  final String landlordName;
  final String bookingRef;
  final double amount;
  final double platformFee;
  final double agentCommission;
  final String status;
  final DateTime? date;
  final bool isReleased;
  const PlatformDeduction({
    required this.id,
    required this.propertyName,
    required this.landlordName,
    required this.bookingRef,
    required this.amount,
    required this.platformFee,
    required this.agentCommission,
    required this.status,
    this.date,
    required this.isReleased,
  });
}

class AdminCommissionScreen extends StatefulWidget {
  const AdminCommissionScreen({super.key});

  @override
  State<AdminCommissionScreen> createState() => _AdminCommissionScreenState();
}

class _AdminCommissionScreenState extends State<AdminCommissionScreen> {
  int _selectedFilter = 0;
  static const _filters = ['All', 'Released', 'Held'];
  bool _isLoading = true;
  String? _error;

  double _feePercentage = 10.0;
  List<PlatformDeduction> _deductions = [];
  double _totalPlatformFee = 0;
  double _totalAgentCommission = 0;
  double _totalAmount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final response = await AdminCommissionService().getPlatformDeductions();
      final data = response['data'];
      if (mounted && data != null) {
        setState(() {
          _feePercentage = (data['fee_percentage'] as num?)?.toDouble() ?? 10.0;
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          _totalPlatformFee = (summary['total_platform_fee'] as num?)?.toDouble() ?? 0;
          _totalAgentCommission = (summary['total_agent_commission'] as num?)?.toDouble() ?? 0;
          _totalAmount = (summary['total_amount'] as num?)?.toDouble() ?? 0;
          _totalCount = (summary['count'] as int?) ?? 0;

          final list = data['deductions'] as List<dynamic>? ?? [];
          _deductions = list.map<PlatformDeduction>((d) => PlatformDeduction(
            id: d['id'] as String? ?? '',
            propertyName: d['property_name'] as String? ?? '',
            landlordName: d['landlord_name'] as String? ?? '',
            bookingRef: d['booking_ref'] as String? ?? '',
            amount: (d['amount'] as num?)?.toDouble() ?? 0,
            platformFee: (d['platform_fee'] as num?)?.toDouble() ?? 0,
            agentCommission: (d['agent_commission'] as num?)?.toDouble() ?? 0,
            status: d['status'] as String? ?? '',
            date: DateTime.tryParse(d['date'] as String? ?? ''),
            isReleased: d['is_released'] as bool? ?? false,
          )).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load commission data. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<PlatformDeduction> get _filteredDeductions {
    if (_selectedFilter == 0) return _deductions;
    if (_selectedFilter == 1) return _deductions.where((d) => d.isReleased).toList();
    if (_selectedFilter == 2) return _deductions.where((d) => !d.isReleased).toList();
    return _deductions;
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 15, color: AppColors.subtitle), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchData(); }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
              child: Text('Platform Commission', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
            ),
            const SizedBox(height: 16),
            _buildFeeBanner(),
            _buildSummaryCards(),
            _buildDeductionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.percent, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current Platform Fee', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 2),
                Text('$_feePercentage%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text('Auto-deducted on escrow release', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9))),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _summaryCard('Platform Earnings', '₦${_fmt(_totalPlatformFee)}', Icons.account_balance_wallet_outlined, AppColors.primary),
          const SizedBox(width: 10),
          _summaryCard('Agent Payouts', '₦${_fmt(_totalAgentCommission)}', Icons.person_outline, AppColors.warning),
          const SizedBox(width: 10),
          _summaryCard('Total Volume', '₦${_fmt(_totalAmount)}', Icons.trending_up, AppColors.success),
          const SizedBox(width: 10),
          _summaryCard('Transactions', '$_totalCount', Icons.receipt_long_outlined, AppColors.secondary),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.subtitle), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDeductionsSection() {
    final deductions = _filteredDeductions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Commission Deductions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = _selectedFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(_filters[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? AppColors.textWhite : AppColors.subtitle)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (deductions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.hint),
                  const SizedBox(height: 8),
                  const Text('No deductions yet', style: TextStyle(fontSize: 14, color: AppColors.subtitle)),
                  const SizedBox(height: 4),
                  const Text('Commission is recorded when escrow funds are released', style: TextStyle(fontSize: 12, color: AppColors.hint)),
                ],
              ),
            )
          else
            ...deductions.map((d) => _buildDeductionCard(d)),
        ],
      ),
    );
  }

  Widget _buildDeductionCard(PlatformDeduction d) {
    final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = d.date != null ? '${months[d.date!.month]} ${d.date!.day}, ${d.date!.year}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadow.minimal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.home_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.propertyName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${d.landlordName}  ·  ${d.bookingRef}', style: const TextStyle(fontSize: 11, color: AppColors.hint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: d.isReleased ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(d.isReleased ? 'Released' : 'Held', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: d.isReleased ? AppColors.success : AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platform Fee', style: TextStyle(fontSize: 10, color: AppColors.hint)),
                      const SizedBox(height: 2),
                      Text('₦${_fmt(d.platformFee)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agent Commission', style: TextStyle(fontSize: 10, color: AppColors.hint)),
                      const SizedBox(height: 2),
                      Text('₦${_fmt(d.agentCommission)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warning)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Escrow Amount', style: TextStyle(fontSize: 10, color: AppColors.hint)),
                    const SizedBox(height: 2),
                    Text('₦${_fmt(d.amount)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ],
                ),
              ],
            ),
          ),
          if (dateStr.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.hint)),
          ],
        ],
      ),
    );
  }
}
