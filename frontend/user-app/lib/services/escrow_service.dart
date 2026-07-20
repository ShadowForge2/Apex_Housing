import 'api_client.dart';

class EscrowModel {
  final String id;
  final String? bookingId;
  final String? status;
  final double? amount;
  final String? currency;
  final String? fundedAt;
  final String? releasedAt;
  final String? createdAt;

  EscrowModel({
    required this.id,
    this.bookingId,
    this.status,
    this.amount,
    this.currency,
    this.fundedAt,
    this.releasedAt,
    this.createdAt,
  });

  factory EscrowModel.fromJson(Map<String, dynamic> json) {
    return EscrowModel(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString(),
      status: json['status']?.toString(),
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency']?.toString(),
      fundedAt: json['funded_at']?.toString(),
      releasedAt: json['released_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class EscrowService {
  final ApiClient _client = ApiClient.instance;

  Future<EscrowModel> getEscrowByBooking(String bookingId) async {
    final response = await _client.get('/escrow/booking/$bookingId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return EscrowModel.fromJson(data);
  }

  Future<EscrowModel> getEscrow(String escrowId) async {
    final response = await _client.get('/escrow/$escrowId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return EscrowModel.fromJson(data);
  }
}
