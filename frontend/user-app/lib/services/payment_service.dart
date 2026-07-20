import 'api_client.dart';

class WalletModel {
  final String? id;
  final String? userId;
  final num balance;
  final num pendingBalance;
  final String currency;
  final num totalEarned;
  final num totalWithdrawn;

  WalletModel({
    this.id,
    this.userId,
    this.balance = 0,
    this.pendingBalance = 0,
    this.currency = 'NGN',
    this.totalEarned = 0,
    this.totalWithdrawn = 0,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString(),
      balance: json['balance'] ?? 0,
      pendingBalance: json['pending_balance'] ?? 0,
      currency: json['currency'] ?? 'NGN',
      totalEarned: json['total_earned'] ?? 0,
      totalWithdrawn: json['total_withdrawn'] ?? 0,
    );
  }
}

class TransactionModel {
  final String? id;
  final String? escrowId;
  final String? bookingId;
  final String? type;
  final num amount;
  final String currency;
  final String status;
  final String? paymentMethod;
  final String? paymentGateway;
  final String? reference;
  final String? description;
  final bool isRefundable;
  final String? createdAt;

  TransactionModel({
    this.id,
    this.escrowId,
    this.bookingId,
    this.type,
    this.amount = 0,
    this.currency = 'NGN',
    this.status = 'PENDING',
    this.paymentMethod,
    this.paymentGateway,
    this.reference,
    this.description,
    this.isRefundable = false,
    this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString(),
      escrowId: json['escrow_id']?.toString(),
      bookingId: json['booking_id']?.toString(),
      type: json['payment_type']?.toString(),
      amount: json['amount'] ?? 0,
      currency: json['currency'] ?? 'NGN',
      status: json['status'] ?? 'PENDING',
      paymentMethod: json['payment_method']?.toString(),
      paymentGateway: json['payment_gateway']?.toString(),
      reference: json['gateway_reference']?.toString(),
      description: json['description']?.toString(),
      isRefundable: json['is_refundable'] ?? false,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class PaymentService {
  final ApiClient _api = ApiClient.instance;

  Future<WalletModel> getWallet() async {
    final response = await _api.get('/payments/wallet');
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return WalletModel.fromJson(Map<String, dynamic>.from(data['data']));
    }
    return WalletModel();
  }

  Future<List<TransactionModel>> listTransactions({int page = 1, int pageSize = 50}) async {
    final response = await _api.get('/payments/transactions', queryParameters: {'page': page, 'page_size': pageSize});
    final data = response.data;
    if (data is Map && data['data'] is Map && data['data']['transactions'] is List) {
      return (data['data']['transactions'] as List)
          .map((t) => TransactionModel.fromJson(Map<String, dynamic>.from(t)))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> listBanks() async {
    final response = await _api.get('/payments/banks');
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> verifyBankAccount(String accountNumber, String bankCode) async {
    final response = await _api.post('/payments/bank-accounts/verify', data: {
      'account_number': accountNumber,
      'bank_code': bankCode,
    });
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'verified': false};
  }

  Future<Map<String, dynamic>> addBankAccount({
    required String bankName,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    bool isDefault = true,
  }) async {
    final response = await _api.post('/payments/bank-accounts', data: {
      'bank_name': bankName,
      'bank_code': bankCode,
      'account_number': accountNumber,
      'account_name': accountName,
      'is_default': isDefault,
    });
    return response.data is Map ? Map<String, dynamic>.from(response.data) : {};
  }

  Future<List<Map<String, dynamic>>> listMyBankAccounts() async {
    final response = await _api.get('/payments/bank-accounts');
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<void> deleteBankAccount(String accountId) async {
    await _api.delete('/payments/bank-accounts/$accountId');
  }

  Future<Map<String, dynamic>> requestWithdrawal({
    required String bankAccountId,
    required double amount,
  }) async {
    final response = await _api.post('/payments/withdraw', data: {
      'bank_account_id': bankAccountId,
      'amount': amount,
    });
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {};
  }

  Future<Map<String, dynamic>> listWithdrawals({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (status != null) params['status'] = status;
    final response = await _api.get('/payments/withdrawals', queryParameters: params);
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'total': 0, 'withdrawals': []};
  }

  Future<Map<String, dynamic>> cancelWithdrawal(String withdrawalId) async {
    final response = await _api.post('/payments/withdraw/$withdrawalId/cancel');
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {};
  }

  Future<Map<String, dynamic>> checkBusinessDay() async {
    final response = await _api.get('/payments/business-days/check');
    final data = response.data;
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data']);
    }
    return {'can_withdraw': true};
  }
}
