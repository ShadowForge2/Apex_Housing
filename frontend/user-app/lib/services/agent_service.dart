import 'api_client.dart';
import 'property_service.dart';

class AgentProfile {
  final String userId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? agencyName;
  final String? bio;
  final int? totalListings;
  final double? rating;

  AgentProfile({
    required this.userId,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.agencyName,
    this.bio,
    this.totalListings,
    this.rating,
  });

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      userId: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      agencyName: json['agency_name']?.toString(),
      bio: json['bio']?.toString(),
      totalListings: json['total_listings'] as int?,
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class AgentService {
  final ApiClient _client = ApiClient.instance;

  Future<AgentProfile> getAgentProfile(String agentUserId) async {
    final response = await _client.get('/agents/$agentUserId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return AgentProfile.fromJson(data);
  }

  Future<PropertyListResponse> getAgentProperties(String agentUserId) async {
    final response = await _client.get('/agents/$agentUserId/properties');

    final body = response.data as Map<String, dynamic>;
    return PropertyListResponse.fromJson(body);
  }
}
