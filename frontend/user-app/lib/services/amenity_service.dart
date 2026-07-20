import 'api_client.dart';

class AmenityModel {
  final String id;
  final String? name;
  final String? icon;
  final String? category;

  AmenityModel({
    required this.id,
    this.name,
    this.icon,
    this.category,
  });

  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    return AmenityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      icon: json['icon']?.toString(),
      category: json['category']?.toString(),
    );
  }
}

class AmenityService {
  final ApiClient _client = ApiClient.instance;

  Future<List<AmenityModel>> listAmenities() async {
    final response = await _client.get('/amenities/');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .map((e) => AmenityModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
