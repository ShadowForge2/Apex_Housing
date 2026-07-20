import 'api_client.dart';

class ReportModel {
  final String id;
  final String? bookingId;
  final String? reportNumber;
  final String? propertyTitle;
  final String? propertyAddress;
  final String? bookingReference;
  final String? bookingStatus;
  final String? totalAmount;
  final String? securityDeposit;
  final String? serviceFee;
  final String? currency;
  final String? paymentReference;
  final String? paymentDate;
  final bool tenantSigned;
  final String? tenantSignedAt;
  final bool landlordSigned;
  final String? landlordSignedAt;
  final bool isFinalized;
  final bool isDownloaded;
  final int downloadCount;
  final String? createdAt;

  ReportModel({
    required this.id,
    this.bookingId,
    this.reportNumber,
    this.propertyTitle,
    this.propertyAddress,
    this.bookingReference,
    this.bookingStatus,
    this.totalAmount,
    this.securityDeposit,
    this.serviceFee,
    this.currency,
    this.paymentReference,
    this.paymentDate,
    this.tenantSigned = false,
    this.tenantSignedAt,
    this.landlordSigned = false,
    this.landlordSignedAt,
    this.isFinalized = false,
    this.isDownloaded = false,
    this.downloadCount = 0,
    this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString(),
      reportNumber: json['report_number']?.toString(),
      propertyTitle: json['property_title']?.toString(),
      propertyAddress: json['property_address']?.toString(),
      bookingReference: json['booking_reference']?.toString(),
      bookingStatus: json['booking_status']?.toString(),
      totalAmount: json['total_amount']?.toString(),
      securityDeposit: json['security_deposit']?.toString(),
      serviceFee: json['service_fee']?.toString(),
      currency: json['currency']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      paymentDate: json['payment_date']?.toString(),
      tenantSigned: json['tenant_signed'] == true,
      tenantSignedAt: json['tenant_signed_at']?.toString(),
      landlordSigned: json['landlord_signed'] == true,
      landlordSignedAt: json['landlord_signed_at']?.toString(),
      isFinalized: json['is_finalized'] == true,
      isDownloaded: json['is_downloaded'] == true,
      downloadCount: json['download_count'] ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'report_number': reportNumber,
      'property_title': propertyTitle,
      'property_address': propertyAddress,
      'booking_reference': bookingReference,
      'booking_status': bookingStatus,
      'total_amount': totalAmount,
      'security_deposit': securityDeposit,
      'service_fee': serviceFee,
      'currency': currency,
      'tenant_signed': tenantSigned,
      'landlord_signed': landlordSigned,
      'is_finalized': isFinalized,
      'created_at': createdAt,
    };
  }
}

class ReportService {
  final ApiClient _client = ApiClient.instance;

  Future<List<ReportModel>> listReports() async {
    final response = await _client.get('/reports/');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'];
    if (data is Map && data.containsKey('reports')) {
      final reports = data['reports'] as List;
      return reports.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is List) {
      return data.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<ReportModel> getReport(String reportId) async {
    final response = await _client.get('/reports/$reportId');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return ReportModel.fromJson(data);
  }

  Future<ReportModel> getReportByBooking(String bookingId) async {
    final response = await _client.get('/reports/booking/$bookingId');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return ReportModel.fromJson(data);
  }

  Future<ReportModel> generateReport(String bookingId) async {
    final response = await _client.post('/reports/generate/$bookingId');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return ReportModel.fromJson(data);
  }

  Future<String> downloadReport(String reportId) async {
    final response = await _client.get('/reports/$reportId/download');
    final body = response.data as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return data['html_content']?.toString() ?? '';
  }

  Future<void> signReport(String reportId, {String? signatureData}) async {
    await _client.post('/reports/$reportId/sign', data: {
      if (signatureData != null) 'signature_data': signatureData,
    });
  }
}
