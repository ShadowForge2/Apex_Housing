import 'api_client.dart';

class ReviewModel {
  final String id;
  final String? propertyId;
  final String? userId;
  final int? rating;
  final String? comment;
  final String? createdAt;

  ReviewModel({
    required this.id,
    this.propertyId,
    this.userId,
    this.rating,
    this.comment,
    this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString(),
      userId: json['user_id']?.toString(),
      rating: json['rating'] as int?,
      comment: json['comment']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ReviewService {
  final ApiClient _client = ApiClient.instance;

  Future<List<ReviewModel>> getPropertyReviews(String propertyId) async {
    final response = await _client.get('/reviews/property/$propertyId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<ReviewModel> createReview({
    required String propertyId,
    required int rating,
    String? comment,
  }) async {
    final responseData = <String, dynamic>{
      'property_id': propertyId,
      'rating': rating,
    };
    if (comment != null) responseData['comment'] = comment;

    final response = await _client.post(
      '/reviews/',
      data: responseData,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return ReviewModel.fromJson(data);
  }
}
