import 'api_client.dart';

class DashboardStats {
  final int? totalProperties;
  final int? activeBookings;
  final double? totalRevenue;
  final int? pendingApplications;
  final Map<String, dynamic>? additional;

  DashboardStats({
    this.totalProperties,
    this.activeBookings,
    this.totalRevenue,
    this.pendingApplications,
    this.additional,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalProperties: json['total_properties'] as int?,
      activeBookings: json['active_bookings'] as int?,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble(),
      pendingApplications: json['pending_applications'] as int?,
      additional: json,
    );
  }
}

class LandlordService {
  final ApiClient _client = ApiClient.instance;

  Future<DashboardStats> getDashboardStats() async {
    final response = await _client.get('/landlords/dashboard/stats');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return DashboardStats.fromJson(data);
  }
}
