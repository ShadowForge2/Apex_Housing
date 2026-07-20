import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../data/admin_models.dart';
import '../../utils/loading_overlay.dart';
import '../../services/admin_service.dart';

class AdminTransactionsScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const AdminTransactionsScreen({super.key, this.isSuperAdmin = false});

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  bool get _isSuperAdmin => widget.isSuperAdmin;

  int _selectedFilter = 0;
  String _searchQuery = '';
  List<AdminTransaction> _transactions = [];
  bool _isLoading = true;
  String? _error;

  static const _filters = ['All', 'Rent', 'Deposits', 'Fees', 'Withdrawals', 'Disputes'];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await AdminService().listTransactions();
      final data = response['data'];
      if (data != null && mounted) {
        final txList = data['transactions'] as List<dynamic>? ?? [];
        setState(() {
          _transactions = txList.map<AdminTransaction>((t) {
            return AdminTransaction(
              reference: t['reference'] as String? ?? 'TX-0000',
              fromName: t['from_name'] as String? ?? 'Unknown',
              toName: t['to_name'] as String? ?? 'Unknown',
              amount: (t['amount'] as num?)?.toDouble() ?? 0.0,
              type: _parseTransactionType(t['type'] as String? ?? 'rent'),
              status: _parseTransactionStatus(t['status'] as String? ?? 'completed'),
              date: t['date'] as String? ?? '',
              isCredit: t['is_credit'] as bool? ?? true,
            );
          }).toList();
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _transactions = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load transactions. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  TransactionType _parseTransactionType(String type) {
    switch (type.toLowerCase()) {
      case 'deposit': return TransactionType.deposit;
      case 'fee': return TransactionType.fee;
      case 'withdrawal': return TransactionType.withdrawal;
      case 'dispute': return TransactionType.dispute;
      default: return TransactionType.rent;
    }
  }

  TransactionStatus _parseTransactionStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return TransactionStatus.pending;
      case 'failed': return TransactionStatus.failed;
      default: return TransactionStatus.completed;
    }
  }

  List<AdminTransaction> get _filteredTransactions {
    var list = _transactions.toList();

    if (_selectedFilter > 0) {
      final typeMap = {
        1: TransactionType.rent,
        2: TransactionType.deposit,
        3: TransactionType.fee,
        4: TransactionType.withdrawal,
        5: TransactionType.dispute,
      };
      final type = typeMap[_selectedFilter];
      list = list.where((t) => t.type == type).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where(
            (t) =>
                t.fromName.toLowerCase().contains(q) ||
                t.toName.toLowerCase().contains(q) ||
                t.reference.toLowerCase().contains(q) ||
                _typeLabel(t.type).toLowerCase().contains(q),
          )
          .toList();
    }

    return list;
  }

  int _filterCount(int filterIndex) {
    if (filterIndex == 0) return _transactions.length;
    final typeMap = {
      1: TransactionType.rent,
      2: TransactionType.deposit,
      3: TransactionType.fee,
      4: TransactionType.withdrawal,
      5: TransactionType.dispute,
    };
    return _transactions.where((t) => t.type == typeMap[filterIndex]).length;
  }

  void _showDetailSheet(AdminTransaction t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionDetailSheet(
        transaction: t,
        onRefund: () => _handleRefund(t),
        onFlag: () => _handleFlag(t),
        isSuperAdmin: _isSuperAdmin,
      ),
    );
  }

  void _handleRefund(AdminTransaction t) {
    if (!_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Super Admin can issue refunds')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text('Issue Refund', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issue a refund of ₦${_formatAmount(t.amount)} for ${t.reference}?',
              style: const TextStyle(fontSize: 14, color: AppColors.subtitle),
            ),
            const SizedBox(height: 4),
            Text(
              '${t.fromName} → ${t.toName}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.subtitle)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await runWithLoading(
                context,
                action: () async {
                  await Future.delayed(const Duration(milliseconds: 1000));
                  setState(() {
                    final index = _transactions.indexWhere((tx) => tx.reference == t.reference);
                    if (index != -1) {
                      _transactions[index] = AdminTransaction(
                        type: t.type,
                        amount: t.amount,
                        isCredit: !t.isCredit,
                        fromName: t.fromName,
                        toName: t.toName,
                        date: t.date,
                        status: TransactionStatus.refunded,
                        reference: t.reference,
                      );
                    }
                  });
                },
                message: 'Processing refund...',
              );
              if (context.mounted) showAppToast(context, 'Refund issued successfully');
            },
            child: const Text('Refund', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _handleFlag(AdminTransaction t) async {
    await runWithLoading(
      context,
      action: () async {
        await Future.delayed(const Duration(milliseconds: 600));
        setState(() {
          final index = _transactions.indexWhere((tx) => tx.reference == t.reference);
          if (index != -1) {
            _transactions[index] = AdminTransaction(
              type: TransactionType.dispute,
              amount: t.amount,
              isCredit: t.isCredit,
              fromName: t.fromName,
              toName: t.toName,
              date: t.date,
              status: TransactionStatus.pending,
              reference: t.reference,
            );
          }
        });
      },
      message: 'Flagging transaction...',
    );
    if (context.mounted) {
      showAppToast(context, 'Transaction ${t.reference} flagged for review', backgroundColor: AppColors.warning);
    }
  }

  IconData _typeIcon(TransactionType type) => switch (type) {
    TransactionType.rent => Icons.home_outlined,
    TransactionType.deposit => Icons.savings_outlined,
    TransactionType.fee => Icons.payments_outlined,
    TransactionType.withdrawal => Icons.account_balance_outlined,
    TransactionType.dispute => Icons.warning_amber_outlined,
  };

  Color _typeColor(TransactionType type) => switch (type) {
    TransactionType.rent => AppColors.primary,
    TransactionType.deposit => AppColors.success,
    TransactionType.fee => AppColors.warning,
    TransactionType.withdrawal => const Color(0xFF3B82F6),
    TransactionType.dispute => AppColors.error,
  };

  Color _statusColor(TransactionStatus status) => switch (status) {
    TransactionStatus.completed => AppColors.success,
    TransactionStatus.pending => AppColors.warning,
    TransactionStatus.failed => AppColors.error,
    TransactionStatus.refunded => AppColors.primary,
  };

  Color _statusBg(TransactionStatus status) => switch (status) {
    TransactionStatus.completed => AppColors.successLight,
    TransactionStatus.pending => AppColors.warningLight,
    TransactionStatus.failed => AppColors.errorLight,
    TransactionStatus.refunded => AppColors.lightPurple,
  };

  String _statusLabel(TransactionStatus status) => switch (status) {
    TransactionStatus.completed => 'Completed',
    TransactionStatus.pending => 'Pending',
    TransactionStatus.failed => 'Failed',
    TransactionStatus.refunded => 'Refunded',
  };

  String _typeLabel(TransactionType type) => switch (type) {
    TransactionType.rent => 'Rent',
    TransactionType.deposit => 'Deposit',
    TransactionType.fee => 'Platform Fee',
    TransactionType.withdrawal => 'Withdrawal',
    TransactionType.dispute => 'Dispute',
  };

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buf.write(',');
      buf.write(parts[i]);
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
                  onPressed: () => setState(() { _isLoading = true; _error = null; _fetchTransactions(); }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final transactions = _filteredTransactions;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Transactions', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5)),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            child: _SummaryCards(transactions: _transactions),
          ),
          const SizedBox(height: 12),
          Container(
            color: AppColors.background,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name, reference...',
                hintStyle: const TextStyle(color: AppColors.hint, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.hint),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() => _searchQuery = ''),
                        child: const Icon(Icons.close, size: 18, color: AppColors.hint),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
          Container(
            height: 40,
            color: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final selected = _selectedFilter == i;
                final count = _filterCount(i);
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${_filters[i]} ($count)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.textWhite : AppColors.subtitle,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 56, color: AppColors.hint),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No transactions match your search' : 'No transactions found',
                          style: const TextStyle(fontSize: 15, color: AppColors.subtitle),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchTransactions,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final t = transactions[i];
                        final color = _typeColor(t.type);
                        return GestureDetector(
                          onTap: () => _showDetailSheet(t),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              boxShadow: AppShadow.minimal,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Icon(_typeIcon(t.type), size: 20, color: color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _typeLabel(t.type),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.text,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${t.isCredit ? '+' : '-'}₦${_formatAmount(t.amount)}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: t.isCredit ? AppColors.success : AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${t.fromName}  →  ${t.toName}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.subtitle),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            t.date,
                                            style: const TextStyle(fontSize: 11, color: AppColors.hint),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _statusBg(t.status),
                                              borderRadius: BorderRadius.circular(AppRadius.pill),
                                            ),
                                            child: Text(
                                              _statusLabel(t.status),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _statusColor(t.status),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            t.reference,
                                            style: const TextStyle(fontSize: 10, color: AppColors.hint),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right, size: 18, color: AppColors.hint),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final List<AdminTransaction> transactions;
  const _SummaryCards({required this.transactions});

  String _fmt(double v) {
    final parts = v.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buf.write(',');
      buf.write(parts[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    double totalVolume = 0;
    double platformFees = 0;
    int pendingDisputes = 0;
    double refunds = 0;
    for (final t in transactions) {
      totalVolume += t.amount;
      if (t.type == TransactionType.fee) platformFees += t.amount;
      if (t.type == TransactionType.dispute && t.status == TransactionStatus.pending) pendingDisputes++;
      if (t.status == TransactionStatus.refunded) refunds += t.amount;
    }
    return Row(
      children: [
        _card('Total Volume', '₦${_fmt(totalVolume)}', Icons.trending_up, AppColors.primary),
        const SizedBox(width: 10),
        _card('Platform Fees', '₦${_fmt(platformFees)}', Icons.account_balance, AppColors.warning),
        const SizedBox(width: 10),
        _card('Disputes', '$pendingDisputes', Icons.gavel, AppColors.error),
        const SizedBox(width: 10),
        _card('Refunds', '₦${_fmt(refunds)}', Icons.replay, AppColors.subtitle),
      ],
    );
  }

  Widget _card(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.subtitle),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionDetailSheet extends StatelessWidget {
  final AdminTransaction transaction;
  final VoidCallback onRefund;
  final VoidCallback onFlag;
  final bool isSuperAdmin;

  const _TransactionDetailSheet({
    required this.transaction,
    required this.onRefund,
    required this.onFlag,
    this.isSuperAdmin = true,
  });

  Color _statusColor(TransactionStatus status) => switch (status) {
    TransactionStatus.completed => AppColors.success,
    TransactionStatus.pending => AppColors.warning,
    TransactionStatus.failed => AppColors.error,
    TransactionStatus.refunded => AppColors.primary,
  };

  Color _statusBg(TransactionStatus status) => switch (status) {
    TransactionStatus.completed => AppColors.successLight,
    TransactionStatus.pending => AppColors.warningLight,
    TransactionStatus.failed => AppColors.errorLight,
    TransactionStatus.refunded => AppColors.lightPurple,
  };

  String _statusLabel(TransactionStatus status) => switch (status) {
    TransactionStatus.completed => 'Completed',
    TransactionStatus.pending => 'Pending',
    TransactionStatus.failed => 'Failed',
    TransactionStatus.refunded => 'Refunded',
  };

  String _typeLabel(TransactionType type) => switch (type) {
    TransactionType.rent => 'Rent Payment',
    TransactionType.deposit => 'Security Deposit',
    TransactionType.fee => 'Platform Fee',
    TransactionType.withdrawal => 'Withdrawal',
    TransactionType.dispute => 'Dispute',
  };

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(0).split('');
    final buf = StringBuffer();
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) buf.write(',');
      buf.write(parts[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final sColor = _statusColor(t.status);
    final sBg = _statusBg(t.status);

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.reference,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: sBg,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      _statusLabel(t.status),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${t.isCredit ? '+' : '-'}₦${_formatAmount(t.amount)}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: t.isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              _detailTile('Type', _typeLabel(t.type), Icons.category_outlined),
              _detailTile('From', t.fromName, Icons.arrow_upward_outlined),
              _detailTile('To', t.toName, Icons.arrow_downward_outlined),
              _detailTile('Date', t.date, Icons.calendar_today_outlined),
              _detailTile('Reference', t.reference, Icons.tag),
              _detailTile('Direction', t.isCredit ? 'Credit (Incoming)' : 'Debit (Outgoing)', Icons.swap_vert),
              const SizedBox(height: 16),
              if (t.status == TransactionStatus.completed || t.status == TransactionStatus.pending) ...[
                Row(
                  children: [
                    if (isSuperAdmin)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            onRefund();
                          },
                          icon: const Icon(Icons.replay, size: 18),
                          label: const Text('Issue Refund'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                          ),
                        ),
                      ),
                    if (isSuperAdmin) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onFlag();
                        },
                        icon: const Icon(Icons.flag_outlined, size: 18),
                        label: const Text('Flag for Review'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _detailTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.subtitle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.hint)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
