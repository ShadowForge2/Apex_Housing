import 'package:dio/dio.dart';
import 'api_client.dart';
import 'exceptions.dart';

class AdminDashboardResponse {
  final int totalUsers;
  final int totalLandlords;
  final int totalTenants;
  final int totalProperties;
  final int totalBookings;
  final int activeBookings;
  final int pendingProperties;
  final int pendingKyc;
  final int openDisputes;
  final double totalRevenue;
  final int activeEscrowsCount;
  final List<dynamic> recentSignups;
  final int recentSignupsCount;
  final List<dynamic> activeEscrows;
  final List<Map<String, dynamic>> monthlyRevenue;
  final List<Map<String, dynamic>> recentActivity;

  AdminDashboardResponse({
    required this.totalUsers,
    required this.totalLandlords,
    required this.totalTenants,
    required this.totalProperties,
    required this.totalBookings,
    required this.activeBookings,
    required this.pendingProperties,
    required this.pendingKyc,
    required this.openDisputes,
    required this.totalRevenue,
    required this.activeEscrowsCount,
    required this.recentSignups,
    required this.recentSignupsCount,
    required this.activeEscrows,
    required this.monthlyRevenue,
    required this.recentActivity,
  });

  factory AdminDashboardResponse.fromJson(Map<String, dynamic> json) {
    final rawSignups = json['recent_signups'];
    List<dynamic> signupsList;
    int signupsCount;
    if (rawSignups is List) {
      signupsList = rawSignups;
      signupsCount = rawSignups.length;
    } else if (rawSignups is int) {
      signupsList = [];
      signupsCount = rawSignups;
    } else {
      signupsList = [];
      signupsCount = 0;
    }

    final rawEscrows = json['active_escrows'];
    List<dynamic> escrowsList;
    if (rawEscrows is List) {
      escrowsList = rawEscrows;
    } else {
      escrowsList = [];
    }

    final rawMonthly = json['monthly_revenue'];
    List<Map<String, dynamic>> monthlyList = [];
    if (rawMonthly is List) {
      monthlyList = rawMonthly.map<Map<String, dynamic>>((e) => {
        'month': e['month'] ?? '',
        'revenue': (e['revenue'] as num?)?.toDouble() ?? 0.0,
      }).toList();
    }

    final rawActivity = json['recent_activity'];
    List<Map<String, dynamic>> activityList = [];
    if (rawActivity is List) {
      activityList = rawActivity.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
    }

    return AdminDashboardResponse(
      totalUsers: json['total_users'] as int? ?? 0,
      totalLandlords: json['total_landlords'] as int? ?? 0,
      totalTenants: json['total_tenants'] as int? ?? 0,
      totalProperties: json['total_properties'] as int? ?? 0,
      totalBookings: json['total_bookings'] as int? ?? 0,
      activeBookings: json['active_bookings'] as int? ?? 0,
      pendingProperties: json['pending_properties'] as int? ?? 0,
      pendingKyc: json['pending_kyc'] as int? ?? 0,
      openDisputes: json['open_disputes'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      activeEscrowsCount: json['active_escrows_count'] as int? ?? 0,
      recentSignups: signupsList,
      recentSignupsCount: signupsCount,
      activeEscrows: escrowsList,
      monthlyRevenue: monthlyList,
      recentActivity: activityList,
    );
  }
}

class AdminService {
  final ApiClient _client = ApiClient.instance;

  Map<String, dynamic> _parseResponse(Response response) {
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      return body;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: body['message'] as String? ?? 'Operation failed',
      errors: body['errors'] as Map<String, dynamic>?,
    );
  }

  dynamic _getData(Response response) {
    final result = _parseResponse(response);
    return result['data'];
  }

  // Dashboard

  Future<AdminDashboardResponse> getDashboard() async {
    final response = await _client.get('/admin/dashboard');
    final data = _getData(response) as Map<String, dynamic>;
    return AdminDashboardResponse.fromJson(data);
  }

  // User Management

  Future<Map<String, dynamic>> listUsers({int page = 1}) async {
    final response =
        await _client.get('/admin/users', queryParameters: {'page': page});
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getUserDetail(String userId) async {
    final response = await _client.get('/admin/users/$userId');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> suspendUser(String userId) async {
    final response = await _client.put('/admin/users/$userId/suspend');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> activateUser(String userId) async {
    final response = await _client.put('/admin/users/$userId/activate');
    return _parseResponse(response);
  }

  // Property Management

  Future<Map<String, dynamic>> listPendingProperties() async {
    final response = await _client.get('/admin/properties/pending');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> approveProperty(
    String propertyId,
    bool approved, {
    String? rejectionReason,
  }) async {
    final data = <String, dynamic>{
      'property_id': propertyId,
      'approved': approved,
    };
    if (rejectionReason != null) {
      data['rejection_reason'] = rejectionReason;
    }
    final response = await _client.post('/admin/properties/approve', data: data);
    return _parseResponse(response);
  }

  // KYC Management

  Future<Map<String, dynamic>> listPendingKyc() async {
    final response = await _client.get('/admin/kyc/pending');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> approveKyc(
    String documentId,
    bool approved, {
    String? rejectionReason,
  }) async {
    final data = <String, dynamic>{
      'document_id': documentId,
      'approved': approved,
    };
    if (rejectionReason != null) {
      data['rejection_reason'] = rejectionReason;
    }
    final response = await _client.post('/admin/kyc/approve', data: data);
    return _parseResponse(response);
  }

  // Fraud Alerts

  Future<Map<String, dynamic>> getFraudAlerts() async {
    final response = await _client.get('/admin/fraud-alerts');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> updateFraudAlert(
    String alertId, {
    String? status,
  }) async {
    final data = <String, dynamic>{};
    if (status != null) {
      data['status'] = status;
    }
    final response =
        await _client.put('/admin/fraud-alerts/$alertId', data: data);
    return _parseResponse(response);
  }

  // Admin Management

  Future<Map<String, dynamic>> listAdmins() async {
    final response = await _client.get('/admin/admins');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> inviteAdmin(
    String email, {
    String role = 'ADMIN',
  }) async {
    final response = await _client.post('/admin/admins/invite', data: {
      'email': email,
      'role': role,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> removeAdmin(String userId) async {
    final response = await _client.delete('/admin/admins/$userId');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> updateAdminRole(
    String userId, {
    required String role,
  }) async {
    final response = await _client.post('/admin/admins/change-role', data: {
      'user_id': userId,
      'role': role,
    });
    return _parseResponse(response);
  }

  // Audit Logs

  Future<Map<String, dynamic>> listAuditLogs() async {
    final response = await _client.get('/admin/audit-logs');
    return _parseResponse(response);
  }

  // Bookings

  Future<Map<String, dynamic>> listBookings({String? status, int page = 1}) async {
    final params = <String, dynamic>{'page': page};
    if (status != null) params['status'] = status;
    final response = await _client.get('/admin/bookings', queryParameters: params);
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> resolveDispute(String bookingId, String resolution, {String? ruling}) async {
    final response = await _client.put('/admin/bookings/$bookingId/resolve', data: {
      'resolution': resolution,
      'ruling': ruling,
    });
    return _parseResponse(response);
  }

  // Transactions

  Future<Map<String, dynamic>> listTransactions({String? type, int page = 1}) async {
    final params = <String, dynamic>{'page': page};
    if (type != null) params['type'] = type;
    final response = await _client.get('/admin/transactions', queryParameters: params);
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getTransactionDetail(String transactionId) async {
    final response = await _client.get('/admin/transactions/$transactionId');
    return _parseResponse(response);
  }

  // Reports

  Future<Map<String, dynamic>> listReports({String? status, int page = 1}) async {
    final params = <String, dynamic>{'page': page};
    if (status != null) params['status'] = status;
    final response = await _client.get('/admin/reports', queryParameters: params);
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> updateReport(String reportId, {String? status, String? resolution}) async {
    final data = <String, dynamic>{};
    if (status != null) data['status'] = status;
    if (resolution != null) data['resolution'] = resolution;
    final response = await _client.put('/admin/reports/$reportId', data: data);
    return _parseResponse(response);
  }

  // Platform Settings

  Future<Map<String, dynamic>> getPlatformSettings() async {
    final response = await _client.get('/admin/settings');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> updatePlatformSettings({
    bool? autoApproveListings,
    bool? maintenanceMode,
    double? platformFeePercentage,
    int? minBookingAmount,
    double? tenantMarkupPercentage,
    double? agentMarkdownPercentage,
  }) async {
    final data = <String, dynamic>{};
    if (autoApproveListings != null) data['auto_approve_listings'] = autoApproveListings;
    if (maintenanceMode != null) data['maintenance_mode'] = maintenanceMode;
    if (platformFeePercentage != null) data['platform_fee_percentage'] = platformFeePercentage;
    if (minBookingAmount != null) data['min_booking_amount'] = minBookingAmount;
    if (tenantMarkupPercentage != null) data['tenant_markup_percentage'] = tenantMarkupPercentage;
    if (agentMarkdownPercentage != null) data['agent_markdown_percentage'] = agentMarkdownPercentage;
    final response = await _client.put('/admin/settings', data: data);
    return _parseResponse(response);
  }

  // Admin Group Chat

  Future<Map<String, dynamic>> getAdminGroupChat() async {
    final response = await _client.get('/admin/group-chat');
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getAdminGroupChatMessages({int page = 1, int pageSize = 50}) async {
    final response = await _client.get('/admin/group-chat/messages', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> sendGroupChatMessage(String content) async {
    final response = await _client.post('/admin/group-chat/message', data: {
      'content': content,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> addGroupChatMember(String userId) async {
    final response = await _client.post('/admin/group-chat/members', data: {
      'user_id': userId,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> removeGroupChatMember(String userId) async {
    final response = await _client.delete('/admin/group-chat/members/$userId');
    return _parseResponse(response);
  }

  // Notifications (admin receives these)

  Future<Map<String, dynamic>> getNotifications({int page = 1, int pageSize = 20}) async {
    final response = await _client.get('/notifications', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return _parseResponse(response);
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _client.put('/notifications/$notificationId/read');
  }

  Future<void> markAllNotificationsRead() async {
    await _client.put('/notifications/read-all');
  }

  // Broadcast announcements (super admin only)

  Future<Map<String, dynamic>> broadcastAnnouncement({
    required String title,
    required String message,
    List<String>? roles,
    bool sendEmail = false,
    String? emailSubject,
  }) async {
    final data = <String, dynamic>{
      'title': title,
      'message': message,
      'send_email': sendEmail,
    };
    if (roles != null) data['roles'] = roles;
    if (emailSubject != null) data['email_subject'] = emailSubject;
    final response = await _client.post('/admin/broadcast', data: data);
    return _parseResponse(response);
  }

  // Messages / Live Chat (complaint tickets)

  Future<Map<String, dynamic>> getConversations({int page = 1, int pageSize = 20}) async {
    final response = await _client.get('/messages/conversations', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> getConversationMessages(String conversationId, {int page = 1, int pageSize = 50}) async {
    final response = await _client.get('/messages/conversations/$conversationId/messages', queryParameters: {
      'page': page,
      'page_size': pageSize,
    });
    return _parseResponse(response);
  }

  Future<Map<String, dynamic>> sendMessage(String conversationId, String content, {String messageType = 'text'}) async {
    final response = await _client.post('/messages/messages', data: {
      'conversation_id': conversationId,
      'content': content,
      'message_type': messageType,
    });
    return _parseResponse(response);
  }
}
