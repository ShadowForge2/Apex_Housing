import 'api_client.dart';

class BookingModel {
  final String id;
  final String? propertyId;
  final String? userId;
  final String? status;
  final String? moveInDate;
  final String? notes;
  final bool? termsAgreed;
  final String? createdAt;
  final int totalAmount;

  BookingModel({
    required this.id,
    this.propertyId,
    this.userId,
    this.status,
    this.moveInDate,
    this.notes,
    this.termsAgreed,
    this.createdAt,
    this.totalAmount = 0,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString(),
      userId: json['user_id']?.toString(),
      status: json['status']?.toString(),
      moveInDate: json['move_in_date']?.toString(),
      notes: json['notes']?.toString(),
      termsAgreed: json['terms_agreed'] as bool?,
      createdAt: json['created_at']?.toString(),
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
    );
  }
}

class BookingService {
  final ApiClient _client = ApiClient.instance;

  Future<List<BookingModel>> listBookings() async {
    final response = await _client.get('/bookings/');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<BookingModel> getBooking(String bookingId) async {
    final response = await _client.get('/bookings/$bookingId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }

  Future<BookingModel> createBooking({
    required String propertyId,
    String? moveInDate,
    String? notes,
    bool termsAgreed = false,
  }) async {
    final responseData = <String, dynamic>{
      'property_id': propertyId,
      'terms_agreed': termsAgreed,
    };
    if (moveInDate != null) responseData['move_in_date'] = moveInDate;
    if (notes != null) responseData['notes'] = notes;

    final response = await _client.post(
      '/bookings/',
      data: responseData,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }

  Future<BookingModel> confirmBooking(String bookingId) async {
    final response = await _client.post('/bookings/$bookingId/confirm');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }

  Future<BookingModel> cancelBooking(String bookingId, {String? reason}) async {
    final response = await _client.post(
      '/bookings/$bookingId/cancel',
      data: null,
      queryParameters: reason != null ? {'reason': reason} : null,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return BookingModel.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getBookingHistory(
      String bookingId) async {
    final response = await _client.get('/bookings/$bookingId/history');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }
}
