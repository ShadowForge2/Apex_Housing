import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../widgets/apex_loading.dart';
import '../../services/payment_service.dart';
import 'transaction_history_screen.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool _isLoading = true;
  String? _error;
  WalletModel? _wallet;
  List<TransactionModel> _transactions = [];
  List<Map<String, dynamic>> _withdrawals = [];
  List<Map<String, dynamic>> _bankAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await Future.wait([
        PaymentService().getWallet(),
        PaymentService().listTransactions(),
        PaymentService().listWithdrawals(),
        PaymentService().listMyBankAccounts(),
      ]);
      if (mounted) {
        setState(() {
          _wallet = results[0] as WalletModel;
          _transactions = results[1] as List<TransactionModel>;
          final wdData = results[2] as Map<String, dynamic>;
          _withdrawals = List<Map<String, dynamic>>.from(wdData['withdrawals'] ?? []);
          _bankAccounts = results[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _showWithdrawSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(
        balance: _wallet?.balance ?? 0,
        bankAccounts: _bankAccounts,
        onSuccess: () {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Withdrawal submitted successfully')),
          );
        },
      ),
    );
  }

  String _formatCompact(num amount) {
    if (amount >= 1000000) return '₦${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '₦${(amount / 1000).toStringAsFixed(0)}K';
    return '₦${amount.toStringAsFixed(0)}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings & Payouts'),
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
                      TextButton(onPressed: _loadData, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildBalanceCard(),
                        const SizedBox(height: 20),
                        _buildStatsRow(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Pending Withdrawals'),
                        const SizedBox(height: 12),
                        _buildPendingWithdrawals(),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Earnings History'),
                        const SizedBox(height: 14),
                        _buildEarningsChart(),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSectionTitle('Recent Payouts'),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
                              child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildPayoutsList(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildBalanceCard() {
    final balance = _wallet?.balance ?? 0;
    final pending = _wallet?.pendingBalance ?? 0;
    final balanceStr = _formatCompact(balance);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(blurRadius: 20, color: AppColors.primary.withValues(alpha: 0.3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Balance', style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(balanceStr, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
          if (pending > 0) ...[
            const SizedBox(height: 6),
            Text('₦${_formatFull(pending.toInt())} pending', style: const TextStyle(fontSize: 12, color: Colors.white54)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              _balanceAction('Withdraw', Icons.account_balance_rounded, _wallet != null && (_wallet!.balance) > 0 ? _showWithdrawSheet : null),
              const SizedBox(width: 14),
              _balanceAction('View History', Icons.receipt_long_rounded, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _balanceAction(String label, IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: enabled ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: enabled ? Colors.white : Colors.white38)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final earned = _wallet?.totalEarned ?? 0;
    final withdrawn = _wallet?.totalWithdrawn ?? 0;
    return Row(
      children: [
        _statCard('Total Earned', '₦${_formatFull(earned.toInt())}', AppColors.success, Icons.trending_up_rounded),
        const SizedBox(width: 12),
        _statCard('Withdrawn', '₦${_formatFull(withdrawn.toInt())}', AppColors.primary, Icons.account_balance_rounded),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.hint)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3));
  }

  Widget _buildPendingWithdrawals() {
    final pending = _withdrawals.where((w) => w['status'] == 'pending' || w['status'] == 'scheduled' || w['status'] == 'processing').toList();
    if (pending.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadow.soft,
        ),
        child: const Center(child: Text('No pending withdrawals', style: TextStyle(color: AppColors.hint, fontSize: 14))),
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
        itemCount: pending.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.border),
        itemBuilder: (_, i) {
          final w = pending[i];
          final amount = (w['amount'] ?? 0).toDouble();
          final status = w['status'] ?? '';
          final bankName = w['bank_name'] ?? '';
          final accountName = w['account_name'] ?? '';
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: status == 'processing' ? AppColors.warning.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    status == 'processing' ? Icons.sync_rounded : Icons.schedule_rounded,
                    size: 20,
                    color: status == 'processing' ? AppColors.warning : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₦${_formatFull(amount.toInt())}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text('$accountName • $bankName', style: const TextStyle(fontSize: 12, color: AppColors.hint), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (status == 'processing' ? AppColors.warning : AppColors.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'processing' ? 'Processing' : 'Scheduled',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: status == 'processing' ? AppColors.warning : AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEarningsChart() {
    final completedTxns = _transactions.where((t) => t.status == 'SUCCESS' && (t.amount) > 0).toList();
    final monthlyEarnings = <String, double>{};
    for (final txn in completedTxns) {
      final dateStr = txn.createdAt ?? '';
      final month = dateStr.length >= 7 ? dateStr.substring(0, 7) : 'Unknown';
      monthlyEarnings[month] = (monthlyEarnings[month] ?? 0) + (txn.amount).toDouble();
    }
    final sortedMonths = monthlyEarnings.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
    final recentMonths = sortedMonths.take(6).toList().reversed.toList();
    final maxAmount = recentMonths.fold<double>(0, (max, e) => e.value > max ? e.value : max);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: recentMonths.isEmpty
          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('No earnings data yet', style: TextStyle(color: AppColors.hint))))
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: recentMonths.map((entry) {
                final barHeight = maxAmount > 0 ? (entry.value / maxAmount) * 120 : 0.0;
                final label = entry.key.length >= 5 ? entry.key.substring(5, 7) : entry.key;
                final amountStr = _formatCompact(entry.value);
                return Column(
                  children: [
                    Text(amountStr, style: const TextStyle(fontSize: 10, color: AppColors.hint)),
                    const SizedBox(height: 6),
                    Container(
                      width: 32, height: barHeight,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    ),
                    const SizedBox(height: 8),
                    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.subtitle, fontWeight: FontWeight.w500)),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPayoutsList() {
    final completedTxns = _transactions.where((t) => t.status == 'SUCCESS').toList().take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadow.soft,
      ),
      child: completedTxns.isEmpty
          ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No payouts yet', style: TextStyle(color: AppColors.hint))))
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: completedTxns.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.border),
              itemBuilder: (_, i) {
                final t = completedTxns[i];
                final amount = t.amount;
                final amountStr = amount >= 0 ? '₦${_formatFull(amount.toInt())}' : '-₦${_formatFull(amount.toInt().abs())}';
                final dateStr = t.createdAt ?? '';
                final displayDate = dateStr.length >= 10 ? dateStr.substring(0, 10) : dateStr;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.account_balance_rounded, size: 20, color: AppColors.success),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(amountStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(height: 2),
                            Text('$displayDate • ${t.reference ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: const Text('Paid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ── Withdrawal Bottom Sheet ──

class _WithdrawSheet extends StatefulWidget {
  final num balance;
  final List<Map<String, dynamic>> bankAccounts;
  final VoidCallback onSuccess;

  const _WithdrawSheet({required this.balance, required this.bankAccounts, required this.onSuccess});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  bool _isProcessing = false;
  bool _isCheckingBusinessDay = true;
  bool _canWithdrawNow = true;
  String _businessDayMessage = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBusinessDay();
    final defaultAcc = widget.bankAccounts.firstWhere(
      (a) => a['is_default'] == true,
      orElse: () => widget.bankAccounts.isNotEmpty ? widget.bankAccounts.first : {},
    );
    if (defaultAcc.isNotEmpty) {
      _selectedAccountId = defaultAcc['id']?.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _checkBusinessDay() async {
    try {
      final result = await PaymentService().checkBusinessDay();
      if (mounted) {
        setState(() {
          _canWithdrawNow = result['can_withdraw'] ?? true;
          _businessDayMessage = result['message']?.toString() ?? '';
          _isCheckingBusinessDay = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingBusinessDay = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedAccountId == null) {
      setState(() => _error = 'Please select a bank account');
      return;
    }
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      setState(() => _error = 'Please enter an amount');
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }
    if (amount > widget.balance.toDouble()) {
      setState(() => _error = 'Insufficient balance');
      return;
    }
    if (amount < 100) {
      setState(() => _error = 'Minimum withdrawal is ₦100');
      return;
    }

    setState(() { _isProcessing = true; _error = null; });
    try {
      await PaymentService().requestWithdrawal(
        bankAccountId: _selectedAccountId!,
        amount: amount,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isProcessing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Withdraw Funds', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 6),
          Text('Available: ₦${widget.balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, color: AppColors.subtitle)),
          const SizedBox(height: 20),

          if (!_isCheckingBusinessDay && !_canWithdrawNow && _businessDayMessage.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_businessDayMessage, style: const TextStyle(fontSize: 12, color: AppColors.warning)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text('Amount (₦)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            decoration: InputDecoration(
              hintText: 'Enter amount',
              prefixText: '₦ ',
              prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 20),

          const Text('Withdraw to', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 8),
          if (widget.bankAccounts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
              child: const Text('No bank account added. Please add one in Settings.', style: TextStyle(fontSize: 13, color: AppColors.hint)),
            )
          else
            ...widget.bankAccounts.map((a) {
              final isSelected = a['id']?.toString() == _selectedAccountId;
              return GestureDetector(
                onTap: () => setState(() { _selectedAccountId = a['id']?.toString(); _error = null; }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_rounded, size: 20, color: isSelected ? AppColors.primary : AppColors.subtitle),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['account_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                            const SizedBox(height: 2),
                            Text('${a['bank_name'] ?? ''} • ${a['account_number'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.hint)),
                          ],
                        ),
                      ),
                      if (isSelected) const Icon(Icons.check_circle_rounded, size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            }),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.error)),
          ],
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Withdraw', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
