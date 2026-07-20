import 'api_client.dart';
import 'property_service.dart';

class LocationModel {
  final String id;
  final String? city;
  final String? state;
  final String? country;
  final int? propertyCount;

  LocationModel({
    required this.id,
    this.city,
    this.state,
    this.country,
    this.propertyCount,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id']?.toString() ?? '',
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      propertyCount: json['property_count'] as int?,
    );
  }
}

class PriceRange {
  final String label;
  final double? min;
  final double? max;

  PriceRange({
    required this.label,
    this.min,
    this.max,
  });

  factory PriceRange.fromJson(Map<String, dynamic> json) {
    return PriceRange(
      label: json['label']?.toString() ?? '',
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
    );
  }
}

class SearchService {
  final ApiClient _client = ApiClient.instance;

  Future<PropertyListResponse> searchProperties({
    String? query,
    String? state,
    String? city,
    String? area,
    double? minPrice,
    double? maxPrice,
    String? priceRange,
    String? propertyType,
    String? agentTags,
    List<String>? amenityIds,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? sortBy,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{};
    if (query != null) queryParams['q'] = query;
    if (state != null) queryParams['state'] = state;
    if (city != null) queryParams['city'] = city;
    if (area != null) queryParams['area'] = area;
    if (minPrice != null) queryParams['min_price'] = minPrice;
    if (maxPrice != null) queryParams['max_price'] = maxPrice;
    if (priceRange != null) queryParams['price_range'] = priceRange;
    if (propertyType != null) queryParams['property_type'] = propertyType;
    if (agentTags != null) queryParams['agent_tags'] = agentTags;
    if (amenityIds != null && amenityIds.isNotEmpty) {
      queryParams['amenity_ids'] = amenityIds;
    }
    if (latitude != null) queryParams['latitude'] = latitude;
    if (longitude != null) queryParams['longitude'] = longitude;
    if (radiusKm != null) queryParams['radius_km'] = radiusKm;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    queryParams['page'] = page;
    queryParams['page_size'] = pageSize;

    final response = await _client.get(
      '/search/properties',
      queryParameters: queryParams,
    );

    final body = response.data as Map<String, dynamic>;
    return PropertyListResponse.fromJson(body);
  }

  Future<List<LocationModel>> getLocations() async {
    final response = await _client.get('/search/locations');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .map((e) => LocationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPopularSearches() async {
    final response = await _client.get('/search/popular');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<PriceRange>> getPriceRanges() async {
    final response = await _client.get('/search/price-ranges');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data
          .map((e) => PriceRange.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
