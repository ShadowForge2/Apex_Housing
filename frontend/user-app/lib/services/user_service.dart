import 'dart:io';
import 'package:dio/dio.dart' as dio;
import 'api_client.dart';

class UserProfile {
  final String id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? role;
  final String? bio;
  final String? profilePicture;
  final String? phoneNumber;
  final String? createdAt;

  UserProfile({
    required this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.role,
    this.bio,
    this.profilePicture,
    this.phoneNumber,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString(),
      firstName: profile?['first_name']?.toString() ?? json['first_name']?.toString(),
      lastName: profile?['last_name']?.toString() ?? json['last_name']?.toString(),
      role: json['role']?.toString(),
      bio: profile?['bio']?.toString() ?? json['bio']?.toString(),
      profilePicture: profile?['profile_picture']?.toString(),
      phoneNumber: profile?['phone_number']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class KycStatus {
  final String? status;
  final String? documentType;
  final String? documentUrl;
  final String? verifiedAt;
  final String? rejectionReason;

  KycStatus({
    this.status,
    this.documentType,
    this.documentUrl,
    this.verifiedAt,
    this.rejectionReason,
  });

  factory KycStatus.fromJson(Map<String, dynamic> json) {
    return KycStatus(
      status: json['status']?.toString(),
      documentType: json['document_type']?.toString(),
      documentUrl: json['document_url']?.toString(),
      verifiedAt: json['verified_at']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
    );
  }
}

class SessionModel {
  final String id;
  final String? ipAddress;
  final String? userAgent;
  final String? createdAt;
  final String? lastActive;

  SessionModel({
    required this.id,
    this.ipAddress,
    this.userAgent,
    this.createdAt,
    this.lastActive,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id']?.toString() ?? '',
      ipAddress: json['ip_address']?.toString(),
      userAgent: json['user_agent']?.toString(),
      createdAt: json['created_at']?.toString(),
      lastActive: json['last_active']?.toString(),
    );
  }
}

class SignatureModel {
  final String id;
  final String? data;
  final String? label;
  final String? createdAt;

  SignatureModel({
    required this.id,
    this.data,
    this.label,
    this.createdAt,
  });

  factory SignatureModel.fromJson(Map<String, dynamic> json) {
    return SignatureModel(
      id: json['id']?.toString() ?? '',
      data: json['signature_data']?.toString() ?? json['data']?.toString(),
      label: json['label']?.toString(),
      createdAt: json['signature_created_at']?.toString() ?? json['created_at']?.toString(),
    );
  }
}

class VerificationStatus {
  final bool isFullyActivated;
  final bool kycVerified;
  final String kycStatus;
  final String? kycRejectionReason;
  final bool hasSignature;
  final bool hasBankAccount;
  final String? nextStep;
  final int stepsCompleted;
  final int totalSteps;
  final int progressPercentage;

  VerificationStatus({
    required this.isFullyActivated,
    required this.kycVerified,
    required this.kycStatus,
    this.kycRejectionReason,
    required this.hasSignature,
    required this.hasBankAccount,
    this.nextStep,
    required this.stepsCompleted,
    required this.totalSteps,
    required this.progressPercentage,
  });

  factory VerificationStatus.fromJson(Map<String, dynamic> json) {
    return VerificationStatus(
      isFullyActivated: json['is_fully_activated'] == true,
      kycVerified: json['kyc_verified'] == true,
      kycStatus: json['kyc_status']?.toString() ?? 'not_started',
      kycRejectionReason: json['kyc_rejection_reason']?.toString(),
      hasSignature: json['has_signature'] == true,
      hasBankAccount: json['has_bank_account'] == true,
      nextStep: json['next_step']?.toString(),
      stepsCompleted: json['steps_completed'] ?? 0,
      totalSteps: json['total_steps'] ?? 3,
      progressPercentage: json['progress_percentage'] ?? 0,
    );
  }
}

class UserService {
  final ApiClient _client = ApiClient.instance;

  Future<UserProfile> getMyProfile() async {
    final response = await _client.get('/users/me');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? profilePicture,
    String? phoneNumber,
  }) async {
    final responseData = <String, dynamic>{};
    if (firstName != null) responseData['first_name'] = firstName;
    if (lastName != null) responseData['last_name'] = lastName;
    if (bio != null) responseData['bio'] = bio;
    if (profilePicture != null) responseData['profile_picture'] = profilePicture;
    if (phoneNumber != null) responseData['phone_number'] = phoneNumber;

    final response = await _client.put(
      '/users/me',
      data: responseData,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  Future<KycStatus> getKycStatus() async {
    final response = await _client.get('/users/kyc/status');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return KycStatus.fromJson(data);
  }

  Future<Map<String, dynamic>> submitKyc({
    required String documentType,
    required File file,
    required File selfie,
  }) async {
    final formData = dio.FormData.fromMap({
      'document_type': documentType,
      'file': await dio.MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
      'selfie': await dio.MultipartFile.fromFile(
        selfie.path,
        filename: selfie.path.split(Platform.pathSeparator).last,
      ),
    });

    final response = await _client.dio.post('/users/kyc', data: formData);

    final body = response.data as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>? ?? {};
  }

  Future<SignatureModel> getMySignature() async {
    final response = await _client.get('/users/me/signature');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return SignatureModel.fromJson(data);
  }

  Future<SignatureModel> saveSignature({
    required String signatureData,
    String? label,
  }) async {
    final responseData = <String, dynamic>{
      'signature_data': signatureData,
    };
    if (label != null) responseData['label'] = label;

    final response = await _client.post(
      '/users/me/signature',
      data: responseData,
    );

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return SignatureModel.fromJson(data);
  }

  Future<List<SessionModel>> listMySessions() async {
    final response = await _client.get('/users/me/sessions');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map) {
      final sessions = data['sessions'];
      if (sessions is List) {
        return sessions
            .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  Future<void> deleteSession(String sessionId) async {
    await _client.delete('/users/me/sessions/$sessionId');
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      '/users/me/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<UserProfile> getUserById(String userId) async {
    final response = await _client.get('/users/$userId');

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return UserProfile.fromJson(data);
  }

  Future<String> uploadProfilePicture(String filePath) async {
    final formData = dio.FormData.fromMap({
      'file': await dio.MultipartFile.fromFile(
        filePath,
        filename: filePath.split(Platform.pathSeparator).last,
      ),
    });

    final response = await _client.dio.post('/users/me/profile-picture', data: formData);

    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return data['profile_picture']?.toString() ?? '';
  }

  Future<void> updatePreference({bool? biometricEnabled}) async {
    final payload = <String, dynamic>{};
    if (biometricEnabled != null) payload['biometric_enabled'] = biometricEnabled;
    await _client.put('/users/me/preferences', data: payload);
  }

  Future<VerificationStatus> fetchVerificationStatus() async {
    final response = await _client.get('/users/me/verification-status');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return VerificationStatus.fromJson(data);
  }
}
