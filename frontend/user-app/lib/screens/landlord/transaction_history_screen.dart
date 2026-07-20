import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/payment_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  int _selectedFilter = 0;
  final _filters = ['All', 'Income', 'Expenses', 'Pending'];
  bool _isLoading = true;
  String? _error;
  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final transactions = await PaymentService().listTransactions();
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _selectedFilter == 0
        ? _transactions
        : _selectedFilter == 1
            ? _transactions.where((t) => (t.amount ?? 0) > 0).toList()
            : _selectedFilter == 2
                ? _transactions.where((t) => (t.amount ?? 0) < 0).toList()
                : _transactions.where((t) => t.status == 'pending').toList();

    final totalIncome = _transactions
        .where((t) => (t.amount ?? 0) > 0)
        .fold<double>(0, (sum, t) => sum + (t.amount ?? 0));
    final totalExpenses = _transactions
        .where((t) => (t.amount ?? 0) < 0)
        .fold<double>(0, (sum, t) => sum + (t.amount ?? 0).abs());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaction History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: ApexLoading())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.subtitle)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _loadTransactions, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: _buildSummaryRow(totalIncome, totalExpenses),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: List.generate(_filters.length, (i) {
                            final active = _selectedFilter == i;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedFilter = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: active ? AppColors.primary : Colors.transparent,
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _filters[i],
                                    style: TextStyle(
                                      color: active ? Colors.white : AppColors.subtitle,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                                    child: const Icon(Icons.receipt_long_rounded, size: 32, color: AppColors.hint),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('No transactions found', style: TextStyle(color: AppColors.subtitle, fontSize: 15)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadTransactions,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (_, i) => _TransactionCard(txn: filtered[i]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryRow(double income, double expenses) {
    return Row(
      children: [
        Expanded(child: _summaryCard('Total Income', income, AppColors.success, Icons.arrow_downward_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _summaryCard('Total Expenses', expenses, AppColors.error, Icons.arrow_upward_rounded)),
      ],
    );
  }

  Widget _summaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.subtitle)),
            ],
          ),
          const SizedBox(height: 10),
          Text('₦${_formatAmount(amount.toInt())}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toString();
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel txn;
  const _TransactionCard({required this.txn});

  @override
  Widget build(BuildContext context) {
    final amount = txn.amount ?? 0;
    final isCredit = amount > 0;
    final status = txn.status ?? 'pending';
    final type = txn.type ?? 'rent';
    final dateStr = txn.createdAt ?? '';
    final displayDate = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _typeColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_typeIcon(type), size: 22, color: _typeColor(type)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.description ?? txn.reference ?? 'Transaction',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(displayDate, style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}₦${_formatFull(amount.toInt())}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isCredit ? AppColors.success : AppColors.error),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'completed' ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  status == 'completed' ? 'Completed' : 'Pending',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: status == 'completed' ? AppColors.success : AppColors.warning),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFull(int amount) {
    final abs = amount.abs();
    final str = abs.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'rent':
        return AppColors.success;
      case 'deposit':
        return AppColors.primary;
      case 'maintenance':
        return AppColors.warning;
      case 'fee':
        return AppColors.error;
      case 'withdrawal':
        return AppColors.subtitle;
      default:
        return AppColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'rent':
        return Icons.home_work_rounded;
      case 'deposit':
        return Icons.savings_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'fee':
        return Icons.payments_rounded;
      case 'withdrawal':
        return Icons.account_balance_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }
}
