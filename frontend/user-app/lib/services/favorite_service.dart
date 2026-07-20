import 'api_client.dart';

class FavoriteModel {
  final String id;
  final String? propertyId;
  final String? userId;
  final String? createdAt;
  final Map<String, dynamic>? property;

  FavoriteModel({
    required this.id,
    this.propertyId,
    this.userId,
    this.createdAt,
    this.property,
  });

  factory FavoriteModel.fromJson(Map<String, dynamic> json) {
    return FavoriteModel(
      id: json['id']?.toString() ?? '',
      propertyId: json['property_id']?.toString(),
      userId: json['user_id']?.toString(),
      createdAt: json['created_at']?.toString(),
      property: json['property'] as Map<String, dynamic>?,
    );
  }
}

class FavoriteService {
  final ApiClient _client = ApiClient.instance;

  Future<Map<String, dynamic>> addFavorite(String propertyId) async {
    final response = await _client.post(
      '/favorites/',
      data: {'property_id': propertyId},
    );

    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  Future<void> removeFavorite(String propertyId) async {
    await _client.delete('/favorites/$propertyId');
  }

  Future<List<FavoriteModel>> getFavorites() async {
    final response = await _client.get('/favorites/');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .map((e) => FavoriteModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<bool> checkFavorited(String propertyId) async {
    final response = await _client.get('/favorites/check/$propertyId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data['is_favorited'] == true || data['favorited'] == true;
    }
    if (data is bool) return data;
    return false;
  }
}
