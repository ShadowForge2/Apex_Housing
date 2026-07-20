import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/payment_service.dart';
import '../../widgets/apex_loading.dart';
import 'signature_screen.dart';

class BankAccountScreen extends StatefulWidget {
  final bool isPostSignup;
  const BankAccountScreen({super.key, this.isPostSignup = false});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final PaymentService _paymentService = PaymentService();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  String? _resolvedAccountName;
  bool _isVerifying = false;
  bool _isSaving = false;
  bool _verified = false;
  bool _loadingBanks = true;
  bool _hasExistingAccount = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _checkExistingAccount();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await _paymentService.listBanks();
      setState(() {
        _banks = banks;
        _loadingBanks = false;
      });
    } catch (e) {
      setState(() {
        _loadingBanks = false;
        _error = 'Failed to load banks';
      });
    }
  }

  Future<void> _checkExistingAccount() async {
    try {
      final accounts = await _paymentService.listMyBankAccounts();
      if (accounts.isNotEmpty) {
        setState(() => _hasExistingAccount = true);
      }
    } catch (e) {
      debugPrint('BankAccount: Failed to check existing account: $e');
    }
  }

  Future<void> _verifyAccount() async {
    if (_accountController.text.length != 10 || _selectedBank == null) return;

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final result = await _paymentService.verifyBankAccount(
        _accountController.text,
        _selectedBank!['code'] ?? '',
      );

      if (result['verified'] == true && result['account_name'] != null) {
        setState(() {
          _resolvedAccountName = result['account_name'];
          _nameController.text = result['account_name'];
          _verified = true;
          _isVerifying = false;
        });
      } else {
        setState(() {
          _verified = false;
          _resolvedAccountName = null;
          _isVerifying = false;
          _error = 'Account not found. Please check details.';
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _verified = false;
        _error = 'Verification failed. Try again.';
      });
    }
  }

  Future<void> _saveBankAccount() async {
    if (!_verified || _selectedBank == null || _accountController.text.length != 10) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _paymentService.addBankAccount(
        bankName: _selectedBank!['name'] ?? '',
        bankCode: _selectedBank!['code'] ?? '',
        accountNumber: _accountController.text,
        accountName: _nameController.text,
        isDefault: true,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account saved successfully'), backgroundColor: Colors.green),
        );

        if (widget.isPostSignup) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SignatureScreen(isPostSignup: true)),
            (route) => route.isFirst,
          );
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'Failed to save bank account. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Account Details'),
        leading: widget.isPostSignup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.of(context).pop(),
              ),
        automaticallyImplyLeading: !widget.isPostSignup,
      ),
      body: _loadingBanks
          ? const Center(child: ApexLoading())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isPostSignup) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance, color: theme.colorScheme.primary, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add your bank account for receiving payments and refunds',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (_hasExistingAccount && !widget.isPostSignup) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text('You already have a bank account on file',
                                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    Text('Select Bank', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          isExpanded: true,
                          value: _selectedBank,
                          hint: Text('Choose your bank',
                              style: TextStyle(color: Colors.grey[500])),
                          items: _banks.map((bank) {
                            return DropdownMenuItem(
                              value: bank,
                              child: Text(bank['name'] ?? '', style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedBank = val;
                              _verified = false;
                              _resolvedAccountName = null;
                              _nameController.clear();
                            });
                            if (_accountController.text.length == 10) _verifyAccount();
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text('Account Number', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _accountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      decoration: InputDecoration(
                        hintText: 'Enter 10-digit account number',
                        prefixIcon: const Icon(Icons.credit_card),
                        suffixIcon: _isVerifying
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: ApexLoading(size: 18),
                              )
                            : _verified
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                      ),
                      onChanged: (val) {
                        setState(() {
                          _verified = false;
                          _resolvedAccountName = null;
                          _nameController.clear();
                        });
                        if (val.length == 10 && _selectedBank != null) _verifyAccount();
                      },
                    ),

                    const SizedBox(height: 20),
                    Text('Account Name', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      readOnly: _verified,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: _verified ? 'Auto-verified' : 'Account name (auto-filled after verification)',
                        prefixIcon: Icon(_verified ? Icons.verified : Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: _verified
                            ? Colors.green.withOpacity(0.08)
                            : isDark
                                ? Colors.grey[850]
                                : Colors.grey[100],
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (_verified && !_isSaving) ? _saveBankAccount : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 22, height: 22, child: ApexLoading(size: 20))
                            : Text(
                                widget.isPostSignup ? 'Save & Continue' : 'Save Bank Account',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    if (widget.isPostSignup) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const SignatureScreen(isPostSignup: true)),
                              (route) => route.isFirst,
                            );
                          },
                          child: Text('Skip for now', style: TextStyle(color: Colors.grey[500])),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
