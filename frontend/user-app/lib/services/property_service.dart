import 'api_client.dart';
import '../models/models.dart';

class PropertyModel {
  final String id;
  final String? landlordId;
  final String? agentId;
  final String title;
  final String slug;
  final String? description;
  final String? propertyType;
  final String? status;
  final List<PropertyImage> images;
  final PropertyLocation? location;
  final PropertyPricing? pricing;
  final PropertyAvailability? availability;
  final List<PropertyFeature> features;
  final List<PropertyAmenity> amenities;
  final String? createdAt;
  final double? distanceKm;

  PropertyModel({
    required this.id,
    this.landlordId,
    this.agentId,
    required this.title,
    required this.slug,
    this.description,
    this.propertyType,
    this.status,
    this.images = const [],
    this.location,
    this.pricing,
    this.availability,
    this.features = const [],
    this.amenities = const [],
    this.createdAt,
    this.distanceKm,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    final isSearchResult = json.containsKey('rent_amount') || json.containsKey('front_image');

    List<PropertyImage> images;
    if (isSearchResult) {
      final frontImg = json['front_image']?.toString();
      images = frontImg != null && frontImg.isNotEmpty
          ? [PropertyImage(id: '0', url: frontImg, label: 'front', isPrimary: true)]
          : [];
    } else {
      images = (json['images'] as List<dynamic>?)
              ?.map((e) => PropertyImage.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    }

    PropertyLocation? location;
    if (isSearchResult) {
      if (json['latitude'] != null || json['city'] != null) {
        location = PropertyLocation(
          id: json['id']?.toString() ?? '',
          address: json['address']?.toString(),
          city: json['city']?.toString(),
          state: json['state']?.toString(),
          country: json['country']?.toString(),
          latitude: (json['latitude'] as num?)?.toDouble(),
          longitude: (json['longitude'] as num?)?.toDouble(),
        );
      }
    } else {
      location = json['location'] != null
          ? PropertyLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null;
    }

    PropertyPricing? pricing;
    if (isSearchResult) {
      if (json['rent_amount'] != null) {
        pricing = PropertyPricing(
          id: json['id']?.toString() ?? '',
          rentAmount: (json['rent_amount'] as num?)?.toDouble(),
          securityDeposit: (json['security_deposit'] as num?)?.toDouble(),
          serviceFee: 0,
          currency: json['currency']?.toString(),
        );
      }
    } else {
      pricing = json['pricing'] != null
          ? PropertyPricing.fromJson(json['pricing'] as Map<String, dynamic>)
          : null;
    }

    PropertyAvailability? availability;
    if (!isSearchResult) {
      availability = json['availability'] != null
          ? PropertyAvailability.fromJson(json['availability'] as Map<String, dynamic>)
          : null;
    }

    return PropertyModel(
      id: json['id']?.toString() ?? '',
      landlordId: json['landlord_id']?.toString(),
      agentId: json['agent_id']?.toString(),
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      propertyType: (json['property_type'] ?? json['type'])?.toString(),
      status: json['status']?.toString(),
      images: images,
      location: location,
      pricing: pricing,
      availability: availability,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => PropertyFeature.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      amenities: (json['amenities'] as List<dynamic>?)
              ?.map((e) => PropertyAmenity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at']?.toString(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }

  Property toProperty() {
    String _featureValue(String name) {
      final matches = features.where((f) => f.featureName?.toLowerCase() == name);
      return matches.isNotEmpty ? (matches.first.featureValue ?? '0') : '0';
    }

    return Property(
      id: id,
      title: title,
      slug: slug,
      description: description ?? '',
      type: propertyType ?? '',
      city: location?.city ?? '',
      state: location?.state ?? '',
      address: location?.address ?? '',
      rentAmount: pricing?.rentAmount?.toInt() ?? 0,
      securityDeposit: pricing?.securityDeposit?.toInt() ?? 0,
      serviceFee: pricing?.serviceFee?.toInt() ?? 0,
      tenantPrice: (pricing?.rentAmount?.toInt() ?? 0) + (pricing?.serviceFee?.toInt() ?? 0),
      currency: pricing?.currency ?? 'NGN',
      bedrooms: int.tryParse(_featureValue('bedrooms')) ?? 0,
      bathrooms: int.tryParse(_featureValue('bathrooms')) ?? 0,
      images: images.map((img) => img.url).where((url) => url.isNotEmpty).toList(),
      features: features.map((f) => '${f.featureName ?? ''}${f.featureValue != null ? ': ${f.featureValue}' : ''}').where((s) => s.isNotEmpty).toList(),
      amenities: amenities.map((a) => a.name ?? '').where((s) => s.isNotEmpty).toList(),
      agentName: agentId ?? 'Agent',
      agentAgency: 'APEX Housing',
      agentRating: 0.0,
      agentListings: 0,
      availabilityFrom: availability?.availableFrom ?? '',
      availabilityUntil: availability?.availableUntil ?? '',
      planType: availability?.planType ?? 'Monthly',
      isAvailable: availability?.isAvailable ?? true,
      isBooked: availability?.isBooked ?? false,
      latitude: location?.latitude,
      longitude: location?.longitude,
      distanceKm: distanceKm,
      landlordId: landlordId,
    );
  }
}

class PropertyImage {
  final String id;
  final String url;
  final String? label;
  final bool isPrimary;
  final int sortOrder;

  PropertyImage({
    required this.id,
    required this.url,
    this.label,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  factory PropertyImage.fromJson(Map<String, dynamic> json) {
    return PropertyImage(
      id: json['id']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      label: json['label']?.toString(),
      isPrimary: json['is_primary'] == true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

class PropertyLocation {
  final String id;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;

  PropertyLocation({
    required this.id,
    this.address,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
  });

  factory PropertyLocation.fromJson(Map<String, dynamic> json) {
    return PropertyLocation(
      id: json['id']?.toString() ?? '',
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class PropertyPricing {
  final String id;
  final double? rentAmount;
  final double? securityDeposit;
  final double? serviceFee;
  final String? currency;

  PropertyPricing({
    required this.id,
    this.rentAmount,
    this.securityDeposit,
    this.serviceFee,
    this.currency,
  });

  factory PropertyPricing.fromJson(Map<String, dynamic> json) {
    return PropertyPricing(
      id: json['id']?.toString() ?? '',
      rentAmount: (json['rent_amount'] as num?)?.toDouble(),
      securityDeposit: (json['security_deposit'] as num?)?.toDouble(),
      serviceFee: (json['service_fee'] as num?)?.toDouble(),
      currency: json['currency']?.toString(),
    );
  }
}

class PropertyAvailability {
  final String id;
  final bool isAvailable;
  final String? availableFrom;
  final String? availableUntil;
  final String? planType;
  final bool isBooked;

  PropertyAvailability({
    required this.id,
    this.isAvailable = true,
    this.availableFrom,
    this.availableUntil,
    this.planType,
    this.isBooked = false,
  });

  factory PropertyAvailability.fromJson(Map<String, dynamic> json) {
    return PropertyAvailability(
      id: json['id']?.toString() ?? '',
      isAvailable: json['is_available'] == true,
      availableFrom: json['available_from']?.toString(),
      availableUntil: json['available_until']?.toString(),
      planType: json['plan_type']?.toString(),
      isBooked: json['is_booked'] == true,
    );
  }
}

class PropertyFeature {
  final String id;
  final String? featureName;
  final String? featureValue;

  PropertyFeature({
    required this.id,
    this.featureName,
    this.featureValue,
  });

  factory PropertyFeature.fromJson(Map<String, dynamic> json) {
    return PropertyFeature(
      id: json['id']?.toString() ?? '',
      featureName: json['feature_name']?.toString(),
      featureValue: json['feature_value']?.toString(),
    );
  }
}

class PropertyAmenity {
  final String id;
  final String? name;
  final String? icon;
  final String? category;

  PropertyAmenity({
    required this.id,
    this.name,
    this.icon,
    this.category,
  });

  factory PropertyAmenity.fromJson(Map<String, dynamic> json) {
    return PropertyAmenity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      icon: json['icon']?.toString(),
      category: json['category']?.toString(),
    );
  }
}

class PropertyListResponse {
  final List<PropertyModel> items;
  final int total;
  final int page;
  final int pageSize;

  PropertyListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory PropertyListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final rawItems = data['properties'] ?? data['items'] ?? data['results'];
      return PropertyListResponse(
        items: (rawItems as List<dynamic>?)
                ?.map((e) =>
                    PropertyModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        total: data['total'] as int? ?? 0,
        page: data['page'] as int? ?? 1,
        pageSize: data['page_size'] as int? ?? 20,
      );
    }
    if (data is List<dynamic>) {
      return PropertyListResponse(
        items: data
            .map((e) => PropertyModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: data.length,
        page: 1,
        pageSize: 20,
      );
    }
    return PropertyListResponse(items: [], total: 0, page: 1, pageSize: 20);
  }
}

class PropertyService {
  final ApiClient _client = ApiClient.instance;

  Future<PropertyListResponse> listProperties({
    int page = 1,
    int pageSize = 20,
    String? city,
    String? state,
    String? propertyType,
    String? status,
    String? landlordId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (city != null) queryParams['city'] = city;
    if (state != null) queryParams['state'] = state;
    if (propertyType != null) queryParams['property_type'] = propertyType;
    if (status != null) queryParams['status'] = status;
    if (landlordId != null) queryParams['landlord_id'] = landlordId;
    if (minPrice != null) queryParams['min_price'] = minPrice;
    if (maxPrice != null) queryParams['max_price'] = maxPrice;

    final response = await _client.get(
      '/properties/',
      queryParameters: queryParams,
    );

    final body = response.data as Map<String, dynamic>;
    return PropertyListResponse.fromJson(body);
  }

  Future<PropertyModel> getProperty(String propertyId) async {
    final response = await _client.get('/properties/$propertyId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return PropertyModel.fromJson(data);
  }

  Future<PropertyModel> getPropertyBySlug(String slug) async {
    final response = await _client.get('/properties/slug/$slug');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return PropertyModel.fromJson(data);
  }

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

  Future<List<Map<String, dynamic>>> getPopularSearches() async {
    final response = await _client.get('/search/popular');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPriceRanges() async {
    final response = await _client.get('/search/price-ranges');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<PropertyModel> createProperty({
    required String title,
    String? description,
    String? propertyType,
    String? address,
    String? city,
    String? state,
    double? rentAmount,
    double? securityDeposit,
    double? serviceFee,
    String? agentTerms,
    List<String>? amenityIds,
  }) async {
    final responseData = <String, dynamic>{
      'title': title,
    };
    if (description != null) responseData['description'] = description;
    if (propertyType != null) responseData['property_type'] = propertyType;
    if (agentTerms != null) responseData['agent_terms'] = agentTerms;
    if (address != null || city != null || state != null) {
      responseData['location'] = {
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
      };
    }
    if (rentAmount != null || securityDeposit != null || serviceFee != null) {
      responseData['pricing'] = {
        if (rentAmount != null) 'rent_amount': rentAmount,
        if (securityDeposit != null) 'security_deposit': securityDeposit,
        if (serviceFee != null) 'service_fee': serviceFee,
      };
    }
    if (amenityIds != null) responseData['amenity_ids'] = amenityIds;

    final response = await _client.post('/properties/', data: responseData);
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return PropertyModel.fromJson(data);
  }

  Future<PropertyModel> updateProperty(
    String propertyId, {
    String? title,
    String? description,
    String? propertyType,
    String? status,
    String? address,
    String? city,
    String? state,
    double? rentAmount,
    double? securityDeposit,
    double? serviceFee,
    List<String>? amenityIds,
  }) async {
    final responseData = <String, dynamic>{};
    if (title != null) responseData['title'] = title;
    if (description != null) responseData['description'] = description;
    if (propertyType != null) responseData['property_type'] = propertyType;
    if (status != null) responseData['status'] = status;
    if (address != null || city != null || state != null) {
      responseData['location'] = {
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
      };
    }
    if (rentAmount != null || securityDeposit != null || serviceFee != null) {
      responseData['pricing'] = {
        if (rentAmount != null) 'rent_amount': rentAmount,
        if (securityDeposit != null) 'security_deposit': securityDeposit,
        if (serviceFee != null) 'service_fee': serviceFee,
      };
    }
    if (amenityIds != null) responseData['amenity_ids'] = amenityIds;

    final response = await _client.put('/properties/$propertyId', data: responseData);
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return PropertyModel.fromJson(data);
  }

  Future<void> deleteProperty(String propertyId) async {
    await _client.delete('/properties/$propertyId');
  }

  Future<void> deletePropertyImage(String propertyId, String imageId) async {
    await _client.delete('/properties/$propertyId/images/$imageId');
  }
}
